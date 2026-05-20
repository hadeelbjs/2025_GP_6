const express = require("express");
const router = express.Router();
const { askGeminiCyberOnly } = require("../utils/geminiService");

router.get("/health", (req, res) => {
  res.json({ success: true, message: "chatbot route is OK" });
});

router.post("/ask", async (req, res) => {
  try {
    const message = (req.body?.message || "").toString().trim();

    if (!message) {
      return res.json({
        success: true,
        reply: "اكتبي سؤالك هنا",
        reason: "EMPTY",
      });
    }

    const result = await askGeminiCyberOnly(message);

    if (!result.ok) {
      return res.json({
        success: true,
        reply: result.message || "حصل خطأ بسيط. جرّبي مرة ثانية.",
        reason: result.reason || "SOFT_GUIDE",
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