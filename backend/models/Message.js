// models/Message.js
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
  
  // البيانات المشفرة
  encryptedType: {
    type: Number,
    required: true,
  },
  
  encryptedBody: {
    type: String,
    required: true,
  },
  
  // حالة الرسالة
  status: {
    type: String,
    enum: ['sent', 'delivered', 'read', 'deleted'],
    default: 'sent',
  },
  
  // قائمة المستخدمين اللي محذوفة عندهم الرسالة
  deletedFor: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    deletedAt: {
      type: Date,
      default: Date.now
    }
  }],
  
  // حذف للجميع (المرسل والمستقبل)
  deletedForEveryone: {
    type: Boolean,
    default: false,
  },
  
  deletedForEveryoneAt: {
    type: Date,
    default: null,
  },
  
  deletedForEveryoneBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
});

// Index للبحث السريع
MessageSchema.index({ senderId: 1, recipientId: 1, createdAt: -1 });

// دالة للتحقق من إمكانية حذف الرسالة للجميع (خلال 48 ساعة)
MessageSchema.methods.canDeleteForEveryone = function(userId) {
  // فقط المرسل يقدر يحذف للجميع
  if (this.senderId.toString() !== userId.toString()) {
    return false;
  }
  
  // خلال 48 ساعة فقط
  const hoursSinceCreation = (Date.now() - this.createdAt) / (1000 * 60 * 60);
  return hoursSinceCreation <= 48;
};

// دالة للتحقق من أن الرسالة محذوفة للمستخدم
MessageSchema.methods.isDeletedFor = function(userId) {
  if (this.deletedForEveryone) return true;
  return this.deletedFor.some(del => del.userId.toString() === userId.toString());
};

module.exports = mongoose.model('Message', MessageSchema);