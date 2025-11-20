// backend/routes/messages.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Message = require('../models/Message');

// ✅ إرسال رسالة مع Base64
router.post('/send', auth, async (req, res) => {
  try {
    const { 
      recipientId, 
      encryptedType, 
      encryptedBody,
      attachmentData,    // Base64
      attachmentType,    // 'image' or 'file'
      attachmentName,
      attachmentMimeType,
      attachmentEncryptionType,
    } = req.body;

    const messageId = require('uuid').v4();

    const message = new Message({
      messageId,
      senderId: req.user.id,
      recipientId,
      encryptedType,
      encryptedBody,
      attachmentData: attachmentData || null,
      attachmentType: attachmentType || null,
      attachmentName: attachmentName || null,
      attachmentMimeType: attachmentMimeType || null,
       attachmentEncryptionType: attachmentEncryptionType || null,
      status: 'sent',
    });

    await message.save();

    //  إرسال عبر Socket
    const io = req.app.get('io');
    if (io && io.sendToUser) {
      const sent = io.sendToUser(recipientId, 'message:new', {
        messageId: message.messageId,
        senderId: req.user.id,
        encryptedType: message.encryptedType,
        encryptedBody: message.encryptedBody,
        attachmentData: message.attachmentData,
        attachmentType: message.attachmentType,
        attachmentName: message.attachmentName,
        attachmentMimeType: message.attachmentMimeType,
        attachmentEncryptionType: message.attachmentEncryptionType,
        createdAt: message.createdAt.toISOString(),
      });

      console.log(`✅ Message sent to recipient: ${sent ? 'delivered' : 'saved for later'}`);
    }

    res.json({
      success: true,
      messageId: message.messageId,
      message: 'تم إرسال الرسالة',
    });

  } catch (err) {
    console.error('Send message error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في إرسال الرسالة',
    });
  }
});

// ✅ حذف من عند المستقبل فقط - مُحدَّث
router.delete('/delete-for-recipient/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const currentUserId = req.user.id;

    const message = await Message.findOne({ messageId });

    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'الرسالة غير موجودة'
      });
    }

    if (message.senderId.toString() !== currentUserId) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية'
      });
    }

    if (message.deletedForEveryone) {
      return res.status(400).json({
        success: false,
        message: 'الرسالة محذوفة للجميع'
      });
    }

    const recipientId = message.recipientId.toString();
    
    // ✅ تحديث في قاعدة البيانات
    if (!message.deletedFor.includes(recipientId)) {
      message.deletedFor.push(message.recipientId);
      message.deletedForRecipient = true;
      await message.save();
    }

    // ✅ إرسال Socket فوري للمستقبل
    const io = req.app.get('io');
    if (io && io.sendToUser) {
      const sent = io.sendToUser(recipientId, 'message:deleted', {
        messageId: message.messageId,
        deletedFor: 'recipient',
      });
      
      console.log(`✅ Delete notification sent to recipient: ${sent}`);
    }

    res.json({
      success: true,
      message: 'تم الحذف من عند المستقبل',
    });

  } catch (err) {
    console.error('Delete for recipient error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في الحذف',
    });
  }
});

// ✅ حذف للجميع - مُحدَّث
router.delete('/delete-for-everyone/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const currentUserId = req.user.id;

    const message = await Message.findOne({ messageId });

    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'الرسالة غير موجودة'
      });
    }

    if (!message.canDeleteForEveryone(currentUserId)) {
      return res.status(403).json({
        success: false,
        message: 'فقط المرسل يمكنه الحذف للجميع'
      });
    }

    if (message.deletedForEveryone) {
      return res.status(400).json({
        success: false,
        message: 'الرسالة محذوفة مسبقاً'
      });
    }

    message.deletedForEveryone = true;
    message.deletedForEveryoneAt = new Date();
    message.status = 'deleted';
    await message.save();

    const io = req.app.get('io');
    if (io && io.sendToUser) {
      const recipientId = message.recipientId.toString();
      
      // ✅ إرسال للمستقبل
      io.sendToUser(recipientId, 'message:deleted', {
        messageId: message.messageId,
        deletedFor: 'everyone',
      });

      // ✅ إرسال للمرسل (تأكيد)
      io.sendToUser(currentUserId, 'message:deleted', {
        messageId: message.messageId,
        deletedFor: 'everyone',
      });

      console.log(`✅ Message deleted for everyone: ${messageId}`);
    }

    res.json({
      success: true,
      message: 'تم الحذف للجميع',
    });

  } catch (err) {
    console.error('Delete for everyone error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في الحذف',
    });
  }
});

// ✅ جلب المحادثة
router.get('/conversation/:userId', auth, async (req, res) => {
  try {
    const { userId: peerId } = req.params;
    const currentUserId = req.user.id;

    let messages = await Message.find({
      $or: [
        { senderId: currentUserId, recipientId: peerId },
        { senderId: peerId, recipientId: currentUserId },
      ],
    })
    .sort({ createdAt: 1 })
    .limit(100);

    // ✅ فلترة الرسائل المحذوفة
    messages = messages.filter(msg => !msg.isDeletedFor(currentUserId));

    const formattedMessages = messages.map(msg => ({
      messageId: msg.messageId,
      senderId: msg.senderId,
      recipientId: msg.recipientId,
      encryptedType: msg.encryptedType,
      encryptedBody: msg.encryptedBody,
      attachmentData: msg.attachmentData,
      attachmentType: msg.attachmentType,
      attachmentName: msg.attachmentName,
      attachmentMimeType: msg.attachmentMimeType,
      status: msg.status,
      deletedForEveryone: msg.deletedForEveryone,
      deletedForRecipient: msg.deletedForRecipient || false,
      createdAt: msg.createdAt,
    }));

    res.json({
      success: true,
      messages: formattedMessages,
    });

  } catch (err) {
    console.error('Get conversation error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب المحادثة',
    });
  }
});

module.exports = router;