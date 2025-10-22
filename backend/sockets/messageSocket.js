// sockets/messageSocket.js

const jwt = require('jsonwebtoken');
const Message = require('../models/Message');

// تخزين المستخدمين المتصلين
const onlineUsers = new Map(); // userId -> socketId
const userSockets = new Map(); // socketId -> userId

module.exports = (io) => {
  
  // ============================================
  // Middleware للتحقق من الـ Token
  // ============================================
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      
      if (!token) {
        console.log('❌ No token provided');
        return next(new Error('Authentication error: No token provided'));
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      socket.userId = decoded.id;
      
      console.log(`✅ User authenticated: ${decoded.id}`);
      next();
    } catch (err) {
      console.error('❌ Socket auth error:', err.message);
      next(new Error('Authentication error'));
    }
  });

  // ============================================
  // Helper Function: إرسال رسالة لمستخدم محدد
  // ============================================
  io.sendToUser = (userId, event, data) => {
    const socketId = onlineUsers.get(userId);
    if (socketId) {
      io.to(socketId).emit(event, data);
      return true;
    }
    return false;
  };

  // ============================================
  // Connection Handler
  // ============================================
  io.on('connection', (socket) => {
    const userId = socket.userId;
    console.log(`🔌 User connected: ${userId} (Socket: ${socket.id})`);

    // ✅ تسجيل المستخدم كـ Online
    onlineUsers.set(userId, socket.id);
    userSockets.set(socket.id, userId);

    // ✅ إخبار الجميع أن هذا المستخدم Online
    socket.broadcast.emit('user:status', {
      userId: userId,
      status: 'online',
      lastSeen: null,
    });

    // ✅ إرسال تأكيد الاتصال للمستخدم نفسه
    socket.emit('connected', {
      userId: userId,
      message: 'Connected successfully',
      timestamp: new Date().toISOString(),
    });

    console.log(`✅ Online users count: ${onlineUsers.size}`);

    // ============================================
    // 📨 إرسال رسالة
    // ============================================
    socket.on('message:send', async (data) => {
      try {
        console.log('📨 Message:send received:', {
          from: userId,
          to: data.recipientId,
          messageId: data.messageId,
          hasAttachment: !!data.attachmentData,
        });

        const {
          messageId,
          recipientId,
          encryptedType,
          encryptedBody,
          attachmentData,
          attachmentType,
          attachmentName,
          attachmentMimeType,
          createdAt,
        } = data;

        // ✅ التحقق من البيانات المطلوبة
        if (!messageId || !recipientId || !encryptedBody || encryptedType === undefined) {
          console.error('❌ Missing required fields');
          return socket.emit('error', {
            message: 'Missing required fields',
          });
        }

        // ✅ حفظ في قاعدة البيانات
        const message = new Message({
          messageId,
          senderId: userId,
          recipientId,
          encryptedType,
          encryptedBody,
          attachmentData: attachmentData || null,
          attachmentType: attachmentType || null,
          attachmentName: attachmentName || null,
          attachmentMimeType: attachmentMimeType || null,
          status: 'sent',
          createdAt: createdAt ? new Date(createdAt) : new Date(),
        });

        await message.save();
        console.log(`✅ Message saved to DB: ${messageId}`);

        // ✅ إرسال للمستقبل
        const recipientSocketId = onlineUsers.get(recipientId);
        let delivered = false;

        if (recipientSocketId) {
          io.to(recipientSocketId).emit('message:new', {
            messageId: message.messageId,
            senderId: userId,
            encryptedType: message.encryptedType,
            encryptedBody: message.encryptedBody,
            attachmentData: message.attachmentData,
            attachmentType: message.attachmentType,
            attachmentName: message.attachmentName,
            attachmentMimeType: message.attachmentMimeType,
            createdAt: message.createdAt.toISOString(),
          });

          delivered = true;
          console.log(`✅ Message delivered to recipient: ${recipientId}`);
        } else {
          console.log(`📭 Recipient offline, message saved for later: ${recipientId}`);
        }

        // ✅ تأكيد للمرسل
        socket.emit('message:sent', {
          messageId: message.messageId,
          status: 'sent',
          delivered: delivered,
          timestamp: message.createdAt.toISOString(),
        });

      } catch (err) {
        console.error('❌ Error sending message:', err);
        socket.emit('error', {
          message: 'Failed to send message',
          error: err.message,
        });
      }
    });

    // ============================================
    // ✅ تحديث حالة الرسالة - delivered
    // ============================================
    socket.on('message:delivered', async (data) => {
      try {
        const { messageId, senderId } = data;

        console.log(`📬 Message delivered acknowledgment: ${messageId}`);

        await Message.findOneAndUpdate(
          { messageId },
          { 
            status: 'delivered',
            deliveredAt: new Date(),
          }
        );

        // ✅ إخبار المرسل
        const senderSocketId = onlineUsers.get(senderId);
        if (senderSocketId) {
          io.to(senderSocketId).emit('message:status_update', {
            messageId,
            status: 'delivered',
            timestamp: new Date().toISOString(),
          });
          console.log(`✅ Delivery status sent to sender: ${senderId}`);
        }

      } catch (err) {
        console.error('❌ Error updating delivered status:', err);
      }
    });

    // ============================================
    // ✅ تحديث حالة الرسالة - verified/read
    // ============================================
    socket.on('message:status', async (data) => {
      try {
        const { messageId, status, recipientId } = data;

        console.log(`📊 Message status update: ${messageId} -> ${status}`);

        await Message.findOneAndUpdate(
          { messageId },
          { 
            status: status,
            ...(status === 'verified' && { readAt: new Date() }),
          }
        );

        // ✅ إخبار المستقبل/المرسل
        const targetSocketId = onlineUsers.get(recipientId);
        if (targetSocketId) {
          io.to(targetSocketId).emit('message:status_update', {
            messageId,
            status,
            timestamp: new Date().toISOString(),
          });
          console.log(`✅ Status update sent to: ${recipientId}`);
        }

      } catch (err) {
        console.error('❌ Error updating message status:', err);
      }
    });

    // ============================================
    // 🗑️ حذف رسالة
    // ============================================
    socket.on('message:delete', async (data) => {
      try {
        const { messageId, deleteFor } = data;

        console.log(`🗑️ Delete request: ${messageId} (${deleteFor})`);

        const message = await Message.findOne({ messageId });

        if (!message) {
          console.error('❌ Message not found:', messageId);
          return socket.emit('error', { message: 'Message not found' });
        }

        // ✅ التحقق من الصلاحيات
        if (message.senderId.toString() !== userId) {
          console.error('❌ Unauthorized delete attempt');
          return socket.emit('error', { message: 'Unauthorized' });
        }

        if (deleteFor === 'everyone') {
          // ✅ حذف للجميع
          message.deletedForEveryone = true;
          message.deletedForEveryoneAt = new Date();
          message.status = 'deleted';
          await message.save();

          const recipientId = message.recipientId.toString();
          const recipientSocketId = onlineUsers.get(recipientId);

          // ✅ إخبار المستقبل
          if (recipientSocketId) {
            io.to(recipientSocketId).emit('message:deleted', {
              messageId,
              deletedFor: 'everyone',
            });
            console.log(`✅ Delete notification sent to recipient: ${recipientId}`);
          }

          // ✅ تأكيد للمرسل
          socket.emit('message:deleted', {
            messageId,
            deletedFor: 'everyone',
          });

          console.log(`✅ Message deleted for everyone: ${messageId}`);

        } else if (deleteFor === 'recipient') {
          // ✅ حذف من عند المستقبل فقط
          const recipientId = message.recipientId.toString();
          
          if (!message.deletedFor.some(id => id.toString() === recipientId)) {
            message.deletedFor.push(message.recipientId);
            message.deletedForRecipient = true;
            await message.save();
          }

          const recipientSocketId = onlineUsers.get(recipientId);

          // ✅ إخبار المستقبل فوراً
          if (recipientSocketId) {
            io.to(recipientSocketId).emit('message:deleted', {
              messageId,
              deletedFor: 'recipient',
            });
            console.log(`✅ Delete notification sent to recipient: ${recipientId}`);
          } else {
            console.log(`📭 Recipient offline, delete will sync later`);
          }

          console.log(`✅ Message deleted for recipient: ${messageId}`);
        }

      } catch (err) {
        console.error('❌ Error deleting message:', err);
        socket.emit('error', { 
          message: 'Failed to delete message',
          error: err.message,
        });
      }
    });

    // ============================================
    // 📊 طلب حالة مستخدم
    // ============================================
    socket.on('request:user_status', (data) => {
      try {
        const { targetUserId } = data;
        
        console.log(`📊 Status request for user: ${targetUserId}`);
        
        const isOnline = onlineUsers.has(targetUserId);
        
        socket.emit('user:status', {
          userId: targetUserId,
          status: isOnline ? 'online' : 'offline',
          lastSeen: isOnline ? null : new Date().toISOString(),
        });

        console.log(`✅ Status sent: ${targetUserId} -> ${isOnline ? 'online' : 'offline'}`);
      } catch (err) {
        console.error('❌ Error getting user status:', err);
      }
    });

    // ============================================
    // ⌨️ المستخدم يكتب
    // ============================================
    socket.on('typing:start', (data) => {
      try {
        const { recipientId } = data;
        const recipientSocketId = onlineUsers.get(recipientId);

        if (recipientSocketId) {
          io.to(recipientSocketId).emit('user:typing', {
            userId: userId,
            isTyping: true,
          });
          console.log(`⌨️ Typing indicator sent: ${userId} -> ${recipientId}`);
        }
      } catch (err) {
        console.error('❌ Error in typing:start:', err);
      }
    });

    socket.on('typing:stop', (data) => {
      try {
        const { recipientId } = data;
        const recipientSocketId = onlineUsers.get(recipientId);

        if (recipientSocketId) {
          io.to(recipientSocketId).emit('user:typing', {
            userId: userId,
            isTyping: false,
          });
        }
      } catch (err) {
        console.error('❌ Error in typing:stop:', err);
      }
    });

    // ============================================
    // ❌ Disconnect Handler
    // ============================================
    socket.on('disconnect', (reason) => {
      console.log(`❌ User disconnected: ${userId} (Reason: ${reason})`);
      
      // ✅ إزالة من القوائم
      onlineUsers.delete(userId);
      userSockets.delete(socket.id);

      // ✅ إخبار الجميع أن المستخدم Offline
      socket.broadcast.emit('user:status', {
        userId: userId,
        status: 'offline',
        lastSeen: new Date().toISOString(),
      });

      console.log(`✅ Online users count: ${onlineUsers.size}`);
    });

    // ============================================
    // ❌ Error Handler
    // ============================================
    socket.on('error', (error) => {
      console.error(`❌ Socket error for user ${userId}:`, error);
    });

  });

  console.log('✅ Message socket handlers initialized');
};