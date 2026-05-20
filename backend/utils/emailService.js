const { Resend } = require('resend');

// إنشاء instance من Resend
const resend = new Resend(process.env.RESEND_API_KEY);

// إرسال رمز التحقق للإيميل (Registration)
const sendVerificationEmail = async (email, fullName, verificationCode) => {
  try {
    const data = await resend.emails.send({
      from: `وصـيد <${process.env.EMAIL_FROM }>`,
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

    return { success: true, messageId: data.id };
  } catch (error) {
    console.error('Resend error:', error);
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
      from: `وصـيد <${process.env.EMAIL_FROM}>`,
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
                هذه الخطوة تضمن أمان حسابك
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
    return { success: true, messageId: data.id };
  } catch (error) {
    console.error('Biometric email error:', error);
    return { 
      success: false, 
      error: error.message || 'فشل إرسال البريد الإلكتروني'
    };
  }
  
};

const sendActivityAlertEmail = async (email, fullName, subject, htmlContent) => {
  try {
    const data = await resend.emails.send({
      from: `وصـيد <${process.env.EMAIL_FROM}>`,
      to: email,
      subject: subject,
      html: htmlContent,
    });
    return { success: true, messageId: data.id };
  } catch (error) {
    console.error('Activity alert email error:', error);
    return { success: false, error: error.message };
  }
};

const sendUnfreezeCodeEmail = async (email, fullName, unfreezeCode) => {
  try {
    const data = await resend.emails.send({
      from: `وصـيد <${process.env.EMAIL_FROM}>`,
      to: email,
      subject: 'رمز فك تجميد حسابك',
      html: `
        <!DOCTYPE html>
        <html dir="rtl">
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 20px; }
            .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; padding: 30px; }
            .header { background: #7f1d1d; color: white; padding: 20px; text-align: center; border-radius: 8px; }
            .code-box { background: #fff1f2; border: 2px dashed #dc2626; border-radius: 8px; padding: 20px; margin: 20px 0; text-align: center; font-size: 32px; font-weight: bold; color: #dc2626; letter-spacing: 5px; }
            .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1> تجميد الحساب</h1>
            </div>
            <h2 style="text-align: center; color: #7f1d1d;">رمز فك تجميد حسابك</h2>
            <p style="text-align: center;">مرحباً <strong>${fullName}</strong>،</p>
            <p style="text-align: center;">تم تجميد حسابك. استخدم الرمز التالي لفك التجميد:</p>
            <div class="code-box">${unfreezeCode}</div>
            <p style="text-align: center;">الرمز صالح لمدة <strong>30 دقيقة</strong> فقط</p>
            <div style="background:#fff1f2;padding:15px;border-radius:8px;margin:20px 0;border:1px solid #fecaca;">
              <p style="margin:0;color:#dc2626;text-align:center;">
                 إذا لم تطلب تجميد حسابك، تجاهل هذه الرسالة
              </p>
            </div>
            <div class="footer">
              <p>فريق وصيد</p>
            </div>
          </div>
        </body>
        </html>
      `
    });
    return { success: true, messageId: data.id };
  } catch (error) {
    console.error('Unfreeze code email error:', error);
    return { success: false, error: error.message };
  }
};

const sendVerificationOTP = async (email, fullName, verificationCode) => {
  try {
    const data = await resend.emails.send({
      from: `وصـيد <${process.env.EMAIL_FROM }>`,
      to: email,
      subject: 'تحقق من الهوية',
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
            <p style="text-align: center;">استخدم الرمز التالي لتأكيد هويتك:</p>
            <div class="code-box">${verificationCode}</div>
            <p style="text-align: center;">الرمز صالح لمدة <strong>10 دقائق</strong> فقط</p>
            <div class="footer">
              <p>إذا لم تقم بطلب خدمة تتطلب تحقق من الهوية يرجى تجاهل هذا الإيميل</p>
            </div>
          </div>
        </body>
        </html>
      `
    });

    return { success: true, messageId: data.id };
  } catch (error) {
    console.error('Resend error:', error);
    return { 
      success: false, 
      error: error.message || 'فشل إرسال البريد الإلكتروني'
    };
  }
};

const sendNewDeviceAlertEmail = async (email, fullName, deviceName, freezeToken) => {
const confirmationLink = `${process.env.BASE_URL}/api/user/freeze-confirmation?token=${freezeToken}&type=password`;
 const html = `
    <!DOCTYPE html><html dir="rtl">
    <head><meta charset="UTF-8"><style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: Arial, sans-serif; background: #f4f4f4; padding: 40px 20px; }
      .container { max-width: 560px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; }
      .header { background: #2D1B69; padding: 32px 24px; text-align: center; }
      .header h2 { color: white; font-size: 22px; font-weight: bold; }
      .body { padding: 32px 24px; }
      .greeting { font-size: 15px; color: #333; margin-bottom: 24px; line-height: 1.6; }
      .info-box { background: #f9f9f9; border: 1px solid #ebebeb; border-radius: 10px; padding: 20px 24px; margin-bottom: 24px; }
      .info-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f0f0f0; direction: rtl; }
      .info-row:last-child { border-bottom: none; }
      .info-label { font-size: 14px; color: #333; font-weight: bold; }
      .info-value { font-size: 14px; color: #555; direction: ltr; }
      .warning { font-size: 13px; color: #c0392b; text-align: center; font-weight: bold; line-height: 1.8; margin-top: 16px; }
      .note { font-size: 13px; color: #888; text-align: center; line-height: 1.8; margin-bottom: 8px; }
      .footer { background: #fafafa; border-top: 1px solid #f0f0f0; padding: 20px; text-align: center; font-size: 12px; color: #aaa; }
    </style></head>
    <body>
      <div class="container">
        <div class="header"><h2>تنبيه أمني</h2></div>
        <div class="body">
          <p class="greeting">مرحباً <strong>${fullName}</strong>،<br>تم تسجيل دخول إلى حسابك من جهاز جديد</p>
          <div class="info-box">
            <div class="info-row">
              <span class="info-label">الجهاز</span>
              <span class="info-value">${deviceName}</span>
            </div>
          </div>
          <p class="note">إذا كنت أنت من قام بذلك، يمكنك تجاهل هذا الإيميل</p>
          <p class="warning">إذا لم تكن أنت، اضغط الزر أدناه لتجميد حسابك فوراً</p>
          <div style="text-align:center;margin:24px 0 8px;">
            <a href="${confirmationLink}"
               style="background:#dc2626;color:white;padding:14px 32px;border-radius:8px;text-decoration:none;font-size:16px;font-weight:bold;">
              تجميد حسابي فوراً
            </a>
          </div>
          <p style="font-size:13px;color:#888;text-align:center;margin-top:12px;">هذا الرابط صالح لمدة 30 دقيقة.</p>
        </div>
        <div class="footer">فريق وصيد</div>
      </div>
    </body></html>
  `;
  await sendActivityAlertEmail(email, fullName, 'تنبيه: تسجيل دخول من جهاز جديد', html);
};

module.exports = { 
  sendVerificationEmail,
  sendBiometricVerificationEmail, 
   sendActivityAlertEmail, 
    sendUnfreezeCodeEmail,
    sendVerificationOTP,
    sendNewDeviceAlertEmail
};