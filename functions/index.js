const admin = require('firebase-admin');
const axios = require('axios');
const { onRequest } = require('firebase-functions/v2/https');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');

admin.initializeApp();
const db = admin.firestore();

// ═══════════════════════════════════════════════════
//  Helper: إرسال FCM لمستخدم عبر رقم هاتفه
// ═══════════════════════════════════════════════════
async function sendFcmToUser(userPhone, title, body, data = {}) {
  if (!userPhone || userPhone.trim() === '') return;
  try {
    const userDoc = await db.collection('users').doc(userPhone).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) {
      logger.info(`No FCM token for user: ${userPhone}`);
      return;
    }
    const stringData = {};
    for (const [k, v] of Object.entries(data)) {
      stringData[k] = String(v ?? '');
    }
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: stringData,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'zafa_main_channel',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    });
    logger.info(`✅ FCM sent to ${userPhone}: ${title}`);
  } catch (e) {
    logger.error(`FCM error for ${userPhone}:`, e.message);
  }
}

// تحويل حالة الحجز إلى نص عربي
function bookingStatusMessage(status) {
  const map = {
    'awaiting_deposit':  'تم تأكيد حجزك ✓ – بانتظار إرسال العربون',
    'deposit_confirmed': 'تم تأكيد استلام العربون ✓ – حجزك مؤكد',
    'confirmed':         'تم تأكيد حجزك ✓',
    'approved':          'تم قبول حجزك ✓',
    'rejected':          'نأسف، تم رفض حجزك',
    'cancelled':         'تم إلغاء حجزك',
    'auto_cancelled':    'تم إلغاء الحجز تلقائياً لعدم إرسال العربون خلال 12 ساعة',
    'deposit_submitted': 'أرسل الزبون تفاصيل العربون – يرجى المراجعة',
    'modified':          'عدّل الزبون بيانات الحجز – يرجى المراجعة',
  };
  return map[status] || `تم تحديث حالة الحجز: ${status}`;
}

// الحالات التي يُشعَر بها الزبون
const CUSTOMER_NOTIFIED_STATUSES = new Set([
  'awaiting_deposit', 'deposit_confirmed', 'confirmed', 'approved',
  'rejected', 'cancelled', 'auto_cancelled',
]);

// الحالات التي يُشعَر بها المزود
const PROVIDER_NOTIFIED_STATUSES = new Set([
  'deposit_submitted', 'modified', 'cancelled',
]);

// ═══════════════════════════════════════════════════
//  1. حجز جديد → إشعار للمزود
// ═══════════════════════════════════════════════════
exports.notifyProviderNewBooking = onDocumentCreated(
  { document: 'bookings/{bookingId}', region: 'us-central1' },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const providerPhone = data.providerId || data.providerPhone || '';
    const customerName  = data.customerName || 'زبون';
    const itemName      = data.itemName || 'خدمة';

    await sendFcmToUser(
      providerPhone,
      '📥 حجز جديد',
      `تم استلام حجز جديد من ${customerName} على ${itemName}`,
      { type: 'new_booking', bookingId: event.params.bookingId },
    );
  }
);

// ═══════════════════════════════════════════════════
//  2. تغيير حالة الحجز → إشعار للزبون أو المزود
// ═══════════════════════════════════════════════════
exports.notifyBookingStatusChange = onDocumentUpdated(
  { document: 'bookings/{bookingId}', region: 'us-central1' },
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();

    if (before.status === after.status) return; // لا تغيير في الحالة

    const status         = after.status || '';
    const customerPhone  = after.customerId  || after.customerPhone  || '';
    const providerPhone  = after.providerId  || after.providerPhone  || '';
    const customerName   = after.customerName  || 'الزبون';
    const providerName   = after.providerName  || 'مزود الخدمة';
    const itemName       = after.itemName || 'الخدمة';
    const bookingId      = event.params.bookingId;
    const msgText        = bookingStatusMessage(status);

    if (CUSTOMER_NOTIFIED_STATUSES.has(status)) {
      await sendFcmToUser(
        customerPhone,
        `📋 تحديث حجزك – ${itemName}`,
        `${msgText} | من: ${providerName}`,
        { type: 'booking_status', status, bookingId },
      );
    }

    if (PROVIDER_NOTIFIED_STATUSES.has(status)) {
      await sendFcmToUser(
        providerPhone,
        `📋 تحديث الحجز – ${itemName}`,
        `${msgText} | من: ${customerName}`,
        { type: 'booking_status', status, bookingId },
      );
    }
  }
);

// ═══════════════════════════════════════════════════
//  3. رسالة جديدة → إشعار للمستقبِل
// ═══════════════════════════════════════════════════
exports.notifyNewChatMessage = onDocumentCreated(
  { document: 'chats/{chatId}/messages/{messageId}', region: 'us-central1' },
  async (event) => {
    const msgData = event.data?.data();
    if (!msgData) return;

    const senderId = msgData.senderId || '';
    const text     = msgData.text || '📎 مرفق';
    const chatId   = event.params.chatId;

    // جلب بيانات المحادثة لمعرفة المستقبِل
    const chatDoc  = await db.collection('chats').doc(chatId).get();
    const chatData = chatDoc.data();
    if (!chatData) return;

    const users = chatData.users || [];
    const recipientId = users.find((id) => id !== senderId);
    if (!recipientId) return;

    // اسم المرسل
    const userInfo   = chatData.userInfo || {};
    const senderInfo = userInfo[senderId] || {};
    const senderName = senderInfo.name || 'مستخدم';

    await sendFcmToUser(
      recipientId,
      `💬 رسالة جديدة من ${senderName}`,
      text.length > 100 ? text.substring(0, 100) + '...' : text,
      { type: 'message', chatId, senderId },
    );
  }
);

// ========== Service Requests Logic ==========

exports.handleServiceRequestApproval = onDocumentUpdated(
  'service_requests/{requestId}',
  {
    region: 'us-central1'
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const requestId = event.params.requestId;

    if (before.status !== 'accepted' && after.status === 'accepted') {
      try {
        const servicePath = getServicePath(after.serviceType);

        await db.collection('services')
          .doc(servicePath)
          .collection('items')
          .add({
            userId: after.userId,
            serviceName: after.serviceName,
            serviceType: after.serviceType,
            items: after.items || [],
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            requestId,
            isActive: true,
            description: after.description || '',
            location: after.location || '',
            phoneNumber: after.phoneNumber || '',
            images: after.images || []
          });

        await db.collection('users').doc(after.userId).update({
          isServiceProvider: true,
          serviceType: after.serviceType,
          serviceCategory: servicePath,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        await db.collection('notifications').add({
          userId: after.userId,
          title: 'تمت الموافقة على طلب تسجيل الخدمة',
          message: `تم قبول طلب تسجيل خدمة ${after.serviceName}`,
          type: 'service_request_approved',
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

      } catch (e) {
        logger.error('Approval error', e);
      }
    }
  }
);

exports.handleServiceRequestRejection = onDocumentUpdated(
  'service_requests/{requestId}',
  {
    region: 'us-central1'
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status !== 'rejected' && after.status === 'rejected') {
      await db.collection('notifications').add({
        userId: after.userId,
        title: 'تم رفض طلب تسجيل الخدمة',
        message: `نأسف، تم رفض طلب تسجيل خدمة ${after.serviceName}`,
        type: 'service_request_rejected',
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  }
);

function getServicePath(serviceType) {
  const map = {
    'قاعة': 'halls',
    'قاعات اعراس': 'halls',
    'مطعم': 'restaurants',
    'فندق': 'hotels',
    'سيارة': 'cars',
    'كيك': 'cakes',
    'فستان الزفاف': 'bride_dresses',
    'بدلة رجالي': 'groom_suits',
    'صالون وعناية': 'salon_care',
    'ورد': 'flowers',
    'تزيين السيارة': 'car_decorations',
    'سياحة': 'honeymoon'
  };
  return map[serviceType] || serviceType.toLowerCase().replace(/\s+/g, '_');
}

// ========== OTP Production Ready with Rate Limit ==========

function generateOtp() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

const OTP_VALIDITY_MS = 5 * 60 * 1000; // 5 دقائق
const OTP_RATE_LIMIT_MS = 60 * 1000;   // 1 دقيقة بين الطلبات

// تحويل صيغة رقم الهاتف إلى الصيغة الدولية بدون +
// 07XXXXXXXXX → 9647XXXXXXXXX
function formatPhoneForOtpiq(phone) {
  let p = phone.trim().replace(/\s+/g, '');
  if (p.startsWith('+')) p = p.slice(1);
  if (p.startsWith('0')) p = '964' + p.slice(1);
  return p;
}

exports.sendOtp = onRequest({
  region: 'us-central1',
  secrets: ['OTPIQ_API_KEY'],
}, async (req, res) => {
  // السماح بـ CORS
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  try {
    const { phone } = req.body;
    if (!phone) return res.status(400).json({ error: 'Phone is required' });

    const otpRef = db.collection('otp').doc(phone);
    const otpDoc = await otpRef.get();

    if (otpDoc.exists) {
      const lastSent = otpDoc.data().lastSent || 0;
      if (Date.now() - lastSent < OTP_RATE_LIMIT_MS) {
        return res.status(429).json({ error: 'Too many requests. Please wait before requesting a new OTP.' });
      }
    }

    const otp = generateOtp();

    await otpRef.set({
      otp,
      createdAt: Date.now(),
      expiresAt: Date.now() + OTP_VALIDITY_MS,
      lastSent: Date.now(),
    });

    const apiKey = (process.env.OTPIQ_API_KEY || '').replace(/[\r\n\t ]/g, '');
    const phoneFormatted = formatPhoneForOtpiq(phone);

    if (apiKey && apiKey.trim() !== '') {
      try {
        const response = await axios.post(
          'https://api.otpiq.com/api/sms',
          {
            phoneNumber: phoneFormatted,
            smsType: 'verification',
            verificationCode: otp,
            provider: 'auto',
          },
          {
            headers: {
              'Authorization': `Bearer ${apiKey}`,
              'Content-Type': 'application/json',
            },
            timeout: 15000,
          }
        );
        logger.info('OTPIQ success:', { status: response.status, data: response.data });
      } catch (otpiqErr) {
        const errBody = otpiqErr.response?.data;
        const errStatus = otpiqErr.response?.status;
        logger.error('OTPIQ API error:', { status: errStatus, body: errBody, msg: otpiqErr.message });
        // رغم الفشل نُعيد success=true لأن الرمز محفوظ في Firestore (test fallback)
        // إذا أردت إيقاف التسجيل عند فشل الإرسال، احذف السطر التالي وانزع التعليق
        // throw otpiqErr;
      }
    } else {
      // وضع الاختبار — يظهر الكود في سجلات Firebase
      logger.warn(`[TEST MODE - No OTPIQ key] OTP for ${phone}: ${otp}`);
    }

    return res.json({ success: true });

  } catch (e) {
    logger.error('sendOtp error', e.message || e);
    return res.status(500).json({ error: 'Failed to send OTP' });
  }
});

exports.verifyOtp = onRequest({
  region: 'us-central1',
}, async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  try {
    const { phone, otp } = req.body;
    if (!phone || !otp) return res.status(400).json({ verified: false });

    const ref = db.collection('otp').doc(phone);
    const snap = await ref.get();

    if (!snap.exists) return res.status(400).json({ verified: false, reason: 'not_found' });

    const data = snap.data();

    if (Date.now() > data.expiresAt) {
      await ref.delete();
      return res.status(400).json({ verified: false, reason: 'expired' });
    }

    if (data.otp !== otp) {
      return res.status(400).json({ verified: false, reason: 'invalid' });
    }

    await ref.delete();
    return res.json({ verified: true });

  } catch (e) {
    logger.error('verifyOtp error', e.message || e);
    return res.status(500).json({ verified: false });
  }
});

// ========== Auto-Cancel Expired Deposits ==========

exports.autoCancelExpiredDeposits = onSchedule(
  {
    schedule: 'every 1 hours',
    region: 'us-central1',
  },
  async (_event) => {
    const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000);
    const snapshot = await db
      .collection('bookings')
      .where('status', '==', 'awaiting_deposit')
      .where('depositAwaitingAt', '<=', twelveHoursAgo)
      .get();

    if (snapshot.empty) {
      logger.info('No expired deposit bookings found.');
      return;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        status: 'auto_cancelled',
        isCancelled: true,
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        cancelReason: 'auto_no_deposit',
      });
    });
    await batch.commit();
    logger.info(`Auto-cancelled ${snapshot.size} expired deposit booking(s).`);
  }
);

