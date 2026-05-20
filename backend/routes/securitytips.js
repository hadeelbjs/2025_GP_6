const express = require('express');
const router = express.Router();
const SecurityTip = require('../models/SecurityTip');

router.get('/today', async (req, res) => {
  try {
    const total = await SecurityTip.countDocuments({ isActive: true });

    if (total === 0) {
      return res.status(404).json({
        success: false,
        message: 'لا توجد نصائح متاحة حالياً',
      });
    }

    const now = new Date();
    const startOfYear = new Date(now.getFullYear(), 0, 0);
    const diff = now - startOfYear;
    const oneDay = 1000 * 60 * 60 * 24;
    const dayOfYear = Math.floor(diff / oneDay);

    const index = (dayOfYear - 1) % total;

    const tip = await SecurityTip.findOne({ isActive: true })
      .sort({ tipId: 1, _id: 1 })
      .skip(index)
      .lean();

    return res.json({
      success: true,
      tip,
    });
  } catch (error) {
    console.error('Error fetching today security tip:', error);
    return res.status(500).json({
      success: false,
      message: 'حدث خطأ أثناء جلب نصيحة اليوم',
    });
  }
});

module.exports = router;