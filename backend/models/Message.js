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
    enum: ['sent', 'delivered', 'verified', 'deleted'],
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
  
  // حذف للجميع
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
  
  deliveredAt: {
    type: Date,
    default: null,
  },
});

// Index للبحث السريع
MessageSchema.index({ senderId: 1, recipientId: 1, createdAt: -1 });

MessageSchema.index(
  { createdAt: 1 },
  { 
    expireAfterSeconds: 172800, // 48 hours
    partialFilterExpression: { 
      status: { $in: ['delivered', 'verified'] } 
    }
  }
);

// دالة للتحقق من إمكانية حذف الرسالة للجميع (خلال 48 ساعة)
MessageSchema.methods.canDeleteForEveryone = function(userId) {
  if (this.senderId.toString() !== userId.toString()) {
    return false;
  }
  
  const hoursSinceCreation = (Date.now() - this.createdAt) / (1000 * 60 * 60);
  return hoursSinceCreation <= 48;
};

// دالة للتحقق من أن الرسالة محذوفة للمستخدم
MessageSchema.methods.isDeletedFor = function(userId) {
  if (this.deletedForEveryone) return true;
  return this.deletedFor.some(del => del.userId.toString() === userId.toString());
};

module.exports = mongoose.model('Message', MessageSchema);