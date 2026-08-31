# Czechify 🇨🇿

AI-powered Czech language learning app targeting CEFR A1 → A2 proficiency and CCE exam preparation.

Built with **Flutter, Clean Architecture, Riverpod, Drift/SQLite**, custom SM-2 spaced repetition, and an EU-hosted DeepSeek V4 Flash model for AI tutoring.

## Tech Stack

- **Framework:** Flutter 3.44 (Dart, AOT compiled)
- **Architecture:** Clean Architecture (3 layers: Presentation, Domain, Data)
- **State Management:** Riverpod 3.x (Notifier + FutureProvider)
- **Navigation:** GoRouter with adaptive scaffold (mobile bottom nav / desktop side rail)
- **Database:** Drift (SQLite) — 12 tables, 4 DAOs
- **Course source:** Published Supabase JSONB packs → cached local Drift
- **AI:** Authenticated Supabase Edge Function → Scaleway Generative APIs (DeepSeek V4 Flash, Paris)
- **STT:** native `speech_to_text` (on-device, OS-native, `cs_CZ` locale)
- **TTS:** Azure neural voice packs from Supabase Storage, permanently cached
  for `just_audio`, with native `flutter_tts` fallback
- **Spaced Repetition:** Custom SM-2 scheduler with ease factor accumulation
- **Platforms:** iOS, Android, macOS, Windows (~95% shared code)

## Features

### 📚 Interactive Lessons
- Units 1-3 seeded (100+ vocabulary, 13 grammar rules, 6 lessons, 69 exercises)
- 8 exercise types: multiple choice, fill-blank, translation, word-order, dictation, declension table, dialogue, pronunciation
- Global hearts system (5 lives, wrong answer = -1 heart, 1 heart regenerates every 30 min)
- XP rewards + streak tracking + daily XP that resets each day
- Unit unlocking based on progress

### 🔁 Spaced Repetition Review
- SM-2 scheduler with ease factor accumulation (reviews get spaced further apart)
- Four rating buttons: Again / Hard / Good / Easy
- Flashcard flip with Czech → English
- Gender badges, IPA, example sentences

### 🎤 Pronunciation Practice
- Read aloud and compare the recognised words with the target phrase; this is
  a transcript check, not acoustic diagnosis of individual Czech sounds
- Levenshtein-based pronunciation scoring engine
- Czech phoneme detection (ř, ě, long vowels, palatalized consonants)
- Per-word score breakdown with color-coded feedback
- Problem sounds detection with practice tips

### 💬 AI Conversation Tutor
- 6 role-play scenarios: Casual Chat, Restaurant, Directions, Shopping, Doctor, Job Interview
- Czech responses with English translations
- Grammar corrections with rule explanations
- New vocabulary chips per message
- TTS speak button on every tutor message
- Powered by a quota-controlled server proxy; no provider key ships in the app

### 📝 Mock CCE Exams
- 4 timed sections: Reading, Listening, Writing, Speaking
- Per-section countdown timer with visual progress bar
- Listening plays real TTS audio (the sentence is never shown)
- Prompted speaking is transcribed and compared with the target phrase; the
  result does not replace pronunciation feedback from a teacher
- AI writing evaluation (grammar, vocabulary, coherence scores)
- Results persisted to the database; pass at 60% overall

### 📊 Progress & Stats
- CEFR level estimate (Pre-A1 / A1 / A2)
- A1 + A2 course completion progress bars
- Unit mastery breakdown per unit
- Badge display (earned / unearned with tooltips)
- Streak, XP, hearts, longest streak stats grid

### 🎨 Polish & Desktop
- Dark/light/system theme switching
- Adaptive layout: mobile bottom nav, desktop NavigationRail (≥600px)
- Onboarding flow (level assessment and goal setting)
- Settings screen (theme, daily goal, neural voice, and TTS rate)
- TTS audio file caching (MD5-hashed, plays cached via `just_audio`)

## Project Structure

```
lib/
├── core/              # Theme, constants, text normalizer, phoneme mapper
├── domain/
│   ├── engines/       # SM-2 Scheduler, Gamification, Pronunciation, LLM Orchestrator, CurriculumTracker
│   ├── entities/      # Unit, Lesson, Exercise, Flashcard, ChatMessage, GamificationState, etc.
│   └── repositories/  # Interface contracts (TTS, STT, LLM, Exam, Conversation, Progress)
├── data/
│   ├── database/      # Drift schema (12 tables, 4 DAOs), migrations
│   ├── repositories/  # Drift implementations + authenticated AI proxy client
│   └── seeds/         # Content seeder (JSON → DB) with SRS card seeding
└── presentation/
    ├── providers/     # 15+ Riverpod Notifier providers (gamification, chat, pronunciation,
    │                  #   writing eval, settings, curriculum, review, database, TTS, STT, LLM)
    ├── routes/        # GoRouter config + adaptive scaffold
    ├── screens/       # Home, Curriculum, Lesson, Review, Chat, Pronunciation, Exam,
    │                  #   Stats, Settings, Onboarding (welcome/level/goal)
    └── widgets/       # ExerciseWidget (8 types), HeartsDisplay, StreakIndicator, XpBadge,
                       #   RecordButton, TtsButton
```

## Current Status

| Metric | Value |
|---|---|
| Dart files | **209 files** |
| `flutter analyze --fatal-infos` | **clean (0 issues)** |
| `flutter test` | **709 tests passing** |
| CI | GitHub Actions (analyze + test) |
| Phases 1-4 | **All complete** |

### Remaining before store release

- Keep the hosted privacy policy and public account-deletion page synchronized
  with the current in-app policy version.
- Complete the Play Console Data Safety, content rating, store listing, and
  closed-testing requirements that apply to the developer account.
- Replace the current email-app AI reply report handoff with an in-app report
  submission before Play review; Google requires generative-AI reports without
  making the user leave the app.
- Keep mock exams labelled as practice/sample content unless the question bank
  and scoring have been independently validated against the relevant official
  exam blueprint.

## Development

```bash
cd Czechify

# Get dependencies
flutter pub get

# Generate Drift code
flutter pub run build_runner build --delete-conflicting-outputs

# Analyze
flutter analyze

# Run tests
flutter test

# Release build (Android; requires android/key.properties for store signing)
flutter build appbundle

# Run on device/emulator
flutter run
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full 20-section architecture document covering:

- Layer architecture & dependency graph
- 5 domain engines (SM-2, Gamification, Pronunciation, LLM, Curriculum)
- Drift database schema (12 tables)
- AI integration (Supabase proxy, Scaleway-hosted DeepSeek V4 Flash, native STT, neural audio packs)
- LLM JSON contracts for tutor AI with corrections + vocabulary extraction
- Audio pipeline & platform configs (mic permissions on Android + iOS)
- 4-phase roadmap (MVP → Production)
- Cost controls (server-side per-user and project quotas)
