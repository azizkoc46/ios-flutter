const fs = require('fs');

const port = Number(process.env.CHROME_PORT || 9222);
const output = process.env.OUTPUT || 'web-runtime.png';
const waitMs = Number(process.env.WAIT_MS || 15000);
const width = Number(process.env.WIDTH || 1440);
const height = Number(process.env.HEIGHT || 1000);

async function main() {
  const pages = await fetch(`http://127.0.0.1:${port}/json`).then((response) =>
    response.json(),
  );
  const page = pages.find((item) => item.type === 'page');
  if (!page) throw new Error('Chrome sayfası bulunamadı.');

  const socket = new WebSocket(page.webSocketDebuggerUrl);
  let nextId = 0;
  const pending = new Map();
  const errors = [];
  const logs = [];

  socket.onmessage = ({ data }) => {
    const message = JSON.parse(data);
    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result);
      return;
    }

    if (message.method === 'Runtime.exceptionThrown') {
      errors.push(message.params.exceptionDetails.text);
    }
    if (message.method === 'Runtime.consoleAPICalled') {
      logs.push(
        message.params.args
          .map((argument) => argument.value ?? argument.description ?? '')
          .join(' '),
      );
    }
    if (message.method === 'Log.entryAdded' && message.params.entry.level === 'error') {
      errors.push(message.params.entry.text);
    }
  };

  await new Promise((resolve, reject) => {
    socket.onopen = resolve;
    socket.onerror = reject;
  });

  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = ++nextId;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });

  await send('Runtime.enable');
  await send('Log.enable');
  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width < 600,
  });
  await send('Page.reload', { ignoreCache: true });
  await new Promise((resolve) => setTimeout(resolve, waitMs));

  const state = await send('Runtime.evaluate', {
    expression: `JSON.stringify({
      title: document.title,
      splash: Boolean(document.getElementById('splash')),
      canvases: document.querySelectorAll('canvas').length,
      flutterViews: document.querySelectorAll('flutter-view').length,
      glassPanes: document.querySelectorAll('flt-glass-pane').length,
      bodyChildren: Array.from(document.body.children).map((element) => element.tagName + '#' + element.id),
      text: document.body.innerText
    })`,
    returnByValue: true,
  });
  const screenshot = await send('Page.captureScreenshot', {
    format: 'png',
    captureBeyondViewport: false,
  });

  fs.writeFileSync(output, Buffer.from(screenshot.data, 'base64'));
  console.log(state.result.value);
  console.log(JSON.stringify({ logs, errors }));
  socket.close();
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
