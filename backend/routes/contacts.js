const express = require('express');
const router = express.Router();
const { body, param, validationResult } = require('express-validator');
const Contact = require('../models/Contact');
const User = require('../models/User');
const auth = require('../middleware/auth');

// البحث عن مستخدم

router.post('/search',
  auth,
  [
    body('searchQuery')
      .trim()
      .notEmpty().withMessage('يجب إدخال اسم المستخدم أو رقم الجوال')
      .isLength({ min: 3 }).withMessage('يجب إدخال 3 أحرف على الأقل')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          message: errors.array()[0].msg 
        });
      }

      const { searchQuery } = req.body;
      const currentUserId = req.user.id;

      // معالجة رقم الجوال - إزالة الرموز والمسافات
      const cleanedQuery = searchQuery.replace(/[+\s-]/g, '');
      
      let phoneVariations = [];
      
      // التحقق إذا كان المدخل رقم
      if (/^\d+$/.test(cleanedQuery)) {
        let baseNumber = cleanedQuery;
        
        // إزالة 966 من البداية إذا موجودة
        if (baseNumber.startsWith('966')) {
          baseNumber = baseNumber.substring(3);
        }
        
        // إزالة 0 من البداية إذا موجودة
        if (baseNumber.startsWith('0')) {
          baseNumber = baseNumber.substring(1);
        }
        
        // إنشاء جميع احتمالات الرقم
        phoneVariations = [
          baseNumber,                    // 5xxxxxxxx
          `0${baseNumber}`,              // 05xxxxxxxx
          `966${baseNumber}`,            // 9665xxxxxxxx
          `+966${baseNumber}`,           // +9665xxxxxxxx
        ];
      }

      // بناء شروط البحث
      const searchConditions = [];
      
      // البحث بالـ username
      searchConditions.push({ username: searchQuery.toLowerCase() });
      
      // البحث بجميع صيغ الجوال
      phoneVariations.forEach(phone => {
        searchConditions.push({ phone: phone });
      });

      // البحث (استثني نفسي)
      const foundUsers = await User.find({
        $or: searchConditions,
        _id: { $ne: currentUserId }
      })
      .select('fullName username')
      .limit(10);

      if (foundUsers.length === 0) {
        return res.status(404).json({ 
          success: false, 
          message: 'لم يتم العثور على أي مستخدم' 
        });
      }

      // فحص حالة العلاقة مع كل مستخدم
      const usersWithStatus = await Promise.all(
        foundUsers.map(async (user) => {
          const relationship = await Contact.getRelationship(currentUserId, user._id.toString());

          return {
            id: user._id,
            fullName: user.fullName,
            username: user.username,
            relationshipStatus: relationship.exists ? relationship.status : null,
            isSentByMe: relationship.exists ? relationship.iAmRequester : null
          };
        })
      );

      res.json({
        success: true,
        users: usersWithStatus
      });

    } catch (error) {
      console.error('❌ خطأ في البحث:', error.message);
      console.error('Stack:', error.stack);
      console.error('Path:', req.path);
      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء البحث' 
      });
    }
  }
);

// إرسال طلب صداقة
router.post('/send-request',
  auth,
  [
    body('userId')
      .notEmpty().withMessage('معرف المستخدم مطلوب')
      .isMongoId().withMessage('معرف المستخدم غير صحيح')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          message: errors.array()[0].msg 
        });
      }

      const { userId } = req.body;
      const currentUserId = req.user.id;

      // لا يمكن إضافة نفسك
      if (userId === currentUserId) {
        return res.status(400).json({ 
          success: false, 
          message: 'لا يمكنك إضافة نفسك' 
        });
      }

      // التحقق من وجود المستخدم
      const targetUser = await User.findById(userId);
      if (!targetUser) {
        return res.status(404).json({ 
          success: false, 
          message: 'المستخدم غير موجود' 
        });
      }

      // التحقق من عدم وجود علاقة سابقة
      const existingContact = await Contact.findOne({
        $or: [
          { requester: currentUserId, recipient: userId },
          { requester: userId, recipient: currentUserId }
        ]
      });

      if (existingContact) {
        let message = '';
        if (existingContact.status === 'accepted') {
          message = 'هذا المستخدم موجود في جهات اتصالك بالفعل';
        } else if (existingContact.status === 'pending') {
          message = 'يوجد طلب صداقة معلق بالفعل';
        } else if (existingContact.status === 'rejected') {
          message = 'تم رفض طلب الصداقة سابقاً';
        }
        return res.status(400).json({ 
          success: false, 
          message 
        });
      }

      // إنشاء طلب الصداقة
      const newContact = new Contact({
        requester: currentUserId,
        recipient: userId,
        status: 'pending'
      });

      await newContact.save();

      res.json({
        success: true,
        message: `تم إرسال طلب الصداقة إلى ${targetUser.fullName}`,
        contact: {
          id: targetUser._id,
          fullName: targetUser.fullName,
          username: targetUser.username,
          status: 'pending'
        }
      });

    } catch (error) {
      console.error('❌ خطأ في إرسال الطلب:', error.message);
      console.error('Stack:', error.stack);
      
      if (error.code === 11000) {
        return res.status(400).json({ 
          success: false, 
          message: 'يوجد طلب معلق بالفعل' 
        });
      }

      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء إرسال الطلب' 
      });
    }
  }
);

// عرض طلبات الصداقة الواردة (pending)
router.get('/pending-requests', auth, async (req, res) => {
  try {
    const currentUserId = req.user.id;

    // جلب الطلبات المعلقة الموجهة لي
    const pendingRequests = await Contact.find({
      recipient: currentUserId,
      status: 'pending'
    })
    .populate('requester', 'fullName username')
    .sort({ createdAt: -1 });

    //  فلترة الطلبات - استبعاد الطلبات من مستخدمين محذوفين
    const validRequests = pendingRequests.filter(req => req.requester !== null);

    //  حذف الطلبات من مستخدمين محذوفين
    const invalidRequests = pendingRequests.filter(req => req.requester === null);
    if (invalidRequests.length > 0) {
      const invalidIds = invalidRequests.map(req => req._id);
      await Contact.deleteMany({ _id: { $in: invalidIds } });
      console.log(`🧹 تم حذف ${invalidIds.length} طلبات من مستخدمين محذوفين`);
    }

    const requests = validRequests.map(req => ({
      requestId: req._id,
      user: {
        id: req.requester._id,
        fullName: req.requester.fullName,
        username: req.requester.username
      },
      createdAt: req.createdAt
    }));

    res.json({
      success: true,
      requests,
      count: requests.length
    });

  } catch (error) {
    console.error('❌ خطأ في جلب الطلبات:', error.message);
    console.error('Stack:', error.stack);
    console.error('User ID:', req.user?.id);
    res.status(500).json({ 
      success: false, 
      message: 'حدث خطأ أثناء جلب الطلبات' 
    });
  }
});

// قبول طلب صداقة
router.post('/accept-request/:requestId',
  auth,
  [
    param('requestId').isMongoId().withMessage('معرف الطلب غير صحيح')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          message: errors.array()[0].msg 
        });
      }

      const { requestId } = req.params;
      const currentUserId = req.user.id;

      // البحث عن الطلب
      const contact = await Contact.findOne({
        _id: requestId,
        recipient: currentUserId,
        status: 'pending'
      }).populate('requester', 'fullName');

      if (!contact) {
        return res.status(404).json({ 
          success: false, 
          message: 'الطلب غير موجود أو تم الرد عليه مسبقاً' 
        });
      }

      // قبول الطلب
      contact.status = 'accepted';
      await contact.save();

      res.json({
        success: true,
        message: `تم قبول طلب الصداقة من ${contact.requester.fullName}`
      });

    } catch (error) {
      console.error('❌ خطأ في قبول الطلب:', error.message);
      console.error('Stack:', error.stack);
      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء قبول الطلب' 
      });
    }
  }
);

// رفض طلب صداقة
router.post('/reject-request/:requestId',
  auth,
  [
    param('requestId').isMongoId().withMessage('معرف الطلب غير صحيح')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          message: errors.array()[0].msg 
        });
      }

      const { requestId } = req.params;
      const currentUserId = req.user.id;

      const contact = await Contact.findOne({
        _id: requestId,
        recipient: currentUserId,
        status: 'pending'
      }).populate('requester', 'fullName');

      if (!contact) {
        return res.status(404).json({ 
          success: false, 
          message: 'الطلب غير موجود' 
        });
      }

      // رفض الطلب (أو حذفه)
      await Contact.deleteOne({ _id: contact._id });

      res.json({
        success: true,
        message: `تم رفض طلب الصداقة من ${contact.requester.fullName}`
      });

    } catch (error) {
      console.error('❌ خطأ في رفض الطلب:', error.message);
      console.error('Stack:', error.stack);
      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء رفض الطلب' 
      });
    }
  }
);

//  عرض قائمة الأصدقاء (accepted فقط)
router.get('/list', auth, async (req, res) => {
  try {
    const currentUserId = req.user.id;

    const contacts = await Contact.find({
      $or: [
        { requester: currentUserId, status: 'accepted' },
        { recipient: currentUserId, status: 'accepted' }
      ]
    })
      .populate('requester', 'fullName username')
      .populate('recipient', 'fullName username')
      .sort({ createdAt: -1 });

    const friendsList = contacts
      // نتأكد أن الصديق ما هو null قبل نكمل
      .filter(contact => contact.requester && contact.recipient)
      .map(contact => {
        const isRequester = contact.requester._id.toString() === currentUserId;
        const friend = isRequester ? contact.recipient : contact.requester;

        return {
          id: friend._id,
          name: friend.fullName,
          username: friend.username,
          addedAt: contact.createdAt
        };
      });

    res.json({
      success: true,
      contacts: friendsList,
      count: friendsList.length
    });

  } catch (error) {
    console.error('❌ خطأ في جلب الأصدقاء:', error.message);
    console.error('Stack:', error.stack);
    console.error('User ID:', req.user?.id);
    res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء جلب القائمة'
    });
  }
});

// حذف صديق
router.delete('/:contactId',
  auth,
  [
    param('contactId').isMongoId().withMessage('معرف جهة الاتصال غير صحيح')
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          message: errors.array()[0].msg 
        });
      }

      const { contactId } = req.params;
      const currentUserId = req.user.id;

      // البحث عن العلاقة
      const contact = await Contact.findOne({
        $or: [
          { requester: currentUserId, recipient: contactId },
          { requester: contactId, recipient: currentUserId }
        ]
      }).populate('requester recipient', 'fullName');

      if (!contact) {
        return res.status(404).json({ 
          success: false, 
          message: 'جهة الاتصال غير موجودة' 
        });
      }

      const deletedFriend = contact.requester._id.toString() === currentUserId 
        ? contact.recipient 
        : contact.requester;

      // الحذف
      await Contact.deleteOne({ _id: contact._id });

      res.json({
        success: true,
        message: `تم حذف ${deletedFriend.fullName} من جهات الاتصال`
      });

    } catch (error) {
      console.error('❌ خطأ في الحذف:', error.message);
      console.error('Stack:', error.stack);
      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء الحذف' 
      });
    }
  }
);

// جلب سياسة لقطات الشاشة
router.get('/:peerUserId/screenshots', auth, async (req, res) => {
  try {
    const currentUserId = req.user.id;
    const { peerUserId } = req.params;

    console.log('📥 GET /screenshots request');
    console.log('   Current User:', currentUserId);
    console.log('   Peer User:', peerUserId);

    const contact = await Contact.findOne({
      $or: [
        { requester: currentUserId, recipient: peerUserId },
        { requester: peerUserId, recipient: currentUserId }
      ],
      status: 'accepted'
    });

    if (!contact) {
      return res.status(404).json({ 
        success: false, 
        message: 'العلاقة غير موجودة',
        myPolicy: false,
        peerPolicy: false
      });
    }

    //  تحديد السياسات بناءً على من هو requester ومن هو recipient
    const iAmRequester = contact.requester.toString() === currentUserId;
    
    // سياستي أنا (هل أسمح للطرف الآخر بالتقاط شاشتي)
    const myPolicy = iAmRequester 
      ? contact.requesterAllowsScreenshots 
      : contact.recipientAllowsScreenshots;
    
    // سياسة الطرف الآخر (هل يسمح لي بالتقاط شاشته)
    const peerPolicy = iAmRequester 
      ? contact.recipientAllowsScreenshots 
      : contact.requesterAllowsScreenshots;

    console.log(' Policies:');
    console.log('   My policy (I allow peer):', myPolicy);
    console.log('   Peer policy (peer allows me):', peerPolicy);

    res.json({
      success: true,
      myPolicy: myPolicy || false,      // أنا أسمح للطرف الآخر؟
      peerPolicy: peerPolicy || false,  // الطرف الآخر يسمح لي؟
      allowScreenshots: peerPolicy || false
    });

  } catch (err) {
    console.error('❌ Get screenshot policy error:', err);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في جلب السياسة',
      myPolicy: false,
      peerPolicy: false
    });
  }
});


// تحديث سياسة لقطات الشاشة
router.put('/:peerUserId/screenshots', auth, async (req, res) => {
  try {
    const { allowScreenshots } = req.body;
    const currentUserId = req.user.id;
    const { peerUserId } = req.params;

    console.log('📝 PUT /screenshots request');
    console.log('   Current User:', currentUserId);
    console.log('   Peer User:', peerUserId);
    console.log('   Allow:', allowScreenshots);

    if (typeof allowScreenshots !== 'boolean') {
      return res.status(400).json({ 
        success: false, 
        message: 'قيمة allowScreenshots يجب أن تكون true أو false' 
      });
    }

    const contact = await Contact.findOne({
      $or: [
        { requester: currentUserId, recipient: peerUserId },
        { requester: peerUserId, recipient: currentUserId }
      ],
      status: 'accepted'
    });

    if (!contact) {
      return res.status(404).json({ 
        success: false, 
        message: 'العلاقة غير موجودة' 
      });
    }

    //  تحديث سياستي فقط (لا أستطيع تغيير سياسة الطرف الآخر)
    const iAmRequester = contact.requester.toString() === currentUserId;
    
    if (iAmRequester) {
      contact.requesterAllowsScreenshots = allowScreenshots;
    } else {
      contact.recipientAllowsScreenshots = allowScreenshots;
    }
    
    await contact.save();

    console.log(' Policy updated:', iAmRequester ? 'requester' : 'recipient', '=', allowScreenshots);

    //  إرسال إشعار Socket للطرف الآخر
    try {
      const io = req.app.get('io');
      if (io && io.sendToUser) {
        const sent = io.sendToUser(peerUserId, 'privacy:screenshots:changed', {
          peerUserId: currentUserId,
          allowScreenshots: allowScreenshots,
          message: allowScreenshots 
            ? 'الطرف الآخر سمح لك بلقطات الشاشة'
            : 'الطرف الآخر منع لقطات الشاشة'
        });
        console.log(sent ? ' Socket notification sent' : '⚠️ User offline');
      }
    } catch (socketErr) {
      console.error('❌ Socket notification failed:', socketErr);
    }

    res.json({
      success: true,
      message: allowScreenshots
        ? 'تم السماح للطرف الآخر بلقطات الشاشة'
        : 'تم منع الطرف الآخر من لقطات الشاشة',
      myPolicy: allowScreenshots
    });

  } catch (err) {
    console.error('❌ Privacy update error:', err);
    res.status(500).json({ 
      success: false, 
      message: 'خطأ في تحديث السياسة' 
    });
  }
});

module.exports = router;