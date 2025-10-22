// config/socket.js
const socketIO = require('socket.io');

const configureSocketIO = (server) => {
  const io = socketIO(server, {
    cors: {
      origin: process.env.NODE_ENV === 'production' 
        ? process.env.CLIENT_URL 
        : '*',
      credentials: true,
      methods: ['GET', 'POST'],
    },
    transports: ['websocket', 'polling'],
    pingTimeout: 60000,
    pingInterval: 25000,
  });

  // Initialize Socket Handlers
  require('../sockets/messageSocket')(io);

  console.log('Socket.IO configured');
  
  return io;
};

module.exports = { configureSocketIO };