// routes/user.js
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const { body, validationResult } = require('express-validator');
const User = require('../models/User');
const { sendVerificationEmail , sendActivityAlertEmail , sendUnfreezeCodeEmail } = require('../utils/emailService');
const twilio = require('twilio');
const client = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
const { parsePhoneNumberFromString } = require('libphonenumber-js');
const auth = require('../middleware/auth'); // middleware للتحقق من التوكن
const authMiddleware = require('../middleware/auth');

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


async function sendActivityAlert(oldEmail, fullName, changeType, freezeToken) {

  // تغيير الجوال — إشعار فقط بدون تجميد
  if (changeType === 'phone') {
    await sendActivityAlertEmail(
      oldEmail,
      fullName,
      'تنبيه أمني — تم تغيير رقم جوالك',
      `
      <div dir="rtl" style="font-family:Arial;max-width:600px;margin:auto;padding:20px;">
        <div style="background:#2D1B69;padding:20px;border-radius:12px 12px 0 0;text-align:center;">
          <h2 style="color:white;margin:0">⚠️ تنبيه أمني</h2>
        </div>
        <div style="background:#f9f9f9;padding:30px;border-radius:0 0 12px 12px;border:1px solid #eee;">
          <p style="font-size:16px">مرحباً <strong>${fullName}</strong>،</p>
          <p style="font-size:15px">تم تغيير <strong>رقم جوالك</strong> في حسابك.</p>
          <p style="font-size:15px;color:#555">إذا لم تكن أنت من قام بذلك، يُنصح بفتح التطبيق والذهاب إلى إعدادات الحساب وتغيير رقم الجوال فوراً.</p>
          <p style="font-size:13px;color:#888">إذا كنت أنت من قام بهذا التغيير، تجاهل هذه الرسالة.</p>
        </div>
      </div>
      `
    );
    return;
  }

  // تغيير الإيميل أو الباسورد — تجميد
  const freezeLink = `${process.env.BASE_URL}/api/user/freeze-confirmation?token=${freezeToken}&type=${changeType}`;
  const changeLabel = changeType === 'email' ? 'بريدك الإلكتروني' : 'كلمة مرورك';

  await sendActivityAlertEmail(
    oldEmail,
    fullName,
    `تنبيه أمني — تم تغيير ${changeLabel}`,
    `
    <div dir="rtl" style="font-family:Arial;max-width:600px;margin:auto;padding:20px;">
      <div style="background:#2D1B69;padding:20px;border-radius:12px 12px 0 0;text-align:center;">
        <h2 style="color:white;margin:0">⚠️ تنبيه أمني</h2>
      </div>
      <div style="background:#f9f9f9;padding:30px;border-radius:0 0 12px 12px;border:1px solid #eee;">
        <p style="font-size:16px">مرحباً <strong>${fullName}</strong>،</p>
        <p style="font-size:15px">تم تغيير <strong>${changeLabel}</strong> في حسابك.</p>
        <p style="font-size:15px;color:#555">إذا لم تكن أنت من قام بذلك، اضغط الزر أدناه لتجميد حسابك فوراً:</p>
        <div style="text-align:center;margin:30px 0;">
          <a href="${freezeLink}" 
             style="background:#dc2626;color:white;padding:14px 32px;border-radius:8px;text-decoration:none;font-size:16px;font-weight:bold;">
            تجميد حسابي فوراً
          </a>
        </div>
        <p style="font-size:13px;color:#888">إذا كنت أنت من قام بهذا التغيير، تجاهل هذه الرسالة.</p>
        <p style="font-size:13px;color:#888">هذا الرابط صالح لمدة 30 دقيقة.</p>
      </div>
    </div>
    `
  );
}

function addDays(date, days) {
  const result = new Date(date.valueOf());
  result.setDate(result.getDate() + days);
  return result;
}

router.get('/password-exp-date', authMiddleware, async (req, res) => {
  try {
    const lastChangedAt = req.user.passwordChangedAt;

    if (!lastChangedAt) {
      return res.status(400).json({
        success: false,
        message: 'لا يوجد تاريخ لتغيير كلمة المرور'
      });
    }

    const daysSinceChange = Math.ceil((Date.now() - lastChangedAt.getTime()) / (1000 * 60 * 60 * 24));

    const daysTillExp = 90 - daysSinceChange;

     if (daysTillExp <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Password has already expired'
      });
    }

    res.json({
      success: true,
      message: 'Exp date retrieved',
      expDate: addDays(lastChangedAt, 90),
      daysTillExp
    });

  } catch (err) {
    res.status(500).json({ success: false, message: 'حدث خطأ في السيرفر' });
  }
});
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

    const oldEmail = user.email;
    const freezeToken = crypto.randomBytes(32).toString('hex');
    user.previousEmail = oldEmail;
    user.email = newEmail.toLowerCase();
    user.isEmailVerified = true;
    user.newEmailVerificationCode = undefined;
    user.newEmailVerificationExpires = undefined;
    user.pendingEmail = undefined;
    user.freezeToken = freezeToken;
    user.freezeTokenExpires = new Date(Date.now() + 30 * 60 * 1000); 
    await user.save();
    await sendActivityAlert(oldEmail, user.fullName, 'email', freezeToken);

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
      await sendActivityAlert(user.email, user.fullName, 'phone', null);

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
  validatePasswordMiddleware,

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

    const freezeToken = crypto.randomBytes(32).toString('hex');
    user.password = hashedPassword;
    user.freezeToken = freezeToken;
    user.freezeTokenExpires = new Date(Date.now() + 30 * 60 * 1000); 
if (req.body.invalidateSession === true) {
  user.tokenVersion = (user.tokenVersion || 1) + 1;
}
    await user.save();
    await sendActivityAlert(user.email, user.fullName, 'password', freezeToken);

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
// ============================================
// حذف الحساب نهائياً
// ============================================
router.delete('/delete-account', auth, async (req, res) => {
  try {
    const userId = req.user.id;
    const { password } = req.body;


    // 1. التحقق من كلمة المرور
    const user = await User.findById(userId).select('+password');
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'المستخدم غير موجود'
      });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'كلمة المرور غير صحيحة'
      });
    }

    // 2. حذف كل شي بالترتيب
    const PreKeyBundle = require('../models/PreKeyBundle');
    const Message = require('../models/Message');
    const Contact = require('../models/Contact');

    // حذف المفاتيح
    await PreKeyBundle.deleteMany({ userId: userId });

    // حذف الرسائل
    await Message.deleteMany({
      $or: [{ senderId: userId }, { recipientId: userId }]
    });

    // حذف جهات الاتصال
    await Contact.deleteMany({
      $or: [{ requester: userId }, { recipient: userId }]
    });

    // حذف المستخدم
    await User.findByIdAndDelete(userId);

    res.json({
      success: true,
      message: 'تم حذف حسابك نهائياً'
    });

  } catch (err) {
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في حذف الحساب'
    });
  }
});


router.get('/freeze-confirmation', (req, res) => {
    const { token, type } = req.query;
    res.send(`
        <!DOCTYPE html><html dir="rtl">
        <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            *{margin:0;padding:0;box-sizing:border-box}
            body{background:#0F0A1E;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:Arial;padding:20px}
            .box{background:#1A1035;border:1px solid rgba(220,38,38,0.35);border-radius:20px;padding:36px 28px;max-width:360px;width:100%;text-align:center}
            .icon{width:64px;height:64px;border-radius:50%;background:rgba(220,38,38,0.12);border:1px solid rgba(220,38,38,0.3);display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:28px}
            h2{color:white;font-size:20px;font-weight:600;margin:0 0 10px}
            p{color:#9CA3AF;font-size:14px;line-height:1.7;margin:0 0 8px}
            .btn{width:100%;background:#dc2626;color:white;border:none;padding:14px;border-radius:10px;font-size:15px;font-weight:600;cursor:pointer;margin-top:20px}
            .btn:hover{background:#b91c1c}
            .hint{color:#6B7280;font-size:12px;margin-top:16px}
        </style></head>
        <body><div class="box">
            <div class="icon">🔒</div>
            <h2>تأكيد تجميد الحساب</h2>
            <p>تم رصد نشاط مشبوه على حسابك.</p>
            <p>هل أنت متأكد من رغبتك في <strong style="color:#f87171">تجميد حسابك فوراً</strong>؟</p>
            <form action="/api/user/freeze-by-token" method="POST">
                <input type="hidden" name="token" value="${token}">
                <input type="hidden" name="type" value="${type}">
                <button type="submit" class="btn">تأكيد التجميد فوراً</button>
            </form>
            <p class="hint">سيصلك رمز فك التجميد على بريدك الإلكتروني</p>
        </div></body></html>
    `);
});

// تجميد الحساب عبر رابط الإيميل
router.post('/freeze-by-token', async (req, res) => {
    const { token, type } = req.body; 
    try {
        const user = await User.findOne({ 
            freezeToken: token,
            freezeTokenExpires: { $gt: Date.now() } 
        });

        if (!user) {
           return res.send(`
        <!DOCTYPE html><html dir="rtl">
        <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            *{margin:0;padding:0;box-sizing:border-box}
            body{background:#0F0A1E;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:Arial;padding:20px}
            .box{background:#1A1035;border:1px solid rgba(220,38,38,0.2);border-radius:20px;padding:36px 28px;max-width:360px;width:100%;text-align:center}
            .icon{width:64px;height:64px;border-radius:50%;background:rgba(107,114,128,0.15);border:1px solid rgba(107,114,128,0.3);display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:28px}
            h2{color:#ef4444;font-size:20px;font-weight:600;margin:0 0 10px}
            p{color:#9CA3AF;font-size:14px;line-height:1.8;margin:0}
        </style></head>
        <body><div class="box">
            <div class="icon">⚠️</div>
            <h2>الرابط غير صالح</h2>
            <p>هذا الرابط منتهي الصلاحية أو تم استخدامه مسبقاً.</p>
            <p style="margin-top:8px">إذا كنت بحاجة لتجميد حسابك، افتح التطبيق وتواصل معنا.</p>
        </div></body></html>
    `);
        }

        if (!user.isAccountFrozen) {
            const unfreezeCode = crypto.randomInt(100000, 999999).toString();
            user.isAccountFrozen = true;
            user.unfreezeCode = unfreezeCode;
           user.unfreezeCodeExpires = new Date(Date.now() + 30 * 60 * 1000); // 30 دقيقة

            await user.save();

            const emailToSend = user.previousEmail || user.email;
            await sendUnfreezeCodeEmail(emailToSend, user.fullName, unfreezeCode);
        }

        return res.send(`
            <!DOCTYPE html><html dir="rtl">
    <head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{background:#0F0A1E;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:Arial;padding:20px}
        .box{background:#1A1035;border:1px solid rgba(220,38,38,0.25);border-radius:20px;padding:36px 28px;max-width:360px;width:100%;text-align:center}
        .icon{width:64px;height:64px;border-radius:50%;background:rgba(220,38,38,0.1);border:1px solid rgba(220,38,38,0.3);display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:28px}
        h2{color:white;font-size:20px;font-weight:600;margin:0 0 10px}
        p{color:#9CA3AF;font-size:14px;line-height:1.8;margin:0 0 6px}
        .info{background:rgba(45,27,105,0.4);border:1px solid rgba(45,27,105,0.6);border-radius:10px;padding:12px 16px;margin:20px 0;display:flex;align-items:center;gap:10px;direction:rtl}
        .info p{color:#C4B5FD;font-size:13px;margin:0}
        .btn{display:block;background:#2D1B69;color:white;padding:14px;border-radius:10px;text-decoration:none;font-size:15px;font-weight:600;margin-top:8px}
        .hint{color:#6B7280;font-size:12px;margin-top:16px}
    </style></head>
    <body><div class="box">
        <div class="icon">🔐</div>
        <h2>تم تجميد حسابك</h2>
        <p>حسابك الآن مجمّد لحمايتك.</p>
        <p>تم إرسال <strong style="color:#e5e7eb">رمز فك التجميد</strong> إلى بريدك الإلكتروني.</p>
        <div class="info"><span style="font-size:18px">📧</span><p>افتح تطبيق وصيد وأدخل الرمز الذي وصلك لفك التجميد</p></div>
        <a href="waseed://frozen?type=${type || 'password'}" class="btn">افتح تطبيق وصيد</a>
        <p class="hint">تحقق من مجلد البريد غير المرغوب فيه إذا لم يصلك الرمز</p>
    </div></body></html>
`);
    } catch (err) {
        res.status(500).send("حدث خطأ في السيرفر");
    }
});

// فك التجميد
router.post('/unfreeze-account', async (req, res) => {
    const { email, code } = req.body;
    try {
        const user = await User.findOne({
            $or: [
                { email: email.toLowerCase() },
                { previousEmail: email.toLowerCase() }
            ],
            unfreezeCode: code,
            unfreezeCodeExpires: { $gt: Date.now() }
        });

        if (!user) {
            return res.status(400).json({ 
                success: false, 
                message: 'الرمز غير صحيح أو منتهي الصلاحية' 
            });
        }

        user.isAccountFrozen = false;
        user.unfreezeCode = undefined;
        user.unfreezeCodeExpires = undefined;
        user.freezeToken = undefined;

        // لو فيه إيميل قديم — ارجعه وامسح الجديد
        if (user.previousEmail) {
            user.email = user.previousEmail;
            user.previousEmail = undefined;
        }

        await user.save();
        res.json({ success: true, message: 'تم فك تجميد حسابك بنجاح' });

    } catch (err) {
        res.status(500).json({ success: false, message: 'حدث خطأ في السيرفر' });
    }
});

module.exports = router;