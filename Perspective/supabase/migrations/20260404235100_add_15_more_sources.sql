-- Add 15 more international and French sources to reach 50 total
-- Focus on major news outlets with reliable RSS feeds

INSERT INTO sources (name, rss_url, url, political_lean, owner_type, lean_source) VALUES
    -- FRENCH SOURCES (5 more)
    ('Le Nouvel Obs', 'https://www.nouvelobs.com/rss.xml', 'https://www.nouvelobs.com', -1, 'private_conglomerate', 'manual'),
    ('Marianne', 'https://www.marianne.net/rss.xml', 'https://www.marianne.net', -1, 'private', 'manual'),
    ('Sud Ouest', 'https://www.sudouest.fr/rss/', 'https://www.sudouest.fr', 0, 'private', 'manual'),
    ('Nice-Matin', 'https://www.nicematin.com/rss', 'https://www.nicematin.com', 0, 'private', 'manual'),
    ('BFM TV', 'https://www.bfmtv.com/rss/info/flux-rss/flux-toutes-les-actualites/', 'https://www.bfmtv.com', 1, 'private_conglomerate', 'manual'),

    -- US SOURCES (4 more)
    ('CNN', 'http://rss.cnn.com/rss/cnn_topstories.rss', 'https://www.cnn.com', -1, 'private_conglomerate', 'manual'),
    ('The New York Times', 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml', 'https://www.nytimes.com', -1, 'private', 'manual'),
    ('The Washington Post', 'https://feeds.washingtonpost.com/rss/world', 'https://www.washingtonpost.com', -1, 'private', 'manual'),
    ('USA Today', 'http://rssfeeds.usatoday.com/usatoday-NewsTopStories', 'https://www.usatoday.com', 0, 'private_conglomerate', 'manual'),

    -- EUROPE (4 more)
    ('The Independent', 'https://www.independent.co.uk/news/world/rss', 'https://www.independent.co.uk', -1, 'private', 'manual'),
    ('The Telegraph', 'https://www.telegraph.co.uk/rss.xml', 'https://www.telegraph.co.uk', 1, 'private', 'manual'),
    ('Spiegel International', 'https://www.spiegel.de/international/index.rss', 'https://www.spiegel.de', 0, 'private', 'manual'),
    ('Le Soir (Belgium)', 'https://www.lesoir.be/rss/section/actualite', 'https://www.lesoir.be', 0, 'private', 'manual'),

    -- INTERNATIONAL (2 more)
    ('The Hindu', 'https://www.thehindu.com/news/international/feeder/default.rss', 'https://www.thehindu.com', -1, 'private', 'manual'),
    ('The Australian', 'https://www.theaustralian.com.au/feed/', 'https://www.theaustralian.com.au', 1, 'private_conglomerate', 'manual')

ON CONFLICT (name) DO NOTHING;
