// One place to call a language model. Groq first (free tier, OpenAI-compatible API), Gemini as a
// fallback; returns the model's raw text, or null when both are unavailable (quota, outage, no key).

const GROQ_MODEL = "openai/gpt-oss-120b";
const GEMINI_MODEL = "gemini-2.5-flash-lite";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** Groq's free tier limits tokens per minute: on a 429 it says how long to wait, so wait and retry. */
async function groq(prompt: string, maxTokens: number): Promise<string | null> {
  const key = process.env.GROQ_API_KEY;
  if (!key) return null;
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await groqOnce(key, prompt, maxTokens);
    if (res === null) return null;
    if (typeof res === "string") return res;
    if (res.retryAfter > 65) return null; // a daily limit, not a per-minute one
    await sleep(res.retryAfter * 1000 + 500);
  }
  return null;
}

async function groqOnce(key: string, prompt: string, maxTokens: number): Promise<string | null | { retryAfter: number }> {
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
  if (res.status === 429) {
    const body = await res.text();
    const wait = Number(body.match(/try again in ([\d.]+)s/)?.[1] ?? res.headers.get("retry-after") ?? 999);
    return { retryAfter: wait };
  }
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
  const safe = (f: () => Promise<string | null>) => f().catch((e) => (console.error("LLM request failed:", e), null));
  const text = (await safe(() => groq(prompt, maxTokens))) ?? (await safe(() => gemini(prompt, maxTokens)));
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
