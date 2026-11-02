// One place to call the language model: Gemini 2.5 Flash-Lite (free tier: about 20 requests a day,
// so callers send several items per request). Returns the model's raw JSON text, or null when it is
// unavailable (quota, outage, no key); callers then skip the work and retry on the next run.

const GEMINI_MODEL = "gemini-2.5-flash-lite";

export async function generate(prompt: string, maxTokens = 2000): Promise<string | null> {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return null;
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${key}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.2, maxOutputTokens: maxTokens, responseMimeType: "application/json" },
        }),
      }
    );
    if (!res.ok) {
      console.error("Gemini error:", res.status, (await res.text()).slice(0, 300));
      return null;
    }
    const data: any = await res.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    return text ? text.replace(/```(?:json)?/g, "").trim() : null;
  } catch (e) {
    console.error("Gemini request failed:", e);
    return null;
  }
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
