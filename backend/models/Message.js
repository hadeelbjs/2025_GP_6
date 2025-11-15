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
  
  // ✅ الصور والملفات كـ Base64
  attachmentData: {
    type: String, // Base64 encoded
    default: null,
  },
  
  attachmentType: {
    type: String, // 'image' or 'file'
    enum: ['image', 'file', null],
    default: null,
  },
  
  attachmentName: {
    type: String, // اسم الملف الأصلي
    default: null,
  },
  
  attachmentMimeType: {
    type: String,
    default: null,
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

failedVerificationAtRecipient: {
  type: Boolean,
  default: false,
},

failedVerification: {
  type: Boolean,
  default: false,
},

visibilityDuration: {
  type: Number,
  required: false,
  min: 1,           
 
},
  
  expiresAt: {
    type: Date,
    required: false, 
    index: true, 
  },
  
  isExpired: {
    type: Boolean,
    default: false,
    index: true,
  }

});


MessageSchema.index({ expiresAt: 1, isExpired: 1 });



// دالة التحقق من الحذف
MessageSchema.methods.canDeleteForEveryone = function(userId) {
  if (this.senderId.toString() !== userId.toString()) {
    return false;
  }
  return true;
};

// دالة التحقق من أن الرسالة محذوفة للمستخدم
MessageSchema.methods.isDeletedFor = function(userId) {
  if (this.deletedForEveryone) return true;
  return this.deletedFor.some(id => id.toString() === userId.toString());
};

module.exports = mongoose.model('Message', MessageSchema);