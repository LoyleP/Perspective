import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const SUPABASE_URL = "https://lsznkuiaowesucmxwwfi.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!SUPABASE_SERVICE_ROLE_KEY) {
  console.error("SUPABASE_SERVICE_ROLE_KEY environment variable not set");
  Deno.exit(1);
}

async function testReformatting() {
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Fetch all stories
  const { data: stories, error } = await supabase
    .from("stories")
    .select("id, title, original_title, title_reformatted_at")
    .order("created_at", { ascending: false })
    .limit(10);

  if (error) {
    console.error("Error fetching stories:", error);
    throw error;
  }

  console.log(`\n=== Found ${stories.length} stories ===\n`);

  for (const story of stories) {
    console.log(`ID: ${story.id}`);
    console.log(`Title (${story.title.length} chars): ${story.title}`);
    console.log(`Original: ${story.original_title || "N/A"}`);
    console.log(`Reformatted at: ${story.title_reformatted_at || "Not yet"}`);
    console.log("---");
  }

  // Check if any were reformatted
  const reformattedCount = stories.filter((s) => s.original_title).length;
  console.log(`\n${reformattedCount} / ${stories.length} stories have been reformatted`);

  if (reformattedCount < stories.length) {
    console.log("\nWaiting 10 seconds for async reformatting to complete...");
    await new Promise((resolve) => setTimeout(resolve, 10000));

    // Re-fetch to check again
    const { data: updatedStories } = await supabase
      .from("stories")
      .select("id, title, original_title")
      .order("created_at", { ascending: false })
      .limit(10);

    const newReformattedCount = updatedStories?.filter((s) => s.original_title).length || 0;
    console.log(`After waiting: ${newReformattedCount} / ${stories.length} stories reformatted`);

    if (newReformattedCount === reformattedCount) {
      console.log("\n⚠️  No new reformatting occurred. Manually triggering...");

      for (const story of stories) {
        if (!story.original_title) {
          console.log(`\nTriggering reformatting for: "${story.title}"`);
          const { data, error: invokeError } = await supabase.functions.invoke(
            "reformat-story-title",
            { body: { story_id: story.id } }
          );

          if (invokeError) {
            console.error(`  ✗ Failed:`, invokeError);
          } else {
            console.log(`  ✓ Success:`, data);
          }
        }
      }
    }
  }
}

testReformatting();
