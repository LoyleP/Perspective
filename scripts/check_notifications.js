import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://lsznkuiaowesucmxwwfi.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxzem5rdWlhb3dlc3VjbXh3d2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwODQ0NjYsImV4cCI6MjA4OTY2MDQ2Nn0.llsAgcjoJHI9VVZjl8PL0k_HDJhUEzrLjxH5r9TgNgQ';

const supabase = createClient(supabaseUrl, supabaseKey);

const { data, error } = await supabase
  .from('notifications')
  .select('*')
  .order('sent_at', { ascending: false })
  .limit(5);

if (error) {
  console.log('Error:', error.message);
} else {
  console.log(`Found ${data.length} notifications:`);
  console.log(JSON.stringify(data, null, 2));
}
