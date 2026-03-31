const express = require('express');
const router = express.Router();
const { sendActivityAlertEmail } = require('../utils/emailService');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

//  حساب المسافة بالكيلومتر (Haversine)
function distanceKm(lat1, lng1, lat2, lng2) {
    if (!lat1 || !lng1 || !lat2 || !lng2) return 0;
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}


// POST /api/anomaly/check

router.post('/check', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { latitude, longitude, locationName, ssid, deviceName } = req.body;
        const anomalies = [];

        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(' Anomaly Check: طلب جديد');
        console.log(`   → userId: ${userId}`);
        console.log(`   → Device: ${deviceName}`);
        console.log(`   → SSID: ${ssid}`);
        console.log(`   → Location: ${latitude}, ${longitude} — ${locationName}`);

        const user = await User.findById(userId).select(
            'registrationLocation registrationWifi registrationDevices pendingFailedAttemptsAlert '
        );

        if (!user) {
            return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
        }

    const sendDeviceAlertEmail = async (detectedDeviceName) => {
    try {
        const userFull = await User.findById(userId).select('email fullName');
        const locationText = locationName ||
            (latitude && longitude
                ? `${Number(latitude).toFixed(2)}, ${Number(longitude).toFixed(2)}`
                : 'موقع غير معروف');

        const html = `
          <!DOCTYPE html><html dir="rtl">
          <head><meta charset="UTF-8"><style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 40px 20px; }
            .container { max-width: 560px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; }
            .header { background: #2D1B69; padding: 32px 24px; text-align: center; }
            .header h2 { color: white; font-size: 22px; font-weight: bold; }
            .body { padding: 32px 24px; }
            .greeting { font-size: 15px; color: #333; margin-bottom: 24px; line-height: 1.6; }
            .info-box { background: #f9f9f9; border: 1px solid #ebebeb; border-radius: 10px; padding: 20px 24px; margin-bottom: 24px; }
            .info-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-bottom: 1px solid #f0f0f0; direction: rtl; }
            .info-row:last-child { border-bottom: none; padding-bottom: 0; margin-bottom: 0; }
            .info-row:first-child { padding-top: 0; margin-bottom: 16px; }
            .info-label { font-size: 14px; color: #888; }
            .info-value { font-size: 14px; color: #222; font-weight: bold; direction: ltr; text-align: left; }
            .note { font-size: 13px; color: #888; text-align: center; line-height: 1.8; margin-bottom: 8px; }
            .warning { font-size: 13px; color: #c0392b; text-align: center; font-weight: bold; line-height: 1.8; }
            .footer { background: #fafafa; border-top: 1px solid #f0f0f0; padding: 20px; text-align: center; font-size: 12px; color: #aaa; }
          </style></head>
          <body>
            <div class="container">
              <div class="header">
                <h2>تنبيه أمني</h2>
              </div>
              <div class="body">
                <p class="greeting">مرحباً <strong>${userFull.fullName}</strong>،<br>تم تسجيل دخول إلى حسابك من جهاز جديد</p>
               <div class="info-box">
                <div class="info-row">
                    <span class="info-label">الجهاز</span>
                    <span class="info-value">${detectedDeviceName}</span>
                </div>
                
                <div class="info-row">
                    <span class="info-label">الموقع</span>
                    <span class="info-value">${locationText}</span>
                </div>
                </div>
                </div>
                <p class="note">إذا كنت أنت من قام بذلك، يمكنك تجاهل هذا الإيميل</p>
                <p class="warning">إذا لم تكن أنت، يُنصح بتغيير كلمة المرور فوراً من إعدادات الحساب</p>
              </div>
              <div class="footer">فريق وصيد</div>
            </div>
          </body></html>
        `;
                await sendActivityAlertEmail(
                    userFull.email,
                    userFull.fullName,
                    'تنبيه: تسجيل دخول من جهاز جديد',
                    html
                );
                console.log(`✅ تم إرسال إيميل التنبيه: ${userFull.email}`);
            } catch (emailErr) {
                console.error('⚠️ فشل إرسال إيميل التنبيه:', emailErr.message);
            }
        };

if (deviceName) {
    const currentToken = req.headers.authorization;

    if (!user.registrationDevice) {
        console.log(`حفظ أول جهاز كجهاز رئيسي: ${deviceName}`);
        
        await User.findByIdAndUpdate(userId, { 
            registrationDevice: deviceName 
        });
        
        user.registrationDevice = deviceName; 
    }

    if (user.registrationDevice === deviceName) {
        console.log(`دخول من الجهاز الرئيسي  (${deviceName}).`);
    } 
    else {
        let deviceRecord = user.registrationDevices.find(d => d.deviceName === deviceName);

        if (!deviceRecord) {
            console.log(`اكتشاف جهاز جديد لأول مرة: ${deviceName}`);
            await sendDeviceAlertEmail(deviceName);

            user.registrationDevices.push({ 
                deviceName: deviceName, 
                lastAlertToken: currentToken 
            });
            await user.save();
        } 
        else if (deviceRecord.lastAlertToken !== currentToken) {
            console.log(` إعادة تنبيه: دخول جديد لجهاز : ${deviceName}`);
            await sendDeviceAlertEmail(deviceName);

            deviceRecord.lastAlertToken = currentToken;
            await user.save();
        } 
        else {
            console.log(` جهاز غريب معروف وفي نفس الجلسة: ${deviceName}`);
        }
    }
}

        //  موقع جغرافي جديد
        if (latitude && longitude) {
            if (!user.registrationLocation?.lat) {
                await User.findByIdAndUpdate(userId, {
                    registrationLocation: { lat: latitude, lng: longitude }
                });
                console.log(`📍 registrationLocation محفوظ لأول مرة: ${latitude}, ${longitude}`);
            } else {
                const distance = distanceKm(
                    latitude, longitude,
                    user.registrationLocation.lat,
                    user.registrationLocation.lng
                );
                console.log(`📏 المسافة عن موقع التسجيل: ${Math.round(distance)} km`);

                if (distance > 100) {
                    const displayLocation = locationName || `${Number(latitude).toFixed(2)}, ${Number(longitude).toFixed(2)}`;
                    anomalies.push({
                        type: 'new_location',
                        detail: `تسجيل دخول من ${displayLocation}`,
                    });
                    console.log(`🚨 new_location: ${displayLocation}`);
                } else {
                    console.log(`✅ الموقع طبيعي — المسافة ${Math.round(distance)} km`);
                }
            }
        }

        // شبكة  جديدة

        if (ssid && ssid !== 'unknown' && ssid !== '<unknown ssid>') {
            const savedWifi = user.registrationWifi;
            console.log(`📶 SSID: "${ssid}" | المحفوظة: "${savedWifi || 'لا يوجد بعد'}"`);

            if (!savedWifi) {
                // أول دخول — احفظ ولا تحذر
                await User.findByIdAndUpdate(userId, { registrationWifi: ssid });
                console.log(`📶 أول شبكة محفوظة: "${ssid}"`);
            } else if (savedWifi !== ssid) {
                // شبكة مختلفة — حذّر ولا تحفظ
                anomalies.push({
                    type: 'new_wifi',
                    detail: `تم الدخول من شبكة جديدة: ${ssid}`,
                });
                console.log(`🚨 new_wifi: "${ssid}"`);
            } else {
                console.log(`✅ الشبكة معروفة — لا يوجد تحذير`);
            }
        } else {
            console.log(' SSID غير متاح — تخطي فحص الشبكة');
        }

        //  محاولات دخول فاشلة سابقة

       if (user.pendingFailedAttemptsAlert > 0) {
            anomalies.push({
                type: 'failed_attempts',
                detail: `تم رصد محاولات لتسجيل الدخول إلى حسابك`,
            });
            console.log(`🚨 failed_attempts: ${user.pendingFailedAttemptsAlert}`);
            await User.findByIdAndUpdate(userId, { pendingFailedAttemptsAlert: 0 });
        }
        /*
         if (user.pendingUnknownDeviceAlert && user.pendingUnknownDeviceAlert !== deviceName) {
            anomalies.push({
                type: 'unknown_device',
                detail: `تسجيل دخول من جهاز جديد: ${user.pendingUnknownDeviceAlert}`,
            });
            console.log(` pending_unknown_device: ${user.pendingUnknownDeviceAlert}`);
            await User.findByIdAndUpdate(userId, { pendingUnknownDeviceAlert: null });
        }
            */
        console.log(`Anomalies: ${anomalies.length}`);

        return res.json({ success: true, anomalies });

    } catch (err) {
        console.error('🔥 Anomaly System Error:', err);
        return res.status(500).json({
            success: false,
            message: 'نظام كشف الأنشطة يواجه مشكلة فنية',
            anomalies: []
        });
    }
});

// POST /api/anomaly/report-action

router.post('/report-action', authMiddleware, async (req, res) => {
    try {
        const { anomalyId, wasMe } = req.body;
        console.log(`📢 بلاغ: ${anomalyId} | wasMe: ${wasMe}`);
        return res.json({ success: true, message: 'تم استلام بلاغك بنجاح' });
    } catch (err) {
        return res.status(500).json({ success: false });
    }
});



module.exports = router;