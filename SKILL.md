---
name: aladinIPTV Player Pro
description: Next-gen IPTV solution with high-performance EPG management and Netflix-style UI.
version: 2.2.0
author: tezalaaddin
tags: [iptv, flutter, media-kit, streaming, isar]
---
# aladinIPTV Player Pro

## ENGLISH
==========
# Technical Expertise & Project Architecture: aladinIPTV Player Pro

This document outlines the advanced engineering principles, architectural patterns, and technical stack implemented in the development of **aladinIPTV Player Pro**.

## 🏗️ System Architecture & Performance Optimization
* **Multi-Threaded Data Processing (Isolates):** Leveraged Dart's `Isolate` (via `compute`) to handle heavy M3U parsing logic. This ensures that even with playlists containing 50,000+ entries, the UI remains responsive at 60 FPS by offloading CPU-intensive tasks to background threads.
* **High-Performance Local Persistence (Isar NoSQL):** Engineered a reactive local data layer using **Isar**. Implemented custom schemas for fast indexing and asynchronous querying of channels, categories, and EPG data.
* **State-Aware "Continue Watching" Engine:** Developed a persistence logic that tracks playback progress for VOD content. Items watched between 5% and 90% are automatically bookmarked with a 60-second periodic sync between the native layer and local DB.
* **Memory-Efficient Batch Processing:** Implemented a stream-based import system that processes and persists data in optimized batches. This prevents memory spikes and ensures stability on low-end mobile devices.

## 🧠 Advanced Content Analysis & Logic
* **Heuristic Data Parsing (RegEx Engine):** Developed a sophisticated Regular Expression engine to extract rich metadata from unstructured M3U strings, including resolution detection (4K, FHD), IMDb ratings, and S0xE0x extraction for VOD.
* **Xtream Codes API Deep Integration:** Fully abstracted the differences between M3U and Xtream protocols. Implemented on-demand episode fetching for series to optimize initial import speed and memory usage.
* **Automated Content Classification:** Built a logical router that categorizes raw stream URLs into Live TV, Movies, or Series based on endpoint patterns, category IDs, and metadata markers.

## 🎬 Multimedia & Native Player Intelligence
* **Native ExoPlayer Core (Kotlin):** Integrated Media3/ExoPlayer for a high-performance video backbone supporting hardware acceleration and Realtek chipset optimizations (System.gc() triggers and 500ms reset timers).
* **Pause-State Metadata Overlay:** Engineered an intelligent info panel that appears during pause mode, displaying TMDB metadata (Poster, IMDb, Year, Overview) for Movies and Series, while maintaining a clean UI for Live TV.
* **Precision Seek & Sync:** Implemented a real-time progress synchronization bridge between Kotlin and Flutter, ensuring millisecond-accurate time tracking and seeking.
* **Zapping Performance (Debounce Logic):** Optimized channel switching with a 500ms debounce and active decoder resource management to prevent audio overlapping during rapid navigation.

## 📺 Android TV UI/UX Engineering
* **TV-First Focus Management:** Engineered a custom focus architecture for the Settings page, allowing D-pad navigation to trigger virtual keyboards and jump between input fields (Server -> User -> Pass -> Save) seamlessly.
* **Keyboard-Aware Layouts:** Implemented dynamic scroll padding to ensure input fields remain visible above the Android system keyboard during data entry.
* **Netflix-Inspired VOD Interface:** Designed hierarchical horizontal scrollable carousels with state-aware "Continue Watching" strips at the top of Movie and Series sections.

---

## TÜRKÇE
==========
# aladinIPTV Player Pro

# 🛠 Teknik Yetkinlikler ve Proje Özellikleri: aladinIPTV Player Pro

Bu dosya, **aladinIPTV Player Pro** projesinin geliştirilme sürecinde kullanılan mimari yaklaşımları, teknik becerileri ve uygulanan çözüm yöntemlerini detaylandırmaktadır.

## 🚀 Temel Mimari ve Performans (Core Architecture)
* **İzole Veri İşleme (High-Performance Isolate Parsing):** On binlerce satırlık M3U dosyalarının UI thread'ini dondurmadan işlenmesi için Flutter `compute` altyapısı ile asenkron ayrıştırma (parsing) yönetimi.
* **Gelişmiş Veritabanı Yönetimi (Isar NoSQL):** Uygulama verilerinin (kanallar, kategoriler, geçmiş) ultra hızlı sorgulanması için Isar entegrasyonu.
* **"İzlemeye Devam Et" Motoru:** VOD içerikler için %5 ile %90 arasındaki izleme ilerlemesini otomatik olarak takip eden ve native katman ile DB arasında 60 saniyelik periyotlarla senkronize olan kalıcı veri katmanı.
* **Verimli Veri Akış Yönetimi (Batch Processing):** Bellek kullanımını optimize eden toplu kayıt (batch insert) ve stream tabanlı ilerleme takibi.

## 🔍 Akıllı İçerik Analizi (Advanced Content Engine)
* **Karmaşık Veri Ayrıştırma (Complex RegEx Parsing):** Kanal isimlerinden kalite etiketlerini (4K, FHD), yapım yıllarını, sezon/bölüm bilgilerini ve IMDb puanlarını ayıklayan özelleştirilmiş RegEx algoritmaları.
* **Xtream Codes API Derin Entegrasyonu:** M3U ve Xtream protokolleri arasındaki mimari farklar soyutlanarak, diziler için "on-demand" (tıklandığında) bölüm çekme özelliği ile bellek tasarrufu sağlandı.
* **Dinamik Kategorizasyon:** Ham verileri kategori ID'leri ve URL desenleri üzerinden otomatik olarak Canlı TV, Film ve Dizi olarak sınıflandıran mantıksal katman.

## 🎬 Multimedya ve Native Oynatıcı Zekası
* **Native ExoPlayer Çekirdeği (Kotlin):** Realtek çipsetli cihazlar için optimize edilmiş (System.gc() ve 500ms reset gecikmesi), donanım hızlandırma destekli Media3/ExoPlayer altyapısı.
* **Durdurma (Pause) Bilgi Paneli:** Video durdurulduğunda devreye giren; film/dizi afişi, IMDb puanı ve özet bilgilerini gösteren akıllı overlay sistemi.
* **Hassas Zaman ve İlerleme Takibi:** Native katmandan Flutter'a milisaniye hassasiyetinde zaman verisi aktaran ve ileri-geri sarmayı (30sn ileri / 10sn geri) senkronize eden köprü.
* **Zapping Optimizasyonu:** Hızlı kanal değişimlerinde seslerin karışmasını önleyen 500ms'lik debounce ve dekoder kaynak temizleme mekanizması.

## 📺 Android TV UI/UX Mühendisliği
* **Kumanda Odak (Focus) Yönetimi:** Ayarlar sayfasında kumanda ile veri girişini kolaylaştıran, alanlar arası (Sunucu -> Kullanıcı -> Onay) otomatik geçiş ve odaklama mimarisi.
* **Klavye Duyarlı Arayüz:** Ekran klavyesi açıldığında veri girilen alanın klavyenin üstünde kalmasını sağlayan dinamik scroll padding sistemi.
* **Modern Netflix Stili Arayüz:** Sayfaların en başında yer alan "Kaldığın Yerden" şeritleri ve yatay kaydırılabilir kategorik listeler.

---

# AladinIPTV Player Pro — Skill Manifest
### Version 2.1.0 · Flutter · Android TV

---

## 0. İçindekiler / Table of Contents

**Türkçe**
1. [Giriş ve Amaç](#1-giriş-ve-amaç)
2. [Mimari Özet ve Dosya Yapısı](#2-mimari-özet-ve-dosya-yapısı)
3. [Akış Şeması (Mantıksal Akış)](#3-akış-şeması-mantıksal-akış)
4. [API / Fonksiyon Dokümantasyonu](#4-api--fonksiyon-dokümantasyonu)
5. [Teknik Yetkinlikler ve Bağımlılıklar](#5-teknik-yetkinlikler-ve-bağımlılıklar)
6. [Kullanım Senaryoları (Prompting)](#6-kullanım-senaryoları-prompting)
7. [Yetenek Tanımları ve Kazanımlar](#7-yetenek-tanımları-ve-kazanımlar)
8. [Düzeltme ve İyileştirmeler](#8-düzeltme-ve-iyileştirmeler)
9. [Hata Yönetimi](#9-hata-yönetimi)
10. [Kısıtlamalar](#10-kısıtlamalar)

---

# TÜRKÇE

---

## 1. Giriş ve Amaç

AladinIPTV Player Pro, kullanıcının kendi IPTV lisansını (M3U URL, Xtream Codes veya yerel .m3u dosyası olarak) getirerek 60.000'i aşkın kanalı; Android TV için tasarlanmış yüksek performanslı bir arayüzle izlemesini sağlar. Uygulama, video oynatımı için ExoPlayer (Media3) tabanlı native Android katmanını, yönetim ve UI için Flutter katmanını kullanır.

---

## 2. Mimari Özet ve Dosya Yapısı

*   **core/parsers/aladin_xtream_parser.dart:** Xtream protokolü, kategori eşleştirme ve on-demand bölüm çekme zekası.
*   **core/services/aladin_channel_service.dart:** İzleme geçmişi (Continue Watching) ve kategori bazlı sayfalama mantığı.
*   **android/app/src/main/kotlin/.../NativePlayerActivity.kt:** Oynatıcı mantığı, zaman takibi, zapping fix ve pause bilgi paneli.
*   **lib/features/settings/aladin_settings_page.dart:** TV kumanda navigasyonu ve dinamik odak yönetimi.

---

## 8. Düzeltme ve İyileştirmeler (V2.1.0)

| # | Özellik / Düzeltme | Açıklama |
|---|--------------------|----------|
| 1 | **Xtream Kategori Fix** | API'den gelen `category_id` değerleri `category_name` ile eşleştirildi, "Diğer" kategorisine düşme sorunu çözüldü. |
| 2 | **On-Demand Episodes** | Xtream dizileri için bölümler sadece diziye tıklandığında çekilerek veritabanına kaydedilir (Lazy Load). |
| 3 | **Kaldığın Yerden** | %5 - %90 arası izlenen içerikler ana sayfada listelenir, tıklandığında saniyesine kadar kaldığı yerden devam eder. |
| 4 | **Pause Bilgi Paneli** | Video durdurulduğunda TMDB'den çekilen afiş, yıl, puan ve özet bilgilerini içeren sol panel eklendi. |
| 5 | **Hassas Zaman Kontrolü** | İleri-geri sarma (30sn/10sn) ve zaman göstergeleri ExoPlayer verileriyle tam uyumlu hale getirildi. |
| 6 | **Settings TV UX** | Kumanda ile text alanlarına girme (OK tuşu), alanlar arası otomatik geçiş ve klavye görünürlük sorunları çözüldü. |
| 7 | **Zapping Stabilizasyonu** | Hızlı kanal değişimlerinde oluşan ses karışması sorunu 500ms debounce ve bellek temizliği ile giderildi. |

---

## 10. Kısıtlamalar

*   **Xtream Bölüm API:** API'de toplu episode endpoint'i olmadığı için diziler on-demand çalışmaya devam edecektir.
*   **RAM Kısıtı:** Realtek cihazlarda aynı anda birden fazla decoder açılamaz; bu yüzden her geçişte `releasePlayer()` zorunludur.
*   **İlerleme Kaydı:** Veritabanı sağlığı için izleme ilerlemesi 60 saniyede bir kaydedilir.

---

# ENGLISH

---

## Technical Skills & Project Features (V2.1.0)

*   **Continue Watching Engine:** Items watched between 5% and 90% are bookmarked; 60s background sync between Native/Flutter layers.
*   **Native Metadata Overlay:** Intelligent info panel during pause displaying TMDB details for VOD content.
*   **Zapping & Reset Logic:** 500ms debounce and active memory cleanup for stable channel switching on low-RAM TV chips.
*   **TV-First UX:** Seamless D-pad focus workflow in settings; automated field jumping and keyboard-aware scroll padding.
*   **Xtream Deep Integration:** Intelligent ID-to-Name category mapping and on-demand episode persistence.




# AladinIPTV Player Pro — Skill Manifest
### Version 2.0.0 · Flutter · Android TV

---

## 0. İçindekiler / Table of Contents

**Türkçe**
1. [Giriş ve Amaç](#1-giriş-ve-amaç)
2. [Mimari Özet ve Dosya Yapısı](#2-mimari-özet-ve-dosya-yapısı)
3. [Akış Şeması (Mantıksal Akış)](#3-akış-şeması-mantıksal-akış)
4. [API / Fonksiyon Dokümantasyonu](#4-api--fonksiyon-dokümantasyonu)
5. [Teknik Yetkinlikler ve Bağımlılıklar](#5-teknik-yetkinlikler-ve-bağımlılıklar)
6. [Kullanım Senaryoları (Prompting)](#6-kullanım-senaryoları-prompting)
7. [Yetenek Tanımları ve Kazanımlar](#7-yetenek-tanımları-ve-kazanımlar)
8. [Düzeltme ve Ekleme Önerileri](#8-düzeltme-ve-ekleme-önerileri)
9. [Hata Yönetimi](#9-hata-yönetimi)
10. [Kısıtlamalar](#10-kısıtlamalar)
11. [Genel Notlar ve Öneriler](#11-genel-notlar-ve-öneriler)
12. [AI Yorumu](#12-ai-yorumu)
13. [Görselleştirme Rehberi](#13-görselleştirme-rehberi)
14. [Geliştirme Yol Haritası (Roadmap)](#14-geliştirme-yol-haritası-roadmap)

**English**
1. [Introduction & Purpose](#introduction--purpose)
2. [Architecture Summary & File Structure](#architecture-summary--file-structure)
3. [Flow Diagram (Logical Flow)](#flow-diagram-logical-flow)
4. [API / Function Documentation](#api--function-documentation)
5. [Technical Skills & Dependencies](#technical-skills--dependencies)
6. [Usage Scenarios (Prompting)](#usage-scenarios-prompting)
7. [Capabilities & Learnings](#capabilities--learnings)
8. [Bug Fixes & Improvement Proposals](#bug-fixes--improvement-proposals)
9. [Error Handling](#error-handling)
10. [Limitations](#limitations)
11. [General Notes & Recommendations](#general-notes--recommendations)
12. [AI Commentary](#ai-commentary)
13. [Visualization Guide](#visualization-guide)
14. [Development Roadmap](#development-roadmap)

---

# TÜRKÇE

---

## 1. Giriş ve Amaç

AladinIPTV Player Pro, kullanıcının kendi IPTV lisansını (M3U URL, Xtream Codes veya yerel .m3u dosyası olarak) getirerek 60.000'i aşkın kanalı; **Canlı TV**, **Film** ve **Dizi** olmak üzere üç ana kategoride listeleyip izlemesini sağlayan, Android TV için tasarlanmış yüksek performanslı bir IPTV oynatıcı uygulamasıdır. Uygulama içinde hiçbir içerik barındırmaz; tamamen kullanıcı tarafından sağlanan listelerle çalışır. Video oynatımı ExoPlayer (Media3) tabanlı native Android katmanında gerçekleşir; Flutter katmanı navigasyon, liste yönetimi, veritabanı ve UI'den sorumludur.

---

## 2. Mimari Özet ve Dosya Yapısı

```
lib/
├── main.dart                        # Uygulama giriş noktası, Isar init, Provider setup
│
├── core/
│   ├── database/
│   │   └── aladin_isar_service.dart # Isar singleton — DB açma/kapama
│   │
│   ├── models/
│   │   ├── aladin_channel_model.dart    # ChannelModel (Isar koleksiyonu) — kanal/bölüm kaydı
│   │   ├── aladin_category_model.dart   # CategoryModel — her içerik türü için kategori
│   │   ├── aladin_playlist_model.dart   # PlaylistModel — playlist meta (url, tip, kimlik bilgileri)
│   │   ├── aladin_epg_model.dart        # EPG yayın saati kaydı
│   │   └── aladin_iptv_item.dart        # M3U parse sonucu taşıyıcı (geçici, DB'ye yazılmaz)
│   │
│   ├── parsers/
│   │   ├── aladin_m3u_parser.dart       # [CORE] Isolate tabanlı M3U parser — regex, type detection
│   │   ├── aladin_xtream_parser.dart    # [CORE] Xtream API istemcisi — live/vod/series + episodes
│   │   └── aladin_import_bridge.dart   # Orkestrasyon — URL/dosya → AladinIPTVItem → ChannelModel
│   │
│   ├── services/
│   │   ├── aladin_channel_service.dart  # CRUD — kanal, kategori, favori, arama, seri bölümleri
│   │   ├── aladin_playlist_service.dart # Import orchestrator — M3U ve Xtream pipeline
│   │   ├── aladin_epg_engine.dart       # EPG senkronizasyon motoru (arka plan)
│   │   ├── aladin_epg_service.dart      # EPG DB sorguları
│   │   ├── aladin_tmdb_service.dart     # TMDB API — film/dizi afişi, puan, özet
│   │   └── aladin_metadata_sync_service.dart # Arka plan metadata senkronizasyonu
│   │
│   └── state/
│       ├── aladin_app_state.dart        # AppState (ChangeNotifier) — aktif playlist, dil, yenileme
│       ├── aladin_app_prefs.dart        # SharedPreferences wrapper
│       └── aladin_app_strings.dart      # Çok dilli UI metinleri (TR/EN/AR/AZ…)
│
├── features/
│   ├── aladin_main_page.dart            # Ana sayfa — alt sekme navigasyonu (TV/Film/Dizi/Ayarlar)
│   ├── live_tv/
│   │   └── aladin_live_tv_page.dart     # Canlı TV sayfası — kategori listesi + EPG overlay
│   ├── movies/
│   │   └── aladin_movies_page.dart      # Film sayfası — platform bazlı kategori şeritleri
│   ├── series/
│   │   └── aladin_series_page.dart      # Dizi sayfası + AladinSeriesDetailPage (sezon/bölüm)
│   ├── favorites/
│   │   └── aladin_favorites_page.dart   # Favoriler sayfası — tüm türleri birleştirir
│   ├── search/
│   │   └── aladin_search_page.dart      # Arama sayfası — isim bazlı anlık arama
│   ├── player/
│   │   └── aladin_player_page.dart      # Flutter köprüsü — MethodChannel ile native ExoPlayer
│   └── settings/
│       └── aladin_settings_page.dart    # Ayarlar + Import (M3U/Xtream/Lokal), dil, EPG
│
├── shared/
│   ├── theme/
│   │   └── aladin_app_theme.dart        # Renk paleti, tipografi sabitler
│   └── widgets/
│       ├── aladin_app_bar.dart          # Ortak AppBar (logo + yenile butonu)
│       ├── aladin_category_row.dart     # Yatay kaydırmalı kategori şeridi — lazy load
│       ├── aladin_channel_card.dart     # Kanal/film/dizi kartı (afiş + logo + rozet)
│       ├── aladin_folder_explorer.dart  # Dosya sistemi tarayıcı (lokal M3U seçimi)
│       └── aladin_manual_logos.dart     # Yerleşik logo haritalama tablosu (kanal adı → URL)
│
android/
├── app/src/main/kotlin/…/
│   ├── MainActivity.kt              # Flutter host + MethodChannel "aladin/exoplayer" tanımı
│   └── NativePlayerActivity.kt      # ExoPlayer UI — D-pad, ses, seektbar, track seçimi
└── app/res/layout/
    └── activity_player.xml          # Player ekranı XML layout
```

### Kritik Mimari Kararlar

| Karar | Neden |
|-------|-------|
| **Isar** NoSQL embedded DB | 60k+ kayıt için hızlı index tabanlı sorgular; SQLite'a göre ~3× hızlı |
| **Isolate** tabanlı M3U parse | 60k satır regex parse UI thread'i bloke etmez |
| **Native ExoPlayer** (Kotlin) | Realtek ve düşük RAM'li TV chiplerinde Flutter video kütüphaneleri çöküyor; native katman daha stabil |
| **MethodChannel** köprüsü | Flutter → Kotlin tek yönlü çağrı; Player context Flutter'dan izole |
| **Provider** state yönetimi | Tek playlist seçimi, dil değişimi ve yenileme için yeterli; Riverpod/Bloc gereksiz overhead |
| **Batch yazma** (200'lük) | DB transaction sayısını düşürür; 60k kanalı ~30s yerine ~8s'de kaydeder |

---

## 3. Akış Şeması (Mantıksal Akış)

### A) M3U Import Akışı

```
Kullanıcı URL/Dosya girer (SettingsPage)
        │
        ▼
PlaylistService.importM3U()
        │
        ├─[URL]──► AladinImportBridge.importFromUrl()
        │              └─► _downloadContent() → HTTP GET (redirect takip eder)
        │
        └─[Dosya]► AladinImportBridge.importFromFile()
                       └─► File.readAsBytes() → UTF-8/Latin-1 decode
                                │
                                ▼
                    AladinM3UParser.aladinParseM3U()  [Flutter isolate]
                        │   Line-by-line regex:
                        │   • #EXTINF: attribute parsing
                        │   • group-title, tvg-logo, tvg-id, tvg-name
                        │   • Content type: SxxExx → series, /movie/ → movie
                        │   • Platform prefix: AMZN|, NF|, DP|, vb.
                        │   • IMDb, year, quality tag extraction
                        │
                        ▼
              List<AladinIPTVItem>  (geçici model)
                        │
                        ▼
              _toChannelModel()  →  List<ChannelModel>  (Isar modeli)
                        │
                        ▼ (200'lük batch'ler)
              Isar.channelModels.putAll()
                        │
                        ▼ (tüm import bitti)
              AladinImportBridge.buildCategories()
                    Unique (categoryName, contentType) çiftleri → CategoryModel
                    channelCount: series için unique seriesName sayısı
                        │
                        ▼
              Isar.categoryModels.putAll()
                        │
                        ▼
              PlaylistModel güncellenir (totalCount, tvCount, movieCount, seriesCount)
```

### B) Xtream Import Akışı

```
Kullanıcı Server/User/Pass girer (SettingsPage)
        │
        ▼
PlaylistService.importXtream()
        │
        ├─► AladinXtreamParser.validate()  → player_api.php?action=login
        │
        ├─► fetchLiveCategories()   → get_live_categories   → CategoryModel[]
        ├─► fetchVodCategories()    → get_vod_categories    → CategoryModel[]
        ├─► fetchSeriesCategories() → get_series_categories → CategoryModel[]
        │           Isar.categoryModels.putAll(tümü)
        │
        ├─► fetchLiveStreams()  → get_live_streams  → ChannelModel[] (batch)
        ├─► fetchVodStreams()   → get_vod_streams   → ChannelModel[] (batch)
        └─► fetchSeriesStreams() → [FIX]
                ├─► _buildCatMap(get_series_categories) → {cat_id: cat_name}
                └─► get_series → ChannelModel[] (batch)
                        • series_id → tvgId
                        • cover     → logoUrl
                        • category_id → catMap lookup → categoryName  ← BUG FIX
                        • seriesName = name  (for DB grouping)
                        • url = ''  (episodes fetched on demand)
                        │
                        ▼
              ChannelService.updateCategoryCountsForPlaylist()  ← BUG FIX
                    Her CategoryModel.channelCount DB'den hesaplanır
```

### C) Dizi Bölümü Akışı (Xtream — On Demand)

```
Kullanıcı SeriesPage'de bir diziye tıklar
        │
        ▼
AladinSeriesDetailPage(seriesName, seriesId=tvgId, playlist)
        │
        ▼
_load()
        │
        ├─► ChannelService.getSeriesEpisodes()
        │       ├─ [M3U] → Bölümler DB'de mevcut → Liste göster ✓
        │       └─ [Xtream] → DB boş (sadece seri kaydı var)
        │                           │
        │                           ▼ [FIX]
        │             AladinXtreamParser.fetchSeriesEpisodes(series_id)
        │                 get_series_info → episodes map
        │                 → List<ChannelModel> (season, episode, url set)
        │                 → ChannelService.saveChannels() → Isar'a yaz
        │
        ▼
Bölüm listesi göster → ListView (sezon filtreli)
        │
Kullanıcı bölüme tıklar
        ▼
PlayerPage(channel=episode, playlist=_filtered)
        │
        ▼ (MethodChannel)
NativePlayerActivity.playCurrentChannel(url)
```

### D) Kategori Satırı Lazy Load Akışı

```
CategoryRow.initState()
        │
        ▼
_fetchNext() ─► ChannelService.getChannelsByCategory(offset=0, limit=100)
        │           [series] → unique seriesName grouping in Dart
        │           [tv/movie] → DB query with offset/limit
        │
        ▼ (kullanıcı sona scroll edince)
_fetchNext() ─► getChannelsByCategory(offset=100, limit=100)  → sayfalama
```

---

## 4. API / Fonksiyon Dokümantasyonu

### `AladinM3UParser`

```dart
static Future<List<AladinIPTVItem>> aladinParseM3U(String content)
// Girdi:  Ham M3U string (60k+ satır)
// Çıktı:  AladinIPTVItem listesi
// Çalışır: Flutter compute isolate (non-blocking)
```

### `AladinXtreamParser`

```dart
Future<bool> validate()
// Girdi:  (constructor: server, username, password)
// Çıktı:  true = geçerli kimlik bilgileri

Future<List<CategoryModel>> fetchLiveCategories(int pid)
Future<List<CategoryModel>> fetchVodCategories(int pid)
Future<List<CategoryModel>> fetchSeriesCategories(int pid)
// Girdi:  playlistId (Isar foreign key)
// Çıktı:  DB'ye yazılmaya hazır CategoryModel listesi

Stream<List<ChannelModel>> fetchLiveStreams(int pid)
Stream<List<ChannelModel>> fetchVodStreams(int pid)
Stream<List<ChannelModel>> fetchSeriesStreams(int pid)
// Girdi:  playlistId
// Çıktı:  200'lük batch'ler halinde ChannelModel stream'i

Future<List<ChannelModel>> fetchSeriesEpisodes(
    String seriesId, int pid, String categoryName)
// Girdi:  seriesId = Xtream series_id, pid = playlistId
// Çıktı:  Bölüm ChannelModel listesi (season, episode, url set)
// Kullanım: Kullanıcı dizi detay sayfasını açtığında on-demand çağrılır
```

### `AladinImportBridge`

```dart
Stream<List<ChannelModel>> importFromUrl(String url, int playlistId, ...)
Stream<List<ChannelModel>> importFromFile(String filePath, int playlistId, ...)
// Girdi:  URL veya lokal dosya yolu
// Çıktı:  200'lük batch stream

static List<CategoryModel> buildCategories(
    Iterable<ChannelModel> channels, int playlistId)
// Girdi:  Import edilen tüm kanallar
// Çıktı:  Sıralı, sayım doğru CategoryModel listesi
// Not:    Dizi kategorileri için unique seriesName sayılır (episode değil)
```

### `ChannelService`

```dart
Future<List<CategoryModel>> getCategories(
    {required int playlistId, required String contentType})
// Girdi:  playlistId, 'tv'|'movie'|'series'
// Çıktı:  sortOrder'a göre sıralı kategori listesi

Future<List<ChannelModel>> getChannelsByCategory({
    required int playlistId, required String categoryName,
    required String contentType, int offset, int limit})
// Not:    series → Dart'ta unique seriesName grouping yapılır
//         tv/movie → DB offset/limit ile sayfalama

Future<void> saveChannels(List<ChannelModel> channels)
// Yeni eklendi: Xtream episode fetcher tarafından kullanılır

Future<bool> hasEpisodes(int playlistId, String seriesName)
// Yeni eklendi: DB'de bölüm olup olmadığını kontrol eder (season != null)

Future<void> updateCategoryCountsForPlaylist(int playlistId)
// Yeni eklendi: Xtream import sonrası channelCount'u DB'den hesaplar
```

### `PlaylistService`

```dart
Future<PlaylistModel> importM3U({
    required String url, required String name,
    bool isLocalFile, ProgressCallback? onProgress})
// Tüm pipeline: download → parse → batch save → kategori build → count güncelle

Future<PlaylistModel> importXtream({
    required String server, required String username,
    required String password, required String name,
    ProgressCallback? onProgress})
// Tüm pipeline: validate → kategoriler → live/vod/series streams → count güncelle [FIX]
```

### `NativePlayerActivity` (Kotlin)

```kotlin
fun prepareAndPlay()   // REALTEK reset: 500ms bekleme + GC + ExoPlayer init
fun playCurrentChannel()  // MediaItem.fromUri + seek restore + play
fun cycleTracks(trackType: Int)  // Altyazı/ses/kalite döngüsü (KIRMIZI/YEŞİL/SARI tuş)
fun cycleAspectRatio()  // Sığdır → Doldur → Zoom döngüsü (MAVİ tuş)
override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean
// ENTER=play/pause, BACK=çık+kaydet, SOL/SAĞ=VOD seek veya ses kontrolü
```

---

## 5. Teknik Yetkinlikler ve Bağımlılıklar

### Teknoloji Yığını

| Katman | Teknoloji | Versiyon |
|--------|-----------|----------|
| UI Framework | Flutter | ≥3.2.0 |
| Database | Isar | ^3.1.0+1 |
| Video (Native) | ExoPlayer (Media3) | (Gradle bağımlılığı) |
| HTTP | http | ^1.2.1 |
| HTTP (advanced) | Dio | ^5.4.3+1 |
| State Management | Provider | ^6.1.2 |
| Image Cache | cached_network_image | ^3.3.1 |
| EPG/XML | xml + archive | ^6.5.0 / ^3.6.1 |
| SVG | flutter_svg | ^2.0.10 |
| Shimmer | shimmer | ^3.0.0 |
| File Picker | file_picker | ^8.0.6 |
| Localisation | intl | ^0.19.0 |
| AI | google_generative_ai | ^0.4.7 |

### Geliştirme Araçları

```yaml
isar_generator: ^3.1.0+1   # Isar G dosyaları için
build_runner: ^2.4.9        # Kod üretici
flutter_launcher_icons: ^0.13.1
flutter_lints: ^3.0.0
```

### Android Yapılandırması

- `minSdk: 21`, `targetSdk: 28+` (Android TV)
- `dependency_overrides: isar_flutter_libs: 3.1.0+1` (versiyon çakışması önlemi)
- AndroidManifest: `android:banner`, `leanback` intent filter, `INTERNET` permission

---

## 6. Kullanım Senaryoları (Prompting)

Bu bölüm, bir AI asistanının bu kod tabanında çalışırken hangi fonksiyonu kullanması gerektiğini tanımlar.

| Senaryo | Çağrılacak Fonksiyon / Dosya |
|---------|------------------------------|
| Yeni M3U URL import et | `PlaylistService.importM3U(url, name)` |
| Yeni Xtream bağlantısı import et | `PlaylistService.importXtream(server, username, password, name)` |
| Lokal .m3u dosyası import et | `PlaylistService.importM3U(url=path, isLocalFile=true)` |
| Kategorileri listele | `ChannelService.getCategories(playlistId, contentType)` |
| Kategori içeriğini getir (sayfalı) | `ChannelService.getChannelsByCategory(...)` |
| Dizi bölümlerini getir (M3U) | `ChannelService.getSeriesEpisodes(playlistId, seriesName)` |
| Dizi bölümlerini getir (Xtream) | `AladinXtreamParser.fetchSeriesEpisodes(seriesId, pid, catName)` |
| Kanal ara | `ChannelService.search(playlistId, query)` |
| Favori toggle | `ChannelService.toggleFavorite(channelId)` |
| Son izlenenleri getir | `ChannelService.getRecent(playlistId, limit)` |
| Playlist sil | `PlaylistService.delete(id)` |
| Playlist yenile | `PlaylistService.importM3U()` veya `importXtream()` (mevcut kaydı siler, yeniden yazar) |
| EPG zorla güncelle | `AladinEpgEngine.instance.forceSync()` |
| Video oynat | `Navigator.push(PlayerPage(channel, playlist))` → MethodChannel |
| M3U string parse et | `AladinM3UParser.aladinParseM3U(content)` |
| Xtream kimlik bilgilerini doğrula | `AladinXtreamParser.validate()` |
| Kategori sayılarını güncelle (Xtream) | `ChannelService.updateCategoryCountsForPlaylist(playlistId)` |

### Kritik Uyarı — Xtream Dizi Akışı

```
❌ YANLIŞ: ChannelService.getSeriesEpisodes() tek başına kullanmak (Xtream'de boş döner)
✅ DOĞRU:
   1. getSeriesEpisodes() → boş mu?
   2. Evet + playlist.type == 'xtream' + seriesId != null
      → AladinXtreamParser.fetchSeriesEpisodes()
      → ChannelService.saveChannels()
      → DB'ye yaz → listeyi güncelle
```

---

## 7. Yetenek Tanımları ve Kazanımlar

### Uygulamanın Yapabildiği

- 60.000+ kanallı M3U playlistleri indirip parse edebilir ve < 30s'de DB'ye kaydedebilir
- Xtream Codes API üzerinden live, VOD ve dizi içerik listelerini ayrı ayrı senkronize edebilir
- Diziler için bölümleri Xtream API'sinden on-demand (tıklandığında) çekebilir
- TV, Film, Dizi içeriklerini otomatik sınıflandırabilir (URL pattern + regex + grup adı)
- Platform prefixlerini (AMZN, NF, DP, HBO, vb.) tanıyarak içeriği etiketleyebilir
- Kategori bazlı yatay şeritlerde lazy loading (sayfalama) yapabilir
- EPG verilerini arka planda senkronize edebilir
- TMDB API üzerinden film/dizi afişi ve meta bilgisi çekebilir
- Android TV D-pad navigasyonunu tam destekler (ExoPlayer native katmanda)
- Realtek chipli düşük RAM'li TV'lerde stabil oynatma yapabilir

### Geliştirme Sürecinde Edinilen Beceriler

- **Isar NoSQL** ile 60k+ kayıt için etkin index tasarımı
- **Flutter compute isolate** ile UI bloklamadan ağır regex işlemi
- **Xtream Codes API** yapısı: live/vod vs series arasındaki alan adı farklılıkları
- **Android TV** için Focus, D-pad, Leanback, ExoPlayer entegrasyonu
- **Realtek TV chip** donanım özellikleri: decoder lock, RAM limiti, GC önemi
- **MethodChannel** ile Flutter ↔ Kotlin native köprü kurma
- **Batch Isar yazma** ile import performans optimizasyonu
- EPG XML parse ve XMLTV formatı

---

## 8. Düzeltme ve Ekleme Önerileri

### 🔴 Kritik Düzeltmeler (Bu sürümde yapıldı)

| # | Sorun | Etkilenen Dosya | Düzeltme |
|---|-------|-----------------|----------|
| 1 | `get_series` API `category_name` yerine `category_id` döndürür → tüm diziler "Diğer" kategorisinde görünüyor | `aladin_xtream_parser.dart` | `_buildCatMap()` ile category_id→name haritası oluşturuldu |
| 2 | Xtream series için `stream_id` yerine `series_id`, `stream_icon` yerine `cover` kullanılıyor | `aladin_xtream_parser.dart` | `_fetchSeries()` ayrı metot olarak yazıldı |
| 3 | Xtream import sonrası tüm kategoriler `channelCount=0` gösteriyor | `aladin_playlist_service.dart` | `updateCategoryCountsForPlaylist()` import sonrası çağrılıyor |
| 4 | Xtream dizisine tıklanınca bölüm listesi boş (DB'de sadece seri başlığı var) | `aladin_series_page.dart` | `fetchSeriesEpisodes()` on-demand çağrısı + DB'ye kayıt |
| 5 | `AladinSeriesDetailPage` `seriesId` ve `playlist` bilgisini almıyordu | `aladin_series_page.dart` | Yeni parametreler eklendi, `_onSeriesTap` güncellendi |
| 6 | `ChannelService.saveChannels()` metodu yoktu | `aladin_channel_service.dart` | Eklendi |

### 🟡 Önerilen İyileştirmeler

| # | Öneri | Öncelik |
|---|-------|---------|
| 1 | `get_series_info` çağrıları önbelleğe alınmalı (SharedPreferences veya Isar'da episode hash) | Orta |
| 2 | Xtream series import progress daha granüler gösterilebilir (kaç seri işlendi) | Düşük |
| 3 | M3U parser: `url = ''` olan xtream seri kayıtlarını `url.isEmpty ? _fetchEpisode() : _play()` şeklinde PlayerPage'de handle et | Orta |
| 4 | Kategori satırları boş (`channels.isEmpty`) olduğunda gizlenmeli; seri sayfasında ghost satırlar görünüyor | Düşük |
| 5 | EPG verisi ve TMDB verisi SharedPreferences yerine Isar'da timestamp ile cache'lenmeli | Düşük |

---

## 9. Hata Yönetimi

### Hata Durumları Tablosu

| Hata | Nerede Oluşur | Ne Yapılmalı |
|------|--------------|--------------|
| `HTTP 400/401/403` | Xtream validate | `'Geçersiz kimlik bilgileri'` mesajı → SettingsPage snackbar |
| `HTTP 4xx/5xx` | M3U URL download | `Exception('HTTP ${res.statusCode}')` → `_showErrorDialog()` |
| `SocketException` | Herhangi ağ çağrısı | `'İnternet bağlantı hatası'` mesajı |
| `HandshakeException` | HTTPS hatalı | `'https → http deneyin'` özel mesajı |
| `TimeoutException` | `http.get(...).timeout(30s)` | Retry veya skip batch |
| `FormatException` | JSON parse (Xtream API) | `try/catch` → `return []` (empty list) |
| `PlaybackException` | ExoPlayer (Kotlin) | Retry ≤3 → nextChannelOnError() |
| Isar write failure | `_db.writeTxn()` | `try/catch` → log + snackbar |
| Dosya bulunamadı | `importFromFile()` | `throw Exception('Dosya bulunamadı: $path')` |
| TMDB timeout | `TmdbService` | Sessiz fail, `_tmdbLoading = false` |
| Xtream episode fetch fail | `fetchSeriesEpisodes()` | `return []` → UI'da "Bölüm bulunamadı" + Retry butonu |

### Kritik Hata Kuralları

- **Hiçbir zaman** `onError: (_, __) {}` gibi sessiz swallow kullanma — en azından `debugPrint` ekle
- Kullanıcıya gösterilen hata mesajları daima `AppStrings` üzerinden gelsin (çok dil desteği)
- Xtream API başarısız olursa `CategoryModel` ve `ChannelModel` yarım halde kalabilir → import tamamlanamadıysa tüm transaction geri al veya silinmiş duruma geç

---

## 10. Kısıtlamalar

| Kısıtlama | Neden |
|-----------|-------|
| Xtream dizi bölümleri `get_series_info` ile her açılışta çekilir (ilk seferinde) | API'de toplu episode endpoint yok; 5000 dizi × get_series_info = çok yavaş; bu yüzden on-demand |
| M3U vs Xtream kanal sayısı farkı (~60k vs ~30k) kalıcıdır | M3U: her bölüm = 1 kayıt. Xtream: her dizi = 1 kayıt (bölümleri ayrı endpoint'te). Mimari fark, düzeltilemez |
| Realtek TV'de aynı anda 2+ video stream başlatılamaz | 1.5GB RAM kısıtı; decoder kilit riski; `MAX_RETRIES=3` + `System.gc()` ile stabilize edildi |
| `file_picker` Android TV'de bazı dosya yollarına erişemeyebilir | Android storage permission kısıtlamaları; `AladinFolderExplorer` custom explorer ile aşıldı |
| EPG senkronizasyonu oynatma sırasında arka planda durduruluyor | RAM tasarrufu için — `aladin_metadata_sync_service.dart.txt` yedek olarak saklandı |
| Isar 3.x `.g.dart` dosyaları `build_runner` ile üretilmeli | Derleme öncesi `flutter pub run build_runner build` zorunlu |
| `isar_flutter_libs: 3.1.0+1` override gerekiyor | Alt paket versiyon çakışması |
| Offline mod yok | Tüm stream URL'leri anlık; offline cache altyapısı mevcut değil |

---

## 11. Genel Notlar ve Öneriler

- **`aladin_metadata_sync_service.dart.txt`** dosyası gereksiz — ya etkin hale getir ya sil. `.txt` uzantısı Flutter derleyicisini karıştırabilir.
- **`video_player: ^2.8.1`** pubspec'te var ama kullanılmıyor (ExoPlayer native). Kaldırılabilir.
- **`google_generative_ai: ^0.4.7`** pubspec'te var ama aktif kullanım görülmedi. Kullanılmıyorsa kaldır — binary boyutunu artırır.
- **`CategoryModel.channelCount`** Xtream import sonrası sıfır gösteriyordu; Bu sürümde düzeltildi.
- **Demo playlist stub'ları** (`aladinDemoPlaylists`) gerçek içerik barındırmadığı için üretim ortamında kaldırılabilir veya kendi demo listenle değiştirilebilir.
- **`aladin_app_strings.dart`** çok büyük — ayrı dosyalara bölünebilir (tr.dart, en.dart, vb.).

---

## 12. AI Yorumu

Bu proje mimari olarak sağlam temel üzerine kurulmuş, ancak **Xtream ve M3U arasındaki API farkı yeterince soyutlanmamış** — bu da birçok kritik hatanın kaynağı olmuştur.

**En önemli mimari risk:** Şu an Xtream serisi tek bir `ChannelModel` kaydı olarak DB'de duruyor (`url=''`). Kullanıcı bölüme tıkladığında PlayerPage bu boş URL'yi native player'a gönderiyor. Bu durum, Xtream serisine tıklanınca oynatmaya çalışması ama başarısız olması anlamına gelir. **Mutlaka** PlayerPage'de `url.isEmpty` kontrolü eklenmelidir — boş URL'de oynatmak yerine detail sayfasına yönlendirmeli.

**En güçlü yapı:** M3U parser + isolate mimarisi gerçekten etkileyici. 60.000 kanallı regex tabanlı parse işlemini UI'ı dondurmadan gerçekleştirmek Flutter'da doğru yapılmış nadir örneklerden biri.

**Realtek optimizasyonu:** `System.gc()` zorlaması ve 500ms gecikme Kotlin katmanında yerinde bir çözüm. Ancak uzun vadede bu TV'lere özel `renderersFactory.setExtensionRendererMode(OFF)` modu denenmelidir — hardware decoder çöküyorsa software decoder her zaman daha güvenli.

---

## 13. Görselleştirme Rehberi

Aşağıdaki sayfaların ekran görüntüsü (screenshot) eklenmesi, projenin kullanıcılara ve diğer geliştiricilere anlatımını önemli ölçüde güçlendirir:

```
[SCREENSHOT — Ana Sayfa / aladin_main_page.dart]
Alt sekme bar: TV | Film | Dizi | Ayarlar
Buraya ana sayfanın landscape görünümünü ekle.

[SCREENSHOT — Canlı TV Sayfası / aladin_live_tv_page.dart]
Kategori şeritleri + üstte EPG bilgisi.
Buraya canlı TV sayfasının ekran görüntüsünü ekle.

[SCREENSHOT — Film Sayfası / aladin_movies_page.dart]
Platform şeritleri (Netflix, Amazon, Disney, vb.)
Buraya film sayfasının ekran görüntüsünü ekle.

[SCREENSHOT — Dizi Sayfası / aladin_series_page.dart]
Kategori satırları + her satırda dizi kartları (afiş).
Buraya dizi sayfasının ekran görüntüsünü ekle.

[SCREENSHOT — Dizi Detay Sayfası / AladinSeriesDetailPage]
Sol: TMDB afişi + puan. Sağ: Sezon filtresi + bölüm listesi.
Buraya dizi detay sayfasının ekran görüntüsünü ekle.

[SCREENSHOT — Player Ekranı / NativePlayerActivity]
ExoPlayer OSD: kanal adı, seek bar, tuş kılavuzu (D-pad yardımı).
Buraya player ekranının ekran görüntüsünü ekle.

[SCREENSHOT — Ayarlar Sayfası / aladin_settings_page.dart]
M3U / Xtream / Lokal sekmeleri + playlist listesi.
Buraya ayarlar sayfasının ekran görüntüsünü ekle.

[SCREENSHOT — Import İlerleme Durumu]
Import sırasındaki progress durumu (parsing, saving 3420 channels...).
Buraya import progress ekranının görüntüsünü ekle.
```

---

## 14. Geliştirme Yol Haritası (Roadmap)

| Özellik | Açıklama | Karmaşıklık |
|---------|----------|-------------|
| **Xtream bölüm önbelleği** | İlk açılışta DB'ye kaydedilen bölümler için "son güncelleme" timestamp kontrolü ekle | Düşük |
| **Çoklu playlist karıştırma** | TV ve Film sekmelerinde birden fazla playlist içeriğini bir arada listele | Orta |
| **Kanal logosu otomatik düzeltme** | Logo yüklenmediğinde `aladin_manual_logos.dart` tablosundan yerel eşleşme | Düşük (kısmen mevcut) |
| **EPG Kılavuzu (tam)** | Canlı TV'de 7 günlük program rehberi grid görünümü | Yüksek |
| **Arama gelişmiş filtre** | İçerik türü (TV/Film/Dizi) + kalite + platform bazlı arama | Orta |
| **Oynatma geçmişi** | Son izlenenleri kategoriye göre gruplayan dedicated sekme | Düşük |
| **Parental Control** | PIN korumalı kategori kilitleme | Orta |
| **Zaman kaydırma (Timeshift)** | Canlı yayında geri sarma — sunucu desteğine bağlı | Yüksek |
| **HEVC/H.265 force mode** | Realtek için belirli formatları yazılım decoder'a yönlendirme seçeneği | Orta |
| **Çevrimdışı mod** | Sık izlenen kanalların stream URL'lerini cache'e alma | Yüksek |

---

---

# ENGLISH

---

## Introduction & Purpose

AladinIPTV Player Pro is a high-performance Android TV IPTV player that allows users to bring their own IPTV license (as an M3U URL, Xtream Codes credentials, or local .m3u file) and browse 60,000+ channels across **Live TV**, **Movies**, and **Series** categories. The app holds no content; it works entirely with user-provided playlists. Video playback runs in a native ExoPlayer (Media3) Android layer; Flutter handles navigation, list management, database, and UI.

---

## Architecture Summary & File Structure

See Türkçe section § 2 for the full annotated file tree (identical structure, language-agnostic).

### Key Architecture Decisions

| Decision | Why |
|----------|-----|
| **Isar** NoSQL embedded DB | ~3× faster than SQLite for 60k+ index-based queries |
| **Isolate-based** M3U parse | 60k-line regex processing doesn't block UI thread |
| **Native ExoPlayer** (Kotlin) | Flutter video libs crash on Realtek/low-RAM TV chips |
| **MethodChannel** bridge | One-way Flutter → Kotlin call; Player context isolated |
| **Provider** state | Sufficient for single playlist, language, refresh; avoids Riverpod overhead |
| **Batch writes** (200-item) | Reduces DB transaction count; saves 60k channels in ~8s vs ~30s |

---

## Flow Diagram (Logical Flow)

See Türkçe section § 3 for the full ASCII flow diagrams (M3U Import, Xtream Import, Series Episode Flow, Category Lazy Load).

---

## API / Function Documentation

See Türkçe section § 4 for complete function signatures, inputs, outputs, and usage notes.

---

## Technical Skills & Dependencies

See Türkçe section § 5 for the full dependency table and Android configuration.

---

## Usage Scenarios (Prompting)

See Türkçe section § 6 for the full scenario → function mapping table.

**Critical Xtream Series Rule:**
```
❌ WRONG: Call getSeriesEpisodes() alone (returns empty for Xtream)
✅ CORRECT:
   1. getSeriesEpisodes() → empty?
   2. Yes + playlist.type == 'xtream' + seriesId != null
      → AladinXtreamParser.fetchSeriesEpisodes()
      → ChannelService.saveChannels() → write to DB → refresh UI
```

---

## Capabilities & Learnings

**What the app can do:**
- Parse 60k+ channel M3U playlists in < 30s via isolate
- Sync Xtream live, VOD, and series lists separately
- Fetch series episodes on-demand from Xtream API
- Auto-classify content (TV/Movie/Series) via URL pattern + regex
- Recognize platform prefixes (AMZN, NF, DP, HBO, etc.)
- Lazy-load category rows with pagination
- Sync EPG in background; fetch TMDB metadata
- Full Android TV D-pad navigation support (native ExoPlayer layer)
- Stable playback on Realtek chipsets with low RAM

**Skills gained:**
- Isar NoSQL index design for 60k+ records
- Flutter compute isolate for non-blocking heavy regex
- Xtream Codes API field differences (live/vod vs series)
- Android TV Focus, D-pad, Leanback, ExoPlayer integration
- Realtek TV hardware specifics: decoder lock, RAM limits, GC importance
- MethodChannel Flutter ↔ Kotlin native bridge
- Batch Isar writing for import performance
- EPG XML parsing, XMLTV format

---

## Bug Fixes & Improvement Proposals

### 🔴 Critical Fixes (Applied in this release)

| # | Bug | File | Fix |
|---|-----|------|-----|
| 1 | `get_series` API returns `category_id` not `category_name` → all series in "Diğer" | `aladin_xtream_parser.dart` | `_buildCatMap()` builds id→name map |
| 2 | Xtream series uses `series_id`/`cover` not `stream_id`/`stream_icon` | `aladin_xtream_parser.dart` | Dedicated `_fetchSeries()` method |
| 3 | All Xtream categories show `channelCount=0` forever | `aladin_playlist_service.dart` | `updateCategoryCountsForPlaylist()` called after import |
| 4 | Tapping Xtream series shows empty episode list | `aladin_series_page.dart` | On-demand `fetchSeriesEpisodes()` + DB save |
| 5 | `AladinSeriesDetailPage` didn't receive `seriesId` or `playlist` | `aladin_series_page.dart` | New parameters + `_onSeriesTap` updated |
| 6 | `ChannelService.saveChannels()` didn't exist | `aladin_channel_service.dart` | Added |

---

## Error Handling

See Türkçe section § 9 for the complete error handling table and rules.

---

## Limitations

See Türkçe section § 10 for the full limitations table.

**Most important permanent limitation:**
> The M3U vs Xtream channel count difference (~60k vs ~30k) is architectural, not a bug. M3U: each episode = 1 record. Xtream: each series = 1 record (episodes at a separate endpoint). Cannot be reconciled without fetching all episodes upfront (too expensive for large libraries).

---

## General Notes & Recommendations

- **`aladin_metadata_sync_service.dart.txt`**: rename or remove; `.txt` extension may confuse the Dart compiler
- **`video_player: ^2.8.1`**: unused (native ExoPlayer used instead) — remove to reduce binary size
- **`google_generative_ai: ^0.4.7`**: no active usage found — remove if unused
- **Demo playlists** in `AppState`: replace with your own for production

---

## AI Commentary

The project has a solid architectural foundation. The **M3U parser + isolate design** is genuinely impressive — parsing 60k channels via regex without freezing the UI is done correctly.

The **primary risk** is the `url=''` pattern for Xtream series entries. When a user taps a series, `PlayerPage` receives a `ChannelModel` with an empty URL and passes it to the native player, which will fail. A guard must be added in `PlayerPage`: if `channel.url.isEmpty`, navigate to `AladinSeriesDetailPage` instead of launching the player.

The **Realtek-specific** `System.gc()` + 500ms delay is a pragmatic short-term solution. Long-term, consider `EXTENSION_RENDERER_MODE_OFF` for Realtek chips to force software decoding from the start.

---

## Visualization Guide

See Türkçe section § 13 for screenshot placement recommendations (Main Page, Live TV, Movies, Series, Series Detail, Player, Settings, Import Progress).

---

## Development Roadmap

See Türkçe section § 14 for the full roadmap table with complexity ratings.

**Top 3 priorities:**
1. **Xtream episode cache timestamp** — low complexity, high user impact
2. **PlayerPage `url.isEmpty` guard** — critical safety fix, low complexity  
3. **Full EPG guide grid** — high complexity, high premium value



## V2.1.4 Sürüm Notları:

Yapılan Geliştirmeler:
1.Akıllı Kategori Eşleştirme (AladinXtreamParser):
◦Xtream API'sinden gelen category_id değerlerini category_name ile eşleştiren fetchCategoryMap fonksiyonu eklendi.
◦Bu sayede canlı yayın, film ve dizilerin "Diğer" kategorisine düşme sorunu çözüldü; her içerik kendi kategorisinde doğru şekilde listeleniyor.
2.Xtream Dizi Yapılandırması:
◦_fetchSeries metodu, Xtream'e özel series_id ve cover alanlarını kullanacak şekilde optimize edildi.
◦Diziler için veritabanına sadece "ana kart" bilgisi (URL boş olacak şekilde) kaydediliyor. Bu, mevcut dizi gruplama mantığınızla tam uyum sağlıyor.
3.On-Demand Bölüm Çekme (AladinSeriesDetailPage):
◦Dizi detay sayfası güncellendi. Eğer veritabanında o diziye ait bölüm yoksa (Xtream'den yeni yüklenmişse), otomatik olarak Xtream API'sine (get_series_info) istek atıp bölümleri çekiyor, veritabanına kaydediyor ve listeliyor.
4.Kanal Sayıları ve Senkronizasyon:
◦ChannelService içine updateCategoryCountsForPlaylist fonksiyonu eklendi. Xtream yüklemesi bittikten sonra tüm kategorilerin kanal ve dizi sayılarını veritabanından hesaplayıp güncelliyor. Böylece arayüzde kategorilerin yanında doğru içerik sayıları görünüyor.
Sonuç: Artık Xtream üzerinden gelen içerikler de tıpkı M3U gibi kategorize edilecek ve diziler tıpkı istediğin gibi "ana kart -> sezon/bölüm listesi" akışıyla çalışacak.

## V2.1.5 Sürüm Notları:

1.aladin_series_page.dart: Eksik olan AladinXtreamParser import'u eklendi ve AladinSeriesDetailPage parametreleri (özellikle seriesId) doğru şekilde yapılandırıldı.
2.aladin_xtream_parser.dart: Kategori eşleştirme mantığı (fetchCategoryMap) ve dizi bölümleri çekme fonksiyonları hatasız hale getirildi.
3.aladin_playlist_service.dart: Import sürecinde yeni fonksiyonların (fetchCategoryMap gibi) kullanımı güncellendi.
4.aladin_channel_service.dart: Yeni eklenen saveChannels ve updateCategoryCountsForPlaylist fonksiyonları veritabanı işlemlerine uygun hale getirildi.

## V2.1.6 Sürüm Notları:

1.Akıllı Yükleme Mantığı: AladinSeriesDetailPage içine, eğer veritabanından gelen listede sadece URL'si boş bir kayıt varsa (yani sadece ana seri kaydı varsa), otomatik olarak Xtream API'sinden bölümleri çekme komutu eklendi.
2.Filtreleme: Sezon ve bölüm listesinde, artık URL'si boş olan "ana seri kaydı" gizleniyor. Böylece sadece gerçek ve oynatılabilir bölümler listede yer alıyor.
3.Gelişmiş Veri Ayrıştırma: Bazı Xtream sunucularında bölüm isimleri title yerine name, bölüm numaraları ise episode yerine episode_num olarak gelebiliyor. Bu alanların tamamını kontrol edecek şekilde parser'ı güncelledim.
Güncellenen Dosyalar:
•lib/features/series/aladin_series_page.dart: Yükleme mantığı ve liste filtreleme düzeltildi.
•lib/core/parsers/aladin_xtream_parser.dart: Bölüm metadata çekimi (isim ve numara) daha esnek hale getirildi.
Şu an dizilere tıkladığında, sistem bölümlerin eksik olduğunu anlayacak, arka planda API'den çekecek ve veritabanına kaydederek listeyi güncelleyecektir.

## V2.1.6 Sürüm Notları:

Ayarlar sayfasındaki klavye ve TV kumandası navigasyon sorunlarını çözmek için aşağıdaki iyileştirmeleri yaptım:
1.Kumanda Odaklanma Sorunu (OK/Enter): Yazı girilen alanlardaki (Server, Kullanıcı Adı vb.) odaklanma mantığını tamamen yeniledim. Artık kumandanın "OK" tuşuna bastığınızda yazı alanı doğrudan aktif hale gelecek ve ekran klavyesi açılacaktır (Mouse kullanımına gerek kalmadı).
2.Klavye Kapatma Sorunu (Obscuring Fields): Yazı alanlarına scrollPadding ekledim. Bu sayede ekran klavyesi açıldığında, üzerinde çalıştığınız kutu otomatik olarak klavyenin üstünde kalacak şekilde yukarı kaydırılacaktır. Ayrıca dikey (Portrait) görünümdeki sabit yükseklik kısıtlamalarını esneterek ekranın daha esnek dolmasını sağladım.
3.Otomatik Geçiş Akışı:
◦Bir alanı doldurup kumandadan "İleri/Next" (veya klavyedeki onay tuşu) dediğinizde, odak otomatik olarak bir sonraki kutuya geçecektir.
◦Tüm bilgiler girildiğinde (örn. Playlist Adı sonrası), odak doğrudan "Yükle/Bağlan" butonunun üzerine gidecektir.
4.Hızlı Başlangıç: Ayarlar sayfası ilk açıldığında veya sekmeler (M3U/Xtream) arasında geçiş yapıldığında, kumanda odağı otomatik olarak en üstteki ilk kutuya (URL veya Sunucu) yerleşecektir.



## V2.1.7 Sürüm Notları:

1. Film/Dizi Bilgi Paneli (Pause Modu)
   •   Akıllı Bilgi Ekranı: Video durdurulduğunda (Pause), ekranın sol tarafında içeriğe özel bir bilgi paneli açılır.
   •   İçerik Duyarlılığı: Eğer bu bir Canlı TV yayını ise sadece kanal ismi görünür. Eğer Film veya Dizi ise; afiş (poster), yapım yılı, IMDb puanı ve içerik özeti (description) ekrana gelir.
   •   Arka Planda Bilgi Çekimi: Veriler Flutter tarafındaki TMDB veritabanından alınarak native oynatıcıya aktarılır.
2. Hassas İleri/Geri Sarma ve Zaman Takibi
   •   Doğru Zamanlama: Video ilerleme çubuğu (SeekBar) ve dakika/saniye göstergeleri artık ExoPlayer'dan gelen gerçek zamanlı verilerle senkronize çalışıyor.
   •   Adlama Süreleri: TV kumandasına daha uygun olması için; Sağ tuş 30 saniye ileri, Sol tuş 10 saniye geri saracak şekilde optimize edildi.
   •   OSD (Ekran Bilgisi): Sarma işlemi sırasında o anki pozisyon ve ilerleme durumu ekranda net bir şekilde görünür.
3. "İzlemeye Devam Et" Özelliği
   •   Otomatik Kayıt: Bir videonun %1'i ile %90'ı arasında bir kısmı izlendiğinde, izleme pozisyonu otomatik olarak veritabanına kaydedilir.
   •   Listeleme: Film ve Dizi ana sayfalarına en başa "⏳ Kaldığın Yerden" şeridi eklendi.
   •   Kaldığı Yerden Başlatma: Bu listeden bir içeriğe tıklandığında, video milisaniyesine kadar kaldığı yerden devam eder.
4. Hızlı Kanal Değiştirme (Zapping) ve Stabilizasyon
   •   Debounce Mantığı: Kumandada yukarı/aşağı tuşlarına çok hızlı basıldığında oluşan "seslerin birbirine girmesi" sorunu, 500ms'lik bir gecikme (debounce) ve temizleme mekanizmasıyla çözüldü.
   •   Güvenli Geçiş: Yeni bir yayına geçmeden önce eski oynatıcı ve dekoder kaynakları tamamen serbest bırakılır, böylece Realtek gibi düşük RAM'li cihazlarda çökme ve ses çakışması engellenir.
   Güncelleme Yapılan Dosyalar:
   •   NativePlayerActivity.kt & activity_player.xml: Tüm görsel ve mantıksal oynatıcı süreçleri.
   •   MainActivity.kt & aladin_player_page.dart: Veri aktarımı ve Flutter-Native iletişimi.
   •   aladin_channel_service.dart & aladin_channel_model.dart: Veritabanı izleme geçmişi altyapısı.
   •   aladin_movies_page.dart & aladin_series_page.dart: UI tarafındaki "İzlemeye Devam Et" listeleri.

## V2.1.8 Sürüm Notları:
Özetle Son Durum:
•Pause Bilgi Paneli: Tamamlandı. Film/Dizi bilgilerini (poster, IMDb, yıl, özet) sol tarafta gösteriyor. TV yayınlarında sadece kanal ismini koruyor.
•Hassas İleri/Geri Sarma: Tamamlandı. Süreler artık anlık ve doğru güncelleniyor.
•İzlemeye Devam Et: Tamamlandı. %1 - %90 arası izlenen içerikler hem film hem dizi sekmelerinde en başta görünüyor.
•Zapping Fix: Tamamlandı. Hızlı kanal değişimlerinde seslerin birbirine karışması ve çökme riski 500ms debounce ve temizleme mekanizmasıyla giderildi.

## V2.1.9 Sürüm Notları:
1.Dosyaya Eklenen Temel Başlıklar:
◦İzlemeye Devam Et (Continue Watching): %5 - %90 arası izleme takibi ve 60 saniyelik veritabanı senkronizasyonu dokümante edildi.
◦Native Oynatıcı Zekası: Pause modunda çıkan TMDB bilgi paneli ve hassas zaman kontrolü (30sn ileri / 10sn geri) teknik detaylara eklendi.
◦TV UX Mühendisliği: Ayarlar sayfasındaki kumanda odak yönetimi, otomatik alan geçişleri ve klavye duyarlı arayüz özellikleri vurgulandı.
2.Xtream Derin Entegrasyonu:
◦ID-İsim kategori eşleştirmesi ve on-demand (tıklandığında) bölüm çekme mimarisi projeye dahil edildi.
3.Performans Optimizasyonu:
◦Hızlı kanal değişimlerindeki (Zapping) ses çakışmalarını önleyen 500ms debounce ve Realtek bellek temizleme mekanizması güncellendi.

## V2.1.9.1 Sürüm Notları:
Talepleriniz doğrultusunda şu geliştirmeleri yaptım:
"Kaldığım Yerden" Ayrımı:
◦LiveTvPage (TV Sayfası) içerisindeki "Kaldığım Yerden" listesini çıkardım.
◦Film ve Diziler kendi sayfalarındaki ("Filmler" ve "Diziler") "Kaldığım Yerden / İzlemeye Devam Et" şeritlerinde yer almaya devam edecek.
2.Dizi Bölümü Poster Fallback (Geri Dönüş):
◦Xtream servisinden dizi bölümleri çekilirken, eğer bölüme ait özel bir poster (thumbnail) yoksa, otomatik olarak dizinin ana posterini kullanacak şekilde güncelledim.
◦Ayrıca ChannelCard bileşenine genel bir iyileştirme ekleyerek, logo yüklenemediğinde TMDB posterine, o da yoksa varsayılan placeholder'a geçiş yapmasını sağladım.
3.Dizi Navigasyonu İyileştirmesi:
◦ChannelModel yapısına parentSeriesId ekledim. Böylece "Kaldığım Yerden" kısmındaki bir bölüme tıkladığınızda, uygulamanın o bölümün ait olduğu dizinin ana detay sayfasına (tüm bölümlerin olduğu liste) doğru şekilde gitmesini sağladım.
Yapılan Değişiklikler:
•lib/core/models/aladin_channel_model.dart: Dizi bölümleri için parentSeriesId alanı eklendi.
•lib/core/parsers/aladin_xtream_parser.dart: Bölüm çekme işlemine ana poster ve parent ID mantığı eklendi.
•lib/features/live_tv/aladin_live_tv_page.dart: TV sayfasındaki son izlenenler listesi sadece canlı kanallarla sınırlandırıldı.
•lib/features/series/aladin_series_page.dart: Bölüm üzerinden dizi detay sayfasına geçiş mantığı düzeltildi.
•lib/shared/widgets/aladin_channel_card.dart: Görsel yükleme hataları için fallback mekanizması güçlendirildi.

## V2.1.9.2 Sürüm Notları:

Kategori sayfasında bir film veya dizi seçildiğinde sadece o içeriğin gitmesi, oynatıcıda (player) ileri-geri yapmayı veya listeden seçim yapmayı engelliyordu.
Bu durumu şu şekilde düzelttim:
1.Kategori Listesini Player'a Gönderme: AladinCategoryPage (Kategori sayfası) üzerinden bir Film veya TV kanalı seçtiğinizde, artık sadece seçtiğiniz kanal değil, o kategorideki tüm liste oynatıcıya gönderiliyor. Böylece player içindeyken kategorideki diğer filmlere kolayca geçiş yapabileceksiniz.
2.Diziler İçin Akıllı Navigasyon: Eğer kategori sayfasından bir Dizi seçerseniz, artık doğrudan player'a gitmek yerine o dizinin detay sayfasına (bölüm listesine) yönlendiriliyorsunuz. Oradan bir bölüm seçtiğinizde ise yine o sezondaki tüm bölümler player'a beraber gidiyor.
3.Dizi Bölümleri Arası Geçiş: Dizi detay sayfasından bir bölüm açtığınızda, seçtiğiniz sezonun tüm bölümleri player'a yüklendiği için bölümler arası geçiş (Sonraki Bölüm / Önceki Bölüm) sorunsuz çalışacaktır.
Yapılan Değişiklikler:
•lib/features/content/aladin_category_page.dart: Tıklama (onTap) fonksiyonu tüm listeyi de kapsayacak şekilde güncellendi.
•lib/features/aladin_main_page.dart: Kategori sayfasından gelen tıklamalar için "İçerik Tipine Göre Yönlendirme" (Diziyse Detay Sayfasına, Filmse Player'a tüm listeyle) mantığı eklendi.
Artık kategori sayfasından bir içerik açıldığında, oynatıcı listenin geri kalanına da hakim olacak.

## V2.1.9.3 Sürüm Notları:
Play Store yayını için gerekli tüm kritik güncellemeleri ve talep ettiğiniz düzenlemeleri tamamladım. Uygulamanız artık yayına hazır bir yapıya sahip.
Yapılan Temel Düzenlemeler:
1.İzinler ve Güvenlik:
◦MANAGE_EXTERNAL_STORAGE izni kaldırıldı. Yerine sadece M3U dosyalarını okumak için yeterli olan READ_EXTERNAL_STORAGE bırakıldı. Bu, Google Play'in reddetme riskini ortadan kaldırır.
◦requestLegacyExternalStorage bayrağı temizlendi.
2.Uygulama Kimliği (Package Name):
◦Uygulama paket adı (Application ID) ve Namespace com.aladin.iptv.player.pro olarak güncellendi.
◦Kotlin dosyaları (MainActivity.kt, NativePlayerActivity.kt) yeni dizin yapısına taşındı ve paket isimleri/referansları bu yeni yapıya göre düzenlendi.
3.Görsel Hazırlık:
◦TV Banner yolu @mipmap/tv_banner olarak ayarlandı.
◦pubspec.yaml dosyasında uygulama ikonu assets/icons/app_logo.png olarak güncellendi ve flutter_launcher_icons ayarları TV standartlarına (adaptive icon) uygun hale getirildi.
4.Temiz Başlangıç (Demo Kaldırma):
◦aladinDemoPlaylists tamamen boşaltıldı. Uygulama artık temiz bir sayfa ile açılacak ve kullanıcıyı doğrudan "Ayarlar" üzerinden kendi listesini eklemeye yönlendirecek.
◦Ana sayfadaki "Veriler senkronize ediliyor" çubuğu kaldırıldı.
5.Hakkında (About) Bölümü:
◦Ayarlar sayfasına bir "Hakkında" butonu eklendi.
◦Bu bölümde uygulamanın adı, sürümü (v2.2.0) ve geliştirici bilgisi yer alıyor.
◦GitHub sayfanıza (https://github.com/tezalaaddin) giden tıklanabilir bir bağlantı eklendi.
6.Sürüm ve Yapılandırma:
◦pubspec.yaml dosyasındaki sürüm numarası isteğiniz üzerine 2.2.0+1 olarak güncellendi.

## V2.1.9.4 Sürüm Notları:
---Yapılan İyileştirmeler:
1.Sorun 1 (Navigasyon Barından Sağ Tuşla Geçiş):
◦LiveTvPage, MoviesPage ve SeriesPage sayfalarına, henüz bir playlist yüklü değilken veya liste boşken ekranda görünen butonlara (Ayarlara Git / Tekrar Dene) autofocus: true özelliği eklendi.
◦Bu sayede navigasyon barındayken sağ tuşa bastığınızda, kumanda odağı "boşlukta kaybolmak" yerine doğrudan bu butonların üzerine konacaktır.
2.İstek 1 (Geri Tuşu ile Navigasyon Barına Dönüş):
◦MainPage (Ana Sayfa) içerisindeki PopScope mantığı güncellendi.
◦Hangi menüde olursanız olun, kumandanın "Geri" (Back) tuşuna bastığınızda (çıkış onayı diyaloğu açılmadan hemen önce ve diyalogda "Hayır" denilirse hemen sonra) odak otomatik olarak sol taraftaki navigasyon barına çekilir.
3.Sorun 2 (Ayarlar Sayfası ve Metin Alanları):
◦EPG Butonu: EPG satırındaki kapsayıcı odak kaldırıldı, böylece kumanda ile bu satıra gelindiğinde odak doğrudan "EPG Güncelle" butonuna yerleşir.
◦Metin Alanları (TextField) Navigasyonu:
▪Metin alanındayken (klavye açık olsun veya olmasın) Yukarı/Aşağı tuşlarına bastığınızda, odak o alandan çıkar ve bir sonraki/önceki öğeye geçer.
▪Metin alanındayken Tamam/OK/Enter tuşuna basıldığında ekran klavyesi otomatik olarak açılır.
▪Metin alanındayken Geri (Back/Escape) tuşuna basıldığında klavye kapanır ve metin alanından çıkış yapılır (unfocus).
Klavye Kayması Çözümü: Language, EPG ve About satırlarını ana ekranın altından alıp, her formun (M3U, Xtream, Lokal) kendi kaydırılabilir alanı (SingleChildScrollView) içerisine en alta taşıdım.
◦Bu sayede klavye açıldığında bu satırlar metin alanlarını yukarı itip ekranı daraltmak yerine, sadece formun sonunda "aşağıda" kalacaklar. Metin alanlarınız artık her zaman görünür olacak.
Güncellenen Dosyalar:
•lib/features/aladin_main_page.dart: Geri tuşu odak yönetimi eklendi.
•lib/features/settings/aladin_settings_page.dart: _TVTextField ve EPG butonu odak mantığı baştan aşağı yenilendi.
•lib/features/live_tv/aladin_live_tv_page.dart: Boş durum butonu için autofocus eklendi.
•lib/features/movies/aladin_movies_page.dart: Boş durum butonu için autofocus eklendi.
•lib/features/series/aladin_series_page.dart: Boş durum butonu için autofocus eklendi.

## V2.1.9.5 Sürüm Notları:

Play Store öncesi bu dokunuşlar gerçekten kritikti. Önerdiğin tüm düzeltmeleri koda uyguladım.
Yapılan Düzenlemeler:
1.Release İmzalama Altyapısı (Kritik):
◦build.gradle.kts dosyasını, android/key.properties dosyasından imza bilgilerini otomatik okuyacak şekilde yapılandırdım.
◦release derleme türü (build type), artık imza dosyası mevcutsa release konfigürasyonunu, değilse debug konfigürasyonunu kullanacak.
◦Önemli: Senin de belirttiğin gibi, keytool ile oluşturacağın .jks dosyasını android/ klasörüne koyup, bilgileri key.properties içine yazmayı unutma.
2.NativePlayerActivity exported="false" (Kritik):
◦AndroidManifest.xml içinde NativePlayerActivity için android:exported="false" satırını ekledim. Bu, Android 12+ için zorunludur ve Play Store reddi almamanı sağlar.
3.SDK Versiyonları (API 35):
◦compileSdk ve targetSdk değerlerini 36'dan 35'e çektim. Şu an için en kararlı ve Play Store'un beklediği en güncel standart budur.
4.TV Banner Konumu:
◦AndroidManifest.xml içinde banner referansını @mipmap/tv_banner yerine @drawable/tv_banner olarak güncelledim.
◦Yapman Gereken: android/app/src/main/res/mipmap-xxxhdpi/tv_banner.png dosyasını android/app/src/main/res/drawable-xhdpi/ klasörüne taşıman (klasör yoksa oluşturmalısın) görsel kalite ve standart açısından daha doğru olacaktır.
Kontrol Listesi (Güncel Durum):
İmzalama Altyapısı Hazır
key.properties ve .jks eklemen yeterli.
Native Activity Export düzeltildi
android:exported="false" eklendi.
Target SDK 35
API 36'dan 35'e düşürüldü.
Manifest'te @drawable yapıldı.
Sadece READ_EXTERNAL_STORAGE ve internet izinleri var.

## V2.1.9.6 Sürüm Notları:

R8 (yeni nesil Proguard) derleyicisi, Flutter'ın çekirdek kütüphanelerinde yer alan ancak projenizde fiziksel olarak bulunmayan Google Play Core bileşenlerini aradığı için "Warning" (Uyarı) veriyor ve bu uyarılar derleme sürecinde veya uygulama çalışma anında (runtime) çökmelere neden olabiliyor.
Belirttiğiniz satırları proguard-rules.pro dosyasına ekledim. Bu sayede R8, bu eksik kütüphaneler için uyarı vermeyi bırakacak ve uygulamayı "eksiksiz" olarak paketleyecektir.
Televizyonlar için tasarladığımız "odaklanma" (focus) sistemi, telefonlarda "dokunma" (gesture) olaylarını kapsamadığı için bu sorunlar yaşanıyor. Hem diyaloglardaki butonlara dokunma desteği ekleyerek hem de oynatıcıda dokunmatik ekran davranışlarını düzelterek bu pürüzleri giderelim.
Yapılacak Düzenlemeler:
1.Diyalog Butonları (Smart TV & Telefon Uyumu): _TVDialogButton bileşenlerine dokunma (GestureDetector) desteği ekliyorum. Böylece telefonlarda parmakla basıldığında da onPressed tetiklenecek.
2.Video Oynatıcı (OSD Kontrolü): Telefonlarda ekrana dokunulduğunda kontrol panelinin (OSD - On Screen Display) açılmasını sağlayacak dokunma dinleyicisi ekliyorum.
Şu an itibariyle:
•✅ Diyaloglar: Hem TV kumandasıyla hem de telefonlarda dokunarak onaylanabiliyor.
•✅ Oynatıcı: Telefonlarda ekrana dokunulduğunda kontroller açılıyor.
•✅ Güvenlik: Android 14 çökme sorunu giderildi.
•✅ İmzalama ve Mağaza: Play Store için gerekli tüm isim, ikon ve paket yapılandırmaları yapıldı.

## V2.1.9.7 Sürüm Notları:

Telefon kullanıcıları için oynatıcıyı (player) tamamen dokunmatik hale getirdim. Artık sadece TV kumandasıyla değil, parmak hareketlerinizle de tüm kontrollere hakim olabilirsiniz.
Eklenen Dokunmatik Özellikler:
1.Ekran Hareketleri (Gestures):
◦Tek Tıklama: Kontrol panelini (OSD) açar veya kapatır.
◦Çift Tıklama: Videoyu durdurur veya devam ettirir (Pause/Play).
◦Sağ/Sol Kaydırma:
▪Film/Dizi: İleri (30sn) veya geri (10sn) sarar.
▪Canlı TV: Sesi yükseltir veya alçaltır.
◦Yukarı/Aşağı Kaydırma: Bir sonraki veya bir önceki kanala/videoya geçer.
◦Uzun Basma: Kanalı veya videoyu favorilere ekler/çıkarır.
2.Tıklanabilir Kontrol Butonları:
◦Ekranın altındaki renkli rehber yazılarını (Altyazı, Ses, Kalite, Oran, Favori) artık buton gibi kullanabilirsiniz.
◦Üzerlerine dokunduğunuzda ilgili ayar (Diller arası geçiş, görüntü oranı vb.) anında değişir.
3.Hızlı Favori: Kanal isminin yanındaki yıldız ikonuna dokunarak da favori durumunu değiştirebilirsiniz.
Yapılan Değişiklikler:
•NativePlayerActivity.kt: Dokunma sensörü (GestureDetector) entegre edildi ve tüm fonksiyonlar bu sensöre bağlandı.
•activity_player.xml: Alt kısımdaki yazılar, dokunmaya hassas ve buton olarak işlev görecek şekilde güncellendi.
Artık hem televizyonda kumandayla hem de cep telefonunda dokunarak profesyonel bir oynatıcı deneyimi elde edeceksiniz.

## UI TARAFI AÇIKLAMASI:

# İlk uygulama çalıştırıldığında kullanıcıdan dil tercihi istenir.
# Daha sonra aladin_live_tv_page.dart sayfası gelir. ilk açılışta hiç bir playlist olmadığı için kullanıcıya bir playlist yüklemesi için aladin_settings_page.dart'ye gitmesi istenir.
# Kullanıcı aladin_settings_page.dart’a gider. Orda çeşitli seçenekleri (M3U URL, XTREAM, LOCAL) kullanarak Playlistini yükler.
# Yüklenen bu kanallar Aktif Edilsin mi? Diye bir onay gelir. Kullanıcı onaylarsa bu playlist aktif edilerek kullanıcı TV kanallarının listelendiği aladin_live_tv_page.dart sayfasına yönlendirilir.
# Ana Ekranda ilk görüntü şu şekildedir. (TV’ler için olan yatay ekranda)
# Sol Tarafta Navigasyon paneli bulunur. Burada yukardan aşağıya doğru;
aladin_live_tv_page.dart
aladin_movies_page.dart
aladin_series_page.dart
aladin_search_page.dart
aladin_favorites_page.dart
aladin_settings_page.dart

sayfalarına yönlendiren linkler bulunuyor.
# Kullanıcı burada extra olarak tanımlanan renkli olan tv kumanda tuşları ile gezinebiliyor. (mesela kırmızı- aladin_live_tv_page.dart, yeşil- aladin_movies_page.dart, sarı- aladin_series_page.dart, mavi- aladin_settings_page.dart sayfalarına gidebilir)
# Kullanıcı bunlardan birine geldiği zaman bu defa ilgili ekran içeriği sağ tarafta listeleniyor.
# Tüm sayfalarda (aladin_live_tv_page.dart, aladin_movies_page.dart, aladin_series_page.dart) içerikler kategorilere ayrılmış şekilde listeleniyor. Dikey kategoriler ve yatay listeler şeklinde...
# Önce Kategori başlığı, yanında kategorideki içerik sayısı yazar, altında ise o kategorideki yayınlar listelenir.
# Kullanıcı bu kategori başlığındaki alana tıkladığında aynı alanda bu defa o kategorideki tüm içerikler (aladin_category_page.dart) bu defa grid şeklinde ekranda gösterilir.

# Eğer kullanıcı buradan bir TV kanalı seçerse bu tv yayını linki (yanına o listede bulunan diğer kanalları da) alarak aladin_player_page.dart sayfasına gider. Burada seçilen kanal oynatılmaya başlanır. Kullanıcı TV kumanda ile yukarı/aşağı tuşlarına basınca o yanında getirdiği listedeki/kategorideki kanallar arasında geçiş sağlanır.  Kullanıcı TV kumanda ile sağ/sol tuşlarına basınca ses artıp azalır. Yine burada rekli tv kumanda renkleri devreye giriyor. (bu defa player page’de kırmızı-altyazı, yeşil-dublaj ses dili, sarı-kalite, mavi-ratio, 0-favorites gibi fonksiyonları üstleniyor.)

# Eğer kullanıcı aladin_movies_page.dart bölümünden herhangi bir film açtığında bu defa yanına o filmin linkini ve aynı kategoride bulunan diğer filmleri de  alarak aladin_player_page.dart sayfasına gider. Kullanıcı TV kumanda ile yukarı/aşağı tuşlarına basınca o yanında getirdiği listedeki/kategorideki filmler arasında geçiş sağlanır.  Kullanıcı TV kumanda ile sağ/sol tuşlarına basınca bu defa ses değil yayın ileri yada geri sarılır. Yine burada rekli tv kumanda renkleri devreye giriyor. (bu defa player page’de kırmızı-altyazı, yeşil-dublaj ses dili, sarı-kalite, mavi-ratio, 0-favorites gibi fonksiyonları üstleniyor.)

# Eğer kullanıcı aladin_series_page.dart bölümünden herhangi bir dizi bölümü açtığında bu defa yanına o dizi bölümünün linkini ve aynı diziye ait diğer tüm bölümleri de  alarak aladin_player_page.dart sayfasına gider. Kullanıcı TV kumanda ile yukarı/aşağı tuşlarına basınca o yanında getirdiği listedeki/kategorideki dizi bölümleri arasında sırayla geçiş sağlanır.  Kullanıcı TV kumanda ile sağ/sol tuşlarına basınca bu defa ses değil yayın ileri yada geri sarılır. Yine burada rekli tv kumanda renkleri devreye giriyor. (bu defa player page’de kırmızı-altyazı, yeşil-dublaj ses dili, sarı-kalite, mavi-ratio, 0-favorites gibi fonksiyonları üstleniyor.)

# Şimdi Listelemelerde TV ve Film kısımları birbirinin aynısı mantıkla çalışıyor neredeyse;
# Ana Liste – Kategori Listesi – Yayınlar – Player Page
# Ama dizilerde durum biraz farklı oluyor. Araya “Sezon ve Bölümler” geliyor.
# Ana Liste – Kategori Listesi – Dizi Ana Sayfası – Sezonlar ve Bölümler – Dizi bölümü – Player Page.
# Her ana bölüm listesinin en başında;
# TV kısmında : Favori kısmı önce gelir, altında diğer kategoriler listelenir.
# Dizi ve Film kısmında ise; Önce Kaldığım Yerden( yada İzlemye Devam Et) sonra Favoriler kısmı sonrasında ise diğer kategoriler listelenir.
# Yine SettingsPage sayfasında EPG güncelleme (bunu otomatik yapmadım çünkü düşük işlemci ve ram’a sahip Tv’leri zorlamak istemiyorum) alanı ve Kayıtlı Playlistler alanları da mevcut.



## Flutter tabanlı IPTV Player TV uygulaması için sana teknik mimariyi ve UI kurallarını tanımlayacağım. Bundan sonraki kod önerilerinde ve hata çözümlerinde bu yapıya sadık kalmanı istiyorum.

0. Uygulama Başlatma ve Playlist Akışı:
•	Uygulama dil tercihiyle açılır. İlk açılışta playlist yoksa aladin_settings_page.dart ekranına gidilir.
•	Playlist (M3U, Xtream veya Local) yüklendikten ve onaylandıktan sonra aladin_live_tv_page.dart ana sayfasına yönlendirme yapılır.
1. Sayfa Yapısı ve İsimlendirme:
•	aladin_live_tv_page.dart: Ana ekran ve canlı TV listesi.
•	aladin_movies_page.dart & aladin_series_page.dart: VOD içerik listeleri.
•	aladin_player_page.dart: Tüm içeriklerin oynatıldığı merkezi player.
•	aladin_settings_page.dart: Playlist (M3U, Xtream, Local) ve EPG yönetimi.
•	aladin_category_page.dart: Kategorilerin Grid (Izgara) görünümü.
2 2. Dashboard ve Global Navigasyon:
•	Uygulama yatay (Landscape) moddadır. Sol tarafta sabit bir navigasyon paneli bulunur.
•	Panelin içeriği: Canlı TV, Filmler, Diziler, Arama, Favoriler ve Ayarlar sayfalarına yönlendirme yapar.
•	Kumanda Kısayolları (Her Yerde Aktif):
o	Kırmızı: aladin_live_tv_page.dart
o	Yeşil: aladin_movies_page.dart
o	Sarı: aladin_series_page.dart
o	Mavi: aladin_settings_page.dart
3. İçerik ve Kategori Mimarisi:
•	Tüm sayfalarda içerikler "Dikey Kategori Başlığı + Yanında Sayı + Altında Yatay Liste" şeklinde dizilir.
•	Kategori başlığına tıklandığında aladin_category_page.dart açılır ve içerikler Grid formatında gösterilir.
•	Sıralama: TV'de en üstte Favoriler, Film ve Dizilerde ise en üstte İzlemeye Devam Et ve ardından Favoriler yer alır.
•	Dizi Akışı: Diğerlerinden farklı olarak; Kategori -> Dizi Ana Sayfası -> Sezonlar/Bölümler -> Player sırasıyla çalışır.
4. Oynatıcı (aladin_player_page.dart) Mantığı:
•	Oynatıcıya gidilirken seçilen içerikle birlikte o listedeki tüm kanal/film/bölüm listesi de taşınır.
•	Kumanda Kontrolleri:
o	Canlı TV: Yukarı/Aşağı (Kanal Değişimi), Sağ/Sol (Ses +/-).
o	Film/Dizi: Yukarı/Aşağı (İçerik Değişimi), Sağ/Sol (İleri/Geri Sarma).
o	Renkli Tuş Fonksiyonları (Player içinde): Kırmızı (Altyazı), Yeşil (Ses Dili), Sarı (Kalite), Mavi (Ratio), 0 Tuşu (Favori).
Bu bilgiler projenin temel yapı taşıdır.Flutter tabanlı IPTV Player TV uygulaması için sana teknik mimariyi ve UI kurallar:

0. Uygulama Başlatma ve Playlist Akışı:
•	Uygulama dil tercihiyle açılır. İlk açılışta playlist yoksa aladin_settings_page.dart ekranına gidilir.
•	Playlist (M3U, Xtream veya Local) yüklendikten ve onaylandıktan sonra aladin_live_tv_page.dart ana sayfasına yönlendirme yapılır.
1. Sayfa Yapısı ve İsimlendirme:
•	aladin_live_tv_page.dart: Ana ekran ve canlı TV listesi.
•	aladin_movies_page.dart & aladin_series_page.dart: VOD içerik listeleri.
•	aladin_player_page.dart: Tüm içeriklerin oynatıldığı merkezi player.
•	aladin_settings_page.dart: Playlist (M3U, Xtream, Local) ve EPG yönetimi.
•	aladin_category_page.dart: Kategorilerin Grid (Izgara) görünümü.
2 2. Dashboard ve Global Navigasyon:
•	Uygulama yatay (Landscape) moddadır. Sol tarafta sabit bir navigasyon paneli bulunur.
•	Panelin içeriği: Canlı TV, Filmler, Diziler, Arama, Favoriler ve Ayarlar sayfalarına yönlendirme yapar.
•	Kumanda Kısayolları (Her Yerde Aktif):
o	Kırmızı: aladin_live_tv_page.dart
o	Yeşil: aladin_movies_page.dart
o	Sarı: aladin_series_page.dart
o	Mavi: aladin_settings_page.dart
3. İçerik ve Kategori Mimarisi:
•	Tüm sayfalarda içerikler "Dikey Kategori Başlığı + Yanında Sayı + Altında Yatay Liste" şeklinde dizilir.
•	Kategori başlığına tıklandığında aladin_category_page.dart açılır ve içerikler Grid formatında gösterilir.
•	Sıralama: TV'de en üstte Favoriler, Film ve Dizilerde ise en üstte İzlemeye Devam Et ve ardından Favoriler yer alır.
•	Dizi Akışı: Diğerlerinden farklı olarak; Kategori -> Dizi Ana Sayfası -> Sezonlar/Bölümler -> Player sırasıyla çalışır.
4. Oynatıcı (aladin_player_page.dart) Mantığı:
•	Oynatıcıya gidilirken seçilen içerikle birlikte o listedeki tüm kanal/film/bölüm listesi de taşınır.
•	Kumanda Kontrolleri:
o	Canlı TV: Yukarı/Aşağı (Kanal Değişimi), Sağ/Sol (Ses +/-).
o	Film/Dizi: Yukarı/Aşağı (İçerik Değişimi), Sağ/Sol (İleri/Geri Sarma).
o	Renkli Tuş Fonksiyonları (Player içinde): Kırmızı (Altyazı), Yeşil (Ses Dili), Sarı (Kalite), Mavi (Ratio), 0 Tuşu (Favori).
Bu bilgiler projenin temel yapı taşıdır.









