<p align="center">
  <img src="icon.svg" alt="Pixel War Remote" width="128"/>
</p>

<h1 align="center">📱 Pixel War Remote</h1>

<p align="center">
  <strong>La manette virtuelle mobile pour <a href="https://github.com/U-Night/pixel-war">Pixel War</a></strong>
</p>

<p align="center">
  <a href="https://github.com/U-Night/pixel-war-remote/releases/latest"><img src="https://img.shields.io/badge/Télécharger-APK%20Android-brightgreen?style=for-the-badge&logo=android" alt="Télécharger APK"/></a>
  <a href="https://github.com/U-Night/pixel-war"><img src="https://img.shields.io/badge/Jeu%20Principal-Pixel%20War-blueviolet?style=for-the-badge&logo=github" alt="Pixel War"/></a>
  <br/>
  <img src="https://img.shields.io/badge/Godot-4.6-blue?style=for-the-badge&logo=godotengine" alt="Godot 4.6"/>
  <img src="https://img.shields.io/badge/C%23-.NET%208-512BD4?style=for-the-badge&logo=dotnet" alt=".NET 8"/>
  <img src="https://img.shields.io/badge/Plateforme-Android-34A853?style=for-the-badge&logo=android" alt="Android"/>
</p>

---

## 📖 Présentation

**Pixel War Remote** est la manette virtuelle mobile du jeu **[Pixel War](https://github.com/U-Night/pixel-war)** — un jeu massivement multijoueur **colocalisé** développé à l'**IUT d'Orsay** (Université Paris-Saclay).

Le principe est simple : tous les joueurs sont physiquement dans la même salle, face à un grand écran partagé. Chaque joueur ouvre cette application sur **son téléphone**, saisit l'adresse IP du serveur de jeu, et se connecte. Son téléphone devient alors une **manette** avec un joystick, un bouton de power-up et un bouton de ping.

> **En résumé :** votre téléphone = votre manette 🎮

---

## 🎮 Comment jouer ?

### 1. Télécharger la manette

Récupérez l'APK Android depuis les **Releases GitHub** :

👉 **[Dernière Release](https://github.com/U-Night/pixel-war-remote/releases/latest)**

> **Note :** l'APK nécessite Android 7.0+ (API 24). Vous devrez peut-être autoriser l'installation depuis des sources inconnues.

### 2. Rejoindre une partie

1. L'hôte lance **Pixel War** sur l'écran partagé — le serveur démarre sur le **port 6967**
2. Assurez-vous d'être connecté au **même réseau Wi-Fi** que l'hôte
3. Ouvrez **Pixel War Remote** sur votre téléphone
4. Entrez l'**adresse IP** de l'hôte (affichée à l'écran) et appuyez sur **Rejoindre**
5. Le serveur vous assigne automatiquement une équipe

### 3. Les équipes

| Équipe | Couleur de fond |
|--------|----------------|
| 🔵 **Bleue** | Bleu marine |
| 🔴 **Rouge** | Rouge sombre |
| 🟢 **Verte** | Vert forêt |
| 🟡 **Jaune** | Jaune doré |

> La couleur de fond de votre manette change automatiquement pour refléter votre équipe.

### 4. Contrôles

| Commande | Action |
|----------|--------|
| 🕹️ **Joystick** | Déplacer votre vaisseau sur l'arène |
| ⚡ **Bouton Power-up** | Activer le bonus que vous avez ramassé |
| 📍 **Ping** | Signaler votre position à vos coéquipiers |

### 5. Power-ups

Quand votre vaisseau ramasse un bonus sur l'arène, il apparaît sur votre manette. Appuyez dessus pour l'activer !

| Power-up | Icône | Effet |
|----------|-------|-------|
| **Agrandissement** (Grow) | 🔷 | Le vaisseau colorie une zone de **3×3 cases** |
| **Vitesse** (Speed) | ⚡ | Vitesse du vaisseau **doublée** temporairement |
| **Bombe de peinture** (Paint Bomb) | 💣 | Explosion coloriant **25 cases** (5×5) |
| **Épée** (Sword) | ⚔️ | Élimine les adverses au contact |

---

## 🛠️ Installation (développement)

### Prérequis

- [Godot Engine 4.6.2](https://godotengine.org/download) — **Mono / .NET** (version avec support C#)
- [.NET SDK 8.0](https://dotnet.microsoft.com/download/dotnet/8.0) (ou .NET 9.0 pour le build Android)
- [Android SDK](https://developer.android.com/studio) (pour l'export APK)

### Installation

```bash
# Cloner le dépôt
git clone https://github.com/U-Night/pixel-war-remote.git
cd pixel-war-remote

# Restaurer les dépendances .NET
dotnet restore
```

### Lancer en développement

1. Ouvrir le projet dans **Godot Engine 4.6 Mono**
2. Attendre la compilation automatique du projet C# (`.sln`)
3. Appuyer sur **F5** (ou le bouton ▶️) pour lancer la manette
4. Entrer `127.0.0.1` (ou l'IP du serveur Pixel War) et se connecter

> **Astuce :** l'émulation du toucher est activée par défaut — vous pouvez tester le joystick à la souris.

---

## 📦 Build & Déploiement

### Build Android (APK)

L'export Android est configuré avec Gradle et cible l'architecture **arm64-v8a**.

#### En local (depuis Godot)

1. Installer le **Android Build Template** depuis Godot : `Projet → Installer le modèle de build Android`
2. Configurer le keystore dans `Éditeur → Paramètres de l'éditeur → Export → Android`
3. Exporter via `Projet → Exporter → Android`

#### CI/CD automatisé

Le projet inclut des pipelines CI/CD pour la construction automatique :

| Plateforme | Fichier | Description |
|-----------|---------|-------------|
| **GitLab CI** | `.gitlab-ci.yml` | Mirror GitHub + build APK + upload au Package Registry |
| **GitHub Actions** | `.github/workflows/build-and-release.yml` | Build APK + création d'une Release GitHub |

Chaque push sur `main` déclenche un build automatique et publie l'APK.

---

## 🏗️ Architecture technique

### Vue d'ensemble

```
┌──────────────────────────────────────────────────────┐
│              ÉCRAN PARTAGÉ  (pixel-war)               │
│                                                      │
│           ┌──────────────────────────┐               │
│           │      Main Server         │               │
│           │   TCP + UDP  :6967       │               │
│           └────────────┬─────────────┘               │
└────────────────────────┼─────────────────────────────┘
                         │ Réseau local (Wi-Fi)
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐
    │ 📱 Tel 1 │   │ 📱 Tel 2 │   │ 📱 Tel N │
    │ Remote   │   │ Remote   │   │ Remote   │
    └──────────┘   └──────────┘   └──────────┘
      (ce repo)      (ce repo)      (ce repo)
```

### Protocole réseau

La manette communique avec le serveur via **deux canaux** sur le port `6967` :

#### 🔵 TCP — Connexion fiable

Utilisé pour les messages **critiques** qui ne doivent pas être perdus :

| Direction | Message | Description |
|-----------|---------|-------------|
| `← Serveur` | `PIXELWAR 1.0` | Annonce du serveur (handshake) |
| `→ Serveur` | `REMOTE 1.0` | Réponse de la manette |
| `← Serveur` | `WELCOME {id}` | Confirmation + attribution d'un ID joueur |
| `← Serveur` | `TEAM_ASSIGNED:{0-3}` | Assignation d'équipe |
| `← Serveur` | Powerup JSON `{"action":"grant","powerup":"..."}` | Notification de power-up |
| `→ Serveur` | Powerup JSON `{"action":"use"}` | Activation d'un power-up |
| `← Serveur` | Message JSON `{"type":"eliminated\|victory\|draw"}` | Fin de partie |

**Format des trames TCP :**

```
┌───────────────────┬────────────────────────────────────┐
│  LENGTH (4B LE)   │           PAYLOAD (N bytes)        │
├───────────────────┼──────────┬───────────┬─────────────┤
│                   │ TYPE(1B) │ SIZE(4B)  │  DATA(M B)  │
└───────────────────┴──────────┴───────────┴─────────────┘
```

#### 🟢 UDP — Entrées temps réel

Utilisé pour les **entrées joystick** (envoyées à **20 Hz**) avec protection d'intégrité :

```
┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│  CRC32   │  LENGTH  │   TYPE   │  USER_ID │  SEQ_ID  │  X | Y   │
│  4 bytes │  2 bytes │  1 byte  │  4 bytes │  4 bytes │  8 bytes │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
              Header (15 bytes)                 Payload (8 bytes)
```

- **CRC32** : vérification d'intégrité (calculé sur tout sauf les 4 premiers octets)
- **Sequence ID** : détection des paquets désordonnés
- **X, Y** : coordonnées du joystick (float32, `-1.0` à `1.0`)

### Structure du projet

```
pixel-war-remote/
├── scenes/                       # Scènes Godot (.tscn)
│   ├── menu.tscn                 # Écran de connexion
│   ├── controller.tscn           # Interface de la manette
│   └── game_over.tscn            # Écran de fin de partie
├── scripts/                      # Scripts de gameplay (GDScript)
│   ├── menu.gd                   # Logique du menu de connexion
│   ├── controller.gd             # Joystick, power-ups, ping
│   ├── game_over.gd              # Écran victoire / élimination / égalité
│   ├── network_manager.gd        # Autoload — gestion TCP et protocole
│   └── network/                  # Couche réseau (C#)
│       ├── UDPClient.cs          # Client UDP (joystick temps réel)
│       ├── UdpPacket.cs          # Structure des paquets UDP
│       ├── Packet.cs             # Sérialisation des paquets TCP
│       └── MessageFramer.cs      # Framing TCP (length-prefixed)
├── assets/controller/            # Icônes des power-ups (SVG)
├── addons/virtual_joystick/      # Plugin de joystick virtuel
├── project.godot                 # Configuration du projet Godot
├── Pixel War Remote.csproj       # Projet C# (.NET 8)
└── export_presets.cfg            # Configuration d'export Android
```

### Technologies

| Composant | Technologie |
|-----------|-------------|
| Moteur | Godot Engine 4.6 (Mobile renderer) |
| Scripts gameplay | GDScript |
| Réseau UDP | C# (.NET 8 / .NET 9 pour Android) |
| Joystick | Plugin [Virtual Joystick](https://github.com/MarcoFazworx/virtual_joystick) |
| CI/CD | GitLab CI + GitHub Actions |
| Build | Gradle (Android APK, arm64-v8a) |

---

## 📜 Licence

Ce projet est distribué sous la **PixelWar Source Code License** (v1.0).

En résumé : usage autorisé à des fins **non commerciales** (étude, modification, contribution). L'exploitation commerciale est exclusive à U-Night Game Studio.

Voir le fichier [LICENSE](LICENSE) pour les termes complets.

---

## 🙏 Crédits

### Équipe

- **Eliott DAGOSTINOZ**
- **Pierrick DROUET DE LA THIBAUDERIE**
- **Gaya BOUNDER**

### Remerciements

- **Lucas PAUSÉ-CHAPUIS**, pour les musiques du jeu 🎵
- Toute l'équipe Godot pour le moteur de jeu 🤍

---

<p align="center">
  Projet réalisé à l'<strong>IUT d'Orsay</strong> — Université Paris-Saclay<br/>
  Développé avec 🤍 et <a href="https://godotengine.org">Godot Engine 4.6</a>
  <br />
  Ce projet est la propriété exclusive de U-Night Game Studio, société en formation dirigée et représentée par Eliott DAGOSTINOZ. Pour toute question: <a href="mailto:contact@u-night.org">contact@u-night.org</a>
</p>
