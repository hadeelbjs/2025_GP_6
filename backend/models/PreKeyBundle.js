// models/PreKeyBundle.js
const mongoose = require('mongoose');

const PreKeyBundleSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true
  },
  
  registrationId: {
    type: Number,
    required: true
  },
  
  identityKey: {
    type: String,
    required: true
  },
  
  signedPreKey: {
    keyId: {
      type: Number,
      required: true
    },
    publicKey: {
      type: String,
      required: true
    },
    signature: {
      type: String,
      required: true
    },
    timestamp: {
      type: Date,
      default: Date.now
    }
  },
  
  preKeys: [{
    keyId: {
      type: Number,
      required: true
    },
    publicKey: {
      type: String,
      required: true
    },
    used: {
      type: Boolean,
      default: false
    },
    usedAt: {
      type: Date,
      default: null
    },
   
  }],
  
  // ✅ إضافة رقم النسخة لتتبع التحديثات
  version: {
    type: Number,
    required: true,
    default: () => Date.now()
  },
  
  lastKeyRotation: {
    type: Date,
    default: Date.now
  },

  
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// تحديث updatedAt تلقائياً
PreKeyBundleSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

// ✅ عند تحديث كامل للمفاتيح، تحديث النسخة
PreKeyBundleSchema.methods.updateVersion = function() {
  this.version = Date.now();
};

// دالة مساعدة: جلب عدد PreKeys المتاحة
PreKeyBundleSchema.methods.getAvailablePreKeysCount = function() {
  return this.preKeys.filter(pk => !pk.used).length;
};

// دالة مساعدة: هل نحتاج تجديد المفاتيح؟
PreKeyBundleSchema.methods.needsRefresh = function() {
  const availableKeys = this.getAvailablePreKeysCount();
  return availableKeys < 20;
};

// دالة مساعدة: الحصول على PreKey غير مستخدم
PreKeyBundleSchema.methods.getUnusedPreKey = function() {
  return this.preKeys.find(pk => !pk.used);
};

// دالة مساعدة: تحديد PreKey كمستخدم
PreKeyBundleSchema.methods.markPreKeyAsUsed = async function(keyId) {
  const preKey = this.preKeys.find(pk => pk.keyId === keyId);
  if (preKey) {
    preKey.used = true;
    preKey.usedAt = Date.now();
    await this.save();
  }
};

module.exports = mongoose.model('PreKeyBundle', PreKeyBundleSchema);