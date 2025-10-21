// backend/config/middleware.js

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// ============================================
// Helper: Get Real Client IP
// ============================================
const getClientIp = (req) => {
  if (process.env.NODE_ENV === 'production') {
    const forwarded = req.headers['x-forwarded-for'];
    if (forwarded) {
      return forwarded.split(',')[0].trim();
    }
  }
  return req.ip || req.connection.remoteAddress;
};

// ============================================
// Rate Limiters
// ============================================

// عام للـ API
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 دقيقة
  max: 100,
  
  validate: {
    trustProxy: false, 
  },
  
  keyGenerator: getClientIp,
  
  standardHeaders: true,
  legacyHeaders: false,
  
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'تم تجاوز الحد المسموح من الطلبات، حاول مرة أخرى بعد قليل',
    });
  },
});

// للتسجيل والدخول
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,
  
  validate: {
    trustProxy: false,
  },
  
  keyGenerator: getClientIp,
  
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'محاولات كثيرة جداً، حاول مرة أخرى بعد 15 دقيقة',
    });
  },
});

// لإرسال الإيميلات
const emailLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // ساعة
  max: 3,
  
  validate: {
    trustProxy: false,
  },
  
  keyGenerator: getClientIp,
  
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

  // Apply Rate Limiters
  app.use('/api/', apiLimiter);
  
  // تطبيق rate limiters محددة
  app.use('/api/auth/register', authLimiter);
  app.use('/api/auth/login', authLimiter);
  app.use('/api/auth/verify-email', emailLimiter);
  app.use('/api/auth/resend-verification-email', emailLimiter);
  app.use('/api/auth/send-phone-verification', emailLimiter);
  app.use('/api/auth/resend-2fa', emailLimiter);
  app.use('/api/auth/forgot-password', emailLimiter);
  app.use('/api/auth/request-biometric-enable', emailLimiter);
  app.use('/api/user/request-email-change', emailLimiter);
  app.use('/api/user/request-phone-change', emailLimiter);

  // Request Logging (Development only)
  if (process.env.NODE_ENV !== 'production') {
    app.use((req, res, next) => {
      console.log(`${req.method} ${req.path} - IP: ${getClientIp(req)}`);
      next();
    });
  }
};

module.exports = { 
  configureMiddleware,
  authLimiter,
  emailLimiter,
  apiLimiter 
};