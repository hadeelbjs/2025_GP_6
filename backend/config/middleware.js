// config/middleware.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// ============================================
// Rate Limiters 
// ============================================

// General API Rate Limiter
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'تم تجاوز الحد المسموح من الطلبات، حاول مرة أخرى بعد قليل',
    });
  },
});

// Authentication Endpoints (Login, Register, 2FA)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Increased from 5 to 10 for better UX
  skipSuccessfulRequests: true,
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'محاولات كثيرة جداً، حاول مرة أخرى بعد 15 دقيقة',
    });
  },
});

// Email/SMS Sending Endpoints (More lenient than before)
const emailLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // Changed from 1 hour to 15 minutes
  max: 5, // Changed from 3 to 5
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'تم إرسال عدد كبير من رسائل التحقق، حاول بعد 15 دقيقة',
    });
  },
});

// NEW: Biometric-specific Rate Limiter (Less restrictive)
const biometricLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // More attempts allowed
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'محاولات كثيرة لتفعيل البايومتركس، حاول بعد 15 دقيقة',
    });
  },
});

// Upload Rate Limiter
const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      message: 'تم تجاوز عدد محاولات رفع الملفات',
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
  // Apply Rate Limiters - FIXED ORDER & CONFIGURATION
  // ============================================
  
  // General API rate limiter (applies to all /api/* routes)
  app.use('/api/', apiLimiter);
  
  // Authentication endpoints
  app.use('/api/auth/register', authLimiter);
  app.use('/api/auth/login', authLimiter);
  app.use('/api/auth/verify-2fa', authLimiter);
  app.use('/api/auth/forgot-password', authLimiter);
  app.use('/api/auth/reset-password', authLimiter);
  app.use('/api/auth/change-password', authLimiter);
  
  // Biometric endpoints - FIXED: Use biometricLimiter instead of emailLimiter
  app.use('/api/auth/request-biometric-enable', biometricLimiter);
  app.use('/api/auth/verify-biometric-enable', biometricLimiter);
  app.use('/api/auth/biometric-login', authLimiter);
  
  // Email/SMS verification endpoints
  app.use('/api/auth/verify-email', emailLimiter);
  app.use('/api/auth/resend-verification-email', emailLimiter);
  app.use('/api/auth/send-phone-verification', emailLimiter);
  app.use('/api/auth/resend-verification-phone', emailLimiter);
  app.use('/api/auth/resend-2fa', emailLimiter);
  
  // User update endpoints
  app.use('/api/user/request-email-change', emailLimiter);
  app.use('/api/user/request-phone-change', emailLimiter);

  // Request Logging (Development only)
  if (process.env.NODE_ENV !== 'production') {
    app.use((req, res, next) => {
      const start = Date.now();
      res.on('finish', () => {
        const duration = Date.now() - start;
        console.log(`${req.method} ${req.path} - ${res.statusCode} - ${duration}ms - IP: ${req.ip}`);
      });
      next();
    });
  }

  console.log('✅ Middleware configured successfully');
};

module.exports = { 
  configureMiddleware,
  authLimiter,
  emailLimiter,
  apiLimiter,
  biometricLimiter,
  uploadLimiter
};