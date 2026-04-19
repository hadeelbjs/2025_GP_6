const mongoose = require('mongoose');

const securityTipSchema = new mongoose.Schema(
  {
    tipId: {
      type: Number,
      required: true,
      unique: true,
    },
    tip_ar: {
      type: String,
      required: true,
      trim: true,
    },
    category: {
      type: String,
      default: 'general',
      trim: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
    collection: 'securitytips',
  }
);

module.exports = mongoose.model('SecurityTip', securityTipSchema);