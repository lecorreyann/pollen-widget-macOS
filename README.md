# Pollen

Widget macOS qui affiche le taux de pollen dans votre ville sous forme de courbe colorée, avec des seuils de risque (faible, modéré, élevé, très élevé).

Utile pour anticiper ses allergies et identifier le type de pollen auquel on est sensible.

## Fonctionnalités

- **Courbe de pollen** sur 24h, demain ou 7 jours
- **Bandes de risque** colorées (vert → jaune → orange → rouge) avec ligne en dégradé selon la valeur
- **Mode Simple** : pollen dominant fusionné en une seule courbe
- **Mode Détaillé** : 6 courbes superposées (Aulne, Bouleau, Graminées, Armoise, Olivier, Ambroisie) pour identifier sa sensibilité
- **Configuration par ville** avec recherche internationale (`Valencia, ES` pour lever l'ambiguïté avec Valence en France)
- **Trois tailles** : small, medium, large — adaptées au bureau ou au centre de notifications
- **Boutons interactifs** dans le widget : changer de période et de mode sans passer par la config
- **Pic annoté** sur la courbe + indicateur « maintenant » pour la vue du jour
- **Fond teinté** selon le niveau de risque courant

## Données

Le widget consomme l'API gratuite [Open-Meteo](https://open-meteo.com/) — pas de clé requise, pas d'inscription.

- Geocoding : `geocoding-api.open-meteo.com`
- Qualité de l'air : `air-quality-api.open-meteo.com`

Le widget se rafraîchit automatiquement toutes les heures.

## Prérequis

- macOS 14 (Sonoma) ou supérieur — testé sur macOS 26 (Tahoe)
- Xcode 15+ avec les outils en ligne de commande
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) pour régénérer le projet (optionnel si vous ne modifiez pas `project.yml`)
- [Homebrew](https://brew.sh/) (pour installer XcodeGen)

## Installation

### 1. Cloner le dépôt

```bash
git clone git@github.com:lecorreyann/pollen-widget-macOS.git
cd pollen-widget-macOS
```

### 2. (Optionnel) Régénérer le projet Xcode

Si vous modifiez `project.yml` :

```bash
brew install xcodegen
xcodegen generate
```

### 3. Compiler

Avec Xcode :

```bash
open Pollen.xcodeproj
```

Puis lancer la cible **Pollen** (ou compiler en ligne de commande) :

```bash
xcodebuild -project Pollen.xcodeproj \
  -scheme Pollen \
  -configuration Debug \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  build
```

### 4. Installer dans /Applications

Pour que macOS reconnaisse le widget dans la galerie, l'app doit résider dans `/Applications` (ou être signée avec un Team ID) :

```bash
DERIVED=$(xcodebuild -project Pollen.xcodeproj -scheme Pollen -showBuildSettings 2>/dev/null \
  | grep -m1 BUILT_PRODUCTS_DIR | awk -F= '{print $2}' | xargs)
cp -R "$DERIVED/Pollen.app" /Applications/
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f /Applications/Pollen.app
open /Applications/Pollen.app
killall chronod   # force le rafraîchissement de la galerie de widgets
```

### 5. Ajouter le widget

1. Clic droit sur le bureau → **Modifier les widgets…**
2. Rechercher « Pollen » et glisser le widget à la taille souhaitée
3. Clic droit sur le widget → **Modifier le widget** pour saisir la ville et la période par défaut

## Utilisation

### Configuration

À la première installation, le widget demande :

- **Ville** : nom libre. Pour lever une ambiguïté, ajoutez un code pays ISO sur 2 lettres :
  - `Valencia` → renvoie Valence, Espagne
  - `Valencia, ES` → force Valence, Espagne
  - `Valence, FR` → force Valence, Drôme
- **Période par défaut** : Aujourd'hui, Demain ou 7 prochains jours

### Navigation dans le widget

- **Boutons Auj. / Demain / 7 j.** : change la période sans rouvrir la config
- **Boutons Simple / Détaillé** :
  - *Simple* : une courbe (maximum des 6 pollens à chaque heure)
  - *Détaillé* : 6 courbes colorées superposées pour comparer les types

Pour identifier votre sensibilité, passez en mode **Détaillé** quand vous avez des symptômes — la courbe la plus haute pointe le pollen probablement responsable.

## Architecture

```
Pollen/                          App conteneur SwiftUI minimale
├── PollenApp.swift              Point d'entrée @main
├── ContentView.swift            Écran d'instructions
└── Pollen.entitlements          Sandbox + accès réseau

PollenWidget/                    Extension WidgetKit
├── PollenWidgetBundle.swift     @main du bundle widget
├── PollenWidget.swift           Configuration du widget + fond teinté
├── PollenWidgetView.swift       Vues SwiftUI (small / medium / large)
├── PollenChart.swift            Swift Charts : ligne en dégradé, grille, pic, multi-courbes
├── PollenProvider.swift         AppIntentTimelineProvider + headline
├── PollenIntent.swift           App Intents (config + navigation période/mode)
├── PollenAPI.swift              Client Open-Meteo (geocoding + air quality)
├── PollenModels.swift           Decodables JSON et PollenSample
└── PollenRisk.swift             Seuils + palette de risque

project.yml                      Manifeste XcodeGen
Pollen.xcodeproj                 Projet Xcode généré
```

## Pile technique

- **Swift 5** + **SwiftUI**
- **WidgetKit** avec `AppIntentConfiguration` pour widgets configurables
- **Swift Charts** pour les graphiques
- **App Intents** pour la navigation interne (boutons dans le widget)
- **XcodeGen** pour générer un `.xcodeproj` reproductible depuis un YAML

## Limitations

- Cible macOS uniquement — code spécifique macOS dans `PollenWidget.swift` (`Color(nsColor:)`)
- Le hover et le clic sur une courbe ne sont pas disponibles : les widgets macOS sont des snapshots non interactifs hors `Button(intent:)`
- Compilation locale en ad-hoc — pour distribuer, ajoutez votre Team ID dans Xcode (*Signing & Capabilities*)

## Licence

MIT.
