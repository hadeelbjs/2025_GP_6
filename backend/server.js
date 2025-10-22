// server.js
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const http = require('http');
const { configureMiddleware } = require('./config/middleware');
const { configureRoutes } = require('./config/routes');
const { configureSocketIO } = require('./config/socket');

const app = express();
app.set('trust proxy', true);

const server = http.createServer(app);

// ============================================
// Socket.IO Configuration
// ============================================
const io = configureSocketIO(server);

// Make io accessible to routes
app.set('io', io);

// ============================================
// Redis Configuration (Optional)
// ============================================
let redisConnected = false;

async function connectRedis() {
  try {
    const { connectRedis: redisConnect } = require('./config/redis');
    await redisConnect();
    redisConnected = true;
    console.log('✅ Redis connected successfully');
  } catch (err) {
    console.log('⚠️ Redis not configured - using in-memory storage');
    redisConnected = false;
  }
}

// ============================================
// MongoDB Connection
// ============================================
async function connectDatabase() {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ MongoDB connected successfully');
  } catch (err) {
    console.error('❌ MongoDB connection error:', err);
    throw err;
  }
}

// ============================================
// Configure Middleware & Routes
// ============================================
configureMiddleware(app);
configureRoutes(app);

// ============================================
// Health Check Endpoint
// ============================================
app.get('/health', (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    services: {
      mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
      redis: redisConnected ? 'connected' : 'not configured',
      socketio: io.engine.clientsCount > 0 ? 'active' : 'idle',
      connectedClients: io.engine.clientsCount,
    },
  };

  const statusCode = mongoose.connection.readyState === 1 ? 200 : 503;
  res.status(statusCode).json(health);
});

// ============================================
// 404 Handler
// ============================================
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'المسار غير موجود',
    path: req.path,
  });
});

// ============================================
// Global Error Handler
// ============================================
app.use((err, req, res, next) => {
  console.error('❌ Error:', err);

  // Timeout error
  if (req.timedout) {
    return res.status(408).json({
      success: false,
      message: 'انتهى وقت الطلب',
    });
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      message: 'خطأ في البيانات المدخلة',
      errors: Object.values(err.errors).map(e => e.message),
    });
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      message: 'توكن غير صالح',
    });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      success: false,
      message: 'انتهت صلاحية الجلسة',
    });
  }

  // Default error
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'حدث خطأ في السيرفر',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// ============================================
// Graceful Shutdown
// ============================================
process.on('SIGTERM', async () => {
  console.log('🛑 SIGTERM received, shutting down gracefully...');
  
  server.close(async () => {
    console.log('🔌 HTTP server closed');
    
    try {
      await mongoose.connection.close();
      console.log('🗄️ MongoDB connection closed');
    } catch (err) {
      console.error('Error closing MongoDB:', err);
    }
    
    process.exit(0);
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error('⚠️ Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
});

// ============================================
// Start Server
// ============================================
const PORT = process.env.PORT || 5000;

async function startServer() {
  try {
    // 1. Connect to MongoDB
    await connectDatabase();
    
    // 2. Try to connect to Redis (optional)
    await connectRedis();
    
    // 3. Start HTTP server
    server.listen(PORT, () => {
      console.log('');
      console.log('═══════════════════════════════════════════');
      console.log('🚀 Waseed Server Started Successfully');
      console.log('═══════════════════════════════════════════');
      console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`Port: ${PORT}`);
      console.log(`URL: http://localhost:${PORT}`);
      console.log(`Database: MongoDB ${mongoose.connection.readyState === 1 ? '✅' : '❌'}`);
      console.log(`Redis: ${redisConnected ? '✅ Connected' : '⚠️ Not configured'}`);
      console.log(`Socket.IO: ✅ Ready`);
      console.log('═══════════════════════════════════════════');
      console.log('');
    });
  } catch (err) {
    console.error('❌ Failed to start server:', err);
    process.exit(1);
  }
}

// Handle unhandled rejections
process.on('unhandledRejection', (err) => {
  console.error('❌ Unhandled Rejection:', err);
  server.close(() => {
    process.exit(1);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('❌ Uncaught Exception:', err);
  server.close(() => {
    process.exit(1);
  });
});

// Start the server
startServer();

module.exports = { app, server, io };