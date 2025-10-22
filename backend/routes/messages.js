// backend/routes/messages.js
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const Message = require('../models/Message');

// ✅ إرسال رسالة (API Fallback)
// في الحالة الطبيعية، الرسائل تُرسل عبر Socket مباشرة
// لكن هذا endpoint موجود كـ fallback أو للاختبار
router.post('/send', auth, async (req, res) => {
  try {
    const { 
      recipientId, 
      encryptedType, 
      encryptedBody,
      attachmentData,
      attachmentType,
      attachmentName,
      attachmentMimeType,
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
      status: 'sent',
    });

    await message.save();

    // ✅ إرسال عبر Socket
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
        createdAt: message.createdAt.toISOString(),
      });

      console.log(`${sent ? '✅' : '📭'} Message sent to recipient: ${recipientId}`);
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

// ✅ جلب المحادثة
router.get('/conversation/:userId', auth, async (req, res) => {
  try {
    const { userId: peerId } = req.params;
    const currentUserId = req.user.id;
    const { limit = 100, before } = req.query;

    const query = {
      $or: [
        { senderId: currentUserId, recipientId: peerId },
        { senderId: peerId, recipientId: currentUserId },
      ],
    };

    // إضافة pagination إذا كان مطلوب
    if (before) {
      query.createdAt = { $lt: new Date(before) };
    }

    let messages = await Message.find(query)
      .sort({ createdAt: -1 })
      .limit(parseInt(limit));

    // عكس الترتيب ليكون من الأقدم للأحدث
    messages = messages.reverse();

    // ✅ فلترة الرسائل المحذوفة
    const filteredMessages = messages.filter(msg => !msg.isDeletedFor(currentUserId));

    const formattedMessages = filteredMessages.map(msg => ({
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
      deliveredAt: msg.deliveredAt,
      readAt: msg.readAt,
    }));

    res.json({
      success: true,
      messages: formattedMessages,
      hasMore: filteredMessages.length === parseInt(limit),
    });

  } catch (err) {
    console.error('Get conversation error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب المحادثة',
    });
  }
});

// ✅ حذف رسالة - API Endpoint (يُفضل استخدام Socket)
router.delete('/delete/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { deleteFor } = req.body; // 'everyone' or 'recipient'
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

    const io = req.app.get('io');
    const recipientId = message.recipientId.toString();

    if (deleteFor === 'everyone') {
      // ✅ حذف للجميع
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

      // ✅ إرسال Socket للمستقبل
      if (io && io.sendToUser) {
        io.sendToUser(recipientId, 'message:deleted', {
          messageId: message.messageId,
          deletedFor: 'everyone',
        });

        // تأكيد للمرسل أيضاً
        io.sendToUser(currentUserId, 'message:deleted', {
          messageId: message.messageId,
          deletedFor: 'everyone',
        });
      }

      return res.json({
        success: true,
        message: 'تم الحذف للجميع',
      });

    } else if (deleteFor === 'recipient') {
      // ✅ حذف من عند المستقبل فقط
      if (!message.deletedFor.some(id => id.toString() === recipientId)) {
        message.deletedFor.push(message.recipientId);
        message.deletedForRecipient = true;
        await message.save();
      }

      // ✅ إرسال Socket للمستقبل
      if (io && io.sendToUser) {
        io.sendToUser(recipientId, 'message:deleted', {
          messageId: message.messageId,
          deletedFor: 'recipient',
        });
      }

      return res.json({
        success: true,
        message: 'تم الحذف من عند المستقبل',
      });
    }

    res.status(400).json({
      success: false,
      message: 'نوع الحذف غير صالح',
    });

  } catch (err) {
    console.error('Delete message error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في الحذف',
    });
  }
});

// ✅ تحديث حالة الرسالة (delivered/read)
router.patch('/status/:messageId', auth, async (req, res) => {
  try {
    const { messageId } = req.params;
    const { status } = req.body; // 'delivered', 'verified', 'read'

    const message = await Message.findOneAndUpdate(
      { messageId },
      { 
        status,
        ...(status === 'delivered' && { deliveredAt: new Date() }),
        ...(status === 'verified' && { readAt: new Date() }),
        ...(status === 'read' && { readAt: new Date() }),
      },
      { new: true }
    );

    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'الرسالة غير موجودة',
      });
    }

    // ✅ إرسال Socket للطرف الآخر
    const io = req.app.get('io');
    if (io && io.sendToUser) {
      const otherUserId = message.senderId.toString() === req.user.id 
        ? message.recipientId.toString()
        : message.senderId.toString();

      io.sendToUser(otherUserId, 'message:status_update', {
        messageId,
        status,
      });
    }

    res.json({
      success: true,
      message: 'تم تحديث الحالة',
    });

  } catch (err) {
    console.error('Update status error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في تحديث الحالة',
    });
  }
});

// ✅ حذف المحادثة كاملة
router.delete('/conversation/:userId', auth, async (req, res) => {
  try {
    const { userId: peerId } = req.params;
    const currentUserId = req.user.id;

    // حذف جميع الرسائل في المحادثة
    await Message.updateMany(
      {
        $or: [
          { senderId: currentUserId, recipientId: peerId },
          { senderId: peerId, recipientId: currentUserId },
        ],
      },
      {
        $addToSet: { deletedFor: currentUserId },
      }
    );

    res.json({
      success: true,
      message: 'تم حذف المحادثة',
    });

  } catch (err) {
    console.error('Delete conversation error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في حذف المحادثة',
    });
  }
});

// ✅ إحصائيات المحادثات
router.get('/stats', auth, async (req, res) => {
  try {
    const userId = req.user.id;

    const unreadCount = await Message.countDocuments({
      recipientId: userId,
      status: { $in: ['sent', 'delivered'] },
      deletedFor: { $ne: userId },
      deletedForEveryone: false,
    });

    const totalConversations = await Message.aggregate([
      {
        $match: {
          $or: [
            { senderId: userId },
            { recipientId: userId },
          ],
          deletedFor: { $ne: userId },
          deletedForEveryone: false,
        },
      },
      {
        $group: {
          _id: {
            $cond: [
              { $eq: ['$senderId', userId] },
              '$recipientId',
              '$senderId',
            ],
          },
        },
      },
      {
        $count: 'total',
      },
    ]);

    res.json({
      success: true,
      stats: {
        unreadMessages: unreadCount,
        totalConversations: totalConversations[0]?.total || 0,
      },
    });

  } catch (err) {
    console.error('Get stats error:', err);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ في جلب الإحصائيات',
    });
  }
});

module.exports = router;