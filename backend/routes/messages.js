// backend/routes/messages.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Message = require('../models/Message');

// ✅ حذف من عند المستقبل فقط
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

    // فقط المرسل يحذف من عند المستقبل
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
    
    // إضافة المستقبل للقائمة
    if (!message.deletedFor.includes(recipientId)) {
      message.deletedFor.push(message.recipientId);
      message.deletedForRecipient = true; // ✅ علامة جديدة
      await message.save();
    }

    // إرسال إشعار عبر Socket
    const io = req.app.get('io');
    if (io && io.sendToUser) {
      io.sendToUser(recipientId, 'message:deleted', {
        messageId: message.messageId,
        deletedFor: 'recipient',
      });
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

// ✅ حذف للجميع (بدون قيد زمني)
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

    // ✅ فقط المرسل يحذف (بدون قيد زمني)
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

    // تحديث حالة الحذف
    message.deletedForEveryone = true;
    message.deletedForEveryoneAt = new Date();
    message.status = 'deleted';
    await message.save();

    // إرسال إشعار عبر Socket للطرفين
    const io = req.app.get('io');
    if (io && io.sendToUser) {
      const recipientId = message.recipientId.toString();
      
      // للمستقبل
      io.sendToUser(recipientId, 'message:deleted', {
        messageId: message.messageId,
        deletedFor: 'everyone',
      });

      // للمرسل (على أجهزته الأخرى)
      io.sendToUser(currentUserId, 'message:deleted', {
        messageId: message.messageId,
        deletedFor: 'everyone',
      });
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

    // فلترة الرسائل المحذوفة
    messages = messages.filter(msg => !msg.isDeletedFor(currentUserId));

    const formattedMessages = messages.map(msg => ({
      messageId: msg.messageId,
      senderId: msg.senderId,
      recipientId: msg.recipientId,
      encryptedType: msg.encryptedType,
      encryptedBody: msg.encryptedBody,
      status: msg.status,
      deletedForEveryone: msg.deletedForEveryone,
      deletedForRecipient: msg.deletedForRecipient || false, // ✅
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