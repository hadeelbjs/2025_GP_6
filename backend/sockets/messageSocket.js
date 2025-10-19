// backend/sockets/messageSocket.js
const jwt = require('jsonwebtoken');
const Message = require('../models/Message');

const userSockets = new Map();

module.exports = (io) => {

  // ✅ التحقق من التوكن
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

  io.on('connection', (socket) => {
    const userId = socket.userId;
    console.log(`✅ User connected: ${userId} (Socket: ${socket.id})`);

    userSockets.set(userId.toString(), socket.id);

    socket.emit('connected', {
      userId,
      message: 'Connected to messaging server'
    });

    // ✅ إرسال رسالة مع مرفقات
    socket.on('message:send', async (data) => {
      try {
        const { 
          messageId, 
          recipientId, 
          encryptedType, 
          encryptedBody,
          attachmentData,
          attachmentType,
          attachmentName,
          attachmentMimeType
        } = data;
        
        const senderId = userId;
        
        console.log(`📤 Sending message: ${messageId} from ${senderId} → ${recipientId}`);

        // ✅ إرسال للمستقبل
        const delivered = io.sendToUser(recipientId, 'message:new', {
          messageId,
          senderId,
          encryptedType,
          encryptedBody,
          attachmentData,
          attachmentType,
          attachmentName,
          attachmentMimeType,
          createdAt: new Date().toISOString(),
        });

        // ✅ تأكيد للمرسل
        socket.emit('message:sent', {
          messageId,
          delivered,
          timestamp: Date.now(),
        });

        // ✅ حفظ في DB إذا offline
        if (!delivered) {
          await Message.create({
            messageId,
            senderId,
            recipientId,
            encryptedType,
            encryptedBody,
            attachmentData,
            attachmentType,
            attachmentName,
            attachmentMimeType,
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

    // ✅ تأكيد الاستلام
    socket.on('message:delivered', async (data) => {
      try {
        const { messageId, senderId, encryptedType, encryptedBody, attachmentData, attachmentType, attachmentName, createdAt } = data;
        const receiverId = userId;

        console.log(`📨 Message delivered confirmation: ${messageId}`);

        await Message.findOneAndUpdate(
          { messageId },
          {
            messageId,
            senderId,
            recipientId: receiverId,
            encryptedType,
            encryptedBody,
            attachmentData,
            attachmentType,
            attachmentName,
            status: 'delivered',
            deliveredAt: new Date(),
            createdAt: createdAt ? new Date(createdAt) : new Date(),
          },
          { upsert: true, new: true }
        );

        // ✅ إشعار المرسل بالاستلام
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

    // ✅ تحديث الحالة
    socket.on('message:status', async (data) => {
      try {
        const { messageId, status, recipientId } = data;
        console.log(`📊 Status update: ${messageId} → ${status}`);

        await Message.findOneAndUpdate(
          { messageId },
          { status, [`${status}At`]: new Date() }
        );

        io.sendToUser(recipientId, 'message:status_update', {
          messageId,
          status,
          timestamp: Date.now(),
        });

      } catch (err) {
        console.error('❌ Status update error:', err);
      }
    });

    // ✅ حذف رسالة - مُصلح بالكامل
    socket.on('message:delete', async (data) => {
      try {
        const { messageId, deleteFor } = data;
        const senderId = userId;

        console.log(`🗑️ Delete request: ${messageId} (deleteFor: ${deleteFor})`);

        const message = await Message.findOne({ messageId });
        
        if (!message) {
          socket.emit('error', { message: 'الرسالة غير موجودة' });
          return;
        }

        if (deleteFor === 'everyone') {
          // ✅ حذف للجميع
          if (message.senderId.toString() !== senderId) {
            socket.emit('error', { message: 'فقط المرسل يمكنه الحذف للجميع' });
            return;
          }

          message.deletedForEveryone = true;
          message.deletedForEveryoneAt = new Date();
          message.status = 'deleted';
          await message.save();

          const recipientId = message.recipientId.toString();
          
          // ✅ إرسال للطرفين فوراً
          io.sendToUser(recipientId, 'message:deleted', {
            messageId,
            deletedFor: 'everyone',
          });

          socket.emit('message:deleted', {
            messageId,
            deletedFor: 'everyone',
          });

          console.log(`✅ Message deleted for everyone: ${messageId}`);

        } else if (deleteFor === 'recipient') {
          // ✅ حذف من عند المستقبل فقط
          if (message.senderId.toString() !== senderId) {
            socket.emit('error', { message: 'ليس لديك صلاحية' });
            return;
          }

          const recipientId = message.recipientId.toString();
          
          // ✅ تحديث قاعدة البيانات
          if (!message.deletedFor.includes(recipientId)) {
            message.deletedFor.push(message.recipientId);
            message.deletedForRecipient = true;
            await message.save();
          }

          // ✅ إرسال فوري للمستقبل
          const sentToRecipient = io.sendToUser(recipientId, 'message:deleted', {
            messageId,
            deletedFor: 'recipient',
          });

          // ✅ تأكيد للمرسل
          socket.emit('message:deleted', {
            messageId,
            deletedFor: 'recipient',
            confirmedDelivery: sentToRecipient,
          });

          console.log(`✅ Message deleted for recipient: ${messageId} (delivered: ${sentToRecipient})`);
        }

      } catch (err) {
        console.error('❌ Delete message error:', err);
        socket.emit('error', { message: 'فشل الحذف' });
      }
    });

    // ✅ حالة الكتابة
    socket.on('typing', (data) => {
      const { recipientId, isTyping } = data;
      io.sendToUser(recipientId, 'typing', {
        senderId: userId,
        isTyping
      });
    });

    socket.on('disconnect', () => {
      console.log(`❌ User disconnected: ${userId}`);
      userSockets.delete(userId.toString());
    });
  });

  // ✅ دالة إرسال محسّنة
  io.sendToUser = (userId, event, data) => {
    const socketId = userSockets.get(userId.toString());
    
    if (!socketId) {
      console.warn(`⚠️ User ${userId} not connected (no socket)`);
      return false;
    }
    
    const socket = io.sockets.sockets.get(socketId);
    
    if (!socket || !socket.connected) {
      console.warn(`⚠️ Socket ${socketId} not connected`);
      userSockets.delete(userId.toString());
      return false;
    }
    
    socket.emit(event, data);
    console.log(`📨 Sent '${event}' to user ${userId}`);
    return true;
  };

  console.log('✅ Socket.IO messaging system initialized');
};