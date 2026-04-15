#!/usr/bin/env node
/**
 * check_sources.js — Query all sources and show their active status
 */

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://lsznkuiaowesucmxwwfi.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxzem5rdWlhb3dlc3VjbXh3d2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwODQ0NjYsImV4cCI6MjA4OTY2MDQ2Nn0.llsAgcjoJHI9VVZjl8PL0k_HDJhUEzrLjxH5r9TgNgQ'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

async function checkSources() {
  const { data, error } = await supabase
    .from('sources')
    .select('*')
    .order('political_lean', { ascending: true })

  if (error) {
    console.error('Error:', error)
    return
  }

  console.log('\n=== All Sources ===\n')

  const active = data.filter(s => s.is_active)
  const inactive = data.filter(s => !s.is_active)

  console.log(`Active sources: ${active.length}`)
  console.log(`Inactive sources: ${inactive.length}\n`)

  console.log('Active:')
  active.forEach(s => {
    console.log(`  ${s.political_lean} | ${s.name.padEnd(25)} | ${s.rss_url}`)
  })

  if (inactive.length > 0) {
    console.log('\nInactive:')
    inactive.forEach(s => {
      console.log(`  ${s.political_lean} | ${s.name.padEnd(25)} | ${s.rss_url}`)
    })
  }
}

checkSources()
