// backend/routes/upload.js
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const auth = require('../middleware/auth');

// ============================================
// إنشاء المجلدات إذا ما كانت موجودة
// ============================================
const uploadDir = path.join(__dirname, '../uploads');
const imagesDir = path.join(uploadDir, 'images');
const filesDir = path.join(uploadDir, 'files');

[uploadDir, imagesDir, filesDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
    console.log(`✅ Created directory: ${dir}`);
  }
});

// ============================================
// إعدادات Multer للصور
// ============================================
const imageStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, imagesDir);
  },
  filename: (req, file, cb) => {
    // ✅ اسم فريد: userId_timestamp_random.ext
    const uniqueName = `${req.user.id}_${Date.now()}_${crypto.randomBytes(8).toString('hex')}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const imageFilter = (req, file, cb) => {
  const allowedTypes = /jpeg|jpg|png|gif|png|webp|heic/;
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  const mimetype = allowedTypes.test(file.mimetype);

  if (extname && mimetype) {
    cb(null, true);
  } else {
    cb(new Error('الملف يجب أن يكون صورة (JPEG, PNG, GIF, WebP, HEIC)'));
  }
};

const uploadImage = multer({
  storage: imageStorage,
  limits: {
    fileSize: 10 * 1024 * 1024, // ✅ 10MB حد أقصى
  },
  fileFilter: imageFilter
});

// ============================================
// إعدادات Multer للملفات
// ============================================
const fileStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, filesDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = `${req.user.id}_${Date.now()}_${crypto.randomBytes(8).toString('hex')}${path.extname(file.originalname)}`;
    cb(null, uniqueName);
  }
});

const fileFilter = (req, file, cb) => {
  // ✅ ممنوع: ملفات تنفيذية خطيرة
  const blockedExtensions = /\.exe|\.bat|\.cmd|\.sh|\.app|\.dmg|\.deb|\.rpm/i;
  
  if (blockedExtensions.test(file.originalname)) {
    cb(new Error('نوع الملف غير مسموح به لأسباب أمنية'));
  } else {
    cb(null, true);
  }
};

const uploadFile = multer({
  storage: fileStorage,
  limits: {
    fileSize: 50 * 1024 * 1024, // ✅ 50MB حد أقصى
  },
  fileFilter: fileFilter
});

// ============================================
// ✅ رفع صورة
// ============================================
router.post('/image', auth, uploadImage.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'لم يتم إرفاق صورة'
      });
    }

    // ✅ رابط الصورة
    const imageUrl = `/uploads/images/${req.file.filename}`;
    
    console.log(`✅ Image uploaded: ${req.file.filename} by user ${req.user.id}`);

    res.json({
      success: true,
      message: 'تم رفع الصورة بنجاح',
      url: imageUrl,
      filename: req.file.filename,
      size: req.file.size,
      mimetype: req.file.mimetype,
    });

  } catch (error) {
    console.error('❌ Image upload error:', error);
    
    // ✅ حذف الملف إذا حصل خطأ
    if (req.file && req.file.path) {
      fs.unlink(req.file.path, (err) => {
        if (err) console.error('Failed to delete file:', err);
      });
    }

    res.status(500).json({
      success: false,
      message: 'فشل رفع الصورة'
    });
  }
});

// ============================================
// ✅ رفع ملف
// ============================================
router.post('/file', auth, uploadFile.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'لم يتم إرفاق ملف'
      });
    }

    // ✅ رابط الملف
    const fileUrl = `/uploads/files/${req.file.filename}`;
    
    console.log(`✅ File uploaded: ${req.file.filename} by user ${req.user.id}`);

    res.json({
      success: true,
      message: 'تم رفع الملف بنجاح',
      url: fileUrl,
      filename: req.file.originalname, // ✅ الاسم الأصلي
      savedAs: req.file.filename, // الاسم المحفوظ
      size: req.file.size,
      mimetype: req.file.mimetype,
    });

  } catch (error) {
    console.error('❌ File upload error:', error);
    
    // ✅ حذف الملف إذا حصل خطأ
    if (req.file && req.file.path) {
      fs.unlink(req.file.path, (err) => {
        if (err) console.error('Failed to delete file:', err);
      });
    }

    res.status(500).json({
      success: false,
      message: 'فشل رفع الملف'
    });
  }
});

// ============================================
// ✅ حذف صورة (optional - للتنظيف)
// ============================================
router.delete('/image/:filename', auth, async (req, res) => {
  try {
    const { filename } = req.params;
    
    // ✅ تحقق أن الملف يخص المستخدم (اسم الملف يبدأ بـ userId)
    if (!filename.startsWith(req.user.id)) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية لحذف هذا الملف'
      });
    }

    const filePath = path.join(imagesDir, filename);

    // ✅ تحقق من وجود الملف
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({
        success: false,
        message: 'الملف غير موجود'
      });
    }

    // ✅ حذف الملف
    fs.unlinkSync(filePath);
    
    console.log(`🗑️ Image deleted: ${filename}`);

    res.json({
      success: true,
      message: 'تم حذف الصورة'
    });

  } catch (error) {
    console.error('❌ Delete image error:', error);
    res.status(500).json({
      success: false,
      message: 'فشل حذف الصورة'
    });
  }
});

// ============================================
// ✅ حذف ملف (optional - للتنظيف)
// ============================================
router.delete('/file/:filename', auth, async (req, res) => {
  try {
    const { filename } = req.params;
    
    if (!filename.startsWith(req.user.id)) {
      return res.status(403).json({
        success: false,
        message: 'ليس لديك صلاحية لحذف هذا الملف'
      });
    }

    const filePath = path.join(filesDir, filename);

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({
        success: false,
        message: 'الملف غير موجود'
      });
    }

    fs.unlinkSync(filePath);
    
    console.log(`🗑️ File deleted: ${filename}`);

    res.json({
      success: true,
      message: 'تم حذف الملف'
    });

  } catch (error) {
    console.error('❌ Delete file error:', error);
    res.status(500).json({
      success: false,
      message: 'فشل حذف الملف'
    });
  }
});

// ============================================
// ✅ Middleware للتعامل مع أخطاء Multer
// ============================================
router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        message: 'حجم الملف كبير جداً'
      });
    }
    return res.status(400).json({
      success: false,
      message: `خطأ في رفع الملف: ${error.message}`
    });
  }

  if (error) {
    return res.status(400).json({
      success: false,
      message: error.message
    });
  }

  next();
});

module.exports = router;