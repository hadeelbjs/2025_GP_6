const jwt = require('jsonwebtoken');
const User = require('../models/User');

// ✅ Middleware للتحقق من التوكن
module.exports = async (req, res, next) => {
  try {
    // 1. استخراج التوكن من Header
    const authHeader = req.header('Authorization');
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        success: false, 
        message: 'يجب تسجيل الدخول أولاً' 
      });
    }

    // 2. إزالة كلمة "Bearer " والحصول على التوكن فقط
    const token = authHeader.replace('Bearer ', '');

    // 3. التحقق من صحة التوكن
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const userId = decoded.user?.id || decoded.userId;

    if (!userId) {
      return res.status(401).json({ 
        success: false, 
        message: 'توكن غير صالح' 
      });
    }

    // 4. التحقق من وجود المستخدم في قاعدة البيانات
    const user = await User.findById(userId);
    
    if (!user) {
      return res.status(401).json({ 
        success: false, 
        message: 'المستخدم غير موجود' 
      });
    }

    // 5. حفظ بيانات المستخدم لاستخدامها في الخطوات التالية
    req.user = {
      id: user._id.toString(),
      username: user.username,
      fullName: user.fullName,
      email: user.email
    };

    // 6. المتابعة للخطوة التالية
    next();

  } catch (error) {
    console.error('Auth Middleware Error:', error);
    
    // معالجة الأخطاء
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ 
        success: false, 
        message: 'توكن غير صالح' 
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        success: false, 
        message: 'انتهت الجلسة، سجلي دخول مجدداً' 
      });
    }

    res.status(500).json({ 
      success: false, 
      message: 'خطأ في التحقق' 
    });
  }
};