#!/usr/bin/env node
/**
 * Teamind Search — Semantic search across indexed group chat history.
 *
 * Usage:
 *   node search.js "API design decision"                    # search all
 *   node search.js "API design decision" --channel C075XXX  # specific channel
 *   node search.js "API design decision" --type decision     # filter by thread type
 *   node search.js "API design decision" --after 2026-03-01  # time filter
 *   node search.js "API design decision" --json              # JSON output
 *   node search.js "API design decision" --limit 10          # max results
 *
 * Required env vars:
 *   EMBEDDING_PROVIDER — "openai" | "gemini" (must match indexer)
 *   OPENAI_API_KEY / GEMINI_API_KEY
 *
 * Optional:
 *   DB_PATH — SQLite database path (default: ./teamind.db)
 */

const Database = require('better-sqlite3');
const path = require('path');
const https = require('https');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'teamind.db');
const EMBEDDING_PROVIDER = process.env.EMBEDDING_PROVIDER || 'openai';
const EMBEDDING_MODEL = process.env.EMBEDDING_MODEL || 'text-embedding-3-small';
const EMBEDDING_DIM = parseInt(process.env.EMBEDDING_DIM || '1536');

const args = process.argv.slice(2);
const query = args.find(a => !a.startsWith('-'));
const JSON_OUTPUT = args.includes('--json');
const LIMIT = parseInt(args[args.indexOf('--limit') + 1]) || 5;
const CHANNEL = args[args.indexOf('--channel') + 1] || null;
const THREAD_TYPE = args[args.indexOf('--type') + 1] || null;
const AFTER = args[args.indexOf('--after') + 1] || null;
const BEFORE = args[args.indexOf('--before') + 1] || null;
const PARTICIPANT = args[args.indexOf('--participant') + 1] || null;

if (!query) {
  console.error('Usage: node search.js "<query>" [--channel X] [--type X] [--after X] [--json]');
  process.exit(1);
}

// --- Helpers ---
function jsonRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    const parsedUrl = new URL(url);
    const req = https.request(parsedUrl, {
      method: options.method || 'GET',
      headers: { 'Content-Type': 'application/json', ...options.headers },
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => { try { resolve(JSON.parse(data)); } catch { resolve(data); } });
    });
    req.on('error', reject);
    if (options.body) req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    req.end();
  });
}

function bufferToFloat32(buf) {
  const arr = new Float32Array(buf.length / 4);
  for (let i = 0; i < arr.length; i++) arr[i] = buf.readFloatLE(i * 4);
  return arr;
}

function cosineSim(a, b) {
  let dot = 0, na = 0, nb = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return dot / (Math.sqrt(na) * Math.sqrt(nb));
}

async function embedText(text) {
  if (EMBEDDING_PROVIDER === 'openai') {
    const res = await jsonRequest('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${process.env.OPENAI_API_KEY}` },
      body: { model: EMBEDDING_MODEL, input: [text], dimensions: EMBEDDING_DIM }
    });
    return res.data[0].embedding;
  }
  if (EMBEDDING_PROVIDER === 'gemini') {
    const res = await jsonRequest(
      `https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL || 'text-embedding-004'}:embedContent?key=${process.env.GEMINI_API_KEY}`,
      { method: 'POST', body: { model: `models/${EMBEDDING_MODEL || 'text-embedding-004'}`, content: { parts: [{ text }] } } }
    );
    return res.embedding.values;
  }
  throw new Error(`Unknown EMBEDDING_PROVIDER: ${EMBEDDING_PROVIDER}`);
}

// --- Main ---
async function main() {
  const db = new Database(DB_PATH, { readonly: true });

  // Embed query
  const queryVec = await embedText(query);

  // --- Search thread summaries ---
  let threadSql = 'SELECT * FROM thread_summaries WHERE embedding IS NOT NULL';
  const threadParams = [];
  if (CHANNEL) { threadSql += ' AND channel_id = ?'; threadParams.push(CHANNEL); }
  if (THREAD_TYPE) { threadSql += ' AND thread_type = ?'; threadParams.push(THREAD_TYPE); }
  if (AFTER) { threadSql += ' AND last_msg_at >= ?'; threadParams.push(AFTER); }
  if (BEFORE) { threadSql += ' AND last_msg_at <= ?'; threadParams.push(BEFORE); }

  const threads = db.prepare(threadSql).all(...threadParams);

  const threadResults = threads.map(t => {
    const vec = bufferToFloat32(t.embedding);
    const score = cosineSim(queryVec, vec);
    return { ...t, score, embedding: undefined };
  }).sort((a, b) => b.score - a.score).slice(0, LIMIT);

  // Filter by participant if specified
  let filteredThreads = threadResults;
  if (PARTICIPANT) {
    filteredThreads = threadResults.filter(t => {
      try {
        const participants = JSON.parse(t.participants || '[]');
        return participants.some(p => p.name?.toLowerCase().includes(PARTICIPANT.toLowerCase()));
      } catch { return false; }
    });
  }

  // --- Search individual messages ---
  let msgSql = 'SELECT * FROM messages WHERE embedding IS NOT NULL';
  const msgParams = [];
  if (CHANNEL) { msgSql += ' AND channel_id = ?'; msgParams.push(CHANNEL); }
  if (AFTER) { msgSql += ' AND created_at >= ?'; msgParams.push(AFTER); }
  if (BEFORE) { msgSql += ' AND created_at <= ?'; msgParams.push(BEFORE); }

  const messages = db.prepare(msgSql).all(...msgParams);
  const msgResults = messages.map(m => {
    const vec = bufferToFloat32(m.embedding);
    const score = cosineSim(queryVec, vec);
    return { ...m, score, embedding: undefined };
  }).sort((a, b) => b.score - a.score).slice(0, LIMIT);

  // --- Output ---
  const result = {
    query,
    threads: filteredThreads.map(t => ({
      thread_ts: t.thread_ts,
      channel_id: t.channel_id,
      title: t.title,
      summary: t.summary,
      thread_type: t.thread_type,
      key_points: JSON.parse(t.key_points || '[]'),
      participants: JSON.parse(t.participants || '[]'),
      open_items: JSON.parse(t.open_items || '[]'),
      msg_count: t.msg_count,
      created_at: t.created_at,
      last_msg_at: t.last_msg_at,
      score: Math.round(t.score * 1000) / 1000,
    })),
    messages: msgResults.map(m => ({
      message_ts: m.message_ts,
      channel_id: m.channel_id,
      thread_ts: m.thread_ts,
      username: m.username,
      text: m.text?.slice(0, 500),
      created_at: m.created_at,
      score: Math.round(m.score * 1000) / 1000,
    })),
  };

  if (JSON_OUTPUT) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(`🔍 Search: "${query}"\n`);

    if (result.threads.length > 0) {
      console.log(`📋 Thread Summaries (${result.threads.length}):`);
      for (const t of result.threads) {
        console.log(`  [${t.score}] ${t.title}`);
        console.log(`    Type: ${t.thread_type} | Messages: ${t.msg_count} | ${t.last_msg_at?.slice(0, 10)}`);
        console.log(`    ${t.summary}`);
        if (t.key_points.length) console.log(`    Key: ${t.key_points.slice(0, 3).join('; ')}`);
        console.log();
      }
    }

    if (result.messages.length > 0) {
      console.log(`💬 Messages (${result.messages.length}):`);
      for (const m of result.messages) {
        console.log(`  [${m.score}] ${m.username}: ${m.text?.slice(0, 120)}`);
        console.log(`    ${m.created_at?.slice(0, 16)}`);
        console.log();
      }
    }
  }

  db.close();
}

main().catch(err => { console.error('❌', err.message); process.exit(1); });
