/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * İŞKUR PAZARCIK İŞ İLANLARI OTOMATİK SENKRONİZASYON BOTU
 * ═══════════════════════════════════════════════════════════════════════════════
 * Bu betik Türkiye İş Kurumu (İŞKUR) e-Şube sisteminden Kahramanmaraş / Pazarcık
 * açık iş ilanlarını çeker, çift kayıtları engeller ve Firebase Firestore'daki
 * 'job_postings' koleksiyonuna doğrudan ekler.
 */

const https = require('https');
const querystring = require('querystring');

const ISKUR_LOGO_URL = 'https://esube.iskur.gov.tr/Assets/img/iskur-kurumsal-logo-bs-production.png';

function fetchInitialPage() {
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
        const cookies = res.headers['set-cookie']
          ? res.headers['set-cookie'].map(c => c.split(';')[0]).join('; ')
          : '';
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

function fetchPazarcikJobsFromIskur(init) {
  return new Promise((resolve, reject) => {
    const formPayload = {
      '__EVENTTARGET': 'ctl04$ctlAcikIsPageCommand$CommandItem_Search',
      '__EVENTARGUMENT': '',
      '__VIEWSTATE': init.viewState,
      '__VIEWSTATEGENERATOR': init.viewStateGenerator,
      '__EVENTVALIDATION': init.eventValidation,
      'ctl04$ctlIl': '46', // Kahramanmaraş
      'ctl04$ctlIlce': '463', // Pazarcık
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
        const regex = /<[^>]+class="[^"]*share-toggle[^"]*"([^>]+)>/gi;
        let match;
        const jobs = [];

        while ((match = regex.exec(html)) !== null) {
          const attrStr = match[1];
          const getAttr = (name) => {
            const m = attrStr.match(new RegExp(`data-${name}='([^']*)'|data-${name}="([^"]*)"`, 'i'));
            return m ? (m[1] || m[2]) : '';
          };

          const ilanNo = getAttr('ilanno').trim();
          if (!ilanNo) continue;

          const rawUrl = getAttr('url').trim();
          const cleanUrl = rawUrl.startsWith('http://')
            ? rawUrl.replace('http://', 'https://')
            : (rawUrl.startsWith('https://') ? rawUrl : `https://esube.iskur.gov.tr/Istihdam/AcikIsIlanDetay.aspx?uiID=${ilanNo}`);

          const sonTarihStr = getAttr('sontarih').trim(); // "13.11.2026"
          let endDate = null;
          if (sonTarihStr) {
            const parts = sonTarihStr.split('.');
            if (parts.length === 3) {
              const day = parseInt(parts[0], 10);
              const month = parseInt(parts[1], 10) - 1;
              const year = parseInt(parts[2], 10);
              endDate = new Date(year, month, day, 23, 59, 59);
            }
          }

          const meslek = getAttr('meslekler').trim() || 'Açık İş Pozisyonu';
          const kontenjan = getAttr('acikissayi').trim() || '1';
          const calismaSekli = getAttr('calismasekli').trim() || 'Tam Zamanlı';

          jobs.push({
            iskurId: ilanNo,
            title: meslek,
            companyName: 'İŞKUR / Pazarcık İşvereni',
            personnelCount: kontenjan,
            employmentType: calismaSekli,
            salary: 'İŞKUR / Sektör Standart',
            applicationUrl: cleanUrl,
            applicationStartDate: new Date(),
            applicationEndDate: endDate,
            description: `Bu ilan Türkiye İş Kurumu (İŞKUR) Pazarcık açık iş ilanları listesinden otomatik olarak aktarılmıştır.\n\n` +
                         `• Pozisyon / Meslek: ${meslek}\n` +
                         `• Açık Kontenjan: ${kontenjan} Kişi\n` +
                         `• Çalışma Şekli: ${calismaSekli}\n` +
                         `• Çalışma Yeri: Kahramanmaraş / Pazarcık\n` +
                         (sonTarihStr ? `• Son Başvuru Tarihi: ${sonTarihStr}\n\n` : `\n`) +
                         `📌 İşverenin unvanını, adresini ve yetkili iletişim bilgilerini görmek ve ilana resmi başvuru yapmak için lütfen aşağıdaki butona dokunarak e-Devlet şifrenizle İŞKUR sistemine giriş yapınız.`,
            images: [ISKUR_LOGO_URL],
            isIskur: true,
            source: 'iskur',
            status: 'active',
            isHired: false,
            views: 0
          });
        }

        resolve(jobs);
      });
    }).on('error', reject);

    req.write(postBody);
    req.end();
  });
}

// Ana senkronizasyon fonksiyonu
async function syncIskurPazarcikJobs(adminDb, adminMessaging) {
  console.log('[İŞKUR Bot] 1. e-Şube sayfası açılıyor...');
  const init = await fetchInitialPage();

  console.log('[İŞKUR Bot] 2. Kahramanmaraş / Pazarcık sorgulanıyor...');
  const jobs = await fetchPazarcikJobsFromIskur(init);
  console.log(`[İŞKUR Bot] İŞKUR'da Pazarcık için ${jobs.length} açık ilan tespit edildi.`);

  if (!adminDb) {
    console.log('[İŞKUR Bot] Firestore bağlantısı verilmedi, sadece veriler listelendi.');
    return { count: jobs.length, jobs };
  }

  let addedCount = 0;
  for (const job of jobs) {
    // Çift kayıt kontrolü
    const snap = await adminDb.collection('job_postings')
      .where('iskurId', '==', job.iskurId)
      .limit(1)
      .get();

    if (!snap.empty) {
      // Zaten veritabanında var, atla
      continue;
    }

    // Yeni ilan ekle
    const docData = {
      ...job,
      createdAt: new Date(),
    };

    const newDoc = await adminDb.collection('job_postings').add(docData);
    addedCount++;
    console.log(`[İŞKUR Bot] Yeni ilan portala kaydedildi: [${job.iskurId}] ${job.title}`);

    // Bildirim Havuzuna Ekle
    try {
      await adminDb.collection('app_notifications').add({
        title: `🏛️ Yeni İŞKUR İlanı: ${job.title}`,
        body: `Pazarcık için İŞKUR'da yeni ${job.title} ilanı açıldı. Detaylar ve başvuru için dokunun.`,
        type: 'job',
        targetType: 'job',
        targetId: newDoc.id,
        topic: 'is_ilanlari',
        createdAt: new Date()
      });

      // FCM Topic Push Bildirimi Gönder
      if (adminMessaging) {
        await adminMessaging.send({
          topic: 'is_ilanlari',
          notification: {
            title: `🏛️ Yeni İŞKUR İlanı: ${job.title}`,
            body: `Pazarcık için İŞKUR'da yeni personel aranıyor. Başvurmak için dokunun.`,
          },
          data: {
            type: 'job',
            targetType: 'job',
            targetId: newDoc.id,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        });
      }
    } catch (notifErr) {
      console.warn('[İŞKUR Bot] Bildirim gönderilirken uyarı:', notifErr.message);
    }
  }

  console.log(`[İŞKUR Bot] Senkronizasyon tamamlandı. Toplam ${addedCount} yeni ilan portala eklendi.`);
  return { found: jobs.length, added: addedCount };
}

module.exports = {
  fetchInitialPage,
  fetchPazarcikJobsFromIskur,
  syncIskurPazarcikJobs
};

// Doğrudan çalıştırıldığında test et
if (require.main === module) {
  (async () => {
    try {
      const result = await syncIskurPazarcikJobs(null, null);
      console.log('Bulunan İlanlar:\n', JSON.stringify(result.jobs.map(j => ({
        ilanNo: j.iskurId,
        meslek: j.title,
        sonTarih: j.applicationEndDate,
        url: j.applicationUrl
      })), null, 2));
    } catch (e) {
      console.error('Hata:', e);
    }
  })();
}
