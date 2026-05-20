// backend/sockets/messageSocket.js
const jwt = require('jsonwebtoken');
const Message = require('../models/Message');

const userSockets = new Map();
const onlineUsers = new Set();

function generateConversationId(userId1, userId2) {
  const ids = [userId1.toString(), userId2.toString()].sort();
  return `${ids[0]}-${ids[1]}`;
}

async function broadcastStatusToContacts(userId, isOnline, io) {
  try {
    const Contact = require('../models/Contact');

    const contacts = await Contact.find({
      $or: [
        { requester: userId, status: 'accepted' },
        { recipient: userId, status: 'accepted' }
      ]
    });

    contacts.forEach(contact => {
      const contactUserId = contact.requester.toString() === userId.toString()
        ? contact.recipient.toString()
        : contact.requester.toString();

      const sent = io.sendToUser(contactUserId, 'user:status', {
        userId: userId,
        isOnline: isOnline
      });

    });

  } catch (err) {
    console.error('Error broadcasting status:', err);
    console.error('Full error:', err.stack);
  }
}

module.exports = (io) => {

  // التحقق من التوكن
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

      next();

    } catch (err) {
      console.error('Socket authentication error:', err.message);
      next(new Error('Authentication error: Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.userId;

    userSockets.set(userId.toString(), socket.id);
    onlineUsers.add(userId.toString());

    socket.emit('connected', {
      userId,
      message: 'Connected to messaging server'
    });

    // إرسال الرسائل المعلقة بعد تأخير لإعطاء الكلاينت وقت لتسجيل الـ listeners
    setTimeout(async () => {
      try {
        const pendingMessages = await Message.find({
          recipientId: userId,
          status: { $in: ['sent', 'pending'] }
        }).sort({ createdAt: 1 }).limit(50);

        if (pendingMessages.length > 0) {

          for (const msg of pendingMessages) {
            // إرسال الرسالة فقط — الحذف يصير بعد تأكيد message:delivered من الكلاينت
            socket.emit('message:new', {
              messageId: msg.messageId,
              senderId: msg.senderId.toString(),
              recipientId: msg.recipientId.toString(),
              encryptedType: msg.encryptedType,
              encryptedBody: msg.encryptedBody,
              attachmentData: msg.attachmentData || null,
              attachmentType: msg.attachmentType || null,
              attachmentName: msg.attachmentName || null,
              attachmentMimeType: msg.attachmentMimeType || null,
              visibilityDuration: msg.visibilityDuration || null,
              expiresAt: msg.expiresAt ? msg.expiresAt.toISOString() : null,
              createdAt: msg.createdAt ? msg.createdAt.toISOString() : new Date().toISOString(),
            });

            // إخبار المرسل أن الرسالة وصلت
            io.sendToUser(msg.senderId.toString(), 'message:status_update', {
              messageId: msg.messageId,
              status: 'delivered',
              timestamp: Date.now(),
            });

          }
        } 
      } catch (err) {
        console.error('Failed to send pending messages:', err);
      }
    }, 3000);

    setTimeout(() => {
      broadcastStatusToContacts(userId.toString(), true, io);
    }, 500);

 // وضَعْ بدلاً منه تحديث الحالة فقط:
socket.on('message:delivered', async (data) => {
  try {
    const { messageId } = data;
    if (!messageId) return;

    // نقوم بتحديث الحالة إلى delivered بدلاً من حذفها فوراً لضمان عدم ضياعها
    await Message.findOneAndUpdate(
      { messageId },
      { $set: { status: 'delivered' } }
    );
  } catch (err) {
    console.error('Error updating delivered message:', err);
  }
});

    socket.on('message:verified_and_saved', async (data) => {
      try {
        const { messageId } = data;
        if (!messageId) return;

        await Message.findOneAndDelete({ messageId });
      } catch (err) {
        console.error('Error cleaning message from cloud DB:', err);
      }
    });

    // إرسال رسالة مع مرفقات
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
          attachmentMimeType,
          visibilityDuration,
          expiresAt,
          createdAt
        } = data;

        const senderId = userId;

        const finalExpiresAt = expiresAt
          ? new Date(expiresAt.endsWith('Z') ? expiresAt : expiresAt + 'Z')
          : null;
        const messageCreatedAt = createdAt ? new Date(createdAt) : new Date();

        const delivered = io.sendToUser(recipientId, 'message:new', {
          messageId,
          senderId,
          encryptedType,
          encryptedBody,
          attachmentData,
          attachmentType,
          attachmentName,
          attachmentMimeType,
          visibilityDuration,
          expiresAt: finalExpiresAt ? finalExpiresAt.toISOString() : null,
          createdAt: messageCreatedAt.toISOString(),
        });

        socket.emit('message:sent', {
          messageId,
          delivered,
          timestamp: Date.now(),
        });

        if (delivered) {
          socket.emit('message:status_update', {
            messageId,
            status: 'delivered',
            timestamp: Date.now(),
            visibilityDuration,
            expiresAt: finalExpiresAt ? finalExpiresAt.toISOString() : null,
          });
        }

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
            createdAt: messageCreatedAt,
            visibilityDuration,
            expiresAt: finalExpiresAt,
            isExpired: false,
          });
   
        }

      } catch (err) {
        console.error('Send message error:', err);
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    socket.on('message:delete_local', (data) => {
      try {
        const { messageId, deleteFor, recipientId } = data;

        if (!recipientId) {
          console.error('recipientId is missing!');
          socket.emit('error', { message: 'معرف المستقبل مفقود' });
          return;
        }

        const sent = io.sendToUser(recipientId, 'message:deleted', {
          messageId,
          deletedFor: deleteFor,
        });

      

      } catch (err) {
        console.error('Delete message error:', err);
        socket.emit('error', { message: 'فشل الحذف' });
      }
    });

    // حالة الكتابة
    socket.on('typing', (data) => {
      const { recipientId, isTyping } = data;
      io.sendToUser(recipientId, 'typing', {
        senderId: userId,
        isTyping
      });
    });

    socket.on('request:user_status', (data) => {
      const { targetUserId } = data;
      const isOnline = onlineUsers.has(targetUserId.toString());

      socket.emit('user:status', {
        userId: targetUserId,
        isOnline: isOnline
      });
    });

    // حذف رسائل المحادثة بعد فشل التحقق
    socket.on('conversation:failed_verification', async (data) => {
      try {
        const { otherUserId } = data;
        const recipientId = userId;

        await Message.updateMany(
          {
            $or: [
              { senderId: otherUserId, recipientId: recipientId },
              { senderId: recipientId, recipientId: otherUserId }
            ]
          },
          {
            $set: {
              deletedForRecipient: true,
              failedVerification: true,
              status: 'failed_verification'
            }
          }
        );

        await Message.updateMany(
          {
            senderId: otherUserId,
            recipientId: recipientId
          },
          {
            $set: {
              failedVerificationAtRecipient: true
            }
          }
        );

        io.sendToUser(otherUserId, 'conversation:recipient_failed_verification', {
          recipientId: recipientId
        });


      } catch (err) {
        console.error('Failed verification error:', err);
      }
    });

    // Privacy screenshots update handler
    socket.on('privacy:screenshots:update', async (data) => {
      try {
        const { targetUserId, allowScreenshots } = data;
        const currentUserId = socket.userId;

        const sent = io.sendToUser(targetUserId, 'privacy:screenshots:changed', {
          peerUserId: currentUserId,
          allowScreenshots: allowScreenshots,
          timestamp: Date.now(),
        });

        socket.emit('privacy:screenshots:updated', {
          success: true,
          targetUserId,
          allowScreenshots,
        });

      } catch (err) {
        console.error('Privacy update error:', err);
        socket.emit('error', { message: 'فشل تحديث سياسة الخصوصية' });
      }
    });

    // معالج الكشف عن Screenshot في iOS
    socket.on('screenshot:taken', async (data) => {
      try {
        const { targetUserId } = data;
        const takenByUserId = socket.userId;
        const User = require('../models/User');
        const user = await User.findById(takenByUserId).select('fullName');
        const takenByName = user?.fullName || 'الطرف الآخر';

        const sent = io.sendToUser(targetUserId, 'screenshot:notification', {
          takenByUserId: takenByUserId,
          takenByName: takenByName,
          timestamp: new Date().toISOString(),
        });

      } catch (err) {
        console.error('Screenshot notification error:', err);
      }
    });

    socket.on('disconnect', () => {

      userSockets.delete(userId.toString());
      onlineUsers.delete(userId.toString());

      setTimeout(() => {
        if (!onlineUsers.has(userId.toString())) {
          broadcastStatusToContacts(userId.toString(), false, io);
        }
      }, 1000);
    });
  });

  // دالة إرسال محسّنة
  io.sendToUser = (userId, event, data) => {
    const socketId = userSockets.get(userId.toString());

    if (!socketId) {
      console.warn(`User ${userId} not connected (no socket)`);
      return false;
    }

    const socket = io.sockets.sockets.get(socketId);

    if (!socket || !socket.connected) {
      console.warn(`Socket ${socketId} not connected`);
      userSockets.delete(userId.toString());
      return false;
    }

    socket.emit(event, data);
    return true;
  };

};