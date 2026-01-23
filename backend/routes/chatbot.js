// routes/chatbot.js
/*const express = require("express");
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

module.exports = router;*/

// routes/chatbot.js
const express = require("express");
const router = express.Router();
const { askGeminiCyberOnly } = require("../utils/geminiService");

// GET /api/chatbot/health (للتجربة السريعة)
router.get("/health", (req, res) => {
  res.json({ success: true, message: "chatbot route is OK" });
});

// POST /api/chatbot/ask
router.post("/ask", async (req, res) => {
  try {
    const message = (req.body?.message || "").toString().trim();

    if (!message) {
      return res.status(400).json({
        success: false,
        reply: "اكتبي سؤالك أولاً.",
        reason: "EMPTY",
      });
    }

    const result = await askGeminiCyberOnly(message);

    if (!result.ok) {
      // ✅ هنا الفرق: نرجّع reason الحقيقي بدل ما نخليه OUT_OF_SCOPE دايم
      const reason = result.reason || "ERROR";

      // OUT_OF_SCOPE / EMPTY -> 400
      // MODEL_ERROR / MODEL_EMPTY / TIMEOUT -> 502 (مشكلة من الموديل/الخدمة)
      const status =
        reason === "OUT_OF_SCOPE" || reason === "EMPTY" ? 400 : 502;

      return res.status(status).json({
        success: false,
        reply: result.message,
        reason,
      });
    }

    return res.json({
      success: true,
      reply: result.message,
      reason: "OK",
    });
  } catch (e) {
    console.error("chatbot error:", e);
    return res.status(500).json({
      success: false,
      reply: "صار خطأ في المساعد الذكي. جرّبي لاحقاً.",
      reason: "SERVER_ERROR",
    });
  }
});

module.exports = router;

