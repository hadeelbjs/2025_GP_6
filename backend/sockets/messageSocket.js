// backend/sockets/messageSocket.js
const jwt = require('jsonwebtoken');
const Message = require('../models/Message');

const userSockets = new Map();
const onlineUsers = new Set(); 

async function broadcastStatusToContacts(userId, isOnline, io) {
  try {
    const Contact = require('../models/Contact');
    
    
    // ✅ البحث باستخدام requester و recipient (مو userId و contactId)
    const contacts = await Contact.find({
      $or: [
        { requester: userId, status: 'accepted' },
        { recipient: userId, status: 'accepted' }
      ]
    });
    
    
    // إرسال الحالة لكل جهة اتصال
    contacts.forEach(contact => {
      // ✅ تحديد الطرف الآخر
      const contactUserId = contact.requester.toString() === userId.toString() 
        ? contact.recipient.toString() 
        : contact.requester.toString();
      
      
      // إرسال الحالة الجديدة
      const sent = io.sendToUser(contactUserId, 'user:status', {
        userId: userId,
        isOnline: isOnline
      });
      
      console.log(`📡 ${sent ? '✅' : '❌'} Sent status to ${contactUserId}: ${userId} is ${isOnline ? 'online' : 'offline'}`);
    });
    
  } catch (err) {
    console.error('❌ Error broadcasting status:', err);
    console.error('Full error:', err.stack);
  }
}



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
    console.log(`✅ User connected: ${userId}`);

    userSockets.set(userId.toString(), socket.id);
      onlineUsers.add(userId.toString());

 socket.emit('connected', {
  userId,
  message: 'Connected to messaging server'
});

// ✅ إرسال الرسائل المعلقة فوراً
(async () => {
  try {
    const pendingMessages = await Message.find({
      recipientId: userId,
      status: { $in: ['sent', 'pending'] }
    }).sort({ createdAt: 1 }).limit(50);

    if (pendingMessages.length > 0) {
      console.log(`📬 Sending ${pendingMessages.length} pending messages to user ${userId}`);

      for (const msg of pendingMessages) {
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
          createdAt: msg.createdAt ? msg.createdAt.toISOString() : new Date().toISOString(),
        });


        await Message.findOneAndUpdate(
          { messageId: msg.messageId },
          { 
            status: 'delivered',
            deliveredAt: new Date()
          }
        );

        // ✅ إبلاغ المرسل أن الرسالة تم توصيلها
        io.sendToUser(msg.senderId.toString(), 'message:status_update', {
          messageId: msg.messageId,
          status: 'delivered',
          timestamp: Date.now(),
        });

        console.log(`📨 Delivered pending message: ${msg.messageId}`);
      }
    } else {
      console.log(`📭 No pending messages for user ${userId}`);
    }
  } catch (err) {
    console.error('❌ Failed to send pending messages:', err);
  }
})();

setTimeout(() => {
  broadcastStatusToContacts(userId.toString(), true, io);
}, 500);

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


        if (delivered) {
          socket.emit('message:status_update', {
            messageId,
            status: 'delivered',  
            timestamp: Date.now(),
          });
        }


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
      
      // ✅ إرسال للمستقبل أولاً
      const sentToRecipient = io.sendToUser(recipientId, 'message:deleted', {
        messageId,
        deletedFor: 'everyone',
      });
      
      console.log(`${sentToRecipient ? '✅' : '⚠️'} Sent delete to recipient ${recipientId}`);

      // ✅ ثم إرسال للمرسل (تأكيد)
      socket.emit('message:deleted', {
        messageId,
        deletedFor: 'everyone',
      });
      
      console.log(`✅ Delete confirmed to sender ${senderId}`);

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

      // ✅ إرسال فوري للمستقبل فقط
      const sentToRecipient = io.sendToUser(recipientId, 'message:deleted', {
        messageId,
        deletedFor: 'recipient',
      });

      console.log(`${sentToRecipient ? '✅' : '⚠️'} Delete sent to recipient ${recipientId}`);
      
      // ✅ لا نرسل للمرسل هنا (هو حذفها من عنده فقط محلياً)
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

    socket.on('request:user_status', (data) => {
      const { targetUserId } = data;
      const isOnline = onlineUsers.has(targetUserId.toString());
      
      socket.emit('user:status', {
        userId: targetUserId,
        isOnline: isOnline
      });
      
    });



// ✅ حذف رسائل المحادثة بعد فشل التحقق 3 مرات
socket.on('conversation:failed_verification', async (data) => {
  try {
    const { otherUserId } = data;
    const recipientId = userId; // المستقبل اللي فشل
    
    console.log(`🗑️ Failed verification: Recipient ${recipientId}, Sender ${otherUserId}`);
    
    // ✅ تحديث حالة الرسائل في MongoDB
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
    
    // ✅ إرسال للمرسل (تحديث حالة الرسائل)
    io.sendToUser(otherUserId, 'conversation:recipient_failed_verification', {
      recipientId: recipientId
    });
    
    console.log(`✅ Messages marked as failed verification`);
    
  } catch (err) {
    console.error('❌ Failed verification error:', err);
  }
});

  socket.on('disconnect', () => {
      console.log(`❌ User disconnected: ${userId}`);
      
      userSockets.delete(userId.toString());
      onlineUsers.delete(userId.toString());
      
      setTimeout(() => {
        if (!onlineUsers.has(userId.toString())) {
          broadcastStatusToContacts(userId.toString(), false, io);
        } else {
        }
      }, 1000);
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

  socket.on('privacy:screenshots:update', (data) => {
  const { peerUserId, allowScreenshots } = data;
  io.sendToUser(peerUserId, 'privacy:screenshots:changed', {
    peerUserId: socket.userId,
    allowScreenshots
  });
});

  console.log('✅ Socket.IO messaging system initialized');
};