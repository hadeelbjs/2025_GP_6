const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');

app.set('trust proxy', true);

const configureMiddleware = (app) => {
  // Security Headers
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    })
  );

  // CORS Configuration
  const corsOptions = {
    origin: process.env.NODE_ENV === 'production' 
      ? process.env.CLIENT_URL 
      : '*',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  };
  app.use(cors(corsOptions));

  // Body Parser
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Static Files
  app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

  // NoSQL Injection Protection
  app.use(sanitizeInputs);

  // Rate Limiting
  app.use('/api/', generalLimiter);
  app.use('/api/auth/login', authLimiter);
  app.use('/api/auth/register', authLimiter);
  app.use('/api/upload', uploadLimiter);

  // Request Logger (Development)
  if (process.env.NODE_ENV === 'development') {
    app.use((req, res, next) => {
      console.log(`📨 ${req.method} ${req.path} - ${new Date().toISOString()}`);
      next();
    });
  }
};

// Sanitize Inputs Middleware
const sanitizeInputs = (req, res, next) => {
  const sanitize = (obj) => {
    if (!obj || typeof obj !== 'object') return;
    
    Object.keys(obj).forEach((key) => {
      if (typeof obj[key] === 'string') {
        obj[key] = obj[key].replace(/\$/g, '');
      } else if (typeof obj[key] === 'object') {
        sanitize(obj[key]);
      }
    });
  };

  sanitize(req.query);
  sanitize(req.body);
  next();
};

// Rate Limiters
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: { success: false, message: 'تم تجاوز عدد الطلبات' },
  standardHeaders: true,
  legacyHeaders: false,
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: { success: false, message: 'تجاوزت عدد محاولات تسجيل الدخول' },
  skipSuccessfulRequests: true,
});

const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { success: false, message: 'تم تجاوز عدد محاولات رفع الملفات' },
});

module.exports = { configureMiddleware };