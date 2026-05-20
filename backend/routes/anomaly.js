const express = require('express');
const router = express.Router();
const { sendActivityAlertEmail } = require('../utils/emailService');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

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

router.post('/check', authMiddleware, async (req, res) => {
    try {
        const userId = req.userId;
        const { latitude, longitude, locationName, ssid } = req.body;
        const anomalies = [];

        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('Anomaly Check: طلب جديد');
        console.log(`   → userId: ${userId}`);
        console.log(`   → SSID: ${ssid}`);
        console.log(`   → Location: ${latitude}, ${longitude} — ${locationName}`);

        const user = await User.findById(userId).select(
            'registrationLocation registrationWifi pendingFailedAttemptsAlert'
        );

        if (!user) {
            return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
        }

        // موقع جغرافي جديد
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

        // شبكة جديدة
        if (ssid && ssid !== 'unknown' && ssid !== '<unknown ssid>') {
            const savedWifi = user.registrationWifi;
            console.log(`📶 SSID: "${ssid}" | المحفوظة: "${savedWifi || 'لا يوجد بعد'}"`);

            if (!savedWifi) {
                await User.findByIdAndUpdate(userId, { registrationWifi: ssid });
                console.log(`📶 أول شبكة محفوظة: "${ssid}"`);
            } else if (savedWifi !== ssid) {
                anomalies.push({
                    type: 'new_wifi',
                    detail: `تم الدخول من شبكة جديدة: ${ssid}`,
                });
                console.log(`🚨 new_wifi: "${ssid}"`);
            } else {
                console.log(`✅ الشبكة معروفة — لا يوجد تحذير`);
            }
        } else {
            console.log('SSID غير متاح — تخطي فحص الشبكة');
        }

        // محاولات دخول فاشلة سابقة
        if (user.pendingFailedAttemptsAlert > 0) {
            anomalies.push({
                type: 'failed_attempts',
                detail: `تم رصد محاولات لتسجيل الدخول إلى حسابك`,
            });
            console.log(`🚨 failed_attempts: ${user.pendingFailedAttemptsAlert}`);
            await User.findByIdAndUpdate(userId, { pendingFailedAttemptsAlert: 0 });
        }

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