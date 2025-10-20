require('dotenv').config();
const express = require('express');
const http = require('http');
const path = require('path');
const mongoose = require('mongoose');

// Import configurations
const { configureMiddleware } = require('./config/middleware');
const { configureRoutes } = require('./config/routes');
const { configureSocketIO } = require('./config/socket');
const { connectDatabase } = require('./config/database');

// Initialize Express App
const app = express();
const server = http.createServer(app);

// Configure Socket.IO
const io = configureSocketIO(server);
app.set('io', io);

// Configure Middleware (Security, CORS, Rate Limiting, etc.)
configureMiddleware(app);

// Connect to Database
connectDatabase();

// Configure Routes
configureRoutes(app);

// Health Check Endpoints
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'Waseed Backend API is running',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    endpoints: {
      auth: '/api/auth',
      contacts: '/api/contacts',
      messages: '/api/messages',
      upload: '/api/upload',
      prekeys: '/api/prekeys',
      user: '/api/user',
    },
  });
});

app.get('/health', (req, res) => {
  res.json({
    success: true,
    status: 'healthy',
    uptime: process.uptime(),
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    timestamp: new Date().toISOString(),
  });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('Error:', err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'حدث خطأ في السيرفر',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'المسار غير موجود',
    path: req.originalUrl,
  });
});

// Start Server
const PORT = process.env.PORT || 3000;
const HOST = '0.0.0.0';

server.listen(PORT, HOST, () => {
  console.log(`Server running on ${HOST}:${PORT}`);
  console.log(`Socket.IO ready`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Started at: ${new Date().toISOString()}`);
});

// Graceful Shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    mongoose.connection.close(false, () => {
      console.log('MongoDB connection closed');
      process.exit(0);
    });
  });
});

module.exports = { app, server, io };
