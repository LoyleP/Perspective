# Perspective - Ground News France

Perspective est une application iOS qui agrège et affiche des articles de presse française avec une analyse du spectre politique.

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
