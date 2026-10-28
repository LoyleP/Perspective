// Keyword topic tagger for story headlines (French + English).
// Keywords are accent-free and lowercase; a trailing "*" matches any word starting
// with the stem, otherwise the keyword must match whole words.

const KEYWORDS: Record<string, string[]> = {
  politique: [
    "election*", "presidentielle*", "legislative*", "municipale*", "gouvernement*", "ministre*",
    "parlement*", "assemblee nationale", "senat", "senateur*", "depute*", "scrutin*", "sondage*",
    "candidat*", "macron", "le pen", "bardella", "melenchon", "retailleau", "attal", "lecornu",
    "edouard philippe", "rassemblement national", "insoumis*", "lfi", "motion de censure",
    "referendum", "parti socialiste", "les republicains", "ecologistes",
    "president", "congress", "senate", "senator*", "prime minister", "trump", "biden", "vance",
    "republican*", "democrat*", "white house", "maison blanche",
  ],
  economie: [
    "econom*", "emploi*", "chomage", "smic", "salaire*", "inflation", "croissance", "budget*",
    "fiscal*", "impot*", "taxe*", "entreprise*", "bourse", "cac 40", "petrole", "carburant*",
    "pouvoir d achat", "faillite*", "dette", "deficit*", "retraite*", "immobilier", "loyer*",
    "banque*", "bce", "fmi", "pib", "licenciement*",
    "tariff*", "stocks", "stock market", "wall street", "jobs", "unemployment", "gdp", "recession",
    "interest rate*", "trade", "oil price*",
  ],
  societe: [
    "education", "ecole*", "enseignant*", "eleve*", "universite*", "sante", "hopital", "hopitaux",
    "medecin*", "greve*", "manifestation*", "mobilisation*", "laicite", "religion*", "immigration",
    "migrant*", "feminicide*", "harcelement", "drogue*", "sncf", "logement*", "pauvrete",
    "school*", "health", "hospital*", "strike*", "protest*", "homeless*",
  ],
  international: [
    "guerre", "ukraine*", "russie", "russe*", "poutine", "zelensky*", "israel*", "gaza", "hamas",
    "hezbollah", "iran*", "liban", "syrie", "chine", "chinois*", "taiwan", "etats unis", "americain*",
    "union europeenne", "otan", "onu", "diplomat*", "espagne", "allemagne", "italie", "royaume uni",
    "bresil*", "inde", "japon", "afrique", "algerie", "maroc", "venezuela", "mexique",
    "war", "russia*", "putin", "gaza", "china", "chinese", "nato", "united nations", "brazil*",
    "india*", "japan*", "spain", "germany", "mexico", "canada", "europe*",
  ],
  environnement: [
    "climat*", "ecolog*", "environnement*", "pollution", "biodiversite", "canicule", "secheresse*",
    "inondation*", "incendie*", "feux de foret", "nucleaire", "energie*", "eolien*", "solaire",
    "emissions", "co2", "tempete*", "ouragan*", "seisme*", "glacier*",
    "climate", "emission*", "wildfire*", "flood*", "hurricane*", "storm*", "heatwave", "drought*",
    "earthquake*", "environment*",
  ],
  justice: [
    "justice", "proces", "tribunal", "tribunaux", "juge", "juges", "jugement", "condamn*",
    "mis en examen", "enquete*", "garde a vue", "prison*", "detenu*", "plainte*", "avocat*",
    "magistrat*", "parquet", "police*", "policier*", "gendarme*", "interpell*", "meurtre*",
    "homicide*", "assassinat*", "attentat*", "agression*",
    "court", "trial", "judge*", "lawsuit*", "sued", "arrest*", "murder*", "crime*", "convicted",
    "indict*", "supreme court",
  ],
  culture: [
    "culture*", "culturel*", "film", "films", "cinema", "serie", "series", "musique", "concert*",
    "album*", "artiste*", "chanteu*", "theatre", "livre", "livres", "roman", "romans",
    "exposition*", "musee*", "patrimoine", "festival*", "cesar", "oscar*", "netflix",
    "movie*", "music", "artist*", "museum*", "book", "books", "grammy*",
  ],
  sport: [
    "sport*", "football", "foot", "ligue 1", "ligue des champions", "psg", "om", "rugby", "tennis",
    "cyclisme", "tour de france", "jeux olympiques", "natation", "basket*", "nba", "formule 1", "f1",
    "match", "matchs", "champion*", "coupe du monde", "mbappe", "bleus",
    "soccer", "nfl", "olympic*", "world cup", "premier league",
  ],
};

function normalize(text: string): string {
  return " " + text
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim() + " ";
}

const MATCHERS: [string, ((text: string) => boolean)[]][] = Object.entries(KEYWORDS).map(
  ([topic, words]) => [
    topic,
    words.map((word) => {
      const stem = normalize(word.replace(/\*$/, "")).trimEnd();
      return word.endsWith("*") ? (text) => text.includes(stem) : (text) => text.includes(stem + " ");
    }),
  ]
);

/** Topics whose keywords appear in any of the given headlines. */
export function topicTags(...titles: string[]): string[] {
  const text = normalize(titles.join(" "));
  return MATCHERS.filter(([, matchers]) => matchers.some((m) => m(text))).map(([topic]) => topic);
}
