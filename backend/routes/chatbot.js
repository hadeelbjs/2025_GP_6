// routes/chatbot.js
const express = require("express");
const router = express.Router();
const { askGeminiCyberOnly } = require("../utils/geminiService");

// POST /api/chatbot/ask
router.post("/ask", async (req, res) => {
  try {
    const { message } = req.body;

    const result = await askGeminiCyberOnly(message);

    if (!result.ok) {
      return res.status(400).json({
        success: false,
        reply: result.message,
        reason: "OUT_OF_SCOPE",
      });
    }

    return res.json({
      success: true,
      reply: result.message,
    });
  } catch (e) {
    console.error("chatbot error:", e);
    return res.status(500).json({
      success: false,
      reply: "صار خطأ في المساعد الذكي. جرّبي لاحقاً.",
    });
  }
});

module.exports = router;
