// middleware/auth.js
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const authMiddleware = async (req, res, next) => {
  try {
    // استخراج التوكن من الـ header
    const token = req.header('Authorization')?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'غير مصرح، الرجاء تسجيل الدخول',
        code: 'NO_TOKEN'
      });
    }

    // التحقق من صلاحية التوكن
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // التحقق من وجود المستخدم
    const user = await User.findById(decoded.user.id).select('-password');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'المستخدم غير موجود',
        code: 'USER_NOT_FOUND'
      });
    }

    // إضافة بيانات المستخدم إلى الـ request
    req.user = user;
    req.userId = user._id;

    next();
  } catch (err) {
    console.error('Auth Middleware Error:', err);

    // التعامل مع انتهاء صلاحية التوكن
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'انتهت صلاحية الجلسة، الرجاء تسجيل الدخول مرة أخرى',
        code: 'TOKEN_EXPIRED'
      });
    }

    // التعامل مع التوكن غير الصالح
    if (err.name === 'JsonWebTokenError') {
      return res.status(401).json({
        success: false,
        message: 'جلسة غير صالحة',
        code: 'INVALID_TOKEN'
      });
    }

    res.status(401).json({
      success: false,
      message: 'فشل التحقق من الصلاحية',
      code: 'AUTH_FAILED'
    });
  }
};

module.exports = authMiddleware;