-- Tag all stories by topic using keyword matching on title.
-- Safe to re-run: always overwrites topic_tags from scratch.
-- Add new keywords to the relevant array as the database grows.

UPDATE stories SET topic_tags = '{}';

UPDATE stories SET topic_tags = array_append(topic_tags, 'politique')
WHERE title ILIKE ANY (ARRAY[
    '%municipale%', '%présidentielle%', '%élection%', '%gouvernement%',
    '%ministre%', '%parlement%', '%assemblée%', '%sénat%', '%député%',
    '%maire%', '%mairie%', '%RN%', '%LFI%', '%LR%', '%PS %', '%PCF%',
    '%Mélenchon%', '%Macron%', '%Le Pen%', '%Glucksmann%', '%Philippe%',
    '%Villepin%', '%Jospin%', '%Bregeon%', '%Coquerel%', '%Evren%',
    '%Grégoire%', '%Tondelier%', '%parti%', '%vote%', '%scrutin%',
    '%suffrage%', '%candidat%', '%campagne%', '%coalition%', '%gauche%',
    '%droite%', '%centre%', '%immigration%', '%migrant%', '%frontière%',
    '%Rassemblement national%', '%La France insoumise%', '%insoumis%',
    '%audiovisuel public%', '%France Inter%'
]);

UPDATE stories SET topic_tags = array_append(topic_tags, 'economie')
WHERE title ILIKE ANY (ARRAY[
    '%économi%', '%emploi%', '%chômage%', '%smic%', '%salaire%',
    '%inflation%', '%croissance%', '%budget%', '%fiscal%', '%impôt%',
    '%taxe%', '%entreprise%', '%marché%', '%bourse%', '%pétrole%',
    '%énergie%', '%carburant%', '%chèque énergie%', '%prime%',
    '%pouvoir d''achat%', '%liquidation%', '%faillite%', '%trader%',
    '%G7%', '%G20%', '%BCE%', '%FMI%', '%dette%', '%déficit%',
    '%retraite%', '%sécurité sociale%', '%arrêt maladie%',
    '%chômage partiel%', '%Air Canada%', '%Air France%', '%Transavia%',
    '%Alinea%', '%livreur%', '%Prisma%', '%immobilier%', '%logement%',
    '%loyer%', '%expulsion%'
]);

UPDATE stories SET topic_tags = array_append(topic_tags, 'societe')
WHERE title ILIKE ANY (ARRAY[
    '%société%', '%social%', '%féminicide%', '%agression%', '%viol%',
    '%violence%', '%meurtre%', '%tuée%', '%tué%', '%mort%',
    '%prison%', '%détenu%', '%garde à vue%', '%interpellé%',
    '%gendarme%', '%police%', '%sécurité%', '%transport%',
    '%école%', '%éducation%', '%enseignant%', '%grève%',
    '%santé%', '%hôpital%', '%médecin%', '%RSA%', '%allocataire%',
    '%religion%', '%baptême%', '%église%', '%réseaux sociaux%',
    '%TikTok%', '%Instagram%', '%YouTube%', '%PFAS%',
    '%nom de famille%', '%Sidaction%', '%VIH%', '%pénibilité%',
    '%livreur%', '%carnaval%', '%manifestation%', '%pêcheur%',
    '%trêve hivernale%'
]);

UPDATE stories SET topic_tags = array_append(topic_tags, 'international')
WHERE title ILIKE ANY (ARRAY[
    '%Sénégal%', '%Chili%', '%Panama%', '%Équateur%', '%Haïti%',
    '%Birmanie%', '%Ukraine%', '%Poutine%', '%Russie%', '%Serbie%',
    '%Espagne%', '%Australie%', '%Danemark%', '%Suède%', '%Italie%',
    '%Népal%', '%Japon%', '%Bosnie%', '%Argentine%', '%Roumanie%',
    '%Nouvelle-Calédonie%', '%Réunion%', '%Algérie%', '%Afrique%',
    '%Europe%', '%UE%', '%parlement européen%', '%Lavrov%',
    '%migrant%', '%migration%', '%international%', '%mondial%',
    '%accord%', '%traité%', '%conflit%', '%guerre%', '%diplomatie%',
    '%Kast%', '%Vucic%', '%flotte fantôme%'
]);

UPDATE stories SET topic_tags = array_append(topic_tags, 'environnement')
WHERE title ILIKE ANY (ARRAY[
    '%environnement%', '%climat%', '%écologi%', '%énergie%',
    '%nucléaire%', '%EDF%', '%réacteur%', '%PFAS%', '%pollution%',
    '%pêche%', '%haie%', '%reforestation%', '%espèce%', '%animal%',
    '%élevage%', '%incendie%', '%volcanique%', '%Fournaise%',
    '%eau%', '%Nestlé%', '%Sainte-Soline%', '%biodiversité%',
    '%migration animal%', '%requin%', '%loutre%', '%chouette%'
]);

UPDATE stories SET topic_tags = array_append(topic_tags, 'justice')
WHERE title ILIKE ANY (ARRAY[
    '%justice%', '%jugé%', '%procès%', '%tribunal%', '%condamné%',
    '%inculpé%', '%mis en examen%', '%arrêté%', '%poursuivi%',
    '%peine%', '%prison%', '%détenu%', '%garde à vue%', '%acquitté%',
    '%recours%', '%plainte%', '%UFC Que Choisir%', '%Ubisoft%',
    '%loge Athanor%', '%Emiliano Sala%', '%Kevin Escoffier%',
    '%dopage%', '%suspendu%', '%évasion fiscale%', '%corruption%',
    '%Cédric%', '%féminicide%', '%agression sexuelle%',
    '%narcotrafiquant%', '%banquier russe%'
]);

UPDATE stories SET topic_tags = array_append(topic_tags, 'culture')
WHERE title ILIKE ANY (ARRAY[
    '%culture%', '%film%', '%cinéma%', '%série%', '%musique%',
    '%concert%', '%album%', '%artiste%', '%théâtre%', '%livre%',
    '%roman%', '%exposition%', '%musée%', '%patrimoine%',
    '%CANNESERIES%', '%Zendaya%', '%Pattinson%', '%Céline Dion%',
    '%Theodora%', '%Isabelle Mergault%', '%Gims%',
    '%Renoir%', '%Cézanne%', '%Matisse%', '%volé%',
    '%France Inter%', '%Nagui%', '%Sophia Aram%',
    '%football%', '%tennis%', '%cyclisme%', '%natation%',
    '%sport%', '%match%', '%champion%', '%médaille%',
    '%Vingegaard%', '%Dzeko%', '%Korir%', '%marathon%',
    '%Coton%', '%Cizeron%', '%Fournier%', '%OM%', '%PSG%',
    '%Lens%', '%LOSC%', '%Nantes%', '%Marseille%',
    '%jeu vidéo%', '%cerisier%'
]);

-- Fallback: any story still untagged gets 'societe' (broad catch-all)
UPDATE stories SET topic_tags = ARRAY['societe']
WHERE topic_tags = '{}';
