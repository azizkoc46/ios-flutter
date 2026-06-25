/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

function cleanData(data) {
  const result = {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value === undefined || value === null) continue;
    result[key] = String(value);
  }
  return result;
}

async function requireAdmin(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Oturum acmaniz gerekiyor.");
  }

  const token = request.auth.token || {};
  const tokenRole = String(token.role || token.rol || token.userRole || "")
      .toLocaleLowerCase("tr-TR")
      .trim();
  const hasAdminClaim = token.admin === true ||
    token.isAdmin === true ||
    tokenRole === "admin" ||
    tokenRole === "yonetici" ||
    tokenRole === "yönetici";
  if (hasAdminClaim) return;

  const adminDoc = await db.collection("customers").doc(request.auth.uid).get();
  const data = adminDoc.exists ? adminDoc.data() || {} : {};
  const role = String(
      data.role || data.rol || data.userRole || data.accountRole || "",
  ).toLocaleLowerCase("tr-TR").trim();
  const isAdmin = role === "admin" ||
    role === "yonetici" ||
    role === "yönetici" ||
    data.isAdmin === true ||
    data.admin === true;
  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Yonetici yetkisi gerekiyor.");
  }
}

async function sendToUserOrTopic(userId, topic, message) {
  const userDoc = await db.collection("customers").doc(userId).get();
  const token = userDoc.exists ? String(userDoc.get("fcmToken") || "") : "";
  if (token) {
    try {
      return await admin.messaging().send({...message, token});
    } catch (error) {
      logger.warn("Direct token delivery failed, using topic fallback", {
        userId,
        code: error && error.code,
      });
    }
  }
  return admin.messaging().send({...message, topic});
}

exports.adminCreateUser = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data || {};
  const email = String(data.email || "").trim().toLowerCase();
  const password = String(data.password || "");
  const displayName = String(data.displayName || "").trim();
  const role = String(data.role || "customer");
  if (!email || password.length < 6 || !displayName) {
    throw new HttpsError("invalid-argument", "Ad, e-posta ve en az 6 karakter sifre zorunludur.");
  }

  const user = await admin.auth().createUser({email, password, displayName});
  await db.collection("customers").doc(user.uid).set({
    fullname: displayName,
    email,
    role,
    isApproved: role === "satici" || role === "admin",
    sellerApproved: role === "satici",
    sellerStatus: role === "satici" ? "approved" : "",
    authType: "admin_created",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: request.auth.uid,
  }, {merge: true});
  return {uid: user.uid};
});

exports.adminDeleteUser = onCall({timeoutSeconds: 540, memory: "1GiB"}, async (request) => {
  await requireAdmin(request);
  const uid = String((request.data || {}).uid || "");
  if (!uid || uid === request.auth.uid) {
    throw new HttpsError("invalid-argument", "Bu kullanici silinemez.");
  }
  const customerRef = db.collection("customers").doc(uid);
  const customerSnap = await customerRef.get();
  const userEmail = customerSnap.exists
    ? String(customerSnap.get("email") || "").trim().toLowerCase()
    : "";
  const deletedPaths = new Set();
  const storagePaths = new Set();

  function collectStoragePaths(value) {
    if (Array.isArray(value)) {
      value.forEach(collectStoragePaths);
      return;
    }
    if (value && typeof value === "object") {
      Object.values(value).forEach(collectStoragePaths);
      return;
    }
    if (typeof value !== "string") return;
    const match = value.match(/\/o\/([^?]+)/);
    if (match) storagePaths.add(decodeURIComponent(match[1]));
  }

  async function deleteSnapshot(snapshot) {
    for (const doc of snapshot.docs) {
      if (deletedPaths.has(doc.ref.path)) continue;
      deletedPaths.add(doc.ref.path);
      collectStoragePaths(doc.data());
      await db.recursiveDelete(doc.ref);
    }
  }

  async function deleteWhere(collection, field, value) {
    if (!value) return;
    await deleteSnapshot(
        await db.collection(collection).where(field, "==", value).get(),
    );
  }

  const ownershipQueries = [
    ["products", "vendorId"], ["products", "sellerId"],
    ["orders", "customerId"], ["orders", "sellerId"],
    ["classified_ads", "ownerId"], ["classified_ads", "sellerId"],
    ["job_postings", "ownerId"], ["job_ads", "ownerId"],
    ["group_posts", "authorId"], ["reviews", "userId"],
    ["seller_reviews", "reviewerId"], ["seller_reviews", "sellerId"],
    ["businesses", "editorId"], ["businesses", "ownerId"],
    ["business_claims", "userId"], ["complaints", "uid"],
    ["complaints", "userId"], ["requests_complaints", "userId"],
    ["phone_verification_requests", "uid"],
    ["corporate_seller_applications", "userId"],
    ["notifications", "to"], ["notifications", "from"],
    ["seller_order_push_requests", "sellerId"],
    ["customer_order_push_requests", "customerId"],
    ["user_notification_requests", "targetUid"],
    ["cek_gonder_reports", "uid"],
  ];

  for (const [collection, field] of ownershipQueries) {
    await deleteWhere(collection, field, uid);
  }
  for (const field of ["authorId", "userId", "uid", "reviewerId"]) {
    try {
      await deleteSnapshot(
          await db.collectionGroup("comments").where(field, "==", uid).get(),
      );
    } catch (error) {
      logger.warn("Comment cleanup query skipped", {uid, field, error});
    }
  }
  await deleteWhere("dernekler", "applicantId", uid);
  if (userEmail) await deleteWhere("dernekler", "adminEmail", userEmail);

  for (const rootCollection of ["customers", "sellers", "admin_tokens"]) {
    const ref = db.collection(rootCollection).doc(uid);
    const snap = await ref.get();
    if (!snap.exists) continue;
    collectStoragePaths(snap.data());
    await db.recursiveDelete(ref);
    deletedPaths.add(ref.path);
  }

  const bucket = admin.storage().bucket();
  for (const prefix of [
    `profile_images/${uid}`, `user-images/${uid}`,
    `products/${uid}_`, `store_covers/${uid}_`,
  ]) {
    const [files] = await bucket.getFiles({prefix});
    files.forEach((file) => storagePaths.add(file.name));
  }
  let deletedFiles = 0;
  for (const path of storagePaths) {
    try {
      await bucket.file(path).delete({ignoreNotFound: true});
      deletedFiles++;
    } catch (error) {
      logger.warn("User storage file could not be deleted", {uid, path, error});
    }
  }
  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if (!error || error.code !== "auth/user-not-found") throw error;
  }
  return {deleted: true, deletedDocuments: deletedPaths.size, deletedFiles};
});

exports.sendTopicNotification = onDocumentCreated(
    "notification_send_requests/{requestId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const request = snap.data() || {};
      const notificationId = request.notificationId || "";
      const topic = request.topic || "pazarcik_duyuru";
      const appNotificationRef = notificationId
        ? db.collection("app_notifications").doc(notificationId)
        : null;

      try {
        await snap.ref.set({
          status: "sending",
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        if (appNotificationRef) {
          await appNotificationRef.set({
            pushStatus: "sending",
            pushStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }

        const data = cleanData({
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          notificationId,
          type: request.type || "Duyuru",
          targetType: request.targetType || "none",
          targetId: request.targetId || "",
          targetLabel: request.targetLabel || "",
          targetExtraId: request.targetExtraId || "",
          targetCollection: request.targetCollection || "",
          linkUrl: request.linkUrl || "",
          url: request.linkUrl || "",
          imageUrl: request.imageUrl || "",
          image: request.imageUrl || "",
        });

        const message = {
          topic,
          notification: {
            title: request.title || "Pazarcik Portal",
            body: request.body || "",
            ...(request.imageUrl ? {imageUrl: request.imageUrl} : {}),
          },
          data,
          android: {
            priority: "high",
            notification: {
              channelId: "pazarcik_main_channel_v5",
              sound: "default",
              ...(request.imageUrl ? {imageUrl: request.imageUrl} : {}),
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        const response = await admin.messaging().send(message);

        await snap.ref.set({
          status: "sent",
          messageId: response,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        if (appNotificationRef) {
          await appNotificationRef.set({
            pushStatus: "sent",
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      } catch (error) {
        logger.error("Topic notification failed", error);
        const errorMessage = error && error.message ? error.message : String(error);

        await snap.ref.set({
          status: "failed",
          error: errorMessage,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        if (appNotificationRef) {
          await appNotificationRef.set({
            pushStatus: "failed",
            pushError: errorMessage,
            failedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      }
    },
);

exports.sendAdminNotification = onDocumentCreated(
    "admin_notification_requests/{requestId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const request = snap.data() || {};

      try {
        await snap.ref.set({
          status: "sending",
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        const tokenSnap = await db.collection("admin_tokens").get();
        const tokens = tokenSnap.docs
            .map((doc) => doc.get("token"))
            .filter((token) => typeof token === "string" && token.length > 0);

        const baseMessage = {
          notification: {
            title: request.title || "Yonetici bildirimi",
            body: request.body || "",
          },
          data: cleanData({
            type: request.type || "general",
            docId: request.docId || "",
            ...(request.extra || {}),
          }),
          android: {
            priority: "high",
            notification: {
              channelId: "pazarcik_main_channel_v5",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        let response = {successCount: 0, failureCount: 0};
        let topicFallback = false;

        if (tokens.length > 0) {
          response = await admin.messaging().sendEachForMulticast({
            tokens,
            ...baseMessage,
          });
        }

        if (tokens.length === 0 || response.successCount === 0) {
          await admin.messaging().send({
            topic: "portal_admins",
            ...baseMessage,
          });
          topicFallback = true;
        }

        await db.collection("admin_notifications_log").add({
          title: request.title || "",
          body: request.body || "",
          type: request.type || "general",
          docId: request.docId || "",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          tokenCount: tokens.length,
          successCount: response.successCount,
          failureCount: response.failureCount,
          topicFallback,
        });

        await snap.ref.set({
          status: "sent",
          tokenCount: tokens.length,
          successCount: response.successCount,
          failureCount: response.failureCount,
          topicFallback,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (error) {
        logger.error("Admin notification failed", error);
        await snap.ref.set({
          status: "failed",
          error: error && error.message ? error.message : String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    },
);

function orderStatusText(status) {
  if (status === "Sipariş Onaylandı" || status === "SipariÅŸ OnaylandÄ±") {
    return {
      title: "Siparişiniz Onaylandı",
      body: "Siparişiniz alındı ve hazırlık başlıyor.",
    };
  }
  if (status === "Hazırlanıyor" || status === "HazÄ±rlanÄ±yor") {
    return {
      title: "Siparişiniz Hazırlanıyor",
      body: "Lezzetleriniz özenle hazırlanıyor.",
    };
  }
  if (status === "Yolda") {
    return {
      title: "Kurye Yolda",
      body: "Siparişiniz adrese doğru yola çıktı.",
    };
  }
  if (status === "Teslim Edildi") {
    return {
      title: "Teslim Edildi",
      body: "Siparişiniz teslim edildi. Afiyet olsun.",
    };
  }
  if (status === "İptal Edildi" || status === "Ä°ptal Edildi") {
    return {
      title: "Sipariş İptal Edildi",
      body: "Siparişiniz iptal edildi.",
    };
  }
  return {
    title: "Sipariş Güncellemesi",
    body: `Sipariş durumunuz: ${status || ""}`,
  };
}

exports.sendCustomerOrderNotification = onDocumentCreated(
    "customer_order_push_requests/{requestId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const request = snap.data() || {};
      const customerId = request.customerId || "";
      const status = request.status || "";

      try {
        if (!customerId) {
          throw new Error("customerId bos");
        }

        await snap.ref.set({
          statusText: "sending",
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        const text = orderStatusText(status);
        const response = await sendToUserOrTopic(
            customerId,
            `customer_${customerId}`,
            {
          notification: text,
          data: cleanData({
            type: "order_status",
            status,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          }),
          android: {
            priority: "high",
            notification: {
              channelId: "customer_order_channel_v5",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
            },
        );

        await snap.ref.set({
          statusText: "sent",
          messageId: response,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (error) {
        logger.error("Customer order notification failed", error);
        await snap.ref.set({
          statusText: "failed",
          error: error && error.message ? error.message : String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    },
);

exports.sendSellerOrderNotification = onDocumentCreated(
    "seller_order_push_requests/{requestId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const request = snap.data() || {};
      const sellerId = request.sellerId || "";
      const customerName = request.customerName || "Müşteri";
      const amount = Number(request.amount || 0);

      try {
        if (!sellerId) {
          throw new Error("sellerId bos");
        }

        await snap.ref.set({
          status: "sending",
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

        const response = await sendToUserOrTopic(
            sellerId,
            `seller_${sellerId}`,
            {
          notification: {
            title: "Yeni Sipariş",
            body: `${customerName} - ${amount.toFixed(2)} TL`,
          },
          data: cleanData({
            type: "new_order",
            sellerId,
            customerName,
            amount: amount.toString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          }),
          android: {
            priority: "high",
            ttl: 86400 * 1000,
            notification: {
              channelId: "seller_order_channel_v5",
              sound: "default",
              visibility: "public",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
            },
        );

        await snap.ref.set({
          status: "sent",
          messageId: response,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (error) {
        logger.error("Seller order notification failed", error);
        await snap.ref.set({
          status: "failed",
          error: error && error.message ? error.message : String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    },
);

function distanceKm(lat1, lng1, lat2, lng2) {
  const p = Math.PI / 180;
  const a = 0.5 - Math.cos((lat2 - lat1) * p) / 2 +
      Math.cos(lat1 * p) * Math.cos(lat2 * p) *
      (1 - Math.cos((lng2 - lng1) * p)) / 2;
  return 12742 * Math.asin(Math.sqrt(a));
}

function earthquakeDocId(eq) {
  const title = String(eq.title || eq.location || "deprem")
      .toLowerCase()
      .replace(/[^a-z0-9ığüşöçİĞÜŞÖÇ]+/gi, "-")
      .slice(0, 80);
  const date = String(eq.date || "").replace(/[^0-9]/g, "").slice(0, 14);
  const mag = String(eq.mag || eq.magnitude || "").replace(/[^0-9.]/g, "");
  return `${date}-${mag}-${title}`.replace(/-+/g, "-");
}

exports.pollEarthquakes = onSchedule(
    {
      schedule: "every 5 minutes",
      timeZone: "Europe/Istanbul",
      region: "us-central1",
    },
    async () => {
      const pazarcikLat = 37.4878;
      const pazarcikLng = 37.2958;
      const minMagnitude = 3.0;
      const maxDistanceKm = 200;

      const response = await fetch(
          "https://api.orhanaydogdu.com.tr/deprem/kandilli/live",
      );
      if (!response.ok) {
        throw new Error(`Kandilli API hata: ${response.status}`);
      }

      const payload = await response.json();
      const list = payload.result || payload.data || [];

      for (const eq of list.slice(0, 25)) {
        const mag = Number(eq.mag || eq.magnitude || 0);
        const coords = eq.geojson && eq.geojson.coordinates;
        if (!Array.isArray(coords) || coords.length < 2) continue;

        const lng = Number(coords[0]);
        const lat = Number(coords[1]);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;

        const dist = distanceKm(pazarcikLat, pazarcikLng, lat, lng);
        if (mag < minMagnitude || dist > maxDistanceKm) continue;

        const id = earthquakeDocId(eq);
        const ref = db.collection("earthquake_alerts").doc(id);
        const existing = await ref.get();
        if (existing.exists) continue;

        const title = eq.title || eq.location || "Bölgesel deprem";
        const body =
          `${mag.toFixed(1)} büyüklüğünde deprem - Pazarcık'a yaklaşık ` +
          `${Math.round(dist)} km`;

        await ref.set({
          title,
          magnitude: mag,
          depth: Number(eq.depth || 0),
          date: eq.date || "",
          lat,
          lng,
          distanceKm: Math.round(dist * 10) / 10,
          source: "Kandilli",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          notified: false,
        });

        const messageId = await admin.messaging().send({
          topic: "all_users",
          notification: {
            title: "Deprem Bilgilendirmesi",
            body,
          },
          data: cleanData({
            type: "earthquake",
            earthquakeId: id,
            title,
            magnitude: mag.toString(),
            distanceKm: Math.round(dist).toString(),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          }),
          android: {
            priority: "high",
            notification: {
              channelId: "earthquake_alert_channel_v1",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });

        await ref.set({
          notified: true,
          messageId,
          notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    },
);
