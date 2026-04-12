const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const ContentScanning = require('../models/ContentScanning');
const multer = require('multer');
const axios = require('axios');
const FormData = require('form-data');

const upload = multer({ 
    storage: multer.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 }
});

const isImageSensitive = (result) => {
    const summary = result.summary ?? {};
    const sensitiveDocTypes = new Set([
        'id_card', 'national_id', 'passport', 'driver_license',
        'residence_permit', 'iqama', 'birth_certificate',
        'health_card', 'insurance_card', 'credit_card', 'bank_card',
        'car_plate', 'credit_cards'
    ]);

    const hasSensitiveDocs = (result.yolo_objects ?? [])
        .some(obj => sensitiveDocTypes.has(
            obj.class?.toLowerCase().replace(' ', '_')
        ));

    return (
        (summary.total_faces    ?? 0) > 0 ||
        (summary.total_keywords ?? 0) > 0 ||
        (summary.total_names    ?? 0) > 0 ||
        (summary.total_barcodes ?? 0) > 0 ||
        hasSensitiveDocs
    );
};

router.post('/scan-image', auth, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No image provided' });
        }

        const formData = new FormData();
        formData.append('file', req.file.buffer, {
            filename:    req.file.originalname,
            contentType: req.file.mimetype,
        });

        // إرسال لـ Modal
        const modalResponse = await axios.post(
            `${process.env.MODAL_URL}/analyze`,
            formData,
            {
                headers: {
                    ...formData.getHeaders(),
                    'x-api-key': process.env.MODAL_SECRET_KEY,
                },
                timeout: 120000,
            }
        );

        const result       = modalResponse.data;
        const isVulnerable = isImageSensitive(result);

        // تحديث الإحصائيات
        const contentScanning = await ContentScanning.findByUserId(req.user.id);
        if (contentScanning) {
            await contentScanning.recordScan('image', isVulnerable);
        }

        return res.status(200).json(result);

    } catch (error) {
        if (error.response) {
            return res.status(error.response.status).json({
                message: error.response.data
            });
        }
        return res.status(500).json({ message: error.message });
    }
});

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
            message: 'File stats updated successfully',
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
        const { linkStats, fileStats, imageStats } = contentScanning;
        res.status(200).json({ linkStats, fileStats, imageStats });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
});

module.exports = router;