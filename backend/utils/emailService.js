// backend/utils/emailService.js

const { Resend } = require('resend');

// إنشاء instance من Resend
const resend = new Resend(process.env.RESEND_API_KEY);

// ============================================
// إرسال رمز التحقق للإيميل (Registration)
// ============================================
const sendVerificationEmail = async (email, fullName, verificationCode) => {
  try {
    const data = await resend.emails.send({
      from: `وصـيد <${process.env.EMAIL_FROM || 'onboarding@resend.dev'}>`,
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
      `
    });

    console.log('✅ Verification email sent via Resend:', data.id);
    return { success: true, messageId: data.id };
  } catch (error) {
    console.error('❌ Resend error:', error);
    return { 
      success: false, 
      error: error.message || 'فشل إرسال البريد الإلكتروني'
    };
  }
};

// ============================================
// إرسال رمز تفعيل البايومتريك
// ============================================
const sendBiometricVerificationEmail = async (email, fullName, verificationCode) => {
  try {
    const data = await resend.emails.send({
      from: `وصـيد <${process.env.EMAIL_FROM || 'onboarding@resend.dev'}>`,
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
                🔒 هذه الخطوة تضمن أمان حسابك
              </p>
            </div>
            <div class="footer">
              <p>إذا لم تطلب تفعيل المصادقة الحيوية، يرجى تجاهل هذا الإيميل</p>
            </div>
          </div>
        </body>
        </html>
      `
    });

    console.log('✅ Biometric email sent via Resend:', data.id);
    return { success: true, messageId: data.id };
  } catch (error) {
    console.error('❌ Biometric email error:', error);
    return { 
      success: false, 
      error: error.message || 'فشل إرسال البريد الإلكتروني'
    };
  }
};

module.exports = { 
  sendVerificationEmail,
  sendBiometricVerificationEmail  
};