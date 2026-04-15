import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://lsznkuiaowesucmxwwfi.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxzem5rdWlhb3dlc3VjbXh3d2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwODQ0NjYsImV4cCI6MjA4OTY2MDQ2Nn0.llsAgcjoJHI9VVZjl8PL0k_HDJhUEzrLjxH5r9TgNgQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function analyzeArticles() {
  console.log('📊 Analyzing articles and story tags...\n');

  // Get stories with their tags
  const { data: stories, error } = await supabase
    .from('stories')
    .select(`
      id,
      title,
      topic_tags,
      created_at,
      articles (
        title,
        sources ( name )
      )
    `)
    .order('created_at', { ascending: false })
    .limit(30);

  if (error) {
    console.error('Error fetching stories:', error);
    return;
  }

  console.log('=== LATEST 30 STORIES ===\n');
  stories.forEach((story, i) => {
    console.log(`${i + 1}. ${story.title}`);
    console.log(`   Tags: [${story.topic_tags.join(', ') || 'EMPTY'}]`);
    console.log(`   Articles: ${story.articles.length}`);
    if (story.articles.length > 0) {
      console.log(`   Sample title: ${story.articles[0].title}`);
    }
    console.log('');
  });

  // Count untagged stories
  const untagged = stories.filter(s => s.topic_tags.length === 0);
  console.log(`\n=== SUMMARY ===`);
  console.log(`Total stories analyzed: ${stories.length}`);
  console.log(`Untagged stories: ${untagged.length}`);
  console.log(`Tagged stories: ${stories.length - untagged.length}\n`);

  // Tag distribution
  const tagCounts = {};
  stories.forEach(story => {
    story.topic_tags.forEach(tag => {
      tagCounts[tag] = (tagCounts[tag] || 0) + 1;
    });
  });

  console.log('=== TAG DISTRIBUTION ===');
  Object.entries(tagCounts)
    .sort((a, b) => b[1] - a[1])
    .forEach(([tag, count]) => {
      console.log(`${tag}: ${count} stories`);
    });
}

analyzeArticles().catch(console.error);
