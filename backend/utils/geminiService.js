const { GoogleGenerativeAI } = require("@google/generative-ai");

// رسالة توجيه إذا كان السؤال بعيد جداً عن الأمن الرقمي
function refusalMessage() {
  return "أنا متخصص في الأمن السيبراني وحماية البيانات والخصوصية. إذا وضّحتي لي قصدك (حسابات؟ جهاز؟ واي فاي؟ روابط؟) أقدر أساعدك بخطوات عملية.";
}

const SYSTEM_INSTRUCTION = `
أنت مساعد متخصص في الأمن السيبراني وحماية البيانات والخصوصية الرقمية.

مهم جداً:
- لا ترفض الأسئلة بسبب صياغتها أو لأنها عامة.
- إذا كان السؤال عاماً مثل: "كيف أحمي نفسي؟" أو "ثغرات؟" افترض أن المقصود هو الحماية الرقمية، وقدّم إجابة عملية.
- إذا كان السؤال غامضاً جداً، اسأل سؤال توضيحي واحد فقط (اختيار من 2-4 خيارات) ثم أعطِ نصائح عامة مؤقتاً.
- إذا كان السؤال بعيداً جداً عن المجال، لا ترفض رفضاً قاطعاً؛ وجّه المستخدم بلطف لربطه بالأمن الرقمي عبر مثالين قصيرين.

قيود السلامة:
- قدّم محتوى دفاعي فقط (حماية/وقاية/تحقق).
- ممنوع شرح خطوات اختراق أو استغلال ثغرات أو أي إرشادات هجومية أو غير قانونية.

أسلوب الإجابة:
- العربية الفصحى المبسطة.
- مختصر وواضح (2-6 نقاط غالباً).
- عند الحاجة: قائمة تحقق أو خطوات مرقمة.
`;

// Timeout helper
function withTimeout(promise, ms = 20000) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("TIMEOUT")), ms)
    ),
  ]);
}

async function askGeminiCyberOnly(userText) {
  try {
    const msg = (userText || "").toString().trim();

    if (!msg) {
      return { ok: false, message: "اكتبي سؤالك أولاً.", reason: "EMPTY" };
    }

    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.error("GEMINI_API_KEY is missing in .env file!");
      return {
        ok: false,
        message: "خطأ في الإعدادات. تواصل مع الدعم الفني.",
        reason: "NO_API_KEY",
      };
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: "models/gemini-2.5-flash",
      systemInstruction: SYSTEM_INSTRUCTION,
      generationConfig: {
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      },
    });

    const result = await withTimeout(model.generateContent(msg), 20000);

    const text = result?.response?.text?.() || "";
    const reply = (text || "").toString().trim();

    if (!reply) {
      console.error("Gemini returned empty response");
      return {
        ok: false,
        message: "المساعد ما رجّع إجابة الآن. جرّبي بعد قليل.",
        reason: "MODEL_EMPTY",
      };
    }

    //  بدل الرفض القاطع: إذا الرد فعلاً رفض/بعيد، نرجّع توجيه لطيف
    const refusalHints = [
      "خارج نطاق",
      "غير متعلق",
      "لا أستطيع المساعدة",
      "لا يمكنني",
      "مختص فقط",
    ];
    const looksLikeRefusal = refusalHints.some((h) => reply.includes(h));

    if (looksLikeRefusal) {
      return { ok: true, message: refusalMessage(), reason: "SOFT_GUIDE" };
    }

    return { ok: true, message: reply, reason: "OK" };
  } catch (error) {
    console.error("Gemini Service Error:", error);

    if (error?.message === "TIMEOUT") {
      return {
        ok: false,
        message: "المساعد تأخر في الرد. جرّبي مرة ثانية.",
        reason: "TIMEOUT",
      };
    }

    const msg = (error?.message || "").toString();

    if (msg.includes("API key") || msg.includes("API_KEY")) {
      return {
        ok: false,
        message: "مفتاح API غير صحيح. تواصل مع الدعم الفني.",
        reason: "INVALID_API_KEY",
      };
    }

    if (msg.toLowerCase().includes("quota")) {
      return {
        ok: false,
        message: "تم استهلاك الكوتا. جرّبي لاحقاً.",
        reason: "QUOTA_EXCEEDED",
      };
    }

    return {
      ok: false,
      message: "صار خطأ في المساعد الذكي. جرّبي لاحقاً.",
      reason: "MODEL_ERROR",
      error: msg,
    };
  }
}

module.exports = { askGeminiCyberOnly };

 
 