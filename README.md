# aladinIPTV Player Pro

**aladinIPTV Player Pro** is a modern, high‑performance IPTV player built with **Flutter**, designed for large and complex M3U / Xtream playlists.

The core goal of this project is not just to play streams, but to **organize massive IPTV content intelligently** with a Netflix‑style user interface and TV‑first experience.

---

## ✨ Key Features

- 📺 **Live TV, Movies & Series**
- 🧭 **Netflix‑style layout**
  - Vertical categories
  - Horizontal content rows
- ⚡ **High‑performance UI**
  - Optimized for very large playlists (50K+ channels)
  - Lazy loading & pagination
- ⭐ **Favorites & Recent Watching**
- 🔍 **Global Search**
- 🎬 **IMDb metadata extraction**
- 📅 **EPG support (XMLTV)** *(in progress)*
- 💾 **Offline‑first architecture**
- 🎮 **TV‑focused navigation (Android TV ready)**

---

## 🖥 UI Philosophy

The UI is inspired by platforms like **Netflix** and **TiviMate**, focusing on:

- Clean, minimal, TV‑friendly design  
- Smooth navigation using remote controls  
- Clear separation between:
  - Live TV
  - Movies (VOD)
  - Series
- Consistent card sizes and aspect‑ratio‑safe posters / logos

**Structure example:**
[ Continue Watching ]
[ Favorites ]
[ News ]
→ Channel → Channel → Channel
[ Sports ]
→ Channel → Channel → Channel
[ Movies ]
→ Movie → Movie → Movie

---

## 🧠 Smart Playlist Parsing

The project includes an **advanced M3U/Xtream parsing engine**, not a basic line reader.

### Supported Metadata Extraction
- Channel / Movie / Series detection
- IMDb rating
- Production year
- Quality tags (SD, HD, FHD, 4K, HEVC, FPS)
- Season & episode parsing
- Poster / logo URLs
- Category normalization
- Duplicate detection via unique keys

### Parser Highlights
- Runs in **isolate** to avoid UI freezes
- Handles malformed or broken playlists safely
- Detects:
  - Live TV
  - Movies
  - Series (SxxExx or date‑based formats)
- Intelligent cleanup of noisy names and tags

---

## ⚙️ Performance & Scalability

Designed to handle **massive IPTV libraries** efficiently:

- 🗄 **Isar Database**
  - Indexed queries
  - Extremely fast local reads
- 📦 Batch inserts & updates
- 🔄 Lazy loading with offset & limit
- 🧠 Cached metadata (IMDb, EPG, posters)
- 🚫 Prevents UI jank & memory overuse

---

## 📡 Playlist Management

- M3U URL import
- Xtream Codes API import
- Local M3U file support
- Duplicate playlist detection
- Safe update mechanism:
  - Keeps playlist ID
  - Preserves favorites & watch history
- Update / rename / delete playlists

---

## 📺 Player Architecture (Planned / In Progress)

- Powered by **media_kit**
- Zapping (channel up/down)
- Aspect‑ratio modes (Fit / Fill / 16:9 / 4:3)
- Timeout handling for broken streams
- EPG overlay
- Program timeline
- Catch‑up support (future)

---

## 📅 EPG (XMLTV)

- Background sync
- Local caching
- “Now Playing” detection
- Upcoming programs
- Designed for TV overlay usage

---

## 🧩 Technology Stack

- **Flutter (Dart)** — UI & application logic
- **Isar** — High‑performance local database
- **cached_network_image** — Image caching
- **media_kit** — Video playback
- **XMLTV** — EPG data
- **Isolates** — Heavy parsing tasks

---

## 🗺 Roadmap

### MVP (Current)
- ✅ Live TV / Movies / Series UI
- ✅ Playlist import & management
- ✅ Smart M3U parsing
- ✅ Favorites & search
- ✅ Stable card & poster rendering

### Pro
- 🚧 Full EPG integration
- 🚧 Advanced Player controls
- 🚧 Catch‑up / archive streams
- 🚧 Improved TV remote handling

### Advanced
- ⏳ User profiles
- ⏳ Cloud sync
- ⏳ Recommendation system
- ⏳ Parental control & PIN lock
- ⏳ Multi‑device support

---

## ⚠️ Legal Notice

This application does **not** provide any IPTV content.

All playlists, streams, and EPG sources are supplied **by the user**.  
The project is intended for **personal use and educational purposes**.

---

## 🛠 Development Status

🚧 **Active Development**

UI and core architecture are stable.  
EPG and player enhancements are currently in progress.

---

## 📌 Version Tag

Current stable UI snapshot:

aladinIPTV-Player-Pro.apk


v6.0-ui-stable

---

## ⭐ Contribution & Feedback

Feedback, issues, and suggestions are welcome.  
This project focuses on long‑term maintainability and professional IPTV experience.


## ⭐ Files and Folders 

MEVCUT KLASÖR YAPISI BU ŞEKİLDE.
├───lib
│    ├───core
│    │   ├───database
│    │   ├───models
│    │   ├───parsers
│    │   ├───services
│    │   └───state
│    ├───features
│    │   ├───favorites
│    │   ├───live_tv
│    │   ├───movies
│    │   ├───player
│    │   ├───search
│    │   ├───series
│    │   └───settings
│    └───shared
│        ├───theme
│        └───widgets
└───lib
    └───assets
        ├───icons
        ├───images
        └───logos