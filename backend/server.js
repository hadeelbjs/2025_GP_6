require('dotenv').config();
const express = require('express');
const http = require('http'); 
const socketIO = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
const { startMessageExpiryJob, startDeliveredMessagesCleanup } = require('./jobs/messageCleanup');

const app = express();
const server = http.createServer(app); 

const io = socketIO(server, {
  cors: {
    origin: '*', 
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE']
  },
  transports: ['websocket', 'polling'],
  allowEIO3: true, 
  pingTimeout: 60000,
  pingInterval: 25000
});

app.set('io', io);

// Security Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));

app.use(cors({
  origin: '*', 
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// خدمة الملفات الثابتة
app.use('/api/uploads', express.static(path.join(__dirname, 'uploads')));

// حماية من NoSQL Injection
app.use((req, res, next) => {
  if (req.query) {
    Object.keys(req.query).forEach(key => {
      const value = req.query[key];
      if (typeof value === 'string') {
        req.query[key] = value.replace(/\$/g, '');
      }
    });
  }
  
  if (req.body) {
    const sanitize = (obj) => {
      Object.keys(obj).forEach(key => {
        if (typeof obj[key] === 'string') {
          obj[key] = obj[key].replace(/\$/g, '');
        } else if (typeof obj[key] === 'object' && obj[key] !== null) {
          sanitize(obj[key]);
        }
      });
    };
    sanitize(req.body);
  }
  
  next();
});

// Rate Limiting
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { success: false, message: 'تم تجاوز عدد الطلبات' }
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // قفل لمدة 15 دقيقة
  max: 5,
  message: { success: false, message: 'تجاوزت عدد محاولات تسجيل الدخول' },
  skipSuccessfulRequests: true
});

const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: { success: false, message: 'تم تجاوز عدد محاولات رفع الملفات' }
});

app.use('/api/', generalLimiter);
app.use('/api/auth/login', authLimiter);
app.use('/api/auth/register', authLimiter);
app.use('/api/upload', uploadLimiter);

// Database Connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('✅ Connected to MongoDB'))
  .catch(err => console.error('❌ DB connection error:', err));

// ✅ Socket.IO - يجب أن تكون قبل Routes
require('./sockets/messageSocket')(io);
startMessageExpiryJob(io);


app.use((req, res, next) => {
  req.io = io;
  next();
});

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/contacts', require('./routes/contacts'));
app.use('/api/user', require('./routes/user')); 
app.use('/api/prekeys', require('./routes/prekeys')); 
app.use('/api/messages', require('./routes/messages'));
app.use('/api/upload', require('./routes/upload'));

app.get('/', (req, res) => {
  res.json({ 
    message: 'API is working',
    endpoints: {
      auth: '/api/auth',
      contacts: '/api/contacts',
      messages: '/api/messages',
      upload: '/api/upload'
    }
  });
});

// Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ 
    success: false, 
    message: 'حدث خطأ في السيرفر' 
  });
});

const PORT = process.env.PORT || 3000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server running on port: ${PORT}`);
  console.log(`✅ Socket.IO ready`);
  console.log(`✅ Listening on all interfaces (0.0.0.0)`);
  console.log(`✅ Message expiry job started`);

});