import { err, pool } from "../lib/db.js";

export async function GET(request: Request): Promise<Response> {
  const id = new URL(request.url).searchParams.get("id");
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) return err("invalid id", 400);
  try {
    const { rows } = await pool.query("SELECT content_type, data FROM source_logos WHERE source_id = $1::uuid", [id]);
    if (!rows[0]) return err("not found", 404);
    return new Response(new Uint8Array(rows[0].data), {
      headers: {
        "Content-Type": rows[0].content_type,
        "Cache-Control": "public, max-age=604800, s-maxage=2592000, stale-while-revalidate=86400",
      },
    });
  } catch (e) {
    console.error(e);
    return err("logo failed");
  }
}
