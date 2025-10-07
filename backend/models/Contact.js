const mongoose = require('mongoose');

// تعريف شكل البيانات في MongoDB
const ContactSchema = new mongoose.Schema({
  // المستخدم الذي أضاف جهة الاتصال
  requester: {
    type: mongoose.Schema.Types.ObjectId, // معرف المستخدم
    ref: 'User', // ربط مع User Model
    required: true
  },
  
  // المستخدم المُضاف كصديق
  recipient: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // حالة العلاقة
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected'], // القيم المسموحة
    default: 'accepted' // الافتراضية: مقبول مباشرة
  },
  
  // تاريخ الإضافة
  createdAt: {
    type: Date,
    default: Date.now
  }
});

// منع إضافة نفس الشخص مرتين (فهرس فريد)
ContactSchema.index({ requester: 1, recipient: 1 }, { unique: true });

// تصدير الـ Model
module.exports = mongoose.model('Contact', ContactSchema);