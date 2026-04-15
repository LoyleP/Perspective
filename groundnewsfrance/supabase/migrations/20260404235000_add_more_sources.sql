-- Add more news sources (French + international) for better story clustering
-- Target: 35 total sources (6 existing + 29 new)

INSERT INTO sources (name, rss_url, url, political_lean, owner_type, lean_source) VALUES
    -- FRENCH SOURCES (13 new)
    -- Center-left
    ('France Info', 'https://www.francetvinfo.fr/titres.rss', 'https://www.francetvinfo.fr', -1, 'state_owned', 'manual'),
    ('Mediapart', 'https://www.mediapart.fr/articles/feed', 'https://www.mediapart.fr', -2, 'independent', 'manual'),
    ('Rue89', 'https://www.nouvelobs.com/rue89/rss.xml', -1, 'private_conglomerate', 'manual'),

    -- Center
    ('Le Point', 'https://www.lepoint.fr/rss.xml', 'https://www.lepoint.fr', 0, 'private_conglomerate', 'manual'),
    ('20 Minutes', 'https://www.20minutes.fr/feeds/rss-une.xml', 'https://www.20minutes.fr', 0, 'private_conglomerate', 'manual'),
    ('France 24', 'https://www.france24.com/fr/france/rss', 'https://www.france24.com', 0, 'state_owned', 'manual'),
    ('La Croix', 'https://www.la-croix.com/RSS/UNIVERS', 'https://www.la-croix.com', 0, 'nonprofit', 'manual'),
    ('Ouest-France', 'https://www.ouest-france.fr/rss/une', 'https://www.ouest-france.fr', 0, 'independent', 'manual'),

    -- Center-right
    ('Le Parisien', 'https://www.leparisien.fr/rss.php', 'https://www.leparisien.fr', 1, 'private_conglomerate', 'manual'),
    ('Paris Match', 'https://www.parismatch.com/rss.xml', 1, 'private_conglomerate', 'manual'),
    ('La Tribune', 'https://www.latribune.fr/rss/a-la-une.html', 1, 'private', 'manual'),

    -- Right
    ('Valeurs Actuelles', 'https://www.valeursactuelles.com/feed', 'https://www.valeursactuelles.com', 2, 'private', 'manual'),
    ('Le Figaro Magazine', 'https://www.lefigaro.fr/rss/figaro_magazine.xml', 1, 'private_conglomerate', 'manual'),

    -- INTERNATIONAL SOURCES (16 new)
    -- US - Left
    ('The Guardian', 'https://www.theguardian.com/world/rss', 'https://www.theguardian.com', -1, 'independent', 'manual'),
    ('NPR', 'https://feeds.npr.org/1001/rss.xml', -1, 'nonprofit', 'manual'),
    ('Politico', 'https://www.politico.com/rss/politics08.xml', -1, 'private', 'manual'),

    -- US - Center
    ('Reuters', 'https://www.reutersagency.com/feed/', 'https://www.reuters.com', 0, 'private_conglomerate', 'manual'),
    ('Associated Press', 'https://www.apnews.com/apf-topnews', 'https://apnews.com', 0, 'cooperative', 'manual'),
    ('BBC News', 'http://feeds.bbci.co.uk/news/world/rss.xml', 0, 'state_owned', 'manual'),

    -- US - Right
    ('The Wall Street Journal', 'https://feeds.a.dj.com/rss/RSSWorldNews.xml', 1, 'private_conglomerate', 'manual'),
    ('Fox News', 'https://moxie.foxnews.com/google-publisher/world.xml', 2, 'private_conglomerate', 'manual'),

    -- Europe
    ('Deutsche Welle', 'https://rss.dw.com/rdf/rss-en-all', 'https://www.dw.com', 0, 'state_owned', 'manual'),
    ('Euronews', 'https://www.euronews.com/rss', 'https://www.euronews.com', 0, 'private', 'manual'),
    ('The Times', 'https://www.thetimes.co.uk/rss', 'https://www.thetimes.co.uk', 1, 'private_conglomerate', 'manual'),
    ('El País', 'https://feeds.elpais.com/mrss-s/pages/ep/site/english.elpais.com/portada', 'https://english.elpais.com', -1, 'private', 'manual'),

    -- Middle East / International
    ('Al Jazeera', 'https://www.aljazeera.com/xml/rss/all.xml', 'https://www.aljazeera.com', -1, 'state_owned', 'manual'),
    ('Haaretz', 'https://www.haaretz.com/cmlink/1.628734', 'https://www.haaretz.com', -1, 'private', 'manual'),

    -- Asia
    ('South China Morning Post', 'https://www.scmp.com/rss/91/feed', 'https://www.scmp.com', 0, 'private', 'manual'),
    ('The Japan Times', 'https://www.japantimes.co.jp/feed/', 'https://www.japantimes.co.jp', 0, 'private', 'manual')

ON CONFLICT (name) DO NOTHING;
