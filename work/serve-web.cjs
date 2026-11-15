const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { execFile } = require('node:child_process');
const root = path.resolve(__dirname, '../web');
const url = 'http://127.0.0.1:5200/';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.woff2': 'font/woff2' };
function open() { execFile('powershell.exe', ['-NoProfile', '-Command', `Start-Process '${url}'`]); }
const server = http.createServer((req, res) => {
  let file;
  try { file = path.resolve(root, '.' + decodeURIComponent(new URL(req.url, url).pathname)); }
  catch { res.writeHead(400); res.end(); return; }
  if (file !== root && !file.startsWith(root + path.sep)) { res.writeHead(403); res.end(); return; }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  fs.readFile(file, (err, data) => {
    res.writeHead(err ? 404 : 200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(err ? 'Not found' : data);
  });
});
server.on('error', err => { console.error(err.message); console.error('Close any previous PathOGen server and try again.'); process.exitCode = 1; });
server.listen(5200, '127.0.0.1', () => { console.log(`PathOGen: ${url}\nKeep this window open while playing. Press Ctrl+C to stop.`); open(); });
