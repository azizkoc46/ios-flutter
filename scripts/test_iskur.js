const https = require('https');
const querystring = require('querystring');

function getInitialPage() {
  return new Promise((resolve, reject) => {
    https.get('https://esube.iskur.gov.tr/Istihdam/AcikIsIlanAra.aspx', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36',
        'Accept-Language': 'tr-TR,tr;q=0.9'
      }
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const cookies = res.headers['set-cookie'] ? res.headers['set-cookie'].map(c => c.split(';')[0]).join('; ') : '';
        const viewStateMatch = data.match(/id="__VIEWSTATE"\s+value="([^"]+)"/);
        const eventValidationMatch = data.match(/id="__EVENTVALIDATION"\s+value="([^"]+)"/);
        const viewStateGeneratorMatch = data.match(/id="__VIEWSTATEGENERATOR"\s+value="([^"]+)"/);

        resolve({
          cookies,
          viewState: viewStateMatch ? viewStateMatch[1] : '',
          eventValidation: eventValidationMatch ? eventValidationMatch[1] : '',
          viewStateGenerator: viewStateGeneratorMatch ? viewStateGeneratorMatch[1] : ''
        });
      });
    }).on('error', reject);
  });
}

async function inspectTableRow() {
  const init = await getInitialPage();
  const formPayload = {
    '__EVENTTARGET': 'ctl04$ctlAcikIsPageCommand$CommandItem_Search',
    '__EVENTARGUMENT': '',
    '__VIEWSTATE': init.viewState,
    '__VIEWSTATEGENERATOR': init.viewStateGenerator,
    '__EVENTVALIDATION': init.eventValidation,
    'ctl04$ctlIl': '46',
    'ctl04$ctlIlce': '463',
    'ctl04$IsyeriTuruRadios': 'ozelSektorRadio',
    'ctl04$ctlCalismaSekli': '',
    'ctl04$ctlCalismaPeryodu': '',
    'ctl04$ctlCalismaYeri': '1',
    'ctl04$ctlIlanTarihi': '0',
    'ctl04$ctlOgrenimDurum': ''
  };

  const postBody = querystring.stringify(formPayload);

  const req = https.request({
    hostname: 'esube.iskur.gov.tr',
    path: '/Istihdam/AcikIsIlanAra.aspx',
    method: 'POST',
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36',
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(postBody),
      'Cookie': init.cookies,
      'Referer': 'https://esube.iskur.gov.tr/Istihdam/AcikIsIlanAra.aspx'
    }
  }, (res) => {
    let html = '';
    res.on('data', chunk => html += chunk);
    res.on('end', () => {
      // Find rows containing uiID=00009861406
      const trRegex = /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi;
      let trMatch;
      while ((trMatch = trRegex.exec(html)) !== null) {
        if (trMatch[1].includes('00009861406')) {
          console.log("Full TR content:\n", trMatch[1].replace(/<style[\s\S]*?<\/style>/gi, ''));
          break;
        }
      }
    });
  });

  req.write(postBody);
  req.end();
}

inspectTableRow();
