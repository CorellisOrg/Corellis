#!/usr/bin/env node
/**
 * Teamind Digest — Generate per-lobster personalized thread digests.
 *
 * Reads from the Teamind SQLite DB, finds threads where each lobster's
 * owner participated in the last N hours, and writes a digest markdown file.
 *
 * Usage:
 *   node digest.js                           # all lobsters, last 24h
 *   node digest.js --lobster alice           # single lobster
 *   node digest.js --hours 48               # custom window
 *   node digest.js --dry-run                # preview only
 *
 * Required env vars:
 *   DB_PATH — path to teamind.db
 *
 * Optional:
 *   LOBSTER_MAP_FILE — JSON file mapping lobster names to Slack user IDs
 *                      default: ../configs/lobster-map.json
 *   OUTPUT_DIR — where to write digest files (default: ./digests)
 */

const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'teamind.db');
const HOURS = parseInt(process.argv.find((a, i, arr) => arr[i - 1] === '--hours') || '24');
const TARGET = process.argv.find((a, i, arr) => arr[i - 1] === '--lobster') || null;
const DRY_RUN = process.argv.includes('--dry-run');
const OUTPUT_DIR = process.env.OUTPUT_DIR || path.join(__dirname, 'digests');

// Load lobster → user_id mapping
const MAP_FILE = process.env.LOBSTER_MAP_FILE ||
  path.join(__dirname, '..', '..', 'configs', 'lobster-map.json');

let lobsterMap = {};
if (fs.existsSync(MAP_FILE)) {
  lobsterMap = JSON.parse(fs.readFileSync(MAP_FILE, 'utf8'));
} else {
  console.warn(`⚠️  No lobster-map.json found at ${MAP_FILE}`);
  console.warn('   Create it: {"alice": "U0XXXXXXXXX", "bob": "U0YYYYYYYYY"}');
  console.warn('   Or set LOBSTER_MAP_FILE env var');
  process.exit(1);
}

const db = new Database(DB_PATH, { readonly: true });
const cutoff = new Date(Date.now() - HOURS * 3600 * 1000).toISOString();
const today = new Date().toISOString().slice(0, 10);

console.log(`📡 Teamind Digest — ${today}`);
console.log(`   Window: last ${HOURS}h (since ${cutoff.slice(0, 16)})`);
console.log(`   Target: ${TARGET || 'all'}`);
console.log();

// Get active threads in the window
const activeThreads = db.prepare(`
  SELECT ts.*, ch.channel_name
  FROM thread_summaries ts
  JOIN channels ch ON ch.channel_id = ts.channel_id
  WHERE ts.last_msg_at >= ?
  ORDER BY ts.last_msg_at DESC
`).all(cutoff);

console.log(`   Found ${activeThreads.length} active threads\n`);

if (activeThreads.length === 0) {
  console.log('✅ No activity, no digests needed');
  process.exit(0);
}

// Get participants for each thread
function getThreadParticipantIds(channelId, threadTs) {
  const msgs = db.prepare(`
    SELECT DISTINCT user_id FROM messages
    WHERE channel_id = ? AND thread_ts = ?
  `).all(channelId, threadTs);
  return msgs.map(m => m.user_id);
}

// Reverse map: user_id → lobster name
const uidToLobster = {};
for (const [name, uid] of Object.entries(lobsterMap)) {
  uidToLobster[uid] = name;
}

// Build per-lobster digest
const digests = {}; // lobster_name → threads[]

for (const thread of activeThreads) {
  const participantIds = getThreadParticipantIds(thread.channel_id, thread.thread_ts);

  // For each participant, if they map to a lobster, add to their digest
  for (const uid of participantIds) {
    const lobsterName = uidToLobster[uid];
    if (!lobsterName) continue;
    if (TARGET && lobsterName !== TARGET) continue;

    if (!digests[lobsterName]) digests[lobsterName] = [];
    digests[lobsterName].push({
      channel: thread.channel_name || thread.channel_id,
      title: thread.title,
      summary: thread.summary,
      type: thread.thread_type,
      key_points: JSON.parse(thread.key_points || '[]'),
      open_items: JSON.parse(thread.open_items || '[]'),
      msg_count: thread.msg_count,
      last_msg: thread.last_msg_at?.slice(0, 16),
    });
  }

  // Also add threads where no specific participant matched (everyone should know)
  if (thread.msg_count >= 10) {
    for (const name of Object.keys(lobsterMap)) {
      if (TARGET && name !== TARGET) continue;
      if (!digests[name]) digests[name] = [];
      // Avoid duplicates
      if (!digests[name].some(d => d.title === thread.title)) {
        digests[name].push({
          channel: thread.channel_name || thread.channel_id,
          title: thread.title,
          summary: thread.summary,
          type: thread.thread_type,
          key_points: JSON.parse(thread.key_points || '[]'),
          open_items: JSON.parse(thread.open_items || '[]'),
          msg_count: thread.msg_count,
          last_msg: thread.last_msg_at?.slice(0, 16),
          highlight: true, // high-activity thread everyone should see
        });
      }
    }
  }
}

// Write digest files
if (!DRY_RUN) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

for (const [name, threads] of Object.entries(digests)) {
  const md = [
    `# Teamind Digest — ${today}`,
    `> ${name}'s personalized digest (last ${HOURS}h, ${threads.length} threads)`,
    '',
  ];

  // Group by channel
  const byChannel = {};
  for (const t of threads) {
    if (!byChannel[t.channel]) byChannel[t.channel] = [];
    byChannel[t.channel].push(t);
  }

  for (const [channel, channelThreads] of Object.entries(byChannel)) {
    md.push(`## #${channel}`);
    md.push('');
    for (const t of channelThreads) {
      md.push(`### ${t.highlight ? '🔥 ' : ''}${t.title}`);
      md.push(`- **Type**: ${t.type} | **Messages**: ${t.msg_count} | **Last**: ${t.last_msg}`);
      md.push(`- ${t.summary}`);
      if (t.key_points.length) {
        md.push('- **Key points**:');
        for (const kp of t.key_points) md.push(`  - ${kp}`);
      }
      if (t.open_items.length) {
        md.push('- **Open items**:');
        for (const oi of t.open_items) {
          const item = typeof oi === 'string' ? oi : oi.item;
          const assignee = typeof oi === 'object' ? oi.assignee : null;
          md.push(`  - ${item}${assignee ? ` → ${assignee}` : ''}`);
        }
      }
      md.push('');
    }
  }

  const content = md.join('\n');

  if (DRY_RUN) {
    console.log(`--- ${name} (${threads.length} threads) ---`);
    console.log(content.slice(0, 500));
    console.log('...\n');
  } else {
    const filePath = path.join(OUTPUT_DIR, `${name}-${today}.md`);
    fs.writeFileSync(filePath, content);
    // Also write a "latest" symlink
    const latestPath = path.join(OUTPUT_DIR, `${name}-latest.md`);
    try { fs.unlinkSync(latestPath); } catch {}
    fs.copyFileSync(filePath, latestPath);
    console.log(`✅ ${name}: ${threads.length} threads → ${filePath}`);
  }
}

if (Object.keys(digests).length === 0) {
  console.log('ℹ️  No lobster owners participated in active threads');
}

db.close();
