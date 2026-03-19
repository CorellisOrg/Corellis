---
name: browser-cdp
description: "Use the local Chrome browser via CDP (Chrome DevTools Protocol) for any task requiring web authentication, cookies, or browser sessions. ALWAYS prefer this over manual cookie env vars. Trigger when: need to access authenticated websites (ASC, Gmail, Notion, etc.), fetch data from sites requiring login, check if user has logged in, or user mentions 'browser', 'noVNC', 'cookie', 'login session'."
---

# Chrome CDP Browser Operations

## ⚡ Core Principles

**A Chrome browser is running in your container. After users log into various services through the noVNC web interface, you can directly reuse the login state through CDP.**

> 🚨 **Never** ask users to manually copy cookies.
> 🚨 **Never** prioritize using cookies from environment variables.
> ✅ **Always prioritize** operating the local Chrome through CDP.

## Architecture

```
User (laptop/phone)
  │
  ▼ Open noVNC web page, log into various services
Chrome in container (keeps running)
  │
  ▼ CDP (127.0.0.1:9222)
You (Lobster AI) operate browser through CDP
```

## Getting noVNC Address

**Check your TOOLS.md**, which contains your noVNC external port and VNC password.

⚠️ **Don't tell users about the internal port 6080**, must use the external port from TOOLS.md.

## Check if Chrome is Running

```bash
curl -s http://127.0.0.1:9222/json/version
```

Returns 200 = Chrome is running. Returns connection refused = Chrome is down, needs restart.

## Common Operations

### 1. List All Open Tabs

```bash
curl -s http://127.0.0.1:9222/json/list
```

### 2. Execute fetch in Logged-in Browser (Most Common!)

Execute JavaScript in browser page context through CDP Runtime.evaluate, automatically carries cookies for that domain:

```bash
# Get WebSocket URL of first tab
WS_URL=$(curl -s http://127.0.0.1:9222/json/list | node -e "
  let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{
    const tabs=JSON.parse(d);
    const tab=tabs.find(t=>t.url.includes('target domain')) || tabs[0];
    console.log(tab.webSocketDebuggerUrl);
  })
")

# Send CDP command through WebSocket
node -e "
const WebSocket = require('ws');
const ws = new WebSocket('$WS_URL');
ws.on('open', () => {
  ws.send(JSON.stringify({
    id: 1,
    method: 'Runtime.evaluate',
    params: {
      expression: \`
        fetch('https://target-api-url', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({your request body})
        }).then(r => r.json()).then(d => JSON.stringify(d))
      \`,
      awaitPromise: true
    }
  }));
});
ws.on('message', (data) => {
  const msg = JSON.parse(data);
  if (msg.id === 1) {
    console.log(msg.result?.result?.value || JSON.stringify(msg));
    ws.close();
  }
});
"
```

### 3. Navigate to Specified Page

```bash
node -e "
const WebSocket = require('ws');
const ws = new WebSocket('$WS_URL');
ws.on('open', () => {
  ws.send(JSON.stringify({
    id: 1,
    method: 'Page.navigate',
    params: { url: 'https://target-url' }
  }));
});
ws.on('message', (data) => {
  const msg = JSON.parse(data);
  if (msg.id === 1) { console.log('Navigated:', JSON.stringify(msg.result)); ws.close(); }
});
"
```

### 4. Get Cookies for Specified Domain

```bash
node -e "
const WebSocket = require('ws');
const ws = new WebSocket('$(curl -s http://127.0.0.1:9222/json/list | node -p "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))[0].webSocketDebuggerUrl")');
ws.on('open', () => {
  ws.send(JSON.stringify({
    id: 1,
    method: 'Network.getCookies',
    params: { urls: ['https://target-domain.com'] }
  }));
});
ws.on('message', (data) => {
  const msg = JSON.parse(data);
  if (msg.id === 1) {
    console.log(JSON.stringify(msg.result.cookies, null, 2));
    ws.close();
  }
});
"
```

### 5. Screenshot

```bash
node -e "
const WebSocket = require('ws');
const ws = new WebSocket('$WS_URL');
ws.on('open', () => {
  ws.send(JSON.stringify({
    id: 1, method: 'Page.captureScreenshot',
    params: { format: 'png' }
  }));
});
ws.on('message', (data) => {
  const msg = JSON.parse(data);
  if (msg.id === 1) {
    require('fs').writeFileSync('/tmp/screenshot.png', Buffer.from(msg.result.data, 'base64'));
    console.log('Saved to /tmp/screenshot.png');
    ws.close();
  }
});
"
```

## Decision Flow

When needing to access websites requiring login:

```
1. curl http://127.0.0.1:9222/json/version → Is Chrome running?
   ├─ No → Tell user Chrome isn't started, need to check container
   └─ Yes ↓
2. curl http://127.0.0.1:9222/json/list → Is there a tab for target domain?
   ├─ Yes → Directly use that tab's WS URL to perform operations
   └─ No ↓
3. Use Page.navigate to open target URL → Check if login is needed
   ├─ Already logged in (has session) → Continue operations
   └─ Not logged in / 302 redirect → Remind user to login via noVNC
       (Check TOOLS.md for noVNC address and password)
```

## Handling User Login Expiration

When CDP requests return 302, 401, 403 or login pages:

1. **Don't** try to use old cookies or environment variables
2. **Don't** ask users to manually copy cookies
3. **Tell the user**: Please re-login through noVNC (provide address and password from TOOLS.md)
4. After user logs in, you can directly operate through CDP with no additional steps

## Notes

- CDP port `127.0.0.1:9222` is only accessible inside the container, don't tell users about this port
- Chrome profile is stored in container volume, login state won't be lost on container restart
- If `ws` module is unavailable, first `npm install -g ws` or use Python websocket
- Each lobster's Chrome is isolated, you can only see your own user's login state