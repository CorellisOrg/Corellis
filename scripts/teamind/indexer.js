#!/usr/bin/env node
/**
 * Teamind Indexer — Fetch Slack channel history, embed, summarize threads.
 *
 * Usage:
 *   node indexer.js                              # incremental, all channels
 *   node indexer.js --channel C0XXXXXXX        # specific channel
 *   node indexer.js --full                        # full re-index
 *   node indexer.js --hours 48                    # last 48h only
 *   node indexer.js --add-channel C0XXX general   # register a new channel
 *   node indexer.js --dry-run                     # preview without writing
 *
 * Required env vars:
 *   SLACK_BOT_TOKEN  — Slack bot token (xoxb-...)
 *   EMBEDDING_PROVIDER — "openai" | "gemini" | "local" (default: openai)
 *   OPENAI_API_KEY / GEMINI_API_KEY — for embedding
 *   LLM_PROVIDER — "anthropic" | "openai" | "bedrock" (for thread summaries)
 *   ANTHROPIC_API_KEY / OPENAI_API_KEY / AWS credentials — for summaries
 *
 * Optional:
 *   DB_PATH          — SQLite database path (default: ./teamind.db)
 *   EMBEDDING_MODEL  — model name (default: text-embedding-3-small)
 *   EMBEDDING_DIM    — dimensions (default: 1536)
 *   SUMMARY_MODEL    — LLM for summaries (default: claude-sonnet-4-20250514)
 *   BATCH_SIZE       — messages per embedding batch (default: 50)
 */

const Database = require('better-sqlite3');
const path = require('path');
const https = require('https');
const http = require('http');

// --- Config ---
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'teamind.db');
const SLACK_TOKEN = process.env.SLACK_BOT_TOKEN;
const EMBEDDING_PROVIDER = process.env.EMBEDDING_PROVIDER || 'openai';
const EMBEDDING_MODEL = process.env.EMBEDDING_MODEL || 'text-embedding-3-small';
const EMBEDDING_DIM = parseInt(process.env.EMBEDDING_DIM || '1536');
const SUMMARY_MODEL = process.env.SUMMARY_MODEL || 'claude-sonnet-4-20250514';
const LLM_PROVIDER = process.env.LLM_PROVIDER || 'anthropic';
const BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '50');

const args = process.argv.slice(2);
const FULL_REINDEX = args.includes('--full');
const DRY_RUN = args.includes('--dry-run');
const HOURS = parseInt(args[args.indexOf('--hours') + 1]) || null;
const TARGET_CHANNEL = args[args.indexOf('--channel') + 1] || null;
const ADD_CHANNEL_ID = args.includes('--add-channel') ? args[args.indexOf('--add-channel') + 1] : null;
const ADD_CHANNEL_NAME = args.includes('--add-channel') ? args[args.indexOf('--add-channel') + 2] : null;

// --- Helpers ---
function jsonRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const client = parsedUrl.protocol === 'https:' ? https : http;
    const req = client.request(parsedUrl, {
      method: options.method || 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve(data); }
      });
    });
    req.on('error', reject);
    if (options.body) req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    req.end();
  });
}

function float32ToBuffer(arr) {
  const buf = Buffer.alloc(arr.length * 4);
  for (let i = 0; i < arr.length; i++) buf.writeFloatLE(arr[i], i * 4);
  return buf;
}

function bufferToFloat32(buf) {
  const arr = new Float32Array(buf.length / 4);
  for (let i = 0; i < arr.length; i++) arr[i] = buf.readFloatLE(i * 4);
  return arr;
}

async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// --- Slack API ---
async function slackApi(method, params = {}) {
  const url = new URL(`https://slack.com/api/${method}`);
  Object.entries(params).forEach(([k, v]) => { if (v !== undefined) url.searchParams.set(k, v); });
  const res = await jsonRequest(url.toString(), {
    headers: { 'Authorization': `Bearer ${SLACK_TOKEN}` }
  });
  if (!res.ok) throw new Error(`Slack API ${method} failed: ${res.error}`);
  return res;
}

async function fetchChannelHistory(channelId, oldest) {
  const messages = [];
  let cursor;
  do {
    const res = await slackApi('conversations.history', {
      channel: channelId, limit: 200, oldest, cursor
    });
    messages.push(...(res.messages || []));
    cursor = res.response_metadata?.next_cursor;
    if (cursor) await sleep(1200); // rate limit
  } while (cursor);
  return messages.sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));
}

async function fetchThreadReplies(channelId, threadTs) {
  const messages = [];
  let cursor;
  do {
    const res = await slackApi('conversations.replies', {
      channel: channelId, ts: threadTs, limit: 200, cursor
    });
    messages.push(...(res.messages || []));
    cursor = res.response_metadata?.next_cursor;
    if (cursor) await sleep(1200);
  } while (cursor);
  return messages.sort((a, b) => parseFloat(a.ts) - parseFloat(b.ts));
}

// --- Embedding ---
async function embedTexts(texts) {
  if (texts.length === 0) return [];

  if (EMBEDDING_PROVIDER === 'openai') {
    const res = await jsonRequest('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` },
      body: { model: EMBEDDING_MODEL, input: texts, dimensions: EMBEDDING_DIM }
    });
    return res.data.map(d => d.embedding);
  }

  if (EMBEDDING_PROVIDER === 'gemini') {
    // Gemini batch embedding
    const res = await jsonRequest(
      `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL || 'text-embedding-004'}:batchEmbedContents?key=${process.env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        body: {
          requests: texts.map(text => ({
            model: `models/${EMBEDDING_MODEL || 'text-embedding-004'}`,
            content: { parts: [{ text }] },
          }))
        }
      }
    );
    return res.embeddings.map(e => e.values);
  }

  throw new Error(`Unknown EMBEDDING_PROVIDER: ${EMBEDDING_PROVIDER}`);
}

// --- LLM Summary ---
async function summarizeThread(messages) {
  const conversation = messages
    .map(m => `[${m.username || m.user_id || 'unknown'}] ${m.text}`)
    .join('\n');

  const prompt = `Analyze this Slack thread conversation and return a JSON object with:
- "title": concise title (1 line)
- "summary": 2-3 sentence summary of what was discussed and concluded
- "thread_type": one of: decision, bug_fix, brainstorm, status_update, qa, casual, announcement
- "key_points": array of specific conclusions, decisions, or technical details
- "participants": array of {name, role} where role is their contribution
- "open_items": array of {item, assignee, deadline} for unresolved items (null if not stated)

Conversation:
${conversation.slice(0, 8000)}

Return ONLY valid JSON, no markdown wrapping.`;

  if (LLM_PROVIDER === 'anthropic') {
    const Anthropic = require('@anthropic-ai/sdk');
    const client = new Anthropic.default();
    const resp = await client.messages.create({
      model: SUMMARY_MODEL,
      max_tokens: 1024,
      messages: [{ role: 'user', content: prompt }],
    });
    return JSON.parse(resp.content[0].text);
  }

  if (LLM_PROVIDER === 'openai') {
    const res = await jsonRequest('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` },
      body: {
        model: SUMMARY_MODEL || 'gpt-4o-mini',
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' },
      }
    });
    return JSON.parse(res.choices[0].message.content);
  }

  throw new Error(`Unknown LLM_PROVIDER: ${LLM_PROVIDER}`);
}

// --- Main ---
async function main() {
  if (!SLACK_TOKEN) { console.error('❌ Missing SLACK_BOT_TOKEN'); process.exit(1); }

  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

  // Handle --add-channel
  if (ADD_CHANNEL_ID) {
    db.prepare('INSERT OR IGNORE INTO channels (channel_id, channel_name) VALUES (?, ?)')
      .run(ADD_CHANNEL_ID, ADD_CHANNEL_NAME || ADD_CHANNEL_ID);
    console.log(`✅ Added channel ${ADD_CHANNEL_ID} (${ADD_CHANNEL_NAME || 'unnamed'})`);
    db.close();
    return;
  }

  // Get channels to index
  let channels = db.prepare('SELECT * FROM channels').all();
  if (TARGET_CHANNEL) {
    channels = channels.filter(c => c.channel_id === TARGET_CHANNEL);
    if (channels.length === 0) {
      console.error(`❌ Channel ${TARGET_CHANNEL} not registered. Use --add-channel first.`);
      process.exit(1);
    }
  }

  if (channels.length === 0) {
    console.log('⚠️  No channels registered. Use: node indexer.js --add-channel <CHANNEL_ID> <name>');
    db.close();
    return;
  }

  console.log(`🧠 Teamind Indexer — ${FULL_REINDEX ? 'FULL' : 'incremental'} mode`);
  console.log(`   Database: ${DB_PATH}`);
  console.log(`   Channels: ${channels.map(c => c.channel_name || c.channel_id).join(', ')}`);
  console.log(`   Embedding: ${EMBEDDING_PROVIDER} / ${EMBEDDING_MODEL} (${EMBEDDING_DIM}d)`);
  console.log(`   LLM: ${LLM_PROVIDER} / ${SUMMARY_MODEL}`);
  console.log(`   Dry run: ${DRY_RUN}`);
  console.log();

  const insertMsg = db.prepare(`
    INSERT OR REPLACE INTO messages (channel_id, thread_ts, message_ts, user_id, username, text, created_at, embedding)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const insertThread = db.prepare(`
    INSERT OR REPLACE INTO thread_summaries 
    (channel_id, thread_ts, title, summary, thread_type, key_points, participants, open_items, msg_count, created_at, last_msg_at, embedding)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const updateState = db.prepare(`
    INSERT OR REPLACE INTO index_state (channel_id, last_ts, last_run) VALUES (?, ?, datetime('now'))
  `);

  let totalMessages = 0;
  let totalThreads = 0;

  for (const channel of channels) {
    console.log(`📡 Indexing #${channel.channel_name || channel.channel_id}...`);

    // Determine start point
    let oldest;
    if (FULL_REINDEX) {
      oldest = '0';
    } else if (HOURS) {
      oldest = String(Date.now() / 1000 - HOURS * 3600);
    } else {
      const state = db.prepare('SELECT last_ts FROM index_state WHERE channel_id = ?').get(channel.channel_id);
      oldest = state?.last_ts || '0';
    }

    // Fetch messages
    const history = await fetchChannelHistory(channel.channel_id, oldest);
    console.log(`   Fetched ${history.length} messages (since ${oldest === '0' ? 'beginning' : new Date(parseFloat(oldest) * 1000).toISOString()})`);

    if (history.length === 0) continue;

    // Group by thread
    const threads = new Map(); // thread_ts → messages[]
    const standalone = [];     // non-thread messages

    for (const msg of history) {
      if (msg.thread_ts && msg.thread_ts !== msg.ts) {
        // Reply in a thread — we'll fetch full thread later
        if (!threads.has(msg.thread_ts)) threads.set(msg.thread_ts, []);
      } else if (msg.thread_ts === msg.ts && msg.reply_count > 0) {
        // Thread parent
        if (!threads.has(msg.thread_ts)) threads.set(msg.thread_ts, []);
      } else {
        standalone.push(msg);
      }
    }

    // Fetch full thread replies
    console.log(`   Found ${threads.size} active threads, fetching replies...`);
    for (const threadTs of threads.keys()) {
      const replies = await fetchThreadReplies(channel.channel_id, threadTs);
      threads.set(threadTs, replies);
      await sleep(500); // be gentle with rate limits
    }

    // Embed standalone messages in batches
    const allMessages = [...standalone];
    for (const msgs of threads.values()) allMessages.push(...msgs);

    console.log(`   Embedding ${allMessages.length} messages...`);
    for (let i = 0; i < allMessages.length; i += BATCH_SIZE) {
      const batch = allMessages.slice(i, i + BATCH_SIZE);
      const texts = batch.map(m => m.text || '').filter(t => t.length > 0);
      if (texts.length === 0) continue;

      const embeddings = await embedTexts(texts);

      if (!DRY_RUN) {
        let embedIdx = 0;
        for (const msg of batch) {
          if (!msg.text || msg.text.length === 0) continue;
          const tsDate = new Date(parseFloat(msg.ts) * 1000).toISOString();
          insertMsg.run(
            channel.channel_id,
            msg.thread_ts || null,
            msg.ts,
            msg.user,
            msg.user_profile?.display_name || msg.user_profile?.real_name || msg.user || null,
            msg.text,
            tsDate,
            float32ToBuffer(embeddings[embedIdx])
          );
          embedIdx++;
        }
      }
      totalMessages += texts.length;
      process.stdout.write(`   Embedded ${Math.min(i + BATCH_SIZE, allMessages.length)}/${allMessages.length}\r`);
      await sleep(200);
    }
    console.log();

    // Summarize threads with ≥3 messages
    const threadEntries = [...threads.entries()].filter(([, msgs]) => msgs.length >= 3);
    console.log(`   Summarizing ${threadEntries.length} threads (≥3 messages)...`);

    for (const [threadTs, msgs] of threadEntries) {
      try {
        const summary = await summarizeThread(msgs.map(m => ({
          username: m.user_profile?.display_name || m.user_profile?.real_name || m.user,
          user_id: m.user,
          text: m.text
        })));

        // Embed the summary
        const [summaryEmbedding] = await embedTexts([`${summary.title}\n${summary.summary}\n${(summary.key_points || []).join('\n')}`]);

        const firstTs = new Date(parseFloat(threadTs) * 1000).toISOString();
        const lastTs = new Date(parseFloat(msgs[msgs.length - 1].ts) * 1000).toISOString();

        if (!DRY_RUN) {
          insertThread.run(
            channel.channel_id, threadTs,
            summary.title, summary.summary, summary.thread_type,
            JSON.stringify(summary.key_points || []),
            JSON.stringify(summary.participants || []),
            JSON.stringify(summary.open_items || []),
            msgs.length, firstTs, lastTs,
            float32ToBuffer(summaryEmbedding)
          );
        }
        totalThreads++;
        process.stdout.write(`   Summarized ${totalThreads}/${threadEntries.length}\r`);
        await sleep(1000); // LLM rate limit
      } catch (err) {
        console.error(`   ⚠️  Failed to summarize thread ${threadTs}: ${err.message}`);
      }
    }
    console.log();

    // Update cursor
    if (!DRY_RUN && history.length > 0) {
      const lastTs = history[history.length - 1].ts;
      updateState.run(channel.channel_id, lastTs);
      db.prepare('UPDATE channels SET last_indexed = datetime(?) WHERE channel_id = ?')
        .run('now', channel.channel_id);
    }
  }

  console.log(`\n✅ Done! Indexed ${totalMessages} messages, ${totalThreads} thread summaries`);

  // Print stats
  const stats = {
    channels: db.prepare('SELECT COUNT(*) as n FROM channels').get().n,
    messages: db.prepare('SELECT COUNT(*) as n FROM messages').get().n,
    threads: db.prepare('SELECT COUNT(*) as n FROM thread_summaries').get().n,
  };
  console.log(`   Total in DB: ${stats.channels} channels, ${stats.messages} messages, ${stats.threads} threads`);

  db.close();
}

main().catch(err => { console.error('❌ Fatal:', err); process.exit(1); });
