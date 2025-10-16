// routes/messages.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Message = require('../models/Message');



// ============================================
// حذف رسالة من عند المستقبل فقط
// ============================================
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

    // فقط المرسل يقدر يحذف من عند المستقبل
    if (message.senderId.toString() !== currentUserId) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية'
      });
    }

    // التحقق من أنها ما انحذفت قبل للجميع
    if (message.deletedForEveryone) {
      return res.status(400).json({
        success: false,
        message: 'الرسالة محذوفة للجميع'
      });
    }

    // إضافة المستقبل لقائمة المحذوفين
    const recipientId = message.recipientId.toString();
    
    const alreadyDeleted = message.deletedFor.some(
      del => del.userId.toString() === recipientId
    );

    if (alreadyDeleted) {
      return res.status(400).json({
        success: false,
        message: 'الرسالة محذوفة مسبقاً من عند المستقبل'
      });
    }

    message.deletedFor.push({
      userId: message.recipientId,
      deletedAt: new Date()
    });

    await message.save();

    // إرسال إشعار للمستقبل عبر Socket.IO
    const io = req.app.get('io');
    if (io) {
      io.sendToUser(recipientId, 'message:deleted', {
        messageId: message.messageId,
        deletedBy: currentUserId,
        deletedFor: 'recipient',
        timestamp: Date.now(),
      });
    }

    res.json({
      success: true,
      message: 'تم حذف الرسالة من عند المستقبل',
      messageId: message.messageId,
    });

  } catch (err) {
    console.error('Delete for recipient error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في حذف الرسالة',
    });
  }
});

// ============================================
// حذف رسالة للجميع (المرسل والمستقبل)
// ============================================
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

    // فقط المرسل يقدر يحذف للجميع
    if (message.senderId.toString() !== currentUserId) {
      return res.status(403).json({
        success: false,
        message: 'فقط المرسل يمكنه الحذف للجميع'
      });
    }

    // التحقق من الوقت المسموح (48 ساعة)
    if (!message.canDeleteForEveryone(currentUserId)) {
      return res.status(400).json({
        success: false,
        message: 'انتهت مدة الحذف (48 ساعة)'
      });
    }

    // التحقق من أنها ما انحذفت قبل
    if (message.deletedForEveryone) {
      return res.status(400).json({
        success: false,
        message: 'الرسالة محذوفة مسبقاً'
      });
    }

    // تحديث حالة الرسالة
    message.deletedForEveryone = true;
    message.deletedForEveryoneAt = new Date();
    message.deletedForEveryoneBy = currentUserId;
    message.status = 'deleted';

    await message.save();

    // إرسال إشعار للطرفين عبر Socket.IO
    const io = req.app.get('io');
    if (io) {
      const recipientId = message.recipientId.toString();
      
      // للمستقبل
      io.sendToUser(recipientId, 'message:deleted', {
        messageId: message.messageId,
        deletedBy: currentUserId,
        deletedFor: 'everyone',
        timestamp: Date.now(),
      });

      // للمرسل (نفسه) على الأجهزة الأخرى
      io.sendToUser(currentUserId, 'message:deleted', {
        messageId: message.messageId,
        deletedBy: currentUserId,
        deletedFor: 'everyone',
        timestamp: Date.now(),
      });
    }

    res.json({
      success: true,
      message: 'تم حذف الرسالة للجميع',
      messageId: message.messageId,
    });

  } catch (err) {
    console.error('Delete for everyone error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في حذف الرسالة',
    });
  }
});

// ============================================
// جلب المحادثة مع مستخدم
// ============================================
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

    // فلترة الرسائل المحذوفة للمستخدم الحالي
    messages = messages.filter(msg => !msg.isDeletedFor(currentUserId));

    const formattedMessages = messages.map(msg => ({
      messageId: msg.messageId,
      senderId: msg.senderId,
      recipientId: msg.recipientId,
      encryptedType: msg.encryptedType,
      encryptedBody: msg.encryptedBody,
      status: msg.status,
      deletedForEveryone: msg.deletedForEveryone,
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