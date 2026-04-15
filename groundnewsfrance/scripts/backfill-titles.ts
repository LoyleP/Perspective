import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const SUPABASE_URL = "https://lsznkuiaowesucmxwwfi.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY environment variable not set");
  Deno.exit(1);
}

async function backfillTitles() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Fetch all stories without reformatted titles
  const { data: stories, error } = await supabase
    .from("stories")
    .select("id, title")
    .is("original_title", null)
    .order("created_at", { ascending: false })
    .limit(1000);

  if (error) {
    console.error("Error fetching stories:", error);
    throw error;
  }

  console.log(`Found ${stories.length} stories to reformat`);

  let successCount = 0;
  let failCount = 0;

  for (const story of stories) {
    console.log(`Reformatting story ${story.id}: "${story.title}"`);

    try {
      const { data, error: invokeError } = await supabase.functions.invoke(
        "reformat-story-title",
        { body: { story_id: story.id } }
      );

      if (invokeError) {
        console.error(`  ✗ Failed: ${invokeError.message}`);
        failCount++;
      } else {
        console.log(`  ✓ Success: "${data.reformatted_title || data.title}"`);
        successCount++;
      }

      // Rate limit: 10 requests/second (Gemini free tier limit)
      await new Promise((resolve) => setTimeout(resolve, 100));
    } catch (err) {
      console.error(`  ✗ Exception for ${story.id}:`, err);
      failCount++;
      continue;
    }
  }

  console.log("\n=== Backfill Complete ===");
  console.log(`Success: ${successCount}`);
  console.log(`Failed: ${failCount}`);
  console.log(`Total: ${stories.length}`);
}

backfillTitles();
