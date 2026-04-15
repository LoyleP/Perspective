#!/usr/bin/env node
/**
 * ingest.mjs — RSS ingestion script for Perspective
 *
 * Fetches articles from seeded French sources over the past N days,
 * clusters them into stories using keyword-overlap heuristics, and
 * upserts everything into Supabase using the service role key.
 *
 * Usage:
 *   cd scripts && npm install
 *   export SUPABASE_SERVICE_KEY=your_service_role_key
 *   node ingest.mjs
 *
 * Get the service role key from:
 *   Supabase Dashboard → Project Settings → API → service_role (secret)
 *
 * Requirements: Node.js 18+
 */

import { createClient } from '@supabase/supabase-js'
import Parser from 'rss-parser'

// ─── Config ───────────────────────────────────────────────────────────────────

const SUPABASE_URL         = 'https://lsznkuiaowesucmxwwfi.supabase.co'
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY

const DAYS_BACK                    = 7
const CLUSTER_WINDOW_HOURS         = 36    // max hours between articles in the same story
const CLUSTER_SIMILARITY_THRESHOLD = 0.18  // Jaccard overlap required to merge
const MAX_FEATURED_STORIES         = 3     // top N by source count get is_featured = true

// ─── Bootstrap ────────────────────────────────────────────────────────────────

if (!SUPABASE_SERVICE_KEY) {
  console.error('Error: SUPABASE_SERVICE_KEY env var is required.')
  console.error('  export SUPABASE_SERVICE_KEY=your_service_role_key')
  process.exit(1)
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false }
})

const rssParser = new Parser({
  timeout: 15_000,
  customFields: {
    item: [
      ['media:content', 'mediaContent'],
      ['media:thumbnail', 'mediaThumbnail'],
      ['enclosure', 'enclosure'],
      ['content:encoded', 'contentEncoded']
    ]
  }
})

// ─── French stopwords ─────────────────────────────────────────────────────────

const STOPWORDS = new Set([
  'les', 'des', 'une', 'est', 'pas', 'que', 'qui', 'dans', 'sur', 'avec',
  'pour', 'par', 'son', 'ses', 'leur', 'leurs', 'aux', 'plus', 'tout', 'cette',
  'mais', 'elle', 'ils', 'elles', 'nous', 'vous', 'etre', 'avoir', 'fait',
  'faire', 'dit', 'dire', 'depuis', 'apres', 'avant', 'entre', 'aussi',
  'comme', 'donc', 'alors', 'ainsi', 'encore', 'tres', 'bien', 'meme',
  'deja', 'lors', 'sous', 'sans', 'selon', 'vers', 'face', 'dont', 'tous',
  'toutes', 'chaque', 'certains', 'certaines', 'celui', 'celle', 'ceux',
  'cent', 'deux', 'trois', 'quatre', 'cinq', 'sept', 'huit', 'neuf', 'dix',
  'lors', 'parmi', 'contre', 'quand', 'etait', 'sera', 'serait', 'peut',
  'vont', 'faut', 'doit', 'doivent', 'autre', 'autres', 'nouveau', 'grande',
  'grand', 'premiers', 'premier', 'annee', 'annees', 'pays', 'france',
  'francais', 'francaise', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi',
  'samedi', 'dimanche', 'janvier', 'fevrier', 'mars', 'avril', 'juin', 'juillet',
  'aout', 'septembre', 'octobre', 'novembre', 'decembre', 'entre', 'milliards',
  'millions', 'euros', 'cent', 'rapport', 'pendant', 'aujourd', 'hier', 'demain'
])

// ─── Topic inference ──────────────────────────────────────────────────────────

const TOPIC_RULES = [
  {
    tag: 'Politique',
    terms: ['gouvernement', 'assemblee', 'senat', 'parlement', 'election', 'ministre',
            'president', 'macron', 'premier ministre', 'vote', 'parti', 'opposition',
            'majorite', 'reforme', 'politique', 'gauche', 'droite', 'depute', 'coalition',
            'cabinet', 'decret', 'premier ministre', 'bayrou', 'barnier', 'melenchon',
            'rassemblement', 'socialiste', 'renaissance', 'republicans']
  },
  {
    tag: 'Économie',
    terms: ['economie', 'budget', 'inflation', 'chomage', 'emploi', 'croissance', 'pib',
            'impot', 'taxe', 'retraite', 'smic', 'entreprise', 'banque', 'marche', 'dette',
            'deficit', 'commerce', 'industrie', 'salaire', 'bourse', 'investissement',
            'pouvoir achat', 'prix', 'cout', 'exportation', 'importation']
  },
  {
    tag: 'International',
    terms: ['ukraine', 'russie', 'gaza', 'trump', 'europe', 'europeenne', 'chine', 'etats-unis',
            'conflit', 'guerre', 'paix', 'sommet', 'otan', 'international', 'mondial',
            'proche-orient', 'israel', 'iran', 'syrie', 'liban', 'afrique', 'asie',
            'diplomatie', 'accord', 'traite', 'sanctions', 'ambassadeur']
  },
  {
    tag: 'Société',
    terms: ['societe', 'police', 'violence', 'securite', 'education', 'ecole', 'universite',
            'sante', 'hopital', 'logement', 'immigration', 'social', 'syndicat', 'greve',
            'chomage', 'pauvrete', 'discrimination', 'religion', 'famille', 'enfants',
            'jeunes', 'personnes agees', 'handicap', 'inegalites', 'racisme']
  },
  {
    tag: 'Justice',
    terms: ['tribunal', 'proces', 'jugement', 'condamne', 'justice', 'arrestation', 'prison',
            'peine', 'audience', 'parquet', 'garde a vue', 'inculpe', 'acquitte', 'appel',
            'cour', 'juge', 'avocat', 'victime', 'plainte', 'enquete', 'instruction']
  },
  {
    tag: 'Environnement',
    terms: ['climat', 'environnement', 'co2', 'energie', 'nucleaire', 'ecologie', 'rechauffement',
            'pollution', 'renouvelable', 'biodiversite', 'dechets', 'carbone', 'emission',
            'transition', 'solaire', 'eolien', 'seisme', 'inondation', 'canicule', 'incendie']
  },
  {
    tag: 'Culture',
    terms: ['culture', 'cinema', 'film', 'musique', 'exposition', 'livre', 'roman', 'art',
            'theatre', 'festival', 'prix', 'recompense', 'cesar', 'bouker', 'academie',
            'spectacle', 'concert', 'album', 'serie', 'television', 'streaming']
  }
]

function normalize(text) {
  return text.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/['']/g, "'")
}

function inferTopics(text) {
  const n = normalize(text)
  const matched = TOPIC_RULES.filter(({ terms }) => terms.some(t => n.includes(t)))
  return matched.length > 0 ? matched.slice(0, 2).map(r => r.tag) : ['Société']
}

// ─── Keyword extraction ───────────────────────────────────────────────────────

function extractKeywords(text) {
  return new Set(
    normalize(text)
      .replace(/[^a-z\s]/g, ' ')
      .split(/\s+/)
      .filter(w => w.length > 3 && !STOPWORDS.has(w))
  )
}

function jaccardSimilarity(a, b) {
  const intersection = [...a].filter(w => b.has(w)).length
  const union = new Set([...a, ...b]).size
  return union === 0 ? 0 : intersection / union
}

// ─── Image extraction ─────────────────────────────────────────────────────────

function extractImage(item) {
  if (item.mediaContent?.$?.url)   return item.mediaContent.$.url
  if (item.mediaThumbnail?.$?.url) return item.mediaThumbnail.$.url
  if (item.enclosure?.url && item.enclosure.type?.startsWith('image/')) return item.enclosure.url
  const html = item.contentEncoded ?? item.content ?? ''
  return html.match(/<img[^>]+src=["']([^"']+)["']/i)?.[1] ?? null
}

// ─── Story clustering ─────────────────────────────────────────────────────────

function clusterArticles(articles) {
  const sorted = [...articles].sort((a, b) => a.publishedAt - b.publishedAt)
  const clusters = []

  for (const article of sorted) {
    const kw = extractKeywords(article.title + ' ' + (article.summary ?? ''))
    let assigned = false

    for (const cluster of clusters) {
      const rep    = cluster.rep
      const hrs    = Math.abs(article.publishedAt - rep.publishedAt) / 3_600_000
      if (hrs > CLUSTER_WINDOW_HOURS) continue
      if (jaccardSimilarity(kw, rep.keywords) >= CLUSTER_SIMILARITY_THRESHOLD) {
        cluster.articles.push(article)
        assigned = true
        break
      }
    }

    if (!assigned) {
      clusters.push({ rep: { ...article, keywords: kw }, articles: [article], featured: false })
    }
  }

  // Mark top N by article count as featured
  const byCount = [...clusters].sort((a, b) => b.articles.length - a.articles.length)
  for (let i = 0; i < Math.min(MAX_FEATURED_STORIES, byCount.length); i++) {
    byCount[i].featured = true
  }

  return clusters
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  const cutoff = new Date(Date.now() - DAYS_BACK * 24 * 3600 * 1000)
  console.log(`Ingesting articles from the past ${DAYS_BACK} days (since ${cutoff.toISOString()})\n`)

  // 1. Load active sources
  const { data: sources, error: srcErr } = await supabase
    .from('sources').select('*').eq('is_active', true)
  if (srcErr) throw srcErr
  console.log(`Loaded ${sources.length} sources\n`)

  // 2. Fetch RSS feeds
  const allArticles = []
  for (const source of sources) {
    try {
      process.stdout.write(`  Fetching ${source.name.padEnd(20)}`)
      const feed = await rssParser.parseURL(source.rss_url)
      let count  = 0

      for (const item of feed.items) {
        const pub = new Date(item.isoDate ?? item.pubDate ?? Date.now())
        if (pub < cutoff) continue
        const url = item.link ?? item.guid ?? ''
        if (!url || !item.title) continue

        allArticles.push({
          sourceId:    source.id,
          title:       item.title.trim(),
          url,
          summary:     item.contentSnippet?.slice(0, 600) ?? null,
          imageURL:    extractImage(item),
          publishedAt: pub
        })
        count++
      }

      console.log(`→ ${count} articles`)
    } catch (err) {
      console.log(`✗ ${err.message}`)
    }

    // Polite delay between requests
    await new Promise(r => setTimeout(r, 600))
  }

  if (allArticles.length === 0) {
    console.log('\nNo articles fetched — check RSS URLs or network access.')
    return
  }

  console.log(`\nTotal: ${allArticles.length} articles → clustering…`)

  // 3. Cluster into stories
  const clusters = clusterArticles(allArticles)
  console.log(`Formed ${clusters.length} story clusters\n`)

  // 4. Upsert into Supabase
  let storiesOk = 0, articlesOk = 0, errors = 0

  for (const cluster of clusters) {
    const { rep, articles, featured } = cluster
    const dates    = articles.map(a => a.publishedAt.getTime())
    const firstPub = new Date(Math.min(...dates))
    const lastPub  = new Date(Math.max(...dates))
    const topicSrc = articles.map(a => a.title).join(' ')

    // Insert story (always new — re-runs create new stories for new articles)
    const { data: story, error: storyErr } = await supabase
      .from('stories')
      .insert({
        title:              rep.title,
        summary:            rep.summary,
        first_published_at: firstPub.toISOString(),
        last_updated_at:    lastPub.toISOString(),
        topic_tags:         inferTopics(topicSrc),
        is_featured:        featured
      })
      .select('id')
      .single()

    if (storyErr) {
      console.warn(`  Story error: ${storyErr.message}`)
      errors++
      continue
    }
    storiesOk++

    // Upsert articles (skip on url conflict — avoids reassigning story_id on re-runs)
    for (const art of articles) {
      const { error: artErr } = await supabase
        .from('articles')
        .upsert({
          source_id:    art.sourceId,
          title:        art.title,
          url:          art.url,
          summary:      art.summary,
          image_url:    art.imageURL,
          published_at: art.publishedAt.toISOString(),
          story_id:     story.id,
          raw_keywords: [...extractKeywords(art.title)],
          click_count:  0
        }, { onConflict: 'url', ignoreDuplicates: true })

      if (artErr) { errors++;  }
      else        { articlesOk++ }
    }
  }

  console.log('─'.repeat(40))
  console.log(`Stories inserted : ${storiesOk}`)
  console.log(`Articles upserted: ${articlesOk}`)
  if (errors > 0) console.log(`Errors           : ${errors}`)
  console.log('\nDone. Refresh the app to see new content.')
}

main().catch(err => { console.error('\nFatal:', err.message); process.exit(1) })
