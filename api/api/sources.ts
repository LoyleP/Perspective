import { err, json, pool } from "../lib/db.js";

export async function GET(request: Request): Promise<Response> {
  const id = new URL(request.url).searchParams.get("id");
  try {
    if (id) {
      if (!/^[0-9a-f-]{36}$/i.test(id)) return err("invalid id", 400);
      const { rows } = await pool.query("SELECT * FROM sources WHERE id = $1::uuid", [id]);
      return rows[0] ? json(rows[0]) : err("not found", 404);
    }
    const { rows } = await pool.query(
      "SELECT * FROM sources WHERE is_active ORDER BY political_lean ASC, name ASC"
    );
    return json(rows, 200, "public, s-maxage=300, stale-while-revalidate=3600");
  } catch (e) {
    console.error(e);
    return err("sources failed");
  }
}
