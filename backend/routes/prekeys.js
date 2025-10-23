// routes/prekeys.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const PreKeyBundle = require('../models/PreKeyBundle');

// رفع PreKey Bundle (كامل أو جزئي)
router.post('/upload', auth, async (req, res) => {
  try {
    const { registrationId, identityKey, signedPreKey, preKeys } = req.body;

    // التحقق من صحة البيانات
    if (!preKeys || !Array.isArray(preKeys) || preKeys.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'يجب إرسال مفاتيح على الأقل'
      });
    }

    // البحث عن Bundle موجود
    let bundle = await PreKeyBundle.findOne({ userId: req.user.id });

    if (bundle) {
      // ✅ CHECK: هل هذا تحديث كامل (Full Bundle Update) أم إضافة PreKeys فقط؟
      const isFullBundleUpdate = registrationId && identityKey && signedPreKey;
      
      if (isFullBundleUpdate) {
        // ⚠️ تحديث كامل - استبدال كل شيء
        console.log(`🔄 FULL BUNDLE UPDATE for user ${req.user.id}`);
        console.log(`  Old registrationId: ${bundle.registrationId}`);
        console.log(`  New registrationId: ${registrationId}`);
        
        // ✅ تحذير إذا كان registrationId مختلف (يعني مفاتيح جديدة تماماً)
        if (bundle.registrationId !== registrationId) {
          console.warn('⚠️ WARNING: RegistrationId changed! Replacing entire bundle.');
        }
        
        // استبدال كل شيء
        bundle.registrationId = registrationId;
        bundle.identityKey = identityKey;
        bundle.signedPreKey = signedPreKey;
        bundle.preKeys = preKeys.map(pk => ({
          keyId: pk.keyId,
          publicKey: pk.publicKey,
          used: false,
          usedAt: null,
          createdAt: new Date()
        }));
        bundle.lastKeyRotation = Date.now();
        bundle.updatedAt = Date.now();
        
        await bundle.save();
        
        return res.json({
          success: true,
          message: 'تم تحديث Bundle بالكامل',
          totalKeys: bundle.preKeys.length,
          availableKeys: bundle.getAvailablePreKeysCount()
        });
      } else {
        // ✅ إضافة PreKeys فقط (بدون تغيير IdentityKey أو SignedPreKey)
        console.log(`➕ ADDING PreKeys ONLY for user ${req.user.id}`);
        console.log(`  Current PreKeys count: ${bundle.preKeys.length}`);
        console.log(`  Adding ${preKeys.length} new PreKeys`);
        
        const newPreKeys = preKeys.map(pk => ({
          keyId: pk.keyId,
          publicKey: pk.publicKey,
          used: false,
          usedAt: null,
          createdAt: new Date()
        }));

        // إضافة المفاتيح الجديدة
        bundle.preKeys.push(...newPreKeys);
        bundle.lastKeyRotation = Date.now();
        bundle.updatedAt = Date.now();

        await bundle.save();

        console.log(`  Total PreKeys after update: ${bundle.preKeys.length}`);
        console.log(`  Available PreKeys: ${bundle.getAvailablePreKeysCount()}`);

        return res.json({
          success: true,
          message: `تم إضافة ${newPreKeys.length} مفتاح جديد`,
          totalKeys: bundle.preKeys.length,
          availableKeys: bundle.getAvailablePreKeysCount()
        });
      }
    }

    // ✅ إنشاء Bundle جديد (أول مرة)
    console.log(`🆕 Creating NEW bundle for user ${req.user.id}`);
    
    if (!registrationId || !identityKey || !signedPreKey) {
      return res.status(400).json({
        success: false,
        message: 'البيانات غير كاملة للتسجيل الأول'
      });
    }

    bundle = new PreKeyBundle({
      userId: req.user.id,
      registrationId,
      identityKey,
      signedPreKey,
      preKeys: preKeys.map(pk => ({
        keyId: pk.keyId,
        publicKey: pk.publicKey,
        used: false,
        usedAt: null,
        createdAt: new Date()
      }))
    });

    await bundle.save();

    console.log(`✅ Bundle created with ${bundle.preKeys.length} PreKeys`);

    res.json({
      success: true,
      message: 'تم رفع المفاتيح بنجاح',
      totalKeys: bundle.preKeys.length,
      availableKeys: bundle.getAvailablePreKeysCount()
    });

  } catch (err) {
    console.error('❌ Upload PreKey Bundle Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في رفع المفاتيح',
      error: err.message
    });
  }
});
// جلب PreKey Bundle لمستخدم معين
router.get('/:userId', auth, async (req, res) => {
  try {
    const bundle = await PreKeyBundle.findOne({
      userId: req.params.userId
    });

    if (!bundle) {
      return res.status(404).json({
        success: false,
        message: 'لم يتم العثور على مفاتيح المستخدم'
      });
    }

    // البحث عن أول PreKey غير مستخدم
    const unusedPreKey = bundle.getUnusedPreKey();
    
    // إذا لم يتبق مفاتيح متاحة
    if (!unusedPreKey) {
      return res.status(503).json({
        success: false,
        message: 'المستخدم نفذت منه المفاتيح المتاحة'
      });
    }

    // تحديد المفتاح كمستخدم
    await bundle.markPreKeyAsUsed(unusedPreKey.keyId);

    // إرجاع البيانات
    res.json({
      success: true,
      bundle: {
        registrationId: bundle.registrationId,
        identityKey: bundle.identityKey,
        signedPreKey: {
          keyId: bundle.signedPreKey.keyId,
          publicKey: bundle.signedPreKey.publicKey,
          signature: bundle.signedPreKey.signature
        },
        preKey: {
          keyId: unusedPreKey.keyId,
          publicKey: unusedPreKey.publicKey
        }
      }
    });

  } catch (err) {
    console.error('Get PreKey Bundle Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب المفاتيح',
      error: err.message
    });
  }
});

// التحقق من عدد المفاتيح المتبقية
router.get('/count/remaining', auth, async (req, res) => {
  try {
    const bundle = await PreKeyBundle.findOne({
      userId: req.user.id
    });

    if (!bundle) {
      return res.json({
        success: true,
        count: 0,
        needsRefresh: true
      });
    }

    const availableCount = bundle.getAvailablePreKeysCount();

    res.json({
      success: true,
      count: availableCount,
      total: bundle.preKeys.length,
      needsRefresh: bundle.needsRefresh()
    });

  } catch (err) {
    console.error('Check PreKeys Count Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في فحص المفاتيح'
    });
  }
});

// تدوير SignedPreKey (اختياري)
router.post('/rotate-signed-prekey', auth, async (req, res) => {
  try {
    const { signedPreKey } = req.body;

    if (!signedPreKey || !signedPreKey.keyId || !signedPreKey.publicKey || !signedPreKey.signature) {
      return res.status(400).json({
        success: false,
        message: 'بيانات SignedPreKey غير صحيحة'
      });
    }

    const bundle = await PreKeyBundle.findOne({
      userId: req.user.id
    });

    if (!bundle) {
      return res.status(404).json({
        success: false,
        message: 'Bundle غير موجود'
      });
    }

    bundle.signedPreKey = signedPreKey;
    bundle.lastKeyRotation = Date.now();
    await bundle.save();

    res.json({
      success: true,
      message: 'تم تحديث SignedPreKey بنجاح'
    });

  } catch (err) {
    console.error('Rotate SignedPreKey Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في تحديث المفتاح'
    });
  }
});

// حذف PreKeys القديمة (تنظيف)
router.delete('/cleanup-old', auth, async (req, res) => {
  try {
    const bundle = await PreKeyBundle.findOne({
      userId: req.user.id
    });

    if (!bundle) {
      return res.status(404).json({
        success: false,
        message: 'Bundle غير موجود'
      });
    }

    const oneMonthAgo = new Date();
    oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);

    const initialCount = bundle.preKeys.length;
    
    // حذف المفاتيح المستخدمة منذ أكثر من شهر
    bundle.preKeys = bundle.preKeys.filter(pk => {
      return !pk.used || (pk.usedAt && pk.usedAt > oneMonthAgo);
    });

    await bundle.save();

    res.json({
      success: true,
      message: 'تم تنظيف المفاتيح القديمة',
      deletedCount: initialCount - bundle.preKeys.length,
      remainingCount: bundle.preKeys.length
    });

  } catch (err) {
    console.error('Cleanup PreKeys Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في التنظيف'
    });
  }
});



module.exports = router;