const mongoose = require('mongoose');

const scanStatsSchema = new mongoose.Schema({
  total:      { type: Number, default: 0 },
  safe:       { type: Number, default: 0 },
  vulnerable: { type: Number, default: 0 },
}, { _id: false });

const ContentScanningSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
    index: true
  },
  linkStats:  { type: scanStatsSchema, default: () => ({}) },
  fileStats:  { type: scanStatsSchema, default: () => ({}) },
  imageStats: { type: scanStatsSchema, default: () => ({}) },
}, { timestamps: true });

ContentScanningSchema.statics.findByUserId = function(userId) {
  return this.findOne({ userId });
};

ContentScanningSchema.methods.recordScan = function(type, isVulnerable) {
  const stat = this[`${type}Stats`];
  if (!stat) throw new Error(`Unknown scan type: ${type}`);

  stat.total++;
  isVulnerable ? stat.vulnerable++ : stat.safe++;
  return this.save();
};

module.exports = mongoose.model('ContentScanning', ContentScanningSchema);