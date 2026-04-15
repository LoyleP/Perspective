#!/usr/bin/env node
/**
 * test_rss_feeds.mjs — Test RSS feed accessibility for inactive sources
 */

import Parser from 'rss-parser'

const parser = new Parser({ timeout: 15000 })

const INACTIVE_SOURCES = [
  { name: 'Les Echos', url: 'https://www.lesechos.fr/rss/rss_une.xml' },
  { name: 'RTL', url: 'https://www.rtl.fr/rss/actu.xml' },
  { name: 'Le Figaro', url: 'https://www.lefigaro.fr/rss/figaro_actualites.xml' },
  { name: "L'Opinion", url: 'https://www.lopinion.fr/feed' }
]

async function testFeed(source) {
  console.log(`\nTesting: ${source.name}`)
  console.log(`URL: ${source.url}`)

  try {
    const feed = await parser.parseURL(source.url)
    console.log(`✓ Success - ${feed.items.length} items found`)
    console.log(`  Title: ${feed.title}`)
    if (feed.items.length > 0) {
      console.log(`  Latest: ${feed.items[0].title}`)
    }
    return { source: source.name, status: 'success', count: feed.items.length }
  } catch (error) {
    console.log(`✗ Failed - ${error.message}`)
    return { source: source.name, status: 'failed', error: error.message }
  }
}

async function main() {
  console.log('=== Testing Inactive RSS Feeds ===')

  const results = []
  for (const source of INACTIVE_SOURCES) {
    const result = await testFeed(source)
    results.push(result)
  }

  console.log('\n=== Summary ===')
  const working = results.filter(r => r.status === 'success')
  const broken = results.filter(r => r.status === 'failed')

  console.log(`\nWorking: ${working.length}`)
  working.forEach(r => console.log(`  ✓ ${r.source} (${r.count} items)`))

  console.log(`\nBroken: ${broken.length}`)
  broken.forEach(r => console.log(`  ✗ ${r.source} - ${r.error}`))
}

main()
