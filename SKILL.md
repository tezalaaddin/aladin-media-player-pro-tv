---
name: aladinIPTV Player Pro
description: Next-gen IPTV solution with high-performance EPG management and Netflix-style UI.
version: 8.6
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
* **High-Performance Local Persistence (Isar NoSQL):** Engineered a reactive local data layer using **Isar**. Implemented custom schemas for fast indexing and asynchronous querying of channels, categories, and EPG data, significantly reducing application cold-start times.
* **Memory-Efficient Batch Processing:** Implemented a stream-based import system that processes and persists data in optimized batches. This prevents memory spikes and ensures stability on low-end mobile devices during large-scale data ingestion.

## 🧠 Advanced Content Analysis & Logic
* **Heuristic Data Parsing (RegEx Engine):** Developed a sophisticated Regular Expression engine to extract rich metadata from unstructured M3U strings, including:
    * **Resolution Detection:** Automatically identifying 4K, FHD, HD, and SD streams.
    * **Content Tagging:** Extracting IMDb ratings, release years, and language metadata.
    * **S0xE0x Extraction:** Parsing season and episode information for VOD (Series) content.
* **Automated Content Classification:** Built a logical router that categorizes raw stream URLs into Live TV, Movies, or Series based on endpoint patterns and metadata markers.

## 📅 EPG Engine & Data Synchronization
* **Multi-Key Matching Algorithm:** Implemented a robust EPG-to-Channel matching system using a priority-based logic (exact ID match -> normalized name match -> fuzzy alias match), achieving high synchronization accuracy across diverse providers.
* **Automated Sync Services:** Developed background synchronization tasks that support **GZip/Deflate** compression for efficient EPG XML fetching, minimizing data consumption for the user.

## 🎬 Multimedia & UI/UX Engineering
* **Native-Grade Media Implementation:** Integrated `media_kit` (FFmpeg-based) to provide a high-performance video backbone supporting hardware acceleration, dynamic aspect ratio switching, and multi-track audio/subtitle management.
* **Netflix-Inspired VOD Interface:** Designed a hierarchical UI architecture featuring horizontal scrollable carousels, dynamic poster fetching from external APIs (TMDB), and state-aware watch history tracking.
* **Scalable Theme Engine:** Established a centralized `AppTheme` architecture, allowing for consistent branding and easy transition between dark/light modes or custom brand skins.

## 🛠️ Technical Stack
* **Language:** Dart (Flutter Framework)
* **State Management:** Provider with a focus on Clean Architecture principles.
* **Persistence:** Isar NoSQL (Acid Compliant)
* **Networking:** Dio / HTTP with Interceptors and Timeout Management.
* **Multimedia:** media_kit (Video/Audio Core)
* **Data Formats:** M3U, XML (EPG), JSON, GZip, M3U8 (HLS).

---
*This project serves as a comprehensive demonstration of full-stack mobile engineering, focusing on high-performance data management and seamless user experiences in the streaming domain.*


## TÜRKÇE
==========
# aladinIPTV Player Pro
Bu yetenek, Flutter ile geliştirilmiş gelişmiş bir IPTV oynatıcı çözümüdür.

# 🛠 Teknik Yetkinlikler ve Proje Özellikleri: aladinIPTV Player Pro

Bu dosya, **aladinIPTV Player Pro** projesinin geliştirilme sürecinde kullanılan mimari yaklaşımları, teknik becerileri ve uygulanan çözüm yöntemlerini detaylandırmaktadır.

## 🚀 Temel Mimari ve Performans (Core Architecture)
* **İzole Veri İşleme (High-Performance Isolate Parsing):** On binlerce satırlık M3U dosyalarının UI thread'ini dondurmadan işlenmesi için Flutter `compute` altyapısı ile asenkron ayrıştırma (parsing) yönetimi.
* **Gelişmiş Veritabanı Yönetimi (Isar NoSQL):** Uygulama verilerinin (kanallar, kategoriler, geçmiş) ultra hızlı sorgulanması ve saklanması için modern NoSQL çözümü olan Isar veritabanı entegrasyonu.
* **Verimli Veri Akış Yönetimi (Batch Processing):** Uzak sunuculardan veya yerel dosyalardan veri aktarımı sırasında bellek kullanımını optimize eden toplu kayıt (batch insert) ve stream tabanlı ilerleme takibi.

## 🔍 Akıllı İçerik Analizi (Advanced Content Engine)
* **Karmaşık Veri Ayrıştırma (Complex RegEx Parsing):** Kanal isimlerinden otomatik olarak kalite etiketlerini (4K, FHD, HD), yapım yıllarını, sezon/bölüm bilgilerini ve IMDb puanlarını ayıklayan özelleştirilmiş düzenli ifade (RegEx) algoritmaları.
* **Dinamik Kategorizasyon:** Ham M3U verilerini otomatik olarak Canlı TV, Film ve Dizi olarak sınıflandıran ve kullanıcı için anlamlı bir yapıya dönüştüren mantıksal katman.

## 📅 EPG ve Senkronizasyon (EPG & Sync Services)
* **Çok Katmanlı EPG Eşleştirme:** Farklı kaynaklardan gelen program rehberi (EPG) verilerini; Kanal ID, Normalleştirilmiş İsim ve Görünen İsim gibi 3 farklı aşamada kontrol ederek %99 doğrulukla eşleştiren algoritma.
* **Otomatik Arka Plan Görevleri:** EPG verilerinin GZip sıkıştırma desteği ile belirli periyotlarla (arka planda) güncellenmesini sağlayan servis yönetimi.

## 🎬 Multimedya ve Kullanıcı Deneyimi (Media UI/UX)
* **Gelişmiş Oynatıcı Entegrasyonu:** `media_kit` kullanarak düşük gecikmeli, donanım hızlandırma destekli ve çoklu altyazı/ses kanalı seçimine olanak tanıyan video player altyapısı.
* **Zengin Meta Veri Sunumu:** TMDB API entegrasyonu ile içeriklerin afiş, oyuncu kadrosu ve özet bilgilerini dinamik olarak çeken içerik yönetim sistemi.
* **Modern Netflix Stili Arayüz:** Kullanıcı odaklı, responsive (duyarlı) ve yüksek performanslı listeleme arayüzleri.

## 🛠 Kullanılan Teknoloji Yığını (Tech Stack)
* **Framework:** Flutter & Dart
* **State Management:** Provider / ChangeNotifier
* **Database:** Isar NoSQL (Local Persistence)
* **Networking:** HTTP & JSON API Management
* **Multimedia:** Media Kit (Video Rendering)
* **Data Formats:** M3U, XML (EPG), JSON, GZip

---
*Bu belge, geliştiricinin büyük veri setleri ile çalışma, performans optimizasyonu ve modern mobil uygulama mimarileri konusundaki yetkinliklerini temsil eder.*