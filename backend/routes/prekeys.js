// routes/prekeys.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const PreKeyBundle = require('../models/PreKeyBundle');

// ===================================
// 📤 رفع PreKey Bundle (كامل أو جزئي)
// ===================================
router.post('/upload', auth, async (req, res) => {
  try {
    const { registrationId, identityKey, signedPreKey, preKeys, version } = req.body;

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
      // تحديد نوع التحديث
      const isFullBundleUpdate = registrationId && identityKey && signedPreKey;
      
      if (isFullBundleUpdate) {
        // تحديث كامل - استبدال كل شيء
        console.log(`🔄 FULL BUNDLE UPDATE for user ${req.user.id}`);
        console.log(`  Old version: ${bundle.version}`);
        console.log(`  New version: ${version || Date.now()}`);
        console.log(`  Old registrationId: ${bundle.registrationId}`);
        console.log(`  New registrationId: ${registrationId}`);
        
        // تحذير إذا كان registrationId مختلف
        if (bundle.registrationId !== registrationId) {
          console.warn('⚠️ WARNING: RegistrationId changed! Complete key rotation.');
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
        
        // تحديث النسخة
        bundle.version = version || Date.now();
        bundle.lastKeyRotation = Date.now();
        bundle.updatedAt = Date.now();
        
        await bundle.save();
        
        console.log(`✅ Bundle updated completely. New version: ${bundle.version}`);
        
        return res.json({
          success: true,
          userId: req.user.id,
          message: 'تم تحديث Bundle بالكامل',
          version: bundle.version,
          totalKeys: bundle.preKeys.length,
          availableKeys: bundle.getAvailablePreKeysCount()
        });
      } else {
        // إضافة PreKeys فقط (بدون تغيير IdentityKey أو SignedPreKey)
        console.log(`➕ ADDING PreKeys ONLY for user ${req.user.id}`);
        console.log(`  Current version: ${bundle.version}`);
        console.log(`  Current PreKeys count: ${bundle.preKeys.length}`);
        console.log(`  Adding ${preKeys.length} new PreKeys`);
        
        const newPreKeys = preKeys.map(pk => ({
          keyId: pk.keyId,
          publicKey: pk.publicKey,
          used: false,
          usedAt: null,
          createdAt: new Date()
        }));

        // إضافة المفاتيح الجديدة (بدون تغيير النسخة)
        bundle.preKeys.push(...newPreKeys);
        bundle.lastKeyRotation = Date.now();
        bundle.updatedAt = Date.now();

        await bundle.save();

        console.log(`✅ PreKeys added. Total: ${bundle.preKeys.length}`);
        console.log(`  Version unchanged: ${bundle.version}`);

        return res.json({
          success: true,
          message: `تم إضافة ${newPreKeys.length} مفتاح جديد`,
          version: bundle.version,
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
      version: version || Date.now(),
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
    console.log(`  Version: ${bundle.version}`);

    res.json({
      success: true,
      message: 'تم رفع المفاتيح بنجاح',
      version: bundle.version,
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

// ===================================
// 📥 جلب PreKey Bundle لمستخدم معين
// ===================================
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
    
    if (!unusedPreKey) {
      return res.status(503).json({
        success: false,
        message: 'المستخدم نفذت منه المفاتيح المتاحة'
      });
    }

    // تحديد المفتاح كمستخدم
    await bundle.markPreKeyAsUsed(unusedPreKey.keyId);

    // إرجاع البيانات مع النسخة
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
        },
        version: bundle.version // ✅ إرجاع النسخة
      }
    });

  } catch (err) {
    console.error('❌ Get PreKey Bundle Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب المفاتيح',
      error: err.message
    });
  }
});

// ===================================
// 🔢 جلب رقم نسخة المفاتيح
// ===================================
router.get('/version/current', auth, async (req, res) => {
  try {
    const bundle = await PreKeyBundle.findOne({
      userId: req.user.id
    }).select('version updatedAt');

    if (!bundle) {
      return res.json({
        success: true,
        version: null,
        exists: false
      });
    }

    res.json({
      success: true,
      version: bundle.version,
      exists: true,
      lastUpdate: bundle.updatedAt
    });

  } catch (err) {
    console.error('❌ Get Version Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب النسخة'
    });
  }
});

// ===================================
// 📊 التحقق من عدد المفاتيح المتبقية
// ===================================
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
      version: bundle.version,
      needsRefresh: bundle.needsRefresh()
    });

  } catch (err) {
    console.error('❌ Check PreKeys Count Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في فحص المفاتيح'
    });
  }
});

// ===================================
// 🔄 تدوير SignedPreKey
// ===================================
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
    // ⚠️ لا نغير النسخة لأن هذا ليس تحديث كامل
    await bundle.save();

    res.json({
      success: true,
      message: 'تم تحديث SignedPreKey بنجاح'
    });

  } catch (err) {
    console.error('❌ Rotate SignedPreKey Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في تحديث المفتاح'
    });
  }
});

// ===================================
// 🧹 حذف PreKeys القديمة (تنظيف)
// ===================================
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
    console.error('❌ Cleanup PreKeys Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في التنظيف'
    });
  }
});

// ===================================
// 🗑️ حذف Bundle كامل (عند حذف الحساب)
// ===================================
router.delete('/delete-bundle', auth, async (req, res) => {
  try {
    const result = await PreKeyBundle.deleteOne({
      userId: req.user.id
    });

    if (result.deletedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Bundle غير موجود'
      });
    }

    res.json({
      success: true,
      message: 'تم حذف Bundle بنجاح'
    });

  } catch (err) {
    console.error('❌ Delete Bundle Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في حذف Bundle'
    });
  }
});

module.exports = router;