#!/usr/bin/env node
/**
 * test_alternative_feeds.mjs — Test alternative RSS feed URLs
 */

import Parser from 'rss-parser'

const parser = new Parser({ timeout: 15000 })

const ALTERNATIVES = [
  // Les Echos alternatives
  { name: 'Les Echos - Alternative 1', url: 'https://www.lesechos.fr/rss/homepage.xml' },
  { name: 'Les Echos - Alternative 2', url: 'https://www.lesechos.fr/rss.xml' },

  // RTL alternatives
  { name: 'RTL - Alternative 1', url: 'https://www.rtl.fr/rss/une.xml' },
  { name: 'RTL - Alternative 2', url: 'https://www.rtl.fr/actu/rss' },

  // L'Opinion alternatives
  { name: "L'Opinion - Alternative 1", url: 'https://www.lopinion.fr/rss' },
  { name: "L'Opinion - Alternative 2", url: 'https://www.lopinion.fr/rss.xml' },
]

async function testFeed(source) {
  console.log(`Testing: ${source.url}`)

  try {
    const feed = await parser.parseURL(source.url)
    console.log(`  ✓ Success - ${feed.items.length} items`)
    if (feed.items.length > 0) {
      console.log(`    Latest: ${feed.items[0].title?.slice(0, 80)}`)
    }
    return { ...source, status: 'success', count: feed.items.length }
  } catch (error) {
    console.log(`  ✗ Failed - ${error.message}`)
    return { ...source, status: 'failed', error: error.message }
  }
}

async function main() {
  console.log('=== Testing Alternative RSS Feeds ===\n')

  const results = []
  for (const source of ALTERNATIVES) {
    const result = await testFeed(source)
    results.push(result)
  }

  console.log('\n=== Working Feeds ===')
  const working = results.filter(r => r.status === 'success')

  if (working.length === 0) {
    console.log('None found')
  } else {
    working.forEach(r => {
      console.log(`\n${r.name}`)
      console.log(`  URL: ${r.url}`)
      console.log(`  Items: ${r.count}`)
    })
  }
}

main()
