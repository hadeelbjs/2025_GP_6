const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const ContentScanning = require('../models/ContentScanning');

router.post('/update-link-stats', auth, async (req, res) => { 
  try {
    const contentScanning = await ContentScanning.findByUserId(req.user.id); 

    if (!contentScanning) {
      return res.status(404).json({ message: 'User stats not found' });
    }

    const { isVulnerable } = req.body;
    await contentScanning.recordScan('link', isVulnerable);

    res.status(200).json({
      message: 'Link stats updated successfully',
      linkStats: contentScanning.linkStats,
    });

  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

router.post('/update-file-stats', auth, async (req, res) => { 
  try {
    const contentScanning = await ContentScanning.findByUserId(req.user.id); 

    if (!contentScanning) {
      return res.status(404).json({ message: 'User stats not found' });
    }

    const { isVulnerable } = req.body;
    await contentScanning.recordScan('file', isVulnerable);

    res.status(200).json({
      message: 'file stats updated successfully',
      fileStats: contentScanning.fileStats,
    });

  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

router.get('/all-stats', auth, async (req, res) => {
  try {
    const contentScanning = await ContentScanning.findByUserId(req.user.id);

    if (!contentScanning) {
      return res.status(404).json({ message: 'User stats not found' });
    }

    const { qrStats, linkStats, fileStats } = contentScanning;
    res.status(200).json({ qrStats, linkStats, fileStats });

  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

module.exports = router;