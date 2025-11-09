const mongoose = require('mongoose');

const ContactSchema = new mongoose.Schema({
  // من أرسل الطلب
  requester: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // من استقبل الطلب
  recipient: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  // حالة الطلب
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected'],
    default: 'pending'
  },
  
  // تاريخ الإرسال
  createdAt: {
    type: Date,
    default: Date.now
  },
  
  // تاريخ الرد (قبول/رفض)
  respondedAt: {
    type: Date
  },

  // سياسة السماح بلقطات الشاشة
  allowScreenshots: {
    type: Boolean,
    default: false
  },

});


// يسمح بطلب واحد فقط (pending أو accepted) بين نفس الشخصين

ContactSchema.index(
  { requester: 1, recipient: 1 },
  { 
    unique: true,
    partialFilterExpression: { status: { $in: ['pending', 'accepted'] } }
  }
);

// للبحث السريع عن الأصدقاء
ContactSchema.index({ requester: 1, status: 1 });
ContactSchema.index({ recipient: 1, status: 1 });

//  دالة مساعدة: هل هم أصدقاء؟
ContactSchema.statics.areFriends = async function(userId1, userId2) {
  const contact = await this.findOne({
    $or: [
      { requester: userId1, recipient: userId2, status: 'accepted' },
      { requester: userId2, recipient: userId1, status: 'accepted' }
    ]
  });
  return !!contact;
};

// ✅ دالة مساعدة: حالة العلاقة
ContactSchema.statics.getRelationship = async function(userId1, userId2) {
  const contact = await this.findOne({
    $or: [
      { requester: userId1, recipient: userId2 },
      { requester: userId2, recipient: userId1 }
    ]
  });
  
  if (!contact) return { exists: false };
  
  return {
    exists: true,
    status: contact.status,
    iAmRequester: contact.requester.toString() === userId1.toString()
  };
};

// ✅ دالة جديدة: جلب عدد الطلبات المعلقة
ContactSchema.statics.getPendingCount = async function(userId) {
  return await this.countDocuments({
    recipient: userId,
    status: 'pending'
  });
};

// ✅ دالة جديدة: جلب عدد الأصدقاء
ContactSchema.statics.getFriendsCount = async function(userId) {
  return await this.countDocuments({
    $or: [
      { requester: userId, status: 'accepted' },
      { recipient: userId, status: 'accepted' }
    ]
  });
};

module.exports = mongoose.model('Contact', ContactSchema);