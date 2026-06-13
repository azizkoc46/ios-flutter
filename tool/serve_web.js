const http = require('http');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..', 'build', 'web');
const port = Number(process.env.PORT || 8080);

const contentTypes = {
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.ico': 'image/x-icon',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.wasm': 'application/wasm',
  '.webp': 'image/webp',
};

http
  .createServer((request, response) => {
    const requestPath = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const relativePath = requestPath === '/' ? 'index.html' : requestPath.replace(/^\/+/, '');
    let filePath = path.resolve(root, relativePath);

    if (!filePath.startsWith(root)) {
      response.writeHead(403).end('Forbidden');
      return;
    }

    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      filePath = path.join(root, 'index.html');
    }

    response.writeHead(200, {
      'Cache-Control': 'no-store',
      'Content-Type': contentTypes[path.extname(filePath)] || 'application/octet-stream',
    });
    fs.createReadStream(filePath).pipe(response);
  })
  .listen(port, '127.0.0.1', () => {
    console.log(`Pazarcik Portal: http://127.0.0.1:${port}`);
  });
