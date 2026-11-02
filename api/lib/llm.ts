// One place to call a language model. Groq first (free tier, OpenAI-compatible API), Gemini as a
// fallback; returns the model's raw text, or null when both are unavailable (quota, outage, no key).

const GROQ_MODEL = "openai/gpt-oss-120b";
const GEMINI_MODEL = "gemini-2.5-flash-lite";

async function groq(prompt: string, maxTokens: number): Promise<string | null> {
  const key = process.env.GROQ_API_KEY;
  if (!key) return null;
  const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: GROQ_MODEL,
      messages: [{ role: "user", content: prompt }],
      temperature: 0.2,
      max_completion_tokens: maxTokens,
      reasoning_effort: "low",
    }),
  });
  if (!res.ok) {
    console.error("Groq error:", res.status, (await res.text()).slice(0, 300));
    return null;
  }
  const data: any = await res.json();
  return data?.choices?.[0]?.message?.content ?? null;
}

async function gemini(prompt: string, maxTokens: number): Promise<string | null> {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return null;
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${key}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.2, maxOutputTokens: maxTokens },
      }),
    }
  );
  if (!res.ok) {
    console.error("Gemini error:", res.status, (await res.text()).slice(0, 300));
    return null;
  }
  const data: any = await res.json();
  return data?.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
}

/** Raw model text with markdown fences stripped, or null. */
export async function generate(prompt: string, maxTokens = 2000): Promise<string | null> {
  const text = (await groq(prompt, maxTokens)) ?? (await gemini(prompt, maxTokens));
  return text ? text.replace(/```(?:json)?/g, "").trim() : null;
}

/** Parses the first JSON value in the model's answer (array or object), or null. */
export function parseJSON(text: string | null): any {
  if (!text) return null;
  const start = text.search(/[\[{]/);
  if (start < 0) return null;
  try {
    return JSON.parse(text.slice(start, Math.max(text.lastIndexOf("]"), text.lastIndexOf("}")) + 1));
  } catch {
    return null;
  }
}
