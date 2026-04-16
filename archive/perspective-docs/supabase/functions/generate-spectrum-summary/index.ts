import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const LEAN_LABELS: Record<string, string> = {
  extreme_gauche: "Extrême-gauche",
  gauche: "Gauche",
  centre: "Centre",
  droite: "Droite",
  extreme_droite: "Extrême-droite",
};

const LEAN_ORDER = [
  "extreme_gauche",
  "gauche",
  "centre",
  "droite",
  "extreme_droite",
];

// Maps the 7-point political_lean integer to a 5-bucket string key.
function leanBucket(politicalLean: number): string {
  if (politicalLean === 1) return "extreme_gauche";
  if (politicalLean <= 3) return "gauche";
  if (politicalLean === 4) return "centre";
  if (politicalLean <= 6) return "droite";
  return "extreme_droite";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  let storyId: string;
  try {
    const body = await req.json();
    storyId = body.story_id;
    if (!storyId) throw new Error("Missing story_id");
  } catch (e) {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Idempotency check — return early if summary already exists.
  const { data: existing, error: checkError } = await supabase
    .from("stories")
    .select("spectrum_summary")
    .eq("id", storyId)
    .single();

  if (checkError) {
    return new Response(JSON.stringify({ error: "Story not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (existing.spectrum_summary !== null) {
    return new Response(JSON.stringify({ status: "already_generated" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Fetch articles with their source lean for this story.
  const { data: articles, error: articlesError } = await supabase
    .from("articles")
    .select("title, summary, published_at, sources(political_lean)")
    .eq("story_id", storyId)
    .order("published_at", { ascending: false });

  if (articlesError || !articles || articles.length === 0) {
    return new Response(JSON.stringify({ error: "No articles found" }), {
      status: 422,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Group articles by lean bucket (max 5 per bucket, already ordered by date desc).
  const grouped: Record<string, { title: string; summary: string | null }[]> =
    {};

  for (const article of articles) {
    const lean = article.sources?.political_lean;
    if (lean == null) continue;
    const bucket = leanBucket(lean);
    if (!grouped[bucket]) grouped[bucket] = [];
    if (grouped[bucket].length < 5) {
      grouped[bucket].push({ title: article.title, summary: article.summary });
    }
  }

  if (Object.keys(grouped).length === 0) {
    return new Response(
      JSON.stringify({ error: "No articles with lean data" }),
      { status: 422, headers: { "Content-Type": "application/json" } }
    );
  }

  // Build the articles block for the prompt.
  const articlesBlock = LEAN_ORDER.filter((lean) => grouped[lean])
    .map((lean) => {
      const label = LEAN_LABELS[lean];
      const lines = grouped[lean]
        .map((a) => `- ${a.title}${a.summary ? ". " + a.summary : ""}`)
        .join("\n");
      return `### ${label}\n${lines}`;
    })
    .join("\n\n");

  const prompt = `Tu es un outil d'analyse des médias français. Pour chaque tendance politique ci-dessous, rédige exactement 5 points d'information compilés depuis les articles. Chaque point doit formuler un fait directement, sans jamais faire référence aux articles, aux médias ou à leur angle éditorial. Ne commence jamais par des formules comme "Les articles indiquent que", "Ces médias affirment que", "La presse de gauche souligne que" ou toute autre formulation méta. Chaque point est une phrase affirmative et directe à la troisième personne. Sépare les points par un saut de ligne, chaque point commence par "• ". Réponds toujours en français, quelle que soit la langue des articles.

Réponds UNIQUEMENT avec du JSON valide dans ce format exact, sans markdown ni backticks :
{
  "perspectives": [
    { "lean": "gauche", "summary": "...", "source_count": 0 },
    ...
  ]
}

Articles par tendance politique :

${articlesBlock}`;

  // Call Gemini 2.5 Flash-Lite.
  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (!geminiKey) {
    return new Response(JSON.stringify({ error: "Missing GEMINI_API_KEY" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let geminiResponse: Response;
  try {
    geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 1000,
          },
        }),
      }
    );
  } catch (e) {
    console.error("Gemini fetch failed:", e);
    return new Response(JSON.stringify({ error: "Gemini request failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  if (!geminiResponse.ok) {
    const errText = await geminiResponse.text();
    console.error("Gemini error response:", errText);
    return new Response(JSON.stringify({ error: "Gemini API error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const geminiData = await geminiResponse.json();
  const rawText: string =
    geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

  // Strip markdown code fences Gemini sometimes adds despite instructions.
  const cleanedText = rawText
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  let parsed: { perspectives: { lean: string; summary: string }[] };
  try {
    parsed = JSON.parse(cleanedText);
    if (!Array.isArray(parsed.perspectives)) throw new Error("Bad shape");
  } catch (e) {
    console.error("Failed to parse Gemini JSON. Raw text:", rawText, "Error:", e);
    return new Response(
      JSON.stringify({ error: "Failed to parse Gemini response" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  // Reinject source_count from DB data — never trust LLM numbers.
  const now = new Date().toISOString();
  const perspectives = parsed.perspectives
    .filter((p) => LEAN_ORDER.includes(p.lean) && grouped[p.lean])
    .map((p) => ({
      lean: p.lean,
      summary: p.summary,
      source_count: grouped[p.lean].length,
    }));

  const spectrumSummary = {
    generated_at: now,
    perspectives,
  };

  const { error: updateError } = await supabase
    .from("stories")
    .update({
      spectrum_summary: spectrumSummary,
      summary_generated_at: now,
    })
    .eq("id", storyId);

  if (updateError) {
    console.error("Failed to save spectrum summary:", updateError);
    return new Response(JSON.stringify({ error: "Failed to save" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ status: "generated", perspectives }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
