// backend/config/middleware.js

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// ============================================
// Rate Limiters - FIXED (No Custom keyGenerator)
// ============================================

// عام للـ API
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 100, // 100 طلب
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'تم تجاوز الحد المسموح من الطلبات، حاول مرة أخرى بعد قليل',
    });
  },
});

// للتسجيل والدخول (صارم أكثر)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 5, // 5 محاولات فقط
  skipSuccessfulRequests: true, // لا تحسب المحاولات الناجحة
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'محاولات كثيرة جداً، حاول مرة أخرى بعد 15 دقيقة',
    });
  },
});

// لإرسال الإيميلات/SMS (صارم جداً)
const emailLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // ساعة واحدة
  max: 3, // 3 إيميلات فقط في الساعة
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'تم إرسال عدد كبير من رسائل التحقق، حاول بعد ساعة',
    });
  },
});

// ============================================
// Configure Middleware Function
// ============================================
const configureMiddleware = (app) => {
  // Security Headers
  app.use(helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  }));

  // CORS Configuration
  const corsOptions = {
    origin: process.env.NODE_ENV === 'production'
      ? [
          'https://waseed-team-production.up.railway.app',
          'https://www.waseed.app',
          'https://waseed.app',
        ]
      : '*',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };
  app.use(cors(corsOptions));

  // Body Parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Static Files
  app.use('/uploads', express.static('uploads'));

  // ============================================
  // Apply Rate Limiters
  // ============================================
  
  // Rate limiter عام لكل الـ API
  app.use('/api/', apiLimiter);
  
  // Rate limiters محددة لـ endpoints حساسة
  app.use('/api/auth/register', authLimiter);
  app.use('/api/auth/login', authLimiter);
  app.use('/api/auth/verify-2fa', authLimiter);
  app.use('/api/auth/biometric-login', authLimiter);
  
  // Rate limiters للإيميلات
  app.use('/api/auth/verify-email', emailLimiter);
  app.use('/api/auth/resend-verification-email', emailLimiter);
  app.use('/api/auth/send-phone-verification', emailLimiter);
  app.use('/api/auth/resend-verification-phone', emailLimiter);
  app.use('/api/auth/resend-2fa', emailLimiter);
  app.use('/api/auth/forgot-password', emailLimiter);
  app.use('/api/auth/request-biometric-enable', emailLimiter);
  app.use('/api/user/request-email-change', emailLimiter);
  app.use('/api/user/request-phone-change', emailLimiter);

  // Request Logging (Development only)
  if (process.env.NODE_ENV !== 'production') {
    app.use((req, res, next) => {
      console.log(`${req.method} ${req.path} - IP: ${req.ip}`);
      next();
    });
  }

  console.log('✅ Middleware configured successfully');
};

module.exports = { 
  configureMiddleware,
  authLimiter,
  emailLimiter,
  apiLimiter 
};