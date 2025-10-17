// backend/models/Message.js
const mongoose = require('mongoose');

const MessageSchema = new mongoose.Schema({
  messageId: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  
  recipientId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  
  encryptedType: {
    type: Number,
    required: true,
  },
  
  encryptedBody: {
    type: String,
    required: true,
  },
  
  status: {
    type: String,
    enum: ['sent', 'delivered', 'verified', 'deleted'],
    default: 'sent',
  },
  
  // ✅ حذف من عند مستخدمين محددين
  deletedFor: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  
  // ✅ حذف من عند المستقبل فقط
  deletedForRecipient: {
    type: Boolean,
    default: false,
  },
  
  // ✅ حذف للجميع
  deletedForEveryone: {
    type: Boolean,
    default: false,
  },
  
  deletedForEveryoneAt: Date,
  
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
  
  deliveredAt: Date,
});

// Index للبحث السريع
MessageSchema.index({ senderId: 1, recipientId: 1, createdAt: -1 });

// ✅ حذف الرسائل المحذوفة للجميع بعد 7 أيام (للتنظيف التلقائي)
MessageSchema.index(
  { deletedForEveryoneAt: 1 },
  { 
    expireAfterSeconds: 604800, // 7 days
    partialFilterExpression: { 
      deletedForEveryone: true,
      deletedForEveryoneAt: { $exists: true }
    }
  }
);

// ✅ دالة التحقق من الحذف (بدون قيد زمني)
MessageSchema.methods.canDeleteForEveryone = function(userId) {
  // فقط المرسل يقدر يحذف
  if (this.senderId.toString() !== userId.toString()) {
    return false;
  }
  
  // ✅ بدون قيد زمني - يقدر يحذف متى ما بغى
  return true;
};

// دالة التحقق من أن الرسالة محذوفة للمستخدم
MessageSchema.methods.isDeletedFor = function(userId) {
  if (this.deletedForEveryone) return true;
  return this.deletedFor.some(id => id.toString() === userId.toString());
};

module.exports = mongoose.model('Message', MessageSchema);