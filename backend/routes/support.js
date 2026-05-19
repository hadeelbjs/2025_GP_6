const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { Resend } = require('resend');

const resend = new Resend(process.env.RESEND_API_KEY);

router.post('/contact', authMiddleware, async (req, res) => {
  try {
    const { type, subject, message } = req.body;
    const { fullName, username, email } = req.user;

    if (!type || !subject || !message) {
      return res.status(400).json({ success: false, message: 'جميع الحقول مطلوبة' });
    }

    await resend.emails.send({
      from: `وصـيد <${process.env.EMAIL_FROM}>`,
      to: 'waseed.team@gmail.com',
      subject: `[${type}] ${subject}`,
      html: `
        <!DOCTYPE html>
        <html dir="rtl">
        <head><meta charset="UTF-8"></head>
        <body style="font-family: Arial, sans-serif; background: #f4f4f4; padding: 20px;">
          <div style="max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px;">
            <div style="background: #2D1B69; color: white; padding: 20px; text-align: center; border-radius: 8px;">
              <h2>طلب دعم جديد</h2>
            </div>
            <div style="margin-top: 20px;">
              <p><strong>الاسم:</strong> ${fullName}</p>
              <p><strong>اسم المستخدم:</strong> @${username}</p>
              <p><strong>البريد:</strong> ${email}</p>
              <p><strong>نوع الطلب:</strong> ${type}</p>
              <p><strong>العنوان:</strong> ${subject}</p>
              <hr/>
              <p><strong>الرسالة:</strong></p>
              <p style="background: #f8f9fa; padding: 15px; border-radius: 8px;">${message}</p>
            </div>
          </div>
        </body>
        </html>
      `
    });

    res.json({ success: true, message: 'تم إرسال طلبك بنجاح' });
  } catch (error) {
    console.error('Support email error:', error);
    res.status(500).json({ success: false, message: 'فشل إرسال الطلب' });
  }
});

module.exports = router;