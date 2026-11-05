import { err, json, pool, storiesWithArticles } from "../lib/db.js";
import { upcoming } from "../lib/laws.js";

/** One law with its full step history and the news stories that cover it. */
export async function GET(request: Request): Promise<Response> {
  const uid = new URL(request.url).searchParams.get("uid");
  if (!uid || !/^[A-Z0-9]{6,40}$/.test(uid)) return err("invalid uid", 400);
  try {
    const { rows } = await pool.query(
      `SELECT uid, title, short_title, plain_title, why_it_matters, kind, status, state, accelerated, deposited_at, last_act_at,
              steps, summary, story_ids, senat_url, author_name, author_photo
         FROM laws WHERE uid = $1`,
      [uid]
    );
    const law = rows[0];
    if (!law) return err("not found", 404);
    const stories = law.story_ids.length
      ? await storiesWithArticles("s.id = ANY($1::uuid[])", [law.story_ids], "ORDER BY s.last_updated_at DESC")
      : [];
    const { story_ids, ...rest } = law;
    return json({ ...rest, upcoming: upcoming(law.steps, law.title), stories }, 200, "public, s-maxage=60");
  } catch (e) {
    console.error(e);
    return err("law failed");
  }
}
