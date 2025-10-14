// models/PreKeyBundle.js
const mongoose = require('mongoose');

const PreKeyBundleSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true // للبحث السريع
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
  
  // تحسين: إضافة حقل "used" لتتبع المفاتيح المستخدمة
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
    createdAt: {
      type: Date,
      default: Date.now
    }
  }],
  
  // إضافية: تتبع آخر تحديث للمفاتيح
  lastKeyRotation: {
    type: Date,
    default: Date.now
  },
  
  createdAt: {
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

// دالة مساعدة: جلب عدد PreKeys المتاحة (غير مستخدمة)
PreKeyBundleSchema.methods.getAvailablePreKeysCount = function() {
  return this.preKeys.filter(pk => !pk.used).length;
};

// دالة مساعدة: هل نحتاج تجديد المفاتيح؟
PreKeyBundleSchema.methods.needsRefresh = function() {
  const availableKeys = this.getAvailablePreKeysCount();
  return availableKeys < 20; // إذا أقل من 20 مفتاح، نحتاج تجديد
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