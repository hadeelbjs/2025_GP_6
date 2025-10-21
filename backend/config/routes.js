// config/routes.js
const authRoutes = require('../routes/auth');
const contactsRoutes = require('../routes/contacts');
const messagesRoutes = require('../routes/messages');
const prekeysRoutes = require('../routes/prekeys');
const userRoutes = require('../routes/user');
const uploadRoutes = require('../routes/upload');

const configureRoutes = (app) => {
  // API Routes
  app.use('/api/auth', authRoutes);
  app.use('/api/contacts', contactsRoutes);
  app.use('/api/messages', messagesRoutes);
  app.use('/api/prekeys', prekeysRoutes);
  app.use('/api/user', userRoutes);
  app.use('/api/upload', uploadRoutes);

  console.log('Routes configured');
};

module.exports = { configureRoutes };