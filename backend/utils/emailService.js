const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,
  port: process.env.EMAIL_PORT,
  secure: false,
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
});

const sendVerificationEmail = async (email, fullName, verificationCode) => {
  const mailOptions = {
    from: `"وصـيد" <${process.env.EMAIL_FROM}>`,
    to: email,
    subject: 'تأكيد البريد الإلكتروني',
    html: `
      <!DOCTYPE html>
      <html dir="rtl">
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; }
          .header { background: #2D1B69; color: white; padding: 20px; text-align: center; border-radius: 8px; }
          .code-box { background: #f8f9fa; border: 2px dashed #2D1B69; border-radius: 8px; padding: 20px; margin: 20px 0; text-align: center; font-size: 32px; font-weight: bold; color: #2D1B69; letter-spacing: 5px; }
          .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>مرحباً ${fullName}!</h1>
          </div>
          <h2 style="text-align: center;">تأكيد البريد الإلكتروني</h2>
          <p style="text-align: center;">استخدم الرمز التالي لتأكيد بريدك الإلكتروني:</p>
          <div class="code-box">${verificationCode}</div>
          <p style="text-align: center;">الرمز صالح لمدة <strong>10 دقائق</strong> فقط</p>
          <div class="footer">
            <p>إذا لم تقم بالتسجيل، يرجى تجاهل هذا الإيميل</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error('خطأ في إرسال الإيميل:', error);
    return { success: false, error: error.message };
  }
};

// إيميل خاص بتفعيل البايومتركس
const sendBiometricVerificationEmail = async (email, fullName, verificationCode) => {
  const mailOptions = {
    from: `"وصـيد" <${process.env.EMAIL_FROM}>`,
    to: email,
    subject: 'تفعيل المصادقة الحيوية',
    html: `
      <!DOCTYPE html>
      <html dir="rtl">
      <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 20px; }
          .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; }
          .header { background: #2D1B69; color: white; padding: 20px; text-align: center; border-radius: 8px; }
          .code-box { background: #f8f9fa; border: 2px dashed #2D1B69; border-radius: 8px; padding: 20px; margin: 20px 0; text-align: center; font-size: 32px; font-weight: bold; color: #2D1B69; letter-spacing: 5px; }
          .icon { font-size: 48px; margin-bottom: 10px; }
          .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>مرحباً ${fullName}!</h1>
          </div>
          <h2 style="text-align: center; color: #2D1B69;">تفعيل المصادقة الحيوية</h2>
          <p style="text-align: center;">لتفعيل الدخول بالبصمة، استخدم الرمز التالي:</p>
          <div class="code-box">${verificationCode}</div>
          <p style="text-align: center;">الرمز صالح لمدة <strong>10 دقائق</strong> فقط</p>
          <div style="background: #f0f7ff; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <p style="margin: 0; color: #2D1B69; text-align: center;">
            </p>
          </div>
          <div class="footer">
            <p>إذا لم تطلب تفعيل المصادقة الحيوية، يرجى تجاهل هذا الإيميل</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error('خطأ في إرسال الإيميل:', error);
    return { success: false, error: error.message };
  }
};

// ✅ لا تنسين تصديرها
module.exports = { 
  sendVerificationEmail,
  sendBiometricVerificationEmail  // أضيفيها هنا
};
