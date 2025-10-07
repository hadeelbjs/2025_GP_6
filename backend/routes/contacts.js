const express = require('express');
const router = express.Router();
const { body, param, validationResult } = require('express-validator');
const Contact = require('../models/Contact');
const User = require('../models/User');
const auth = require('../middleware/auth');

// ==================================================
// API 1: البحث عن مستخدم بـ username أو phone
// ==================================================
router.post('/search',
  auth, // تحقق من تسجيل الدخول أولاً
  [
    // التحقق من صحة المدخلات
    body('searchQuery')
      .trim()
      .notEmpty().withMessage('يجب إدخال اسم المستخدم أو رقم الجوال')
      .isLength({ min: 3 }).withMessage('يجب إدخال 3 أحرف على الأقل')
  ],
  async (req, res) => {
    try {
      // فحص الأخطاء
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          message: errors.array()[0].msg 
        });
      }

      const { searchQuery } = req.body;
      const currentUserId = req.user.id; // من الـ auth middleware

      // معالجة رقم الجوال (السعودي)
      let phoneVariations = [];
      if (/^\d+$/.test(searchQuery)) { // إذا كان رقماً
        const cleanPhone = searchQuery.replace(/^\+?966/, ''); // إزالة الكود
        phoneVariations = [
          searchQuery,           // كما هو
          cleanPhone,            // بدون كود
          `+966${cleanPhone}`,   // مع +966
          `966${cleanPhone}`     // مع 966 بدون +
        ];
      }

      // بناء شروط البحث
      const searchConditions = [
        { username: searchQuery.toLowerCase() } // البحث باسم المستخدم
      ];

      // إضافة شروط البحث بالجوال
      phoneVariations.forEach(phone => {
        searchConditions.push({ phone });
      });

      // البحث في قاعدة البيانات
      const foundUsers = await User.find({
        $or: searchConditions,          // أي شرط من الشروط
        _id: { $ne: currentUserId }     // استثني نفسي
      })
      .select('fullName username phone') // فقط هذه الحقول
      .limit(10);                        // 10 نتائج كحد أقصى

      // إذا لم يتم العثور على أحد
      if (foundUsers.length === 0) {
        return res.status(404).json({ 
          success: false, 
          message: 'لم يتم العثور على أي مستخدم' 
        });
      }

      // التحقق من حالة كل مستخدم (هل هو صديق بالفعل؟)
      const usersWithStatus = await Promise.all(
        foundUsers.map(async (user) => {
          const existingContact = await Contact.findOne({
            $or: [
              { requester: currentUserId, recipient: user._id },
              { requester: user._id, recipient: currentUserId }
            ]
          });

          return {
            id: user._id,
            fullName: user.fullName,
            username: user.username,
            isContact: existingContact?.status === 'accepted',
            contactStatus: existingContact?.status || null
          };
        })
      );

      // إرجاع النتائج
      res.json({
        success: true,
        users: usersWithStatus
      });

    } catch (error) {
      console.error('خطأ في البحث:', error);
      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء البحث' 
      });
    }
  }
);

// ==================================================
// API 2: إضافة جهة اتصال
// ==================================================
router.post('/add',
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
          message: 'لا يمكنك إضافة نفسك كصديق' 
        });
      }

      // التحقق من وجود المستخدم المستهدف
      const targetUser = await User.findById(userId);
      if (!targetUser) {
        return res.status(404).json({ 
          success: false, 
          message: 'المستخدم المطلوب غير موجود' 
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
        if (existingContact.status === 'accepted') {
          return res.status(400).json({ 
            success: false, 
            message: 'هذا المستخدم موجود في جهات اتصالك بالفعل' 
          });
        }
        return res.status(400).json({ 
          success: false, 
          message: 'يوجد طلب معلق مع هذا المستخدم' 
        });
      }

      // إنشاء العلاقة الجديدة
      const newContact = new Contact({
        requester: currentUserId,
        recipient: userId,
        status: 'accepted'
      });

      await newContact.save(); // حفظ في قاعدة البيانات

      res.json({
        success: true,
        message: `تمت إضافة ${targetUser.fullName} بنجاح`,
        contact: {
          id: targetUser._id,
          fullName: targetUser.fullName,
          username: targetUser.username
        }
      });

    } catch (error) {
      console.error('خطأ في إضافة جهة اتصال:', error);
      
      if (error.code === 11000) { // خطأ التكرار
        return res.status(400).json({ 
          success: false, 
          message: 'جهة الاتصال موجودة بالفعل' 
        });
      }

      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء إضافة جهة الاتصال' 
      });
    }
  }
);

// ==================================================
// API 3: عرض قائمة جهات الاتصال
// ==================================================
router.get('/list', auth, async (req, res) => {
  try {
    const currentUserId = req.user.id;

    // جلب جميع العلاقات المقبولة
    const contacts = await Contact.find({
      $or: [
        { requester: currentUserId, status: 'accepted' },
        { recipient: currentUserId, status: 'accepted' }
      ]
    })
    .populate('requester', 'fullName username')  // جلب بيانات المستخدم
    .populate('recipient', 'fullName username')
    .sort({ createdAt: -1 });                   // الأحدث أولاً

    // تحويل البيانات لصيغة مناسبة للفرونت إند
    const contactsList = contacts.map(contact => {
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
      contacts: contactsList,
      count: contactsList.length
    });

  } catch (error) {
    console.error('خطأ في جلب جهات الاتصال:', error);
    res.status(500).json({ 
      success: false, 
      message: 'حدث خطأ أثناء جلب قائمة جهات الاتصال' 
    });
  }
});

// ==================================================
// API 4: حذف جهة اتصال
// ==================================================
router.delete('/:contactId',
  auth,
  [
    param('contactId')
      .isMongoId().withMessage('معرف جهة الاتصال غير صحيح')
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

      // معرفة اسم الصديق المحذوف
      const deletedFriend = contact.requester._id.toString() === currentUserId 
        ? contact.recipient 
        : contact.requester;

      // الحذف من قاعدة البيانات
      await Contact.deleteOne({ _id: contact._id });

      res.json({
        success: true,
        message: `تم حذف ${deletedFriend.fullName} من جهات الاتصال`
      });

    } catch (error) {
      console.error('خطأ في حذف جهة اتصال:', error);
      res.status(500).json({ 
        success: false, 
        message: 'حدث خطأ أثناء حذف جهة الاتصال' 
      });
    }
  }
);

module.exports = router;