// routes/user.js
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { sendVerificationEmail } = require('../utils/emailService');
const twilio = require('twilio');
const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const { parsePhoneNumberFromString } = require('libphonenumber-js');
const auth = require('../middleware/auth'); // middleware للتحقق من التوكن

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

// ============================================
// تحديث الصورة الرمزية (Memoji)
// ============================================
router.put('/update-memoji', auth, async (req, res) => {
  const { memoji } = req.body;

  if (!memoji) {
    return res.status(400).json({
      success: false,
      message: 'الرجاء اختيار صورة رمزية'
    });
  }

  try {
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    user.memoji = memoji;
    await user.save();

    res.json({
      success: true,
      message: 'تم تحديث الصورة الرمزية بنجاح',
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        memoji: user.memoji,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified
      }
    });

  } catch (err) {
    console.error('Update Memoji Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// ============================================
// تحديث اسم المستخدم
// ============================================
router.put('/update-username', [
  auth,
  body('username')
    .isLength({ min: 3 }).withMessage('اسم المستخدم يجب أن يكون 3 أحرف على الأقل')
    .matches(/^[a-zA-Z0-9_]+$/).withMessage('اسم المستخدم يجب أن يحتوي فقط على أحرف أو أرقام أو _')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: errors.array()[0].msg
    });
  }

  const { username } = req.body;

  try {
    // التحقق من أن اسم المستخدم غير مستخدم
    const existingUser = await User.findOne({
      username: username.toLowerCase(),
      _id: { $ne: req.user.id }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'اسم المستخدم مستخدم بالفعل'
      });
    }

    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    user.username = username.toLowerCase();
    await user.save();

    res.json({
      success: true,
      message: 'تم تحديث اسم المستخدم بنجاح',
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        memoji: user.memoji,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified
      }
    });

  } catch (err) {
    console.error('Update Username Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// ============================================
// طلب تغيير البريد الإلكتروني (إرسال رمز تحقق)
// ============================================
router.post('/request-email-change', [
  auth,
  body('newEmail').isEmail().withMessage('الرجاء إدخال بريد إلكتروني صالح')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: errors.array()[0].msg
    });
  }

  const { newEmail } = req.body;

  try {
    // التحقق من أن البريد الإلكتروني غير مستخدم
    const existingUser = await User.findOne({
      email: newEmail.toLowerCase(),
      _id: { $ne: req.user.id }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'البريد الإلكتروني مستخدم بالفعل'
      });
    }

    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    // إنشاء رمز التحقق
    const verificationCode = generateCode();
    user.newEmailVerificationCode = verificationCode;
    user.newEmailVerificationExpires = new Date(Date.now() + 10 * 60 * 1000);
    user.pendingEmail = newEmail.toLowerCase();
    await user.save();

    await sendVerificationEmail(newEmail, user.fullName, verificationCode);

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق إلى البريد الإلكتروني الجديد'
    });

  } catch (err) {
    console.error('Request Email Change Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// ============================================
// التحقق من تغيير البريد الإلكتروني
// ============================================
router.post('/verify-email-change', auth, async (req, res) => {
  const { newEmail, code } = req.body;

  try {
    const user = await User.findOne({
      _id: req.user.id,
      pendingEmail: newEmail.toLowerCase(),
      newEmailVerificationCode: code,
      newEmailVerificationExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'الرمز غير صحيح أو منتهي الصلاحية'
      });
    }

    user.email = newEmail.toLowerCase();
    user.isEmailVerified = true;
    user.newEmailVerificationCode = undefined;
    user.newEmailVerificationExpires = undefined;
    user.pendingEmail = undefined;
    await user.save();

    res.json({
      success: true,
      message: 'تم تحديث البريد الإلكتروني بنجاح',
      user: {
        id: user.id,
        fullName: user.fullName,
        username: user.username,
        email: user.email,
        phone: user.phone,
        memoji: user.memoji,
        isEmailVerified: user.isEmailVerified,
        isPhoneVerified: user.isPhoneVerified
      }
    });

  } catch (err) {
    console.error('Verify Email Change Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في السيرفر'
    });
  }
});

// ============================================
// طلب تغيير رقم الهاتف (إرسال رمز تحقق)
// ============================================
router.post('/request-phone-change', auth, async (req, res) => {
  const { newPhone } = req.body;
  const normalizedPhone = normalizePhone(newPhone);

  if (!normalizedPhone) {
    return res.status(400).json({
      success: false,
      message: 'رقم الجوال غير صالح'
    });
  }

  try {
    // التحقق من أن رقم الهاتف غير مستخدم
    const existingUser = await User.findOne({
      phone: normalizedPhone,
      _id: { $ne: req.user.id }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'رقم الجوال مستخدم بالفعل'
      });
    }

    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    // إرسال رمز التحقق عبر Twilio
    const verification = await client.verify.v2
      .services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verifications
      .create({ to: normalizedPhone, channel: 'sms' });

    // حفظ الرقم الجديد كـ pending
    user.pendingPhone = normalizedPhone;
    await user.save();

    res.json({
      success: true,
      message: 'تم إرسال رمز التحقق عبر SMS',
      status: verification.status
    });

  } catch (err) {
    console.error('Request Phone Change Error:', err);
    res.status(500).json({
      success: false,
      message: 'فشل إرسال رمز التحقق'
    });
  }
});

// ============================================
// التحقق من تغيير رقم الهاتف
// ============================================
router.post('/verify-phone-change', auth, async (req, res) => {
  const { newPhone, code } = req.body;
  const normalizedPhone = normalizePhone(newPhone);

  if (!normalizedPhone) {
    return res.status(400).json({
      success: false,
      message: 'رقم الجوال غير صالح'
    });
  }

  try {
    const user = await User.findById(req.user.id);

    if (!user || user.pendingPhone !== normalizedPhone) {
      return res.status(400).json({
        success: false,
        message: 'رقم الجوال غير متطابق'
      });
    }

    // التحقق من الرمز عبر Twilio
    const check = await client.verify.v2
      .services(process.env.TWILIO_VERIFY_SERVICE_SID)
      .verificationChecks
      .create({ to: normalizedPhone, code });

    if (check.status === 'approved') {
      user.phone = normalizedPhone;
      user.isPhoneVerified = true;
      user.pendingPhone = undefined;
      await user.save();

      return res.json({
        success: true,
        message: 'تم تحديث رقم الجوال بنجاح',
        user: {
          id: user.id,
          fullName: user.fullName,
          username: user.username,
          email: user.email,
          phone: user.phone,
          memoji: user.memoji,
          isEmailVerified: user.isEmailVerified,
          isPhoneVerified: user.isPhoneVerified
        }
      });
    }

    return res.status(400).json({
      success: false,
      message: 'رمز التحقق غير صحيح'
    });

  } catch (err) {
    console.error('Verify Phone Change Error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء التحقق من الرمز'
    });
  }
});

// ============================================
// تغيير كلمة المرور
// ============================================
router.post('/change-password', [
  auth,
  body('currentPassword').notEmpty().withMessage('الرجاء إدخال كلمة المرور الحالية'),
  body('newPassword').isLength({ min: 6 }).withMessage('يجب أن تكون كلمة المرور الجديدة 6 أحرف على الأقل')
], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: errors.array()[0].msg
    });
  }

  const { currentPassword, newPassword } = req.body;

  try {
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    // التحقق من كلمة المرور الحالية
    const isMatch = await bcrypt.compare(currentPassword, user.password);

    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: 'كلمة المرور الحالية غير صحيحة'
      });
    }

    // تشفير كلمة المرور الجديدة
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    user.password = hashedPassword;
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

module.exports = router;