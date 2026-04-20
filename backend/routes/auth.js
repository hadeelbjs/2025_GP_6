
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const PreKeyBundle = require('../models/PreKeyBundle');
const Message = require('../models/Message');
const { sendVerificationEmail, sendBiometricVerificationEmail,sendVerificationOTP , sendNewDeviceAlertEmail } = require('../utils/emailService');
const twilio = require('twilio');
const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const { parsePhoneNumberFromString } = require('libphonenumber-js');
const authMiddleware = require('../middleware/auth');
const ContentScanning = require('../models/ContentScanning');
// ============================================
// تخزين مؤقت للبيانات قبل التحقق (في الذاكرة)
// ============================================
const pendingRegistrations = new Map();

// تنظيف البيانات المنتهية كل 15 دقيقة
setInterval(() => {
  const now = Date.now();
  for (const [key, value] of pendingRegistrations.entries()) {
    if (value.expiresAt < now) {
      console.log(`🗑️ Cleaning expired registration: ${key}`);
      pendingRegistrations.delete(key);
    }
  }
}, 15 * 60 * 1000);

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
  const { newPassword } = req.body;
  
  if (!newPassword) {
    return res.status(400).json({
      success: false,
      message: 'الرجاء إدخال كلمة المرور'
    });
  }
  
  const errors = User.validatePasswordStrength(newPassword);
  
  if (errors.length > 0) {
    return res.status(400).json({
      success: false,
      message: errors[0]
    });
  }
  
  next();
};
router.post('/send-otp', authMiddleware, async (req, res) => {
  try {
     const user = req.user;
    if (!user) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }

    const verificationCode = generateCode();
    user.verificationCode = verificationCode;
    user.verificationCodeExpires = Date.now() + 10 * 60 * 1000;
    await user.save();

    try {
      await sendEmailWithTimeout(
        () => sendVerificationOTP(req.body.email, user.fullName, verificationCode),
        10000
      );
    } catch (emailError) {
      console.error('Email sending failed:', emailError.message);
      return res.status(500).json({ success: false, message: 'فشل إرسال الإيميل' });
    }

    res.json({ success: true, message: 'تم إرسال رمز التحقق' });

  } catch (err) {
    res.status(500).json({ success: false, message: 'حدث خطأ في السيرفر' });
  }
});

router.post('/verify-otp', authMiddleware, async (req, res) => {
  try {
    const { code } = req.body; 

    if (!code) {
      return res.status(400).json({ success: false, message: 'أدخل رمز التحقق' });
    }

    const user = req.user;
    if (!user) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }

    if (code !== user.verificationCode || user.verificationCodeExpires < Date.now()) {
      return res.status(400).json({ success: false, message: 'رمز خاطئ أو منتهي الصلاحية' });
    }

    user.verificationCode = null;
    user.verificationCodeExpires = null;
    await user.save();

    res.json({ success: true, message: 'تم التحقق بنجاح' });

  } catch (err) {
    res.status(500).json({ success: false, message: 'حدث خطأ في السيرفر' });
  }
});
// ============================================
// الخطوة 1: التسجيل - إرسال OTP (بدون حفظ البيانات)
// ============================================
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

    const { fullName, username, email, phone, newPassword } = req.body;
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

      // إنشاء رمز التحقق
      const verificationCode = generateCode();
      const newRegistrationId = crypto.randomBytes(16).toString('hex');

      // تشفير كلمة المرور
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(newPassword, salt);

      // حفظ البيانات مؤقتاً في الذاكرة
      pendingRegistrations.set(newRegistrationId, {
        fullName,
        username: username.toLowerCase(),
        email: email.toLowerCase(),
        phone: normalizedPhone,
        password: hashedPassword,
        verificationCode,
        expiresAt: Date.now() + 10 * 60 * 1000, // 10 دقائق
        createdAt: Date.now()
      });

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
        newRegistrationId,
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

// ============================================
// الخطوة 2: التحقق من OTP وحفظ المستخدم
// ============================================
router.post('/verify-email-and-create', async (req, res) => {

const { newRegistrationId, code, deviceName } = req.body;

  // التحقق من وجود الرمز
  if (!code) {
    return res.status(400).json({
      success: false,
      message: 'الرجاء إدخال رمز التحقق'
    });
  }

  // التحقق من وجود معرف التسجيل
  if (!newRegistrationId) {
    return res.status(400).json({
      success: false,
      message: 'معرف التسجيل مطلوب - الرجاء إعادة التسجيل'
    });
  }

  try {
    // البحث عن البيانات المؤقتة
    const pendingData = pendingRegistrations.get(newRegistrationId);

    if (!pendingData) {
      return res.status(400).json({
        success: false,
        message: 'انتهت صلاحية الجلسة، الرجاء إعادة التسجيل'
      });
    }
    if (pendingData.verificationCode !== code) {
 
      return res.status(400).json({
        success: false,
        message: 'الرمز غير صحيح'
      });
    }

    // التحقق من انتهاء الصلاحية
    if (pendingData.expiresAt < Date.now()) {
      pendingRegistrations.delete(newRegistrationId);
      return res.status(400).json({
        success: false,
        message: 'انتهت صلاحية الرمز، الرجاء إعادة التسجيل'
      });
    }

    // التحقق مرة أخرى أن البيانات غير مستخدمة
    const existingUser = await User.findOne({ 
      $or: [
        { email: pendingData.email }, 
        { username: pendingData.username }, 
        { phone: pendingData.phone }
      ] 
    });

    if (existingUser) {
      pendingRegistrations.delete(newRegistrationId);
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
      passwordHistory: [{ hash: pendingData.password}],
      registrationDevice: deviceName || null,
    });
  
    await user.save();

    const contentScanning = new ContentScanning({
       userId: user._id,
    });

    await contentScanning.save();



    // حذف البيانات المؤقتة
    pendingRegistrations.delete(newRegistrationId);

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

// ============================================
// إعادة إرسال رمز التحقق (قبل إنشاء الحساب)
// ============================================
router.post('/resend-registration-code', async (req, res) => {
  const { newRegistrationId } = req.body;

  if (!newRegistrationId) {
    return res.status(400).json({
      success: false,
      message: 'معرف التسجيل مطلوب'
    });
  }

  try {
    const pendingData = pendingRegistrations.get(newRegistrationId);

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

    console.log(`🔄 Resending code for: ${pendingData.email}`);
    console.log(`   - New code: ${newCode}`);

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
// إرسال رمز تحقق SMS للهاتف (بعد إنشاء الحساب)
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

// ============================================
// تأكيد رمز OTP للهاتف (بعد إنشاء الحساب)
// ============================================
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
          { user: { id: user.id, username: user.username , tokenVersion: user.tokenVersion } },
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

// تجديد التوكن باستخدام refresh token
router.post('/refresh-token', async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return res.status(401).json({
      success: false,
      message: 'الرجاء تسجيل الدخول مرة أخرى'
    });
  }

  try {
    const decoded = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET
    );

    const user = await User.findById(decoded.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    const accessToken = jwt.sign(
      { user: { id: user.id, username: user.username , tokenVersion: user.tokenVersion } },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      success: true,
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified
      }
    });

  } catch (err) {
    console.error('Refresh Token Error:', err);
    res.status(401).json({
      success: false,
      message: 'انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى'
    });
  }
});

// تخطي التحقق من الجوال (يرسل توكن بعد تأكيد الإيميل)
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

    const token = jwt.sign(
      { user: { id: user.id, username: user.username , tokenVersion: user.tokenVersion } },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
      token,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
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

// إعادة إرسال رمز التحقق بالإيميل
router.post('/resend-verification-email', async (req, res) => {
  const { email } = req.body;

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(404).json({ 
        success: false, 
        message: 'المستخدم غير موجود' 
      });
    }

    if (user.isEmailVerified) {
      return res.status(400).json({ 
        success: false, 
        message: 'البريد الإلكتروني مؤكد بالفعل' 
      });
    }

    const verificationCode = generateCode();
    user.emailVerificationCode = verificationCode;
    user.emailVerificationExpires = new Date(Date.now() + 10 * 60 * 1000);
    await user.save();

    await sendVerificationEmail(user.email, user.fullName, verificationCode);

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق مرة أخرى'
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ 
      success: false, 
      message: 'حدث خطأ في السيرفر' 
    });
  }
});

// إعادة إرسال رمز التحقق برقم الجوال
router.post('/resend-verification-phone', async (req, res) => {
  const { phone } = req.body;
  const normalizedPhone = normalizePhone(phone);

  if (!normalizedPhone) {
    return res.status(400).json({ 
      success: false, 
      message: 'رقم الجوال غير صالح' 
    });
  }

  try {
    const user = await User.findOne({ phone: normalizedPhone });

    if (!user) {
      return res.status(404).json({ 
        success: false, 
        message: 'المستخدم غير موجود' 
      });
    }

    if (user.isPhoneVerified) {
      return res.status(400).json({ 
        success: false, 
        message: 'رقم الجوال مؤكد بالفعل' 
      });
    }

    const verification = await client.verify.v2
      .services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verifications
      .create({ to: normalizedPhone, channel: 'sms' });

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق مرة أخرى',
      status: verification.status
    });

  } catch (err) {
    console.error('Twilio Error:', err);
    res.status(500).json({ 
      success: false, 
      message: 'فشل إرسال رمز التحقق' 
    });
  }
});

// تسجيل الدخول مع التحقق من انتهاء صلاحية الباسورد
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'البيانات غير صحيحة'
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      user.failedLoginAttempts += 1;
      user.lastFailedLoginAt = new Date();
      user.pendingFailedAttemptsAlert = user.failedLoginAttempts;
      await user.save();

      const remaining = 3 - user.failedLoginAttempts; 

      // قفل الحساب مؤقتاً بعد ٣ محاولات فاشلة
      if (user.failedLoginAttempts >= 3) {
        return res.status(403).json({
          success: false,
          message: 'تم قفل الحساب مؤقتاً بعد محاولات فاشلة كثيرة. الرجاء المحاولة لاحقاً.'
        });
      }

      return res.status(400).json({
        success: false,
        message: `بيانات الدخول غير صحيحة. عدد المحاولات الفاشلة: ${user.failedLoginAttempts}${remaining > 0 ? ` (تبقى ${remaining} محاولات)` : ''}`
      });
    }
    if (user.failedLoginAttempts > 0) {
        user.pendingFailedAttemptsAlert = user.failedLoginAttempts;
    }

    // إعادة تعيين عداد المحاولات الفاشلة في حالة نجاح تسجيل الدخول
    user.failedLoginAttempts = 0;
    user.lastFailedLoginAt = null;

    // التحقق من انتهاء صلاحية الباسورد (90 يوم)
    if (user.isPasswordExpired()) {
      return res.status(403).json({
        success: false,
        code: 'PASSWORD_EXPIRED',
        message: 'انتهت صلاحية كلمة المرور. يرجى تغييرها.',
        email: user.email
      });
    }

    // إرسال رمز 2FA إجبارياً
    const twoFACode = generateCode();
    user.twoFACode = twoFACode;
    user.twoFAExpires = new Date(Date.now() + 10 * 60 * 1000);
    await user.save();

    await sendVerificationEmail(user.email, user.fullName, twoFACode);

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
      email: user.email
    });

  } catch (err) {
    console.error('Login Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// التحقق من رمز 2FA
router.post('/verify-2fa', async (req, res) => {
  const { email, code } = req.body;

  try {
    const user = await User.findOne({
      email: email.toLowerCase(),
      twoFACode: code,
      twoFAExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'الرمز غير صحيح أو منتهي الصلاحية'
      });
    }

    user.twoFACode = undefined;
    user.twoFAExpires = undefined;

    // التحقق من وضع الطوارئ
    const emergencyModeActivated = user.emergencyModeActivated || false;
    if (emergencyModeActivated) {
      user.emergencyModeActivated = false;
    }

    await user.save();const { deviceName, locationName, latitude, longitude } = req.body;

if (deviceName) {
    if (!user.registrationDevice) {
        await User.findByIdAndUpdate(user._id, {
            registrationDevice: deviceName
        });
        console.log(`تم تثبيت الجهاز الأساسي: ${deviceName}`);
    }
    else if (user.registrationDevice !== deviceName) {
        console.log(`🚨 دخول من جهاز غير أساسي (${deviceName}) — إرسال إيميل...`);
        try {
        const freezeToken = crypto.randomBytes(32).toString('hex');
        user.freezeToken = freezeToken;
        user.freezeTokenExpires = new Date(Date.now() + 30 * 60 * 1000);
        await user.save();

            await sendNewDeviceAlertEmail(user.email, user.fullName, deviceName, freezeToken);
            console.log(` إيميل التنبيه أُرسل: ${user.email}`);
        } catch (emailErr) {
            console.error('⚠️ فشل إرسال الإيميل:', emailErr.message);
        }
    }
}

    const accessToken = jwt.sign(
      { user: { id: user.id, username: user.username ,tokenVersion: user.tokenVersion } },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    const refreshToken = jwt.sign(
      { user: { id: user.id } },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: '30d' }
    );

    res.json({
      success: true,
      message: 'تم تسجيل الدخول بنجاح',
      accessToken,
      refreshToken,
      emergencyModeActivated,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified
      }
    });

  } catch (err) {
    console.error('2FA Verify Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// طلب إعادة تعيين كلمة المرور (إرسال رمز)
router.post('/forgot-password', async (req, res) => {
  const { email } = req.body;

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني'
      });
    }

    const resetCode = generateCode();
    user.passwordResetCode = resetCode;
    user.passwordResetExpires = new Date(Date.now() + 10 * 60 * 1000);
    await user.save();

    await sendVerificationEmail(user.email, user.fullName, resetCode);

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق إلى بريدك الإلكتروني'
    });

  } catch (err) {
    console.error('Forgot Password Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// التحقق من رمز إعادة التعيين
router.post('/verify-reset-code', async (req, res) => {
  const { email, code } = req.body;

  try {
    const user = await User.findOne({
      email: email.toLowerCase(),
      passwordResetCode: code,
      passwordResetExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'الرمز غير صحيح أو منتهي الصلاحية'
      });
    }

    res.json({
      success: true,
      message: 'تم التحقق من الرمز بنجاح'
    });

  } catch (err) {
    console.error('Verify Reset Code Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// إعادة تعيين كلمة المرور مع التحقق من القوة والتاريخ
router.post('/reset-password', validatePasswordMiddleware, async (req, res) => {
  const { email, code, newPassword } = req.body;

  try {
    const user = await User.findOne({
      email: email.toLowerCase(),
      passwordResetCode: code,
      passwordResetExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'الرمز غير صحيح أو منتهي الصلاحية'
      });
    }

    // التحقق من عدم تكرار آخر 12 باسورد
    const isUnique = await user.checkPasswordHistory(newPassword);
    
    if (!isUnique) {
      return res.status(400).json({
        success: false,
        message: 'لا يمكن استخدام أحد آخر 12 كلمات مرور سابقة'
      });
    }

    // تشفير كلمة المرور الجديدة
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    // إضافة الباسورد الجديد للتاريخ
    user.addToPasswordHistory(hashedPassword);
    
    user.password = hashedPassword;
    user.passwordChangedAt = new Date(); // تحديث تاريخ التغيير
    user.passwordResetCode = undefined;
    user.passwordResetExpires = undefined;
    await user.save();

    res.json({
      success: true,
      message: 'تم تغيير كلمة المرور بنجاح'
    });

  } catch (err) {
    console.error('Reset Password Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// تغيير كلمة المرور (للمستخدم المسجل دخول)
router.post('/change-password', authMiddleware, validatePasswordMiddleware, async (req, res) => {
  const { currentPassword, newPassword } = req.body;

  try {
    const user = await User.findById(req.userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    // التحقق من الباسورد الحالي
    const isMatch = await bcrypt.compare(currentPassword, user.password);

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: 'كلمة المرور الحالية غير صحيحة'
      });
    }

    // التحقق من عدم تكرار آخر 12 باسورد
    const isUnique = await user.checkPasswordHistory(newPassword);
    
    if (!isUnique) {
      return res.status(400).json({
        success: false,
        message: 'لا يمكن استخدام أحد آخر 12 كلمات مرور سابقة'
      });
    }

    // تشفير كلمة المرور الجديدة
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    // إضافة الباسورد الجديد للتاريخ
    user.addToPasswordHistory(hashedPassword);
    
    user.password = hashedPassword;
   if (req.body.invalidateSession === true) {
  user.tokenVersion = (user.tokenVersion || 1) + 1;
}
    await user.save();

    res.json({
      success: true,
      message: 'تم تغيير كلمة المرور بنجاح'
    });

  } catch (err) {
    console.error('Change Password Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// توليد باسورد عشوائي قوي
router.get('/generate-secure-password', (req, res) => {
  try {
    const length = parseInt(req.query.length) || 12;
    
    if (length < 8 || length > 50) {
      return res.status(400).json({
        success: false,
        message: 'الطول يجب أن يكون بين 8 و 50 حرف'
      });
    }

    const password = User.generateSecurePassword(length);

    res.json({
      success: true,
      password
    });

  } catch (err) {
    console.error('Generate Password Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// التحقق من حالة الباسورد (متى يحتاج تغيير)
router.get('/password-status', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    const daysSinceChange = user.passwordChangedAt 
      ? Math.floor((Date.now() - user.passwordChangedAt.getTime()) / (1000 * 60 * 60 * 24))
      : 0;

    const daysUntilExpiry = 90 - daysSinceChange;
    const isExpired = user.isPasswordExpired();

    res.json({
      success: true,
      passwordChangedAt: user.passwordChangedAt,
      daysSinceChange,
      daysUntilExpiry: daysUntilExpiry > 0 ? daysUntilExpiry : 0,
      isExpired
    });

  } catch (err) {
    console.error('Password Status Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

router.post('/request-biometric-enable', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    const verificationCode = generateCode();
    user.biometricVerificationCode = verificationCode;
    user.biometricVerificationExpires = new Date(Date.now() + 10 * 60 * 1000);
    await user.save();

    await sendBiometricVerificationEmail(user.email, user.fullName, verificationCode);

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق إلى بريدك الإلكتروني'
    });

  } catch (err) {
    console.error('Request Biometric Enable Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

router.post('/verify-biometric-enable', authMiddleware, async (req, res) => {
  const { code } = req.body;

  try {
    const user = await User.findOne({
      _id: req.userId,
      biometricVerificationCode: code,
      biometricVerificationExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'الرمز غير صحيح أو منتهي الصلاحية'
      });
    }

    user.biometricEnabled = true;
    user.biometricVerificationCode = undefined;
    user.biometricVerificationExpires = undefined;
    await user.save();

    res.json({
      success: true,
      message: 'تم تفعيل المصادقة الحيوية بنجاح'
    });

  } catch (err) {
    console.error('Verify Biometric Enable Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

router.post('/disable-biometric', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    user.biometricEnabled = false;
    await user.save();

    res.json({
      success: true,
      message: 'تم إلغاء المصادقة الحيوية'
    });

  } catch (err) {
    console.error('Disable Biometric Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

router.post('/biometric-login', async (req, res) => {
  const { email } = req.body;

  try {
    const user = await User.findOne({ 
      email: email.toLowerCase(),
      biometricEnabled: true 
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المصادقة الحيوية غير مفعلة لهذا الحساب'
      });
    }

    // التحقق من انتهاء صلاحية الباسورد حتى مع البايومتركس
    if (user.isPasswordExpired()) {
      return res.status(403).json({
        success: false,
        code: 'PASSWORD_EXPIRED',
        message: 'انتهت صلاحية كلمة المرور. يرجى تغييرها قبل تسجيل الدخول.',
        email: user.email
      });
    }

    const accessToken = jwt.sign(
      { user: { id: user.id, username: user.username , tokenVersion: user.tokenVersion} },
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
      message: 'تم تسجيل الدخول بالبايومتريكس بنجاح',
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        memoji: user.memoji || '😊',
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified,
        biometricEnabled: user.biometricEnabled
      }
    });

  } catch (err) {
    console.error('Biometric Login Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

router.get('/biometric-status', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    
    res.json({
      success: true,
      biometricEnabled: user?.biometricEnabled || false
    });

  } catch (err) {
    res.status(500).json({
      success: false,
      message: 'حدث خطأ'
    });
  }
});

router.post('/resend-2fa', async (req, res) => {
  const { email } = req.body;

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    const twoFACode = generateCode();
    user.twoFACode = twoFACode;
    user.twoFAExpires = new Date(Date.now() + 10 * 60 * 1000);
    await user.save();

    await sendVerificationEmail(user.email, user.fullName, twoFACode);

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق مرة أخرى'
    });

  } catch (err) {
    console.error('Resend 2FA Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// ===== وضع الطوارئ =====
router.post('/emergency-mode', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'المستخدم غير موجود' });
    }

    user.emergencyModeActivated = true;
    user.emergencyModeAt = new Date();
    user.identityPublicKey = undefined;
    user.signedPreKey = undefined;
    await user.save();

    // حذف مفاتيح التشفير الفعلية المعتمدة في النظام الحالي
    await PreKeyBundle.deleteOne({ userId: req.userId });

    // إشعار الأطراف المرتبطين بمحادثات مع هذا المستخدم لبدء إعادة تهيئة session
    const io = req.app.get('io');
    if (io && io.sendToUser) {
      const sentTo = await Message.distinct('recipientId', { senderId: user._id });
      const receivedFrom = await Message.distinct('senderId', { recipientId: user._id });
      const peerIds = [...new Set([...sentTo, ...receivedFrom].map((id) => id.toString()))]
        .filter((id) => id !== user.id.toString());

      for (const peerId of peerIds) {
        io.sendToUser(peerId, 'contact:emergency_mode_activated', {
          userId: user.id.toString(),
          at: user.emergencyModeAt,
        });
      }
    }

    res.json({ success: true, message: 'تم تفعيل وضع الطوارئ' });
  } catch (err) {
    console.error('Emergency Mode Error:', err);
    res.status(500).json({ success: false, message: 'حدث خطأ في السيرفر' });
  }
});

module.exports = router;
