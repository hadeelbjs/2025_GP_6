const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  fullName: {
    type: String,
    required: true,
    trim: true
  },
  username: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  phone: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  password: {
    type: String,
    required: true
  },
  
  // حقول التحقق من البريد الإلكتروني
  isEmailVerified: {
    type: Boolean,
    default: false
  },
  emailVerificationCode: String,
  emailVerificationExpires: Date,
  
  // حقول التحقق من رقم الجوال
  isPhoneVerified: {
    type: Boolean,
    default: false
  },
  
  // حقول التحقق الثنائي (2FA) لتسجيل الدخول
  twoFACode: String,
  twoFAExpires: Date,
  
  // حقول إعادة تعيين كلمة المرور
  passwordResetCode: String,
  passwordResetExpires: Date,
  
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('User', UserSchema);