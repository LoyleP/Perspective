# App Store Connect Metadata

## App Information

**App Name:** Perspective - Actualités France
**Subtitle:** Analyse du spectre politique
**Bundle ID:** (votre bundle identifier, ex: com.arthurfondeville.perspective)
**SKU:** perspective-ios
**Primary Language:** French (France)

---

## Version Information (1.0)

### Description (French)

```
Perspective vous aide à comprendre l'actualité française sous tous les angles politiques.

FONCTIONNALITÉS

• Analyse du spectre politique de chaque sujet d'actualité
• Suivi de la propriété des médias français
• Couverture par orientation politique (gauche, centre, droite)
• Alertes push pour les nouvelles histoires importantes
• Comparaison des sources par biais politique éditorial

COMMENT ÇA MARCHE

Perspective agrège les articles de dizaines de sources françaises et affiche comment chaque orientation politique couvre les mêmes événements. Comprenez les angles morts médiatiques et découvrez la diversité des perspectives sur l'actualité.

Chaque source est classée sur un spectre de 7 positions, de l'extrême-gauche à l'extrême-droite, basé sur une analyse éditoriale approfondie.

TRANSPARENCE MÉDIATIQUE

Consultez les informations de propriété pour chaque média et comprenez les intérêts économiques derrière l'information que vous consommez.

GRATUIT ET SANS PUB

L'application est entièrement gratuite, sans publicité. Votre vie privée est respectée : aucune donnée personnelle n'est collectée.
```

**Character count:** ~985/4000

### Keywords (French)

```
actualités,nouvelles,politique,médias,presse,gauche,droite,analyse,spectre,france
```

**Character count:** 86/100

### What's New (Version 1.0)

```
Première version de Perspective pour iOS.

Fonctionnalités :
• Fil d'actualité personnalisé
• Analyse du spectre politique
• Suivi de la propriété des médias
• Notifications pour nouveaux sujets
• Mode sombre
```

### Promotional Text (optional, appears above description)

```
Comprenez l'actualité sous tous les angles politiques.
```

---

## App Store Review Information

### Contact Information
- **First Name:** Arthur
- **Last Name:** F.
- **Phone Number:** (votre numéro de téléphone)
- **Email:** arthur.fondevillepro@gmail.com

### Sign-In Required:** No (app is read-only, no authentication)

### Notes for Reviewer:

```
L'application agrège des actualités françaises publiques provenant d'une base de données Supabase.

Aucune authentification n'est requise - l'accès est anonyme en lecture seule.

Les notifications push sont optionnelles et peuvent être testées via Paramètres → Développeur → Tester les notifications (builds Debug uniquement).

Toutes les fonctionnalités sont accessibles sans compte utilisateur.
```

---

## App Privacy

### Privacy Policy URL
https://loylep.github.io/Perspective/legal/privacy-policy

### Privacy Practices (Privacy Nutrition Label)

**Data Not Collected:** You must select this option

Aucune donnée n'est collectée ou transmise. Tout est stocké localement :
- Préférences de notifications → UserDefaults (local)
- Thème de l'app → UserDefaults (local)
- Signets → UserDefaults (local)
- État onboarding → UserDefaults (local)

**No tracking:** Confirmez que l'app ne suit pas les utilisateurs

---

## Age Rating

Répondre au questionnaire App Store Connect :

| Question | Réponse |
|----------|---------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | **Infrequent/Mild** |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Unrestricted Web Access | **Yes** (articles ouvrent sites externes) |
| Contests | None |

**Expected Rating:** 12+ (en raison de "Unrestricted Web Access" + thèmes politiques)

---

## App Review Attachments

### Demo Account
**Not required** (app ne nécessite pas de compte)

### Review Notes
Voir "Notes for Reviewer" ci-dessus

---

## Categories

**Primary Category:** News
**Secondary Category:** (optional) Reference

---

## Pricing and Availability

**Price:** Free
**Availability:** France (ou tous les pays)

---

## App Store Distribution

### Export Compliance

**Question:** "Does your app use encryption?"

**Réponse:** Yes (HTTPS utilise encryption)

**Follow-up:** "Does your app qualify for any of the exemptions provided in Category 5, Part 2 of the U.S. Export Administration Regulations?"

**Réponse:** Yes - Standard encryption only (HTTPS/TLS pour connexions réseau)

Pas besoin de documentation export compliance pour HTTPS standard.

---

## Support & Marketing

**Support URL:** https://github.com/LoyleP/Perspective
**Marketing URL:** (optional - laisser vide ou créer landing page)
**Copyright:** 2026 Arthur F.

---

## Screenshots Required

Préparer avant soumission :

### iPhone 6.7" (iPhone 15 Pro Max, 14 Pro Max)
- Résolution: 1290 × 2796 pixels
- Minimum: 1 screenshot, Maximum: 10
- Recommandé: 4-5 screenshots

**Écrans suggérés:**
1. Feed view (fil d'actualité)
2. Story detail avec spectrum summary
3. Coverage chart (graphique couverture)
4. Sources view (propriété médias)
5. Settings (optionnel)

### iPhone 6.5" (iPhone 14 Plus, 13 Pro Max, 12 Pro Max)
- Résolution: 1242 × 2688 pixels
- Requis si vous supportez ces devices

### iPad Pro 12.9" (3rd gen)
- Résolution: 2048 × 2732 pixels
- Requis si app optimisée pour iPad

### App Preview Video (optional)
- Format: .mov, .m4v, .mp4
- Durée: 15-30 secondes
- Portrait orientation

---

## Pre-Submission Checklist

Avant de cliquer "Submit for Review":

- [ ] GitHub Pages activé (privacy policy accessible)
- [ ] Tous les screenshots uploadés (toutes tailles requises)
- [ ] Description et keywords remplis
- [ ] Age rating questionnaire complété
- [ ] Privacy Nutrition Label configuré (Data Not Collected)
- [ ] Support URL valide
- [ ] Build uploadé via Xcode (Archive → Distribute)
- [ ] Build sélectionné pour review
- [ ] Export compliance répondu (Yes → Standard encryption)
- [ ] Testé sur device physique (pas seulement simulateur)

---

## Après Soumission

**Délai de review:** 1-3 jours généralement

**Statuts possibles:**
- "Waiting for Review" → en attente
- "In Review" → examen en cours
- "Ready for Sale" → approuvé ✅
- "Rejected" → refusé (lire rejection reasons, corriger, re-soumettre)

**Si rejeté:** Lire attentivement les raisons, corriger, incrementer build number, re-soumettre.
