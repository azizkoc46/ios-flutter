async function main() {
  const port = Number(process.env.CHROME_PORT || 9222);
  const pages = await fetch(`http://127.0.0.1:${port}/json`).then((response) =>
    response.json(),
  );
  const page = pages.find((item) => item.type === 'page');
  if (!page) throw new Error('Chrome sayfası bulunamadı.');

  const socket = new WebSocket(page.webSocketDebuggerUrl);
  let nextId = 0;
  const pending = new Map();
  const errors = [];

  socket.onmessage = ({ data }) => {
    const message = JSON.parse(data);
    if (message.id && pending.has(message.id)) {
      const request = pending.get(message.id);
      pending.delete(message.id);
      message.error
        ? request.reject(new Error(message.error.message))
        : request.resolve(message.result);
    }
    if (message.method === 'Runtime.exceptionThrown') {
      errors.push(message.params.exceptionDetails.text);
    }
    if (message.method === 'Runtime.consoleAPICalled') {
      const text = message.params.args
        .map((argument) => argument.value ?? argument.description ?? '')
        .join(' ');
      if (/google|auth|unauthorized|popup/i.test(text)) errors.push(text);
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
  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', {
    width: 1440,
    height: 1000,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await send('Page.navigate', { url: 'http://localhost:8080/' });
  await new Promise((resolve) => setTimeout(resolve, 8000));
  await send('Input.dispatchMouseEvent', {
    type: 'mousePressed',
    x: 647,
    y: 726,
    button: 'left',
    clickCount: 1,
  });
  await send('Input.dispatchMouseEvent', {
    type: 'mouseReleased',
    x: 647,
    y: 726,
    button: 'left',
    clickCount: 1,
  });
  await new Promise((resolve) => setTimeout(resolve, 4000));

  const targets = await fetch(`http://127.0.0.1:${port}/json`).then((response) =>
    response.json(),
  );
  console.log(
    JSON.stringify({
      popupOpened: targets.some(
        (target) =>
          target.id !== page.id && /accounts\.google\.com/.test(target.url),
      ),
      targets: targets.map(({ type, url }) => ({ type, url })),
      errors,
    }),
  );
  socket.close();
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
