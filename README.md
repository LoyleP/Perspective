# Perspective - Ground News France

Perspective est une application iOS qui agrège et affiche des articles de presse française avec une analyse du spectre politique.

---

## 🚀 Quick Start - Télécharger et Tester l'App

### Prérequis

- **macOS** avec Xcode 15.0+ installé
- **iOS 17.0+** (simulateur ou appareil physique)
- Connexion internet (pour les dépendances Swift Package Manager)

### Installation en 4 Étapes

#### 1. Cloner le projet

```bash
git clone https://github.com/[votre-username]/perspective.git
cd perspective
```

#### 2. Ouvrir le projet dans Xcode

```bash
open Perspective/Perspective.xcodeproj
```

**Note**: Ouvrir `Perspective.xcodeproj`, PAS `.xcworkspace` (le projet utilise Swift Package Manager, pas CocoaPods).

#### 3. Configuration Supabase (optionnel)

Le projet inclut des **credentials Supabase par défaut** pour démarrer immédiatement. Pour utiliser votre propre instance:

1. Ouvrir `Perspective/Perspective/Config/AppConfig.swift`
2. Remplacer les valeurs:

```swift
static let supabaseURL = "VOTRE_SUPABASE_URL"
static let supabaseAnonKey = "VOTRE_SUPABASE_ANON_KEY"
```

**Credentials actuels (partagés)**:
- **URL**: `https://lsznkuiaowesucmxwwfi.supabase.co`
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxzem5rdWlhb3dlc3VjbXh3d2ZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwODQ0NjYsImV4cCI6MjA4OTY2MDQ2Nn0.llsAgcjoJHI9VVZjl8PL0k_HDJhUEzrLjxH5r9TgNgQ`

**Note**: Ces clés sont protégées par RLS (Row Level Security) côté serveur. Pas de risque de sécurité pour les données.

#### 4. Lancer l'app

1. Attendre que Xcode télécharge les dépendances automatiquement (barre de progression en haut)
2. Sélectionner un simulateur (iPhone 15 Pro recommandé) ou appareil physique dans la barre d'outils
3. Appuyer sur **▶️ Run** ou `Cmd + R`

**Premier lancement**: L'app se connecte à la base de données Supabase partagée. Aucune configuration supplémentaire requise si vous utilisez les credentials par défaut.

### Fonctionnalités de Test

**Mode Debug** (automatique en développement):
- **Activer Premium gratuitement**: Aller dans Paramètres → Section Debug → Toggle "Mode Premium"
- **Tester les notifications**: Paramètres → Debug → "Envoyer notification de test"
- **Rejouer l'onboarding**: Paramètres → Debug → "Rejouer l'onboarding"

**Tester le paywall** (abonnement gratuit à €0,00):
1. Ouvrir 5 histoires différentes (limite gratuite)
2. Le paywall s'affiche automatiquement
3. Sélectionner Mensuel (€0,00/mois) ou Annuel (€0,00/an)
4. Confirmer l'achat → StoreKit sandbox s'ouvre
5. Approuver → Premium débloqué

**Note**: Les abonnements sont configurés à €0,00 pour les tests. Voir `STOREKIT_SETUP.md` pour les détails.

### Résolution de Problèmes

**"Failed to resolve package dependencies"**
- Aller dans **File** → **Packages** → **Reset Package Caches**
- Puis **File** → **Packages** → **Update to Latest Package Versions**

**"Build Failed" sans détails**
- **Product** → **Clean Build Folder** (`Cmd + Shift + K`)
- Redémarrer Xcode

**L'app affiche "Pas d'articles"**
- Vérifier la connexion internet (requis pour Supabase)
- Consulter les logs Xcode pour erreurs réseau

**Les produits StoreKit ne chargent pas**
- Vérifier que le schéma utilise `Perspective.storekit`: **Product** → **Scheme** → **Edit Scheme** → **Run** → **Options** → **StoreKit Configuration** = `Perspective.storekit`

---

## Fonctionnalités

- Agrégation d'actualités de sources médiatiques françaises
- Classification de biais politique des sources
- Analyse de couverture médiatique par orientation politique
- Notifications push pour nouveaux sujets
- Mode sombre / clair

## Prérequis

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

## Configuration

### 1. Cloner le projet

```bash
git clone https://github.com/[votre-username]/groundnewsfrance.git
cd groundnewsfrance
```

### 2. Configuration Supabase

Le projet utilise Supabase pour accéder à la base de données d'articles. Les credentials sont configurés dans les build settings Xcode.

**IMPORTANT :** Les clés Supabase sont déjà configurées dans `groundnewsfrance.xcodeproj/project.pbxproj` via les paramètres :
- `INFOPLIST_KEY_SupabaseURL`
- `INFOPLIST_KEY_SupabaseAnonKey`

Si vous souhaitez utiliser votre propre instance Supabase :

1. Ouvrez `groundnewsfrance.xcodeproj` dans Xcode
2. Sélectionnez le projet → Target "Perspective" → Build Settings
3. Cherchez "SupabaseURL" et "SupabaseAnonKey"
4. Modifiez les valeurs pour pointer vers votre instance Supabase

Ou modifiez directement dans `groundnewsfrance.xcodeproj/project.pbxproj` (recherchez `INFOPLIST_KEY_SupabaseURL`).

### 3. Ouvrir le projet

```bash
open groundnewsfrance.xcodeproj
```

### 4. Compiler et exécuter

1. Sélectionnez un simulateur ou appareil iOS
2. Appuyez sur `Cmd + R` pour compiler et exécuter

## Structure du projet

```
Perspective/
├── App/                # Point d'entrée et configuration
├── Features/           # Écrans et fonctionnalités
│   ├── Feed/          # Liste des actualités
│   ├── Story/         # Détail d'une histoire
│   ├── Discover/      # Découverte de sources
│   └── Settings/      # Paramètres
├── Core/
│   ├── Models/        # Modèles de données
│   ├── Repositories/  # Accès aux données
│   └── Services/      # Services (Supabase, notifications)
├── Design/            # Design system (couleurs, polices, espacements)
└── Config/            # Configuration de l'app

legal/
├── privacy-policy.md  # Politique de confidentialité
└── terms-of-service.md # Conditions d'utilisation
```

## App Store

L'application est conçue pour respecter les directives de l'App Store :

- **Privacy Policy** : [legal/privacy-policy.md](legal/privacy-policy.md)
- **Terms of Service** : [legal/terms-of-service.md](legal/terms-of-service.md)
- **Age Rating** : 12+ (Thèmes politiques)
- **Permissions** : Notifications uniquement

## Debug

Des fonctionnalités de debug sont disponibles dans Settings (mode `#if DEBUG`) :

- Mode premium (désactive le paywall)
- Test de notifications
- Rejouer l'onboarding

Ces fonctionnalités ne sont pas visibles dans les builds Release.

## Licence

[À définir]

## Contact

- GitHub : https://github.com/[votre-username]/groundnewsfrance
- Email : [votre-email]
