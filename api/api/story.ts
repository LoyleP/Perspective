import { err, json, storiesWithArticles } from "../lib/db.js";

export async function GET(request: Request): Promise<Response> {
  const id = new URL(request.url).searchParams.get("id");
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) return err("invalid id", 400);
  try {
    const [story] = await storiesWithArticles("s.id = $1::uuid", [id], "LIMIT 1");
    return story ? json(story) : err("not found", 404);
  } catch (e) {
    console.error(e);
    return err("story failed");
  }
}
