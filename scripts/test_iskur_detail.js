const https = require('https');

function getPage(url, method = 'GET', postData = '', cookies = '') {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const options = {
      hostname: u.hostname,
      path: u.pathname + u.search,
      method: method,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9',
      }
    };
    if (cookies) options.headers['Cookie'] = cookies;
    if (method === 'POST') {
      options.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      options.headers['Content-Length'] = Buffer.byteLength(postData);
      options.headers['Referer'] = url;
    }

    const req = https.request(options, (res) => {
      let data = '';
      const newCookies = res.headers['set-cookie'] ? res.headers['set-cookie'].map(c => c.split(';')[0]).join('; ') : '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ html: data, cookies: newCookies, statusCode: res.statusCode, headers: res.headers }));
    });
    req.on('error', reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function run() {
  const init = await getPage('https://esube.iskur.gov.tr/Istihdam/AcikIsIlanAra.aspx');
  const viewStateMatch = init.html.match(/id="__VIEWSTATE" value="([^"]+)"/);
  const viewStateGenMatch = init.html.match(/id="__VIEWSTATEGENERATOR" value="([^"]+)"/);
  const eventValMatch = init.html.match(/id="__EVENTVALIDATION" value="([^"]+)"/);

  const postBody = new URLSearchParams({
    '__VIEWSTATE': viewStateMatch ? viewStateMatch[1] : '',
    '__VIEWSTATEGENERATOR': viewStateGenMatch ? viewStateGenMatch[1] : '',
    '__EVENTVALIDATION': eventValMatch ? eventValMatch[1] : '',
    'ctl00$ctl00$ctl00$MasterPageBodyContent$RootMasterPageBodyContent$ContentPlaceHolder1$txtIl': '46',
    'ctl00$ctl00$ctl00$MasterPageBodyContent$RootMasterPageBodyContent$ContentPlaceHolder1$txtIlce': '524',
    'ctl00$ctl00$ctl00$MasterPageBodyContent$RootMasterPageBodyContent$ContentPlaceHolder1$btnAra': 'Ara'
  }).toString();

  const searchRes = await getPage('https://esube.iskur.gov.tr/Istihdam/AcikIsIlanAra.aspx', 'POST', postBody, init.cookies);
  
  console.log('Search res status:', searchRes.statusCode);
  console.log('Search res length:', searchRes.html.length);
  const isNoResult = searchRes.html.includes('Kayıt Bulunamadı') || searchRes.html.includes('Sonuç Bulunamadı');
  console.log('Is no result:', isNoResult);
  const gridIdx = searchRes.html.indexOf('divAcikIsAramaGrid');
  if (gridIdx !== -1) {
    console.log(searchRes.html.substring(gridIdx, gridIdx + 4000));
  }

  
  // Find all links or share-toggle
  const regex = /<[^>]+class="[^"]*share-toggle[^"]*"([^>]+)>/gi;
  let match;
  while ((match = regex.exec(searchRes.html)) !== null) {
    console.log('--- SHARE TOGGLE ---');
    console.log(match[1]);
  }

  // Also find all hrefs in the search results table
  const linkRegex = /href="([^"]*AcikIsIlanDetay[^"]*)"/gi;
  let lMatch;
  while ((lMatch = linkRegex.exec(searchRes.html)) !== null) {
    console.log('--- FOUND DETAIL LINK ---');
    console.log(lMatch[1]);
  }

}

run().catch(console.error);
