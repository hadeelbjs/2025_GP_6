// routes/auth.js - Production Version with Redis
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { sendVerificationEmail, sendBiometricVerificationEmail } = require('../utils/emailService');
const twilio = require('twilio');
const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const { parsePhoneNumberFromString } = require('libphonenumber-js');
const authMiddleware = require('../middleware/auth');

// ============================================
// Redis Integration (إذا كان متوفر)
// ============================================
let useRedis = false;
let redisOperations = null;

try {
  redisOperations = require('../config/redis');
  useRedis = true;
  console.log('✅ Using Redis for pending registrations');
} catch (err) {
  console.log('⚠️ Redis not configured, using in-memory storage');
  useRedis = false;
}

// ============================================
// In-Memory Storage (Fallback)
// ============================================
const pendingRegistrations = new Map();

// تنظيف البيانات المنتهية كل 15 دقيقة
if (!useRedis) {
  setInterval(() => {
    const now = Date.now();
    for (const [key, value] of pendingRegistrations.entries()) {
      if (value.expiresAt < now) {
        pendingRegistrations.delete(key);
      }
    }
  }, 15 * 60 * 1000);
}

// ============================================
// Storage Abstraction Layer
// ============================================
const storageOps = {
  async save(key, data) {
    if (useRedis) {
      return await redisOperations.savePendingRegistration(key, data);
    } else {
      pendingRegistrations.set(key, data);
      return true;
    }
  },
  
  async get(key) {
    if (useRedis) {
      return await redisOperations.getPendingRegistration(key);
    } else {
      return pendingRegistrations.get(key);
    }
  },
  
  async delete(key) {
    if (useRedis) {
      return await redisOperations.deletePendingRegistration(key);
    } else {
      pendingRegistrations.delete(key);
      return true;
    }
  },
  
  async update(key, data) {
    if (useRedis) {
      return await redisOperations.updatePendingRegistration(key, data);
    } else {
      const existing = pendingRegistrations.get(key);
      if (existing) {
        pendingRegistrations.set(key, { ...existing, ...data });
        return true;
      }
      return false;
    }
  }
};

// ============================================
// Utility Functions
// ============================================
function normalizePhone(rawPhone) {
  const phoneNumber = parsePhoneNumberFromString(rawPhone);
  if (!phoneNumber || !phoneNumber.isValid()) {
    return null;
  }
  return phoneNumber.number;
}

const generateCode = () => {
  return crypto.randomInt(100000, 999999).toString();
};

const sendEmailWithTimeout = async (emailFunc, timeoutMs = 10000) => {
  return Promise.race([
    emailFunc(),
    new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Email timeout')), timeoutMs)
    )
  ]);
};

const validatePasswordMiddleware = (req, res, next) => {
  const { password } = req.body;
  
  if (!password) {
    return res.status(400).json({
      success: false,
      message: 'الرجاء إدخال كلمة المرور'
    });
  }
  
  const errors = User.validatePasswordStrength(password);
  
  if (errors.length > 0) {
    return res.status(400).json({
      success: false,
      message: errors[0]
    });
  }
  
  next();
};

// ============================================
// REGISTRATION ENDPOINTS
// ============================================

// Step 1: Request Registration (No DB Save)
router.post(
  '/register',
  [
    body('fullName').notEmpty().withMessage('الرجاء إدخال الاسم الكامل'),
    body('username')
      .isLength({ min: 3 }).withMessage('اسم المستخدم يجب أن يكون ٣ أحرف على الأقل')
      .matches(/^[a-zA-Z0-9_]+$/).withMessage('اسم المستخدم يجب أن يحتوي فقط على أحرف أو أرقام أو _'),
    body('email').isEmail().withMessage('الرجاء إدخال بريد إلكتروني صالح'),
    body('phone').custom(value => {
        const phone = normalizePhone(value);
        if (!phone) throw new Error('رقم الجوال غير صالح');
        return true;
    }),
  ],
  validatePasswordMiddleware,
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        success: false, 
        message: errors.array()[0].msg 
      });
    }

    const { fullName, username, email, phone, password } = req.body;
    const normalizedPhone = normalizePhone(phone);

    try {
      // التحقق من أن البيانات غير مستخدمة
      const existingUser = await User.findOne({ 
        $or: [
          { email: email.toLowerCase() }, 
          { username: username.toLowerCase() }, 
          { phone: normalizedPhone }
        ] 
      });

      if (existingUser) {
        let message = '';
        if (existingUser.email === email.toLowerCase()) {
            message = 'البريد الإلكتروني مستخدم بالفعل';
        } else if (existingUser.username === username.toLowerCase()) {
            message = 'اسم المستخدم مستخدم بالفعل';
        } else if (existingUser.phone === normalizedPhone) {
            message = 'رقم الجوال مستخدم بالفعل';
        }
        return res.status(400).json({ success: false, message });
      }

      // إنشاء رمز التحقق و ID فريد
      const verificationCode = generateCode();
      const registrationId = crypto.randomBytes(16).toString('hex');

      // تشفير كلمة المرور
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);

      // حفظ البيانات مؤقتاً
      const success = await storageOps.save(registrationId, {
        fullName,
        username: username.toLowerCase(),
        email: email.toLowerCase(),
        phone: normalizedPhone,
        password: hashedPassword,
        verificationCode,
        expiresAt: Date.now() + 10 * 60 * 1000,
        createdAt: Date.now()
      });

      if (!success) {
        throw new Error('Failed to save registration data');
      }

      // إرسال رمز التحقق
      try {
        await sendEmailWithTimeout(
          () => sendVerificationEmail(email, fullName, verificationCode),
          10000
        );
      } catch (emailError) {
        console.error('Email sending failed:', emailError.message);
      }

      res.json({
        success: true,
        message: 'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
        registrationId,
        email: email.toLowerCase()
      });

    } catch (err) {
      console.error('Register Error:', err);
      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ في السيرفر' 
      });
    }
  }
);

// Step 2: Verify OTP and Create User
router.post('/verify-email-and-create', async (req, res) => {
  const { registrationId, code } = req.body;

  if (!registrationId || !code) {
    return res.status(400).json({
      success: false,
      message: 'الرجاء إدخال رمز التحقق'
    });
  }

  try {
    // البحث عن البيانات المؤقتة
    const pendingData = await storageOps.get(registrationId);

    if (!pendingData) {
      return res.status(400).json({
        success: false,
        message: 'انتهت صلاحية الجلسة، الرجاء إعادة التسجيل'
      });
    }

    // التحقق من الرمز
    if (pendingData.verificationCode !== code) {
      return res.status(400).json({
        success: false,
        message: 'الرمز غير صحيح'
      });
    }

    // التحقق من انتهاء الصلاحية
    if (pendingData.expiresAt < Date.now()) {
      await storageOps.delete(registrationId);
      return res.status(400).json({
        success: false,
        message: 'انتهت صلاحية الرمز، الرجاء إعادة التسجيل'
      });
    }

    // Double Check - التأكد من عدم استخدام البيانات
    const existingUser = await User.findOne({ 
      $or: [
        { email: pendingData.email }, 
        { username: pendingData.username }, 
        { phone: pendingData.phone }
      ] 
    });

    if (existingUser) {
      await storageOps.delete(registrationId);
      return res.status(400).json({
        success: false,
        message: 'البيانات مستخدمة بالفعل، الرجاء إعادة التسجيل ببيانات مختلفة'
      });
    }

    // إنشاء المستخدم في قاعدة البيانات
    const user = new User({
      fullName: pendingData.fullName,
      username: pendingData.username,
      email: pendingData.email,
      phone: pendingData.phone,
      password: pendingData.password,
      passwordChangedAt: new Date(),
      passwordHistory: [{ hash: pendingData.password, changedAt: new Date() }],
      isEmailVerified: true, // تم التحقق بالفعل
      isPhoneVerified: false
    });

    await user.save();

    // حذف البيانات المؤقتة
    await storageOps.delete(registrationId);

    res.json({
      success: true,
      message: 'تم إنشاء الحساب بنجاح',
      email: user.email,
      phone: user.phone
    });

  } catch (err) {
    console.error('Verify and Create Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// Resend Registration Code
router.post('/resend-registration-code', async (req, res) => {
  const { registrationId } = req.body;

  if (!registrationId) {
    return res.status(400).json({
      success: false,
      message: 'معرف التسجيل مطلوب'
    });
  }

  try {
    const pendingData = await storageOps.get(registrationId);

    if (!pendingData) {
      return res.status(400).json({
        success: false,
        message: 'انتهت صلاحية الجلسة، الرجاء إعادة التسجيل'
      });
    }

    // إنشاء رمز جديد
    const newCode = generateCode();
    pendingData.verificationCode = newCode;
    pendingData.expiresAt = Date.now() + 10 * 60 * 1000;

    // حفظ التحديث
    await storageOps.update(registrationId, pendingData);

    // إرسال الرمز الجديد
    try {
      await sendEmailWithTimeout(
        () => sendVerificationEmail(pendingData.email, pendingData.fullName, newCode),
        10000
      );
    } catch (emailError) {
      console.error('Email sending failed:', emailError.message);
    }

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق مرة أخرى'
    });

  } catch (err) {
    console.error('Resend Registration Code Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// ============================================
// PHONE VERIFICATION (After Account Creation)
// ============================================

router.post('/send-phone-verification', async (req, res) => {
  const { phone } = req.body;
  const normalizedPhone = normalizePhone(phone);

  if (!normalizedPhone) {
    return res.status(400).json({ success: false, message: 'رقم الجوال غير صالح' });
  }

  try {
    const verification = await client.verify.v2
      .services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verifications
      .create({ to: normalizedPhone, channel: 'sms' });

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق عبر SMS',
      status: verification.status
    });
  } catch (err) {
    console.error('Twilio Error:', err);
    res.status(500).json({ success: false, message: 'فشل إرسال رمز التحقق' });
  }
});

router.post('/verify-phone', async (req, res) => {
  const { phone, code } = req.body;
  const normalizedPhone = normalizePhone(phone);

  if (!normalizedPhone) {
    return res.status(400).json({
      success: false,
      message: 'رقم الجوال غير صالح'
    });
  }

  try {
    const check = await client.verify.v2
      .services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verificationChecks
      .create({ to: normalizedPhone, code });

    if (check.status === 'approved') {
      const user = await User.findOne({ phone: normalizedPhone });
      
      if (user) {
        user.isPhoneVerified = true;
        await user.save();

        const accessToken = jwt.sign(
          { user: { id: user.id, username: user.username } },
          process.env.JWT_SECRET,
          { expiresIn: '7d' }
        );

        const refreshToken = jwt.sign(
          { user: { id: user.id } },
          process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET,
          { expiresIn: '30d' }
        );

        return res.json({
          success: true,
          message: 'تم تأكيد رقم الجوال بنجاح',
          accessToken,
          refreshToken,
          user: {
            id: user.id,
            fullName: user.fullName,
            username: user.username,
            email: user.email,
            phone: user.phone,
            memoji: user.memoji || '😊',
            isPhoneVerified: user.isPhoneVerified,
            isEmailVerified: user.isEmailVerified
          }
        });
      }
    }

    return res.status(400).json({
      success: false,
      message: 'رمز التحقق غير صحيح'
    });
  } catch (err) {
    console.error('Verify Phone Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء التحقق من الرمز'
    });
  }
});

router.post('/skip-phone-verification', async (req, res) => {
  const { email } = req.body;

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    if (!user.isEmailVerified) {
      return res.status(400).json({
        success: false,
        message: 'الرجاء تأكيد البريد الإلكتروني أولاً'
      });
    }

    const accessToken = jwt.sign(
      { user: { id: user.id, username: user.username } },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    const refreshToken = jwt.sign(
      { user: { id: user.id } },
      process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        memoji: user.memoji || '😊',
        isPhoneVerified: user.isPhoneVerified,
        isEmailVerified: user.isEmailVerified
      }
    });

  } catch (err) {
    console.error('Skip Phone Verification Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// ============================================
// LOGIN & 2FA
// ============================================
// ... (باقي endpoints: login, verify-2fa, forgot-password, etc.)
// نفس الكود من الملف السابق

module.exports = router;