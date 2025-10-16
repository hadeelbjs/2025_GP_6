// backend/sockets/messageSocket.js
const jwt = require('jsonwebtoken');
const Message = require('../models/Message');

// خريطة تربط userId مع socketId النشط
const userSockets = new Map();

module.exports = (io) => {

  //  تحقق من صحة التوكن عند الاتصال
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token;
      
      if (!token) {
        return next(new Error('Authentication error: No token provided'));
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      
      socket.userId = decoded.user?.id || decoded.id || decoded.userId;
      
      if (!socket.userId) {
        return next(new Error('Invalid token structure'));
      }
      
      console.log('✅ Authenticated:', socket.userId);
      next();
      
    } catch (err) {
      console.error('❌ Socket authentication error:', err.message);
      next(new Error('Authentication error: Invalid token'));
    }
  });

  //  عند الاتصال الجديد
  io.on('connection', (socket) => {
    const userId = socket.userId;
    console.log(`✅ User connected: ${userId} (Socket: ${socket.id})`);

    // خزّن العلاقة
    userSockets.set(userId.toString(), socket.id);

    // أرسل تأكيد
    socket.emit('connected', {
      userId,
      message: 'Connected to messaging server'
    });

    //  إرسال رسالة جديدة
    socket.on('message:send', async (data) => {
      try {
        const { messageId, recipientId, encryptedType, encryptedBody } = data;
        const senderId = userId;
        
        console.log(`📤 Sending message: ${messageId} from ${senderId} → ${recipientId}`);

        //  إرسال للمستقبل (إذا متصل)
        const delivered = io.sendToUser(recipientId, 'message:new', {
          messageId,
          senderId,
          encryptedType,
          encryptedBody,
          createdAt: new Date().toISOString(),
        });

        //  أخبر المرسل بالنتيجة
        socket.emit('message:sent', {
          messageId,
          delivered, // true/false
          timestamp: Date.now(),
        });

        //  إذا المستقبل أوفلاين، احفظ في MongoDB
        if (!delivered) {
          await Message.create({
            messageId,
            senderId,
            recipientId,
            encryptedType,
            encryptedBody,
            status: 'sent',
            createdAt: new Date(),
          });
          console.log(`💾 Message saved (offline): ${messageId}`);
        }

      } catch (err) {
        console.error('❌ Send message error:', err);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    //  تأكيد استلام الرسالة من المستقبل
    socket.on('message:delivered', async (data) => {
      try {
        const { messageId, senderId, encryptedType, encryptedBody, createdAt } = data;
        const receiverId = userId;

        console.log(`📨 Message delivered confirmation: ${messageId}`);

        // حفظ/تحديث في MongoDB
        await Message.findOneAndUpdate(
          { messageId },
          {
            messageId,
            senderId,
            recipientId: receiverId,
            encryptedType,
            encryptedBody,
            status: 'delivered',
            deliveredAt: new Date(),
            createdAt: createdAt ? new Date(createdAt) : new Date(),
          },
          { upsert: true, new: true }
        );

        // أخبر المرسل
        io.sendToUser(senderId, 'message:status_update', {
          messageId,
          status: 'delivered',
          timestamp: Date.now(),
        });

        console.log(`✅ Message ${messageId} marked as delivered`);

      } catch (err) {
        console.error('❌ Delivered confirmation error:', err);
      }
    });

    // ✅ تحديث حالة الرسالة (verified)
    socket.on('message:status', async (data) => {
      try {
        const { messageId, status, recipientId } = data;
        console.log(`📊 Status update: ${messageId} → ${status}`);

        // تحديث في MongoDB
        await Message.findOneAndUpdate(
          { messageId },
          { status, [`${status}At`]: new Date() }
        );

        // أخبر الطرف الآخر
        io.sendToUser(recipientId, 'message:status_update', {
          messageId,
          status,
          timestamp: Date.now(),
        });

      } catch (err) {
        console.error('❌ Status update error:', err);
      }
    });

    //  مؤشر الكتابة
    socket.on('typing', (data) => {
      const { recipientId, isTyping } = data;
      io.sendToUser(recipientId, 'typing', {
        senderId: userId,
        isTyping
      });
    });

    //  قطع الاتصال
    socket.on('disconnect', () => {
      console.log(`❌ User disconnected: ${userId}`);
      userSockets.delete(userId.toString());
    });
  });

  //  دالة إرسال محسّنة
  io.sendToUser = (userId, event, data) => {
    const socketId = userSockets.get(userId.toString());
    
    if (!socketId) {
      console.warn(`⚠️ User ${userId} not connected (no socket)`);
      return false;
    }
    
    const socket = io.sockets.sockets.get(socketId);
    
    if (!socket || !socket.connected) {
      console.warn(`⚠️ Socket ${socketId} not connected`);
      userSockets.delete(userId.toString()); // ✅ تنظيف
      return false;
    }
    
    socket.emit(event, data);
    console.log(`📨 Sent '${event}' to user ${userId}`);
    return true;
  };

  console.log('Socket.IO messaging system initialized');
};