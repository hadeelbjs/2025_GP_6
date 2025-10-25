const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema({
  fullName: { type: String, required: true },
  username: { type: String, required: true, unique: true, lowercase: true },
  email: { type: String, required: true, unique: true, lowercase: true },
  phone: { type: String, required: true, unique: true },
  password: { type: String, required: true },

  failedLoginAttempts: { type: Number, default: 0 },
  lastFailedLoginAt: Date,

  
  // تتبع آخر 12 باسورد
  passwordHistory: [{
    hash: String,
    changedAt: { type: Date, default: Date.now }
  }],
  
  // تاريخ آخر تغيير للباسورد
  passwordChangedAt: { type: Date, default: Date.now },
  
  // هل يحتاج تغيير الباسورد (كل 90 يوم)
  passwordResetRequired: { type: Boolean, default: false },
  
  isEmailVerified: { type: Boolean, default: false },
  isPhoneVerified: { type: Boolean, default: false },
  
  emailVerificationCode: String,
  emailVerificationExpires: Date,
  
  twoFACode: String,
  twoFAExpires: Date,
  
  passwordResetCode: String,
  passwordResetExpires: Date,

  
  biometricEnabled: { type: Boolean, default: false },
  biometricVerificationCode: String,
  biometricVerificationExpires: Date,
  
  memoji: { type: String, default: '😊' },
  
  identityPublicKey: String,
  signedPreKey: {
    keyId: Number,
    publicKey: String,
    signature: String
  },

newEmailVerificationCode: String,
newEmailVerificationExpires: Date,
pendingEmail: String,
  
  preKeys: [{
    keyId: Number,
    publicKey: String
  }],
  
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// دالة للتحقق من قوة الباسورد
UserSchema.statics.validatePasswordStrength = function(password) {
  const errors = [];
  
  // الطول 8 أحرف على الأقل
  if (password.length < 8) {
    errors.push('يجب أن تكون كلمة المرور 8 أحرف على الأقل');
  }
  
  // حرف صغير واحد على الأقل
  if (!/[a-z]/.test(password)) {
    errors.push('يجب أن تحتوي كلمة المرور على حرف صغير واحد على الأقل (a-z)');
  }
  
  // حرف كبير واحد على الأقل
  if (!/[A-Z]/.test(password)) {
    errors.push('يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل (A-Z)');
  }
  
  // رقم واحد على الأقل
  if (!/[0-9]/.test(password)) {
    errors.push('يجب أن تحتوي كلمة المرور على رقم واحد على الأقل (0-9)');
  }
  
  // رمز خاص واحد على الأقل
  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?£$*]/.test(password)) {
    errors.push('يجب أن تحتوي كلمة المرور على رمز خاص واحد على الأقل (!@#$%^&*)');
  }
  
  return errors;
};

// دالة للتحقق من تكرار آخر 12 باسورد
UserSchema.methods.checkPasswordHistory = async function(newPassword) {
  const bcrypt = require('bcryptjs');
  
  if (!this.passwordHistory || this.passwordHistory.length === 0) {
    return true; // لا توجد باسوردات سابقة
  }
  
  // التحقق من آخر 12 باسورد
  const last12 = this.passwordHistory.slice(-12);
  
  for (const oldPassword of last12) {
    const isMatch = await bcrypt.compare(newPassword, oldPassword.hash);
    if (isMatch) {
      return false; // الباسورد مستخدم من قبل
    }
  }
  
  return true; // الباسورد جديد
};

// دالة لإضافة الباسورد للتاريخ
UserSchema.methods.addToPasswordHistory = function(passwordHash) {
  if (!this.passwordHistory) {
    this.passwordHistory = [];
  }
  
  this.passwordHistory.push({
    hash: passwordHash,
    changedAt: new Date()
  });
  
  // الاحتفاظ بآخر 12 فقط
  if (this.passwordHistory.length > 12) {
    this.passwordHistory = this.passwordHistory.slice(-12);
  }
};

// دالة للتحقق من انتهاء صلاحية الباسورد (90 يوم)
UserSchema.methods.isPasswordExpired = function() {
  if (!this.passwordChangedAt) {
    return false; // لو ما فيه تاريخ، نعتبره ما انتهى
  }
  
  const daysSinceChange = (Date.now() - this.passwordChangedAt.getTime()) / (1000 * 60 * 60 * 24);
  return daysSinceChange >= 90;
};

// دالة لتوليد باسورد عشوائي قوي (بدون نمط ثابت)
UserSchema.statics.generateSecurePassword = function(length = 12) {
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const numbers = '0123456789';
  const special = '!@#$%^&*()_+-=[]{}|;:,.<>?£$*';
  
  const allChars = lowercase + uppercase + numbers + special;
  
  let password = '';
  
  // ضمان وجود حرف من كل نوع
  password += lowercase[Math.floor(Math.random() * lowercase.length)];
  password += uppercase[Math.floor(Math.random() * uppercase.length)];
  password += numbers[Math.floor(Math.random() * numbers.length)];
  password += special[Math.floor(Math.random() * special.length)];
  
  // إكمال الباقي عشوائياً
  for (let i = password.length; i < length; i++) {
    password += allChars[Math.floor(Math.random() * allChars.length)];
  }
  
  // خلط الأحرف عشوائياً (لتجنب النمط الثابت)
  return password.split('').sort(() => Math.random() - 0.5).join('');
};



module.exports = mongoose.model('User', UserSchema);