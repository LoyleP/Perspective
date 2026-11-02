// @ts-nocheck
import { pool } from "./db.js";

// Titles must fit on three lines of a phone card.
const MAX_TITLE_CHARS = 90;
const BATCH = 15;

/** Normalises spacing, strips quotes / trailing punctuation and capitalises the first letter. */
export function cleanTitle(raw: string): string {
  const t = raw
    .replace(/\s+/g, " ")
    .trim()
    .replace(/^["«»“”'\s]+|["«»“”'\s]+$/g, "")
    .replace(/[.…\s]+$/, "");
  return t ? t.charAt(0).toLocaleUpperCase("fr-FR") + t.slice(1) : t;
}

/** Asks Gemini for one neutral French headline per story, from the story's own article headlines. */
async function rewriteBatch(stories: { id: string; headlines: string[] }[]): Promise<Record<string, string>> {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return {};

  const block = stories
    .map((s) => `[${s.id}]\n${s.headlines.map((h) => `- ${h}`).join("\n")}`)
    .join("\n\n");

  const prompt = `Tu es rédacteur en chef d'une application d'actualité française. Pour chaque sujet ci-dessous, écris UN titre clair, neutre et factuel, en français, à partir des titres d'articles fournis (qui peuvent être en anglais, en minuscules ou mal formulés : ne les recopie pas, reformule).

Structure obligatoire : une seule phrase complète « qui + fait quoi (+ où / quand / combien) », avec un sujet et un verbe conjugué, par exemple « Le Sénat adopte le texte sur la sécurité » ou « Lula réélu président du Brésil au second tour ». Le titre doit se comprendre seul, sans avoir lu l'article.

Règles de forme : ${MAX_TITLE_CHARS} caractères maximum, la première lettre en majuscule, majuscules uniquement pour les noms propres (pas de MAJUSCULES, pas de Title Case à l'anglaise), pas de point final, pas de guillemets ni de deux-points, pas de « ... », pas de nom de média, pas de formulation putaclic, pas d'opinion, pas de question. Écris toujours en français, quelle que soit la langue des articles. Si les titres divergent, retiens le fait commun à la majorité d'entre eux.

Réponds UNIQUEMENT avec du JSON valide, sans markdown ni backticks, au format :
[{ "id": "...", "title": "..." }]

Sujets :

${block}`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${key}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { temperature: 0.2, maxOutputTokens: 2000 },
      }),
    }
  );
  if (!res.ok) {
    console.error("Gemini title error:", await res.text());
    return {};
  }
  const data = await res.json();
  const raw = (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "").replace(/```json|```/g, "").trim();
  try {
    const out: Record<string, string> = {};
    const known = new Set(stories.map((s) => s.id));
    for (const item of JSON.parse(raw)) {
      const id = String(item.id ?? "").replace(/[\[\]\s]/g, "");
      if (!known.has(id)) continue;
      const title = cleanTitle(String(item.title ?? ""));
      if (title && title.length <= MAX_TITLE_CHARS) out[id] = title;
    }
    return out;
  } catch (e) {
    console.error("Failed to parse Gemini titles:", raw, e);
    return {};
  }
}

/** Rewrites the titles of stories that haven't been rewritten yet (at most `limit` per call). */
export async function rewriteStoryTitles(limit = 60): Promise<number> {
  const { rows } = await pool.query(
    `SELECT s.id, array_agg(a.title ORDER BY a.published_at DESC) AS headlines
       FROM stories s JOIN articles a ON a.story_id = s.id AND a.is_primary
      WHERE s.title_rewritten_at IS NULL
      GROUP BY s.id, s.last_updated_at
      ORDER BY s.last_updated_at DESC
      LIMIT $1`,
    [limit]
  );

  let updated = 0;
  for (let i = 0; i < rows.length; i += BATCH) {
    const batch = rows.slice(i, i + BATCH).map((r) => ({ id: r.id, headlines: r.headlines.slice(0, 6) }));
    const titles = await rewriteBatch(batch);
    for (const [id, title] of Object.entries(titles)) {
      await pool.query("UPDATE stories SET title = $2, title_rewritten_at = now() WHERE id = $1::uuid", [id, title]);
      updated++;
    }
  }
  return updated;
}
