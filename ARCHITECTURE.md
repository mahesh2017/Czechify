# ARCHITECTURE.md — AI-Powered Czech Language Learning App

> **App Name:** Czechify
> **Target:** CEFR A1 → A2 Czech proficiency, CCE exam preparation
> **Platforms:** iOS, Android, macOS, Windows
> **Framework:** Flutter 3.x (Dart, AOT compiled)

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Layer Architecture](#2-layer-architecture)
3. [Domain Layer — Core Engines](#3-domain-layer--core-engines)
4. [Data Layer — Repositories & Storage](#4-data-layer--repositories--storage)
5. [Presentation Layer — UI & State](#5-presentation-layer--ui--state)
6. [AI & Cloud Integration](#6-ai--cloud-integration)
7. [Curriculum Data Model](#7-curriculum-data-model)
8. [Gamification Engine](#8-gamification-engine)
9. [Pronunciation Scoring Engine](#9-pronunciation-scoring-engine)
10. [Spaced Repetition (FSRS) Integration](#10-spaced-repetition-fsrs-integration)
11. [LLM API Contracts](#11-llm-api-contracts)
12. [Audio Pipeline](#12-audio-pipeline)
13. [Platform-Specific Configurations](#13-platform-specific-configurations)
14. [Project Structure](#14-project-structure)
15. [Dependency Graph](#15-dependency-graph)
16. [Offline Mode Strategy](#16-offline-mode-strategy)
17. [Security & API Key Management](#17-security--api-key-management)
18. [Testing Strategy](#18-testing-strategy)
19. [Build & Deployment](#19-build--deployment)
20. [Roadmap](#20-roadmap)

---

## 1. System Overview

### 1.1 Purpose

A Flutter application that teaches Czech from zero to A2 level using AI-powered features:
- Structured 21-unit curriculum aligned to CCE exam format
- AI conversation practice with real-time grammar correction
- Pronunciation scoring for Czech-specific sounds (ř, ě, vowel length)
- Spaced repetition (FSRS) for vocabulary and grammar retention
- Full mock exam simulator for CCE-A1 and CCE-A2

### 1.2 Design Principles

1. **Clean Architecture** — UI, business logic, and data are decoupled. Each layer can be tested and replaced independently.
2. **Offline-First** — Core learning (lessons, flashcards, pronunciation drills) works without internet. Cloud AI features degrade gracefully.
3. **Single Codebase** — ~95% shared across iOS, Android, macOS, Windows. Platform-specific code isolated via interface adapters.
4. **Cost-Aware AI** — TTS responses are cached by hash. LLM calls use the cheapest model that meets quality needs. Vosk (free) is primary STT; Whisper API is fallback.
5. **Exam-Aligned** — Every unit maps to CCE exam competencies. Mock exam mode replicates real test conditions.

### 1.3 High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │
│  │  Lesson   │  │ SRS Deck │  │ AI Chat  │  │  Mock Exam   │    │
│  │  Screen   │  │  Screen  │  │  Screen  │  │   Screen     │    │
│  └─────┬─────┘  └─────┬────┘  └─────┬────┘  └──────┬───────┘    │
│        │              │              │              │            │
│        └──────────────┴──────────────┴──────────────┘            │
│                           │  Riverpod Providers                   │
├───────────────────────────┼─────────────────────────────────────┤
│                     DOMAIN LAYER                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │
│  │ FSRS     │  │ Gamifica │  │ Pronun   │  │  LLM         │    │
│  │ Scheduler│  │  Engine  │  │ Scoring  │  │  Orchestrator│    │
│  └─────┬────┘  └─────┬────┘  └─────┬────┘  └──────┬───────┘    │
│        │              │              │              │            │
│  ┌─────┴──────────────┴──────────────┴──────────────┴──────┐    │
│  │              Curriculum Progress Tracker                │    │
│  └────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│                      DATA LAYER                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │
│  │ Drift DB │  │  Hive    │  │ Secure   │  │  Audio File  │    │
│  │ (SQLite) │  │ (KV)    │  │ Storage  │  │  Manager     │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘    │
│  ┌──────────┐  ┌──────────┐                                   │
│  │ API      │  │ TTS      │                                   │
│  │ Clients  │  │ Cache    │                                   │
│  │ (Dio)    │  │          │                                   │
│  └──────────┘  └──────────┘                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Layer Architecture

### 2.1 Dependency Rule

Dependencies flow **inward only**:

```
Presentation → Domain ← Data
```

- **Domain** depends on nothing external. It defines interfaces (abstract classes) that Data and Presentation implement.
- **Data** implements Domain interfaces and handles external I/O (database, APIs, files).
- **Presentation** consumes Domain models and triggers Domain use cases via Riverpod providers.

### 2.2 Layer Responsibilities

| Layer | Owns | Does NOT Know About |
|---|---|---|
| Presentation | Widgets, screens, route definitions, Riverpod providers | SQLite, Dio, API keys |
| Domain | Business rules, entities, use cases, engine interfaces | Flutter widgets, Drift tables, Dio |
| Data | Database schema, API clients, repositories, file I/O | Riverpod, widgets, UI state |

### 2.3 Interface Boundaries

Domain defines these abstract interfaces (implemented in Data):

```dart
// Domain defines the contract; Data implements it.
abstract class CurriculumRepository {
  Future<List<Unit>> getUnits(Phase phase);
  Future<Unit> getUnit(int unitId);
  Future<List<Lesson>> getLessons(int unitId);
  Future<Lesson> getLesson(int lessonId);
  Future<List<Exercise>> getExercises(int lessonId);
}

abstract class VocabularyRepository {
  Future<List<Flashcard>> getDueCards({DateTime? asOf});
  Future<void> updateCard(SrsCard card, Rating rating, DateTime reviewedAt);
  Future<List<Flashcard>> searchCards(String query);
}

abstract class ConversationRepository {
  Future<void> saveMessage(ChatMessage message);
  Future<List<ChatMessage>> getHistory(String conversationId);
  Future<void> clearConversation(String conversationId);
}

abstract class ProgressRepository {
  Stream<ProgressState> watchProgress();
  Future<void>recordCompletion(String unitId, int lessonId, int score);
  Future<StreakState> getStreak();
  Future<void> updateStreak(StreakState state);
}

abstract class ExamRepository {
  Future<MockExam> getMockExam(ExamLevel level);
  Future<ExamResult> saveResult(ExamResult result);
  Future<List<ExamResult>> getResults(ExamLevel level);
}

abstract class SttService {
  Future<String> transcribe(String audioPath);
  Stream<PartialTranscript> transcribeStream(String audioPath);
}

abstract class TtsService {
  Future<String> synthesize(String text, {String? voiceId});
  Future<File> getCachedOrSynthesize(String text, {String? voiceId});
}

abstract class LlmService {
  Future<LlmResponse> complete(LlmRequest request);
  Stream<LlmChunk> streamComplete(LlmRequest request);
}
```

---

## 3. Domain Layer — Core Engines

### 3.1 SRS Scheduler

Uses a simplified SM-2 scheduler for vocabulary and grammar pattern cards. The
stored `difficulty` field is the ease factor and `stability` is the interval in
days; these are not FSRS parameters.

```dart
class SrsScheduler {
  /// Calculate the next review date and update card state.
  SchedulingResult schedule(SrsCard card, Rating rating, DateTime now);

  /// Get all cards due for review before or on [asOf].
  List<SrsCard> getDueCards(List<SrsCard> allCards, DateTime asOf) {
    return allCards.where((c) => c.due.isBefore(asOf) || c.due.isAtSameMomentAs(asOf)).toList();
  }
}
```

**Card types:**
- `VocabularyCard` — word/phrase with audio, image, IPA, example sentence
- `GrammarCard` — pattern-based (e.g., "decline 'žena' in accusative") with full paradigm review

### 3.2 Gamification Engine

Manages XP, streaks, hearts, leagues, and badges. Pure state machine — no I/O.

```dart
class GamificationEngine {
  /// Calculate XP earned for an action.
  int calculateXp(XpAction action) {
    return switch (action) {
      XpAction.lessonCompleted(lesson) when lesson.isPerfect => 20,
      XpAction.lessonCompleted(:final accuracy)
        when accuracy >= 0.8 => 15,
      XpAction.lessonCompleted() => 10,
      XpAction.reviewSessionCompleted(reviewCount: final count) => count * 2,
      XpAction.streakMilestone(days: final d) => d * 5,
      XpAction.badgeEarned(badge) => badge.xpReward,
    };
  }

  /// Process a wrong answer: deduct hearts, check for game over.
  HeartResult processWrongAnswer(GamificationState state) {
    final newHearts = state.hearts - 1;
    return HeartResult(
      hearts: newHearts,
      isGameOver: newHearts <= 0,
      canRefill: newHearts <= 0,
    );
  }

  /// Update streak: called once per day on first activity.
  StreakUpdate updateStreak(StreakState current, DateTime now) {
    final today = DateUtils.dateOnly(now);
    final lastActive = DateUtils.dateOnly(current.lastActiveDate);

    if (today == lastActive) {
      return StreakUpdate.unchanged(current); // already active today
    }

    final daysSinceLast = today.difference(lastActive).inDays;
    if (daysSinceLast == 1) {
      return StreakUpdate.incremented(current.copyWith(
        currentStreak: current.currentStreak + 1,
        longestStreak: max(current.longestStreak, current.currentStreak + 1),
        lastActiveDate: now,
      ));
    } else {
      return StreakUpdate.reset(current.copyWith(
        currentStreak: 1,
        lastActiveDate: now,
      ));
    }
  }

  /// Check if a badge should be unlocked.
  List<Badge> checkBadges(ProgressSnapshot progress) {
    final unlocked = <Badge>[];
    for (final badge in Badge.all) {
      if (!progress.earnedBadges.contains(badge.id) && badge.criteria.isMet(progress)) {
        unlocked.add(badge);
      }
    }
    return unlocked;
  }
}
```

### 3.3 Pronunciation Scoring Engine

Custom scoring since Azure Pronunciation Assessment doesn't support Czech.

```dart
class PronunciationScorer {
  /// Score user's pronunciation against expected text.
  ///
  /// Pipeline:
  /// 1. STT transcribes user audio → actual text
  /// 2. Normalize both texts (lowercase, strip punctuation)
  /// 3. Word-level alignment (Levenshtein distance)
  /// 4. Phonetic comparison for Czech-specific sounds
  /// 5. Return per-word and overall scores
  PronunciationResult score({
    required String expectedText,
    required String actualTranscription,
    required AudioRecording recording,
  }) {
    final normalized = _normalize(expectedText);
    final actual = _normalize(actualTranscription);

    // Word-level alignment
    final alignment = _alignWords(normalized, actual);

    // Phonetic scoring for Czech problem sounds
    final phonemeScores = _scorePhonemes(alignment);

    // Overall accuracy
    final accuracy = _calculateAccuracy(phonemeScores);

    return PronunciationResult(
      overallScore: accuracy,
      wordScores: alignment.wordResults,
      problemSounds: phonemeScores.where((p) => p.score < 0.7).map((p) => p.phoneme).toList(),
      feedback: _generateFeedback(phonemeScores),
    );
  }

  /// Czech-specific phonetic scoring.
  /// Focus on: ř [r̝], ě [jɛ], long vs short vowels (á/a, é/e, í/i, ó/o, ú/u),
  /// palatalized consonants (ď, ť, ň).
  List<PhonemeScore> _scorePhonemes(WordAlignment alignment) {
    // Implementation uses phoneme mapping:
    // - Map Czech orthography to approximate IPA
    // - Compare expected vs actual phoneme sequences
    // - Weight ř, ě, vowel length higher (they change meaning)
    // ...
  }

  String _generateFeedback(List<PhonemeScore> scores) {
    final problems = scores.where((s) => s.score < 0.7).toList();
    if (problems.isEmpty) return 'Skvělé! Výborná výslovnost.';

    return problems.map((p) => switch (p.phoneme) {
      'ř' => 'Practice the "ř" sound — roll the tongue slightly further back.',
      'ě' => 'The "ě" softens the consonant before it (dě → d+ye).',
      'long_vowel' => 'Czech distinguishes short and long vowels. Lengthen: ${p.example}.',
      _ => 'Check pronunciation of "${p.phoneme}" in "${p.word}".',
    }).join('\n');
  }
}
```

### 3.4 LLM Orchestrator

Builds prompts, sends to LLM, parses structured responses.

```dart
class LLMOrchestrator {
  final LlmService _llm;

  /// Build a conversation turn request with system prompt and history.
  LlmRequest buildConversationRequest({
    required CEFRLevel level,
    required String scenario,
    required String userMessage,
    required List<ChatMessage> history,
  }) {
    final systemPrompt = _buildTutorPrompt(level, scenario);
    final messages = [
      SystemMessage(systemPrompt),
      ...history.map((m) => m.toLlmMessage()),
      UserMessage(userMessage),
    ];

    return LlmRequest(
      model: _selectModel(level),
      messages: messages,
      temperature: 0.7,
      responseFormat: ResponseFormat.jsonSchema(TutorResponseSchema.schema),
    );
  }

  String _buildTutorPrompt(CEFRLevel level, String scenario) {
    return '''
You are a patient Czech language tutor for a CEFR ${level.label} learner.

Rules:
- Respond primarily in Czech using vocabulary appropriate for ${level.label}.
- Keep responses short: max 3 sentences for A1, max 5 sentences for A2.
- If the learner makes a grammar error, correct it and explain the rule briefly in English.
- Stay in character for the scenario: "$scenario".
- Include English translation for any new vocabulary in brackets.
- Return your response as JSON matching the specified schema.
''';
  }

  /// Parse the LLM response into structured data.
  TutorResponse parseTutorResponse(LlmResponse response) {
    final json = jsonDecode(response.content) as Map<String, dynamic>;
    return TutorResponse.fromJson(json);
  }
}
```

### 3.5 Curriculum Progress Tracker

```dart
class CurriculumProgressTracker {
  /// Determine if a lesson is unlocked.
  bool isLessonUnlocked(LessonProgress progress, Lesson lesson, List<Lesson> unitLessons) {
    if (lesson.orderInUnit == 0) return true; // first lesson always open
    final prevLesson = unitLessons.firstWhere((l) => l.orderInUnit == lesson.orderInUnit - 1);
    return progress.completedLessonIds.contains(prevLesson.id);
  }

  /// Calculate unit completion percentage.
  double unitCompletion(int unitId, List<LessonProgress> progress) {
    final unitLessons = progress.where((p) => p.unitId == unitId).toList();
    if (unitLessons.isEmpty) return 0.0;
    final completed = unitLessons.where((l) => l.isCompleted).length;
    return completed / unitLessons.length;
  }

  /// Determine CEFR level estimate based on progress.
  CEFRLevel estimateLevel(ProgressSnapshot snapshot) {
    final a1Completion = snapshot.a1CompletionRate;
    final a2Completion = snapshot.a2CompletionRate;
    final mockExamScores = snapshot.mockExams;

    if (a2Completion > 0.8 && mockExamScores.any((e) => e.level == ExamLevel.a2 && e.passed)) {
      return CEFRLevel.a2;
    }
    if (a1Completion > 0.8 && mockExamScores.any((e) => e.level == ExamLevel.a1 && e.passed)) {
      return CEFRLevel.a1;
    }
    return CEFRLevel.preA1;
  }
}
```

---

## 4. Data Layer — Repositories & Storage

### 4.1 Database Schema (Drift / SQLite)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DRIFT DATABASE SCHEMA                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐        ┌──────────────┐        ┌──────────────┐    │
│  │   units      │        │   lessons    │        │  exercises  │    │
│  ├──────────────┤        ├──────────────┤        ├──────────────┤    │
│  │ id (PK)      │◄───┐   │ id (PK)      │◄───┐   │ id (PK)      │    │
│  │ title        │    │   │ unit_id (FK) │    │   │ lesson_id(FK)│    │
│  │ phase (A1/A2)│    └───│ order_in_unit│    └───│ type         │    │
│  │ order_index  │        │ title        │        │ prompt       │    │
│  │ description  │        │ description  │        │ data (JSON)  │    │
│  │ grammar_tags │        │ duration_min │        │ answer_key   │    │
│  │ is_exam_prep │        │ is_review    │        │ grammar_rule │    │
│  └──────────────┘        └──────────────┘        │ xp_reward    │    │
│                                                   └──────────────┘    │
│  ┌──────────────┐        ┌──────────────┐        ┌──────────────┐    │
│  │ flashcards   │        │ srs_cards    │        │chat_messages │    │
│  ├──────────────┤        ├──────────────┤        ├──────────────┤    │
│  │ id (PK)      │◄───┐   │ id (PK)      │        │ id (PK)      │    │
│  │ word_cz      │    │   │ card_type    │        │ conversation │    │
│  │ word_en      │    └───│ flashcard_id │        │  _id (FK)   │    │
│  │ ipa          │        │ stability    │        │ role         │    │
│  │ gender       │        │ difficulty   │        │ content      │    │
│  │ case_info    │        │ due (datetime)│       │ corrections  │    │
│  │ audio_hash   │        │ reps         │        │  (JSON)     │    │
│  │ image_path   │        │ state         │        │ created_at   │    │
│  │ example_cz   │        │ last_reviewed │       └──────────────┘    │
│  │ example_en   │        └──────────────┘                            │
│  │ unit_id (FK) │                                                    │
│  │ difficulty   │        ┌──────────────┐        ┌──────────────┐    │
│  └──────────────┘        │ conversations│        │  exam_results│    │
│                          ├──────────────┤        ├──────────────┤    │
│  ┌──────────────┐        │ id (PK)      │        │ id (PK)      │    │
│  │  badges      │        │ scenario     │        │ level (A1/A2)│    │
│  ├──────────────┤        │ cefr_level   │        │ taken_at     │    │
│  │ id (PK)      │        │ created_at   │        │ reading_score│    │
│  │ name         │        └──────────────┘        │ listening    │    │
│  │ description  │                                 │ _score       │    │
│  │ icon         │        ┌──────────────┐         │ writing_score│    │
│  │ xp_reward    │        │ user_progress│         │ speaking     │    │
│  │ criteria(JSON)│       ├──────────────┤         │ _score       │    │
│  └──────────────┘        │ key (PK)     │         │ total_score  │    │
│                          │ value (JSON) │         │ passed       │    │
│  ┌──────────────┐        │ updated_at   │         │ details(JSON)│    │
│  │ grammar_rules│        └──────────────┘         └──────────────┘    │
│  ├──────────────┤                                                    │
│  │ id (PK)      │        ┌──────────────┐                            │
│  │ rule_name    │        │ mock_exams   │                            │
│  │ pattern      │        ├──────────────┤                            │
│  │ explanation  │        │ id (PK)      │                            │
│  │ case_affected│        │ level (A1/A2)│                            │
│  │ examples(JSON)│       │ sections(JSON)│                           │
│  │ unit_id (FK) │        │ time_limits  │                            │
│  └──────────────┘        └──────────────┘                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Exercise Data Format (JSON in `exercises.data`)

Each exercise type has a structured JSON payload:

```json
// Multiple Choice
{
  "type": "multiple_choice",
  "question_cz": "Jaký je akuzativ slova 'káva'?",
  "question_en": "What is the accusative of 'coffee'?",
  "options": ["káva", "kávu", "kávy", "kávě"],
  "correct_index": 1,
  "explanation": "Feminine nouns ending in -a change to -u in accusative."
}

// Fill in the Blank
{
  "type": "fill_blank",
  "sentence": "Dám ___ kamarádovi. (I'll give it to my friend.)",
  "blank_count": 1,
  "accepted_answers": ["to"],
  "explanation": "Neuter pronoun 'to' doesn't change in accusative."
}

// Declension Table
{
  "type": "declension_table",
  "word": "žena",
  "gender": "feminine",
  "paradigm": "žena",
  "cases": ["nominative", "accusative", "genitive", "dative", "locative", "instrumental"],
  "answer_key": {
    "nominative": "žena",
    "accusative": "ženu",
    "genitive": "ženy",
    "dative": "ženě",
    "locative": "ženě",
    "instrumental": "ženou"
  }
}

// Word Order Arrangement
{
  "type": "word_order",
  "words": ["já", "mám", "nový", "kamarád", "—", "I have a new friend"],
  "correct_order": [0, 1, 2, 3],
  "explanation": "Standard SVO order. Adjective before noun."
}

// Listening / Dictation
{
  "type": "dictation",
  "audio_hash": "a3f2c1...",
  "expected_text": "Dobrý den, jak se máte?",
  "language": "cs-CZ"
}

// Pronunciation
{
  "type": "pronunciation",
  "target_text": "Řeka teče přes most.",
  "target_audio_hash": "b7e4d2...",
  "focus_sounds": ["ř"],
  "min_score": 0.65
}

// Translation
{
  "type": "translation",
  "direction": "en_to_cz",
  "source": "I would like a coffee, please.",
  "accepted_answers": ["Chtěl bych kávu, prosím.", "Dal bych si kávu, prosím."],
  "grammar_note": "After 'chtít' the object is in accusative: káva → kávu."
}

// Aspect Recognition (A2)
{
  "type": "aspect_recognition",
  "sentence": "Udělal jsem úkol. (I finished the homework.)",
  "options": ["perfective", "imperfective"],
  "correct_index": 0,
  "explanation": "Udělat is perfective (completed action). Dělat would be imperfective."
}

// v vs na Drill
{
  "type": "preposition_case",
  "place": "nádraží",
  "options": ["v", "na"],
  "correct": "na",
  "explanation": "Na nádraží — 'na' is used for open-air places, events, islands."
}
```

### 4.3 Hive Key-Value Store

| Key | Value | Purpose |
|---|---|---|
| `user.preferences.theme` | `dark` / `light` / `system` | App theme |
| `user.preferences.target_level` | `A1` / `A2` | Current study target |
| `user.preferences.daily_goal_xp` | `int` | XP target per day |
| `gamification.hearts` | `int` | Current heart count |
| `gamification.streak` | `int` | Current day streak |
| `gamification.longest_streak` | `int` | All-time best |
| `gamification.league` | `String` | Current league tier |
| `gamification.gems` | `int` | Virtual currency |
| `gamification.total_xp` | `int` | Lifetime XP |
| `audio.tts_voice` | `String` | Preferred Czech TTS voice ID |
| `audio.stt_engine` | `vosk` / `whisper` | Active STT engine |
| `content.curriculum_version` | `String` | Content pack version |
| `app.last_active_date` | `DateTime` | For streak calculation |

---

## 5. Presentation Layer — UI & State

### 5.1 Riverpod Provider Architecture

```dart
// ── Providers ──

// Curriculum
@riverpod
class CurriculumUnits extends AsyncNotifier<List<Unit>> {
  @override
  Future<List<Unit>> build() => ref.read(curriculumRepositoryProvider).getUnits(Phase.a1);
}

@riverpod
class CurrentLesson extends AsyncNotifier<Lesson?> {
  @override
  Future<Lesson?> build(int lessonId) =>
      ref.read(curriculumRepositoryProvider).getLesson(lessonId);
}

// SRS
@riverpod
class DueCards extends AsyncNotifier<List<Flashcard>> {
  @override
  Future<List<Flashcard>> build() =>
      ref.read(vocabularyRepositoryProvider).getDueCards();
}

// AI Conversation
@riverpod
class ChatConversation extends AsyncNotifier<List<ChatMessage>> {
  String? _conversationId;

  @override
  Future<List<ChatMessage>> build() async {
    _conversationId = _conversationId ?? _createConversation();
    return ref.read(conversationRepositoryProvider).getHistory(_conversationId!);
  }

  Future<void> sendMessage(String audioPath) async {
    // 1. Transcribe audio
    state = AsyncLoading();
    final text = await ref.read(sttServiceProvider).transcribe(audioPath);
    final userMessage = ChatMessage.user(text);
    state = AsyncData([...state.value!, userMessage]);
    await ref.read(conversationRepositoryProvider).saveMessage(userMessage);

    // 2. Send to LLM
    final request = ref.read(llmOrchestratorProvider).buildConversationRequest(
      level: CEFRLevel.a1,
      scenario: "Ordering at a restaurant",
      userMessage: text,
      history: state.value!,
    );
    final response = await ref.read(llmServiceProvider).complete(request);
    final tutorResponse = ref.read(llmOrchestratorProvider).parseTutorResponse(response);

    // 3. TTS for tutor reply
    final audioFile = await ref.read(ttsServiceProvider).getCachedOrSynthesize(
      tutorResponse.tutorReplyCz,
    );

    final tutorMessage = ChatMessage.tutor(
      text: tutorResponse.tutorReplyCz,
      translation: tutorResponse.tutorReplyEn,
      corrections: tutorResponse.corrections,
      audioPath: audioFile.path,
    );
    state = AsyncData([...state.value!, tutorMessage]);
    await ref.read(conversationRepositoryProvider).saveMessage(tutorMessage);
  }
}

// Gamification
@riverpod
class GamificationStateNotifier extends Notifier<GamificationState> {
  @override
  GamificationState build() => _loadFromHive();

  void onLessonCompleted(int xp, bool isPerfect) { ... }
  void onWrongAnswer() { ... }
  void onStreakCheck() { ... }
  void onBadgeUnlocked(Badge badge) { ... }
}

// Mock Exam
@riverpod
class MockExamSession extends AsyncNotifier<ExamSessionState> {
  @override
  Future<ExamSessionState> build(ExamLevel level) async {
    final exam = await ref.read(examRepositoryProvider).getMockExam(level);
    return ExamSessionState.initial(exam);
  }

  void startSection(ExamSection section) { ... }
  void submitAnswer(ExamAnswer answer) { ... }
  void completeSection() { ... }
  Future<ExamResult> finishExam() async { ... }
}
```

### 5.2 Screen Inventory

| Screen | Route | Description |
|---|---|---|
| Onboarding | `/onboarding` | Language level assessment, goal setting, API key entry |
| Home / Dashboard | `/` | Streak, XP, daily goal, continue learning button, quick access to SRS |
| Curriculum Path | `/curriculum` | Visual map of 21 units (A1/A2), locked/unlocked states |
| Unit Detail | `/unit/:id` | Lessons in unit, progress, grammar overview |
| Lesson Player | `/lesson/:id` | Exercise-by-exercise flow, hearts, progress bar |
| SRS Review | `/review` | Due flashcards, swipe/card flip interaction |
| AI Conversation | `/chat` | Role-play scenarios with AI tutor |
| Pronunciation Lab | `/pronunciation/:id` | Record-and-compare with visual feedback |
| Mock Exam | `/exam/:level` | Timed exam sections, results screen |
| Progress / Stats | `/stats` | CEFR level estimate, mastery breakdown, badge collection |
| Settings | `/settings` | TTS voice, STT engine, API keys, theme, daily goal |

### 5.3 Responsive Layout Strategy

```
Mobile (< 600px):
┌────────────┐
│  Screen    │  Single column, bottom nav bar
│  Content   │  Full-screen lesson player
│            │  Collapsible app drawer
└────────────┘

Desktop (≥ 600px):
┌────────┬───────────────────┐
│  Nav   │  Screen Content   │  Side navigation rail
│  Rail   │                   │  Wider exercise layouts
│  ├ Home │                   │  Split-pane for chat (sidebar + conversation)
│  ├ Path │                   │  Declension tables shown side-by-side
│  ├ SRS  │                   │
│  ├ Chat │                   │
│  └ More │                   │
└────────┴───────────────────┘
```

GoRouter with `ShellRoute` for adaptive layout:

```dart
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AdaptiveScaffold(child: child),
      routes: [
        GoRoute(path: '/', builder: (s, c) => HomeScreen()),
        GoRoute(path: '/curriculum', builder: (s, c) => CurriculumScreen()),
        GoRoute(path: '/lesson/:id', builder: (s, c) => LessonPlayerScreen(id: int.parse(c.pathParameters['id']!))),
        GoRoute(path: '/chat', builder: (s, c) => ChatScreen()),
        GoRoute(path: '/review', builder: (s, c) => SrsReviewScreen()),
        GoRoute(path: '/exam/:level', builder: (s, c) => MockExamScreen(level: ExamLevel.values.byName(c.pathParameters['level']!))),
        GoRoute(path: '/stats', builder: (s, c) => StatsScreen()),
        GoRoute(path: '/settings', builder: (s, c) => SettingsScreen()),
      ],
    ),
  ],
);
```

---

## 6. AI & Cloud Integration

### 6.1 Service Architecture

```
┌─────────────────────────────────────────────────────┐
│                  AI Service Layer                     │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  STT Manager │  │  TTS Manager │  │  LLM         │  │
│  │              │  │              │  │  Orchestrator │  │
│  │  ┌─────────┐ │  │  ┌─────────┐│  │             │  │
│  │  │  Vosk   │ │  │  │ Edge TTS ││  │  ┌────────┐│  │
│  │  │ (local) │ │  │  │ (free)  ││  │  │DeepSeek││  │
│  │  └─────────┘ │  │  └─────────┘│  │  │  V3    ││  │
│  │  ┌─────────┐ │  │  ┌─────────┐│  │  └────────┘│  │
│  │  │ Whisper │ │  │  │ Google  ││  │  ┌────────┐│  │
│  │  │  API    │ │  │  │Chirp3-HD││  │  │ Gemini ││  │
│  │  │(cloud)  │ │  │  │(cloud) ││  │  │ Flash  ││  │
│  │  └─────────┘ │  │  └─────────┘│  │  └────────┘│  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
│                                                      │
│  ┌─────────────────────────────────────────────────┐│
│  │           TTS Audio Cache (hash → file)           ││
│  └─────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

### 6.2 STT Manager (Fallback Strategy)

```dart
class SttManager implements SttService {
  final VoskSttEngine _vosk;      // primary, offline
  final WhisperSttEngine _whisper; // fallback, cloud
  final ConnectivityChecker _connectivity;

  @override
  Future<String> transcribe(String audioPath) async {
    // Try Vosk first (free, instant, offline)
    try {
      final result = await _vosk.transcribe(audioPath);
      if (result.confidence > 0.5) return result.text;
    } catch (_) {
      // Vosk failed, fall through to Whisper
    }

    // Fallback to Whisper API (needs internet)
    if (await _connectivity.hasInternet) {
      return _whisper.transcribe(audioPath);
    }

    throw OfflineTranscriptionError();
  }
}
```

### 6.3 TTS Manager (with Caching)

```dart
class TtsManager implements TtsService {
  final EdgeTtsEngine _edgeTts;    // free, development
  final GoogleTtsEngine _googleTts; // production quality
  final TtsCache _cache;
  final bool _useCloudTts;

  @override
  Future<File> getCachedOrSynthesize(String text, {String? voiceId}) async {
    final hash = _hashText(text, voiceId);

    // Check cache first
    final cached = _cache.get(hash);
    if (cached != null) return cached;

    // Synthesize
    final audioBytes = _useCloudTts
      ? await _googleTts.synthesize(text, voiceId: voiceId)
      : await _edgeTts.synthesize(text, voiceId: voiceId);

    return _cache.put(hash, audioBytes);
  }

  String _hashText(String text, String? voiceId) {
    final combined = '${voiceId ?? 'default'}::$text';
    return sha256.convert(utf8.encode(combined)).toString();
  }
}

class TtsCache {
  final Directory _cacheDir;

  File? get(String hash) {
    final file = File('${_cacheDir.path}/tts_$hash.mp3');
    return file.existsSync() ? file : null;
  }

  Future<File> put(String hash, Uint8List audio) async {
    final file = File('${_cacheDir.path}/tts_$hash.mp3');
    await file.writeAsBytes(audio);
    return file;
  }
}
```

### 6.4 LLM Provider Fallback Chain

```dart
class LlmProviderChain implements LlmService {
  final List<LlmProvider> _chain = [
    DeepSeekProvider(model: 'deepseek-v3'),   // cheapest, good Czech
    GeminiProvider(model: 'gemini-2.5-flash'), // fast, very cheap
    OpenAiProvider(model: 'gpt-4o-mini'),     // reliable fallback
  ];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    for (final provider in _chain) {
      try {
        return await provider.complete(request);
      } catch (e) {
        continue; // try next provider
      }
    }
    throw AllProvidersFailedError();
  }
}
```

---

## 7. Curriculum Data Model

### 7.1 Unit Structure (21 Units)

```
Phase 1: A1 (Units 1-10, ~12 weeks)
├── Unit 1:  Sounds & Pronunciation
├── Unit 2:  Greetings & Introductions
├── Unit 3:  Gender & Nominative Case
├── Unit 4:  Present Tense — být & mít
├── Unit 5:  Present Tense — Regular Verbs
├── Unit 6:  Accusative Case
├── Unit 7:  Pronouns & Possessives
├── Unit 8:  Family & Basic Descriptions
├── Unit 9:  Food & Ordering
└── Unit 10: A1 Review & Exam Prep

Phase 2: A2 (Units 11-21, ~20 weeks)
├── Unit 11: Noun Declension Paradigms
├── Unit 12: Genitive Case
├── Unit 13: Dative Case
├── Unit 14: Locative Case (v vs na)
├── Unit 15: Instrumental Case
├── Unit 16: Prepositions Master Map
├── Unit 17: Past Tense
├── Unit 18: Verb Aspect (recognition)
├── Unit 19: Future Tense & Comparison
├── Unit 20: Themed Applied Practice
└── Unit 21: A2 Review & Exam Prep
```

### 7.2 Lesson Structure

Each unit contains 3-6 lessons. Each lesson contains 8-15 exercises.

```
Unit
├── Lesson 1 (Introduction / New Concepts)
│   ├── Grammar explanation card
│   ├── 2-3 presentation exercises (read & listen)
│   ├── 5-8 practice exercises (varied types)
│   └── 1-2 production exercises (speak / write)
│
├── Lesson 2 (Practice / Reinforcement)
│   ├── 2-3 review exercises (previous lesson)
│   ├── 6-8 new practice exercises
│   └── 1 dialogue exercise
│
├── Lesson 3 (Application / Production)
│   ├── 2-3 scenario exercises
│   ├── 1 listening comprehension
│   ├── 1 speaking exercise (pronunciation)
│   └── 1 writing exercise
│
└── Lesson 4 (Unit Review)
    ├── Mixed exercise set (all grammar from unit)
    └── Progress checkpoint (mastery threshold: 80%)
```

### 7.3 Grammar Rules Reference Table

| ID | Rule | Unit | Case Affected | Example |
|---|---|---|---|---|
| GR-001 | Feminine -a → -u in accusative | 6 | Accusative | káva → kávu |
| GR-002 | Animate masc. -a in accusative | 6 | Accusative | pes → psa |
| GR-003 | Inanimate masc. unchanged in accusative | 6 | Accusative | hrad → hrad |
| GR-004 | Genitive after quantities (5+) | 12 | Genitive | pět korun |
| GR-005 | Genitive after do/z/od/u/bez | 12 | Genitive | do obchodu |
| GR-006 | Dative recipient | 13 | Dative | Dám to kamarádovi |
| GR-007 | Dative experiencer (feelings) | 13 | Dative | Je mi zima |
| GR-008 | Locative after v/na | 14 | Locative | v Praze |
| GR-009 | v vs na distinction | 14 | Locative | na nádraží, v restauraci |
| GR-010 | Instrumental of means | 15 | Instrumental | jedu vlakem |
| GR-011 | Instrumental of profession | 15 | Instrumental | Jsem učitelem |
| GR-012 | Instrumental with s | 15 | Instrumental | s kamarádem |
| GR-013 | Past tense: l-participle + auxiliary | 17 | N/A | dělal jsem |
| GR-014 | Past tense participle agreement | 17 | N/A | ona dělala |
| GR-015 | Aspect: perfective vs imperfective | 18 | N/A | dělat/udělat |
| GR-016 | Future: budu + imperfective | 19 | N/A | budu dělat |
| GR-017 | Comparative: -ejší/-ší | 19 | N/A | větší, lepší |

### 7.4 Content Seeding

Curriculum content is seeded from a JSON content pack bundled with the app:

```
assets/
├── curriculum/
│   ├── a1_units.json          # Units 1-10 metadata
│   ├── a2_units.json          # Units 11-21 metadata
│   ├── lessons/
│   │   ├── unit01_lesson01.json
│   │   ├── unit01_lesson02.json
│   │   ├── ...
│   │   └── unit21_lesson04.json
│   └── grammar_rules.json     # GR-001 to GR-017+
├── vocabulary/
│   ├── a1_vocabulary.json     # ~300 words
│   └── a2_vocabulary.json     # ~800 words
└── exams/
    ├── cce_a1_mock.json       # Mock exam definition
    └── cce_a2_mock.json
```

---

## 8. Gamification Engine

### 8.1 State Model

```dart
class GamificationState {
  final int hearts;           // 0-5, lose 1 per wrong answer
  final int maxHearts;         // 5 (default), 7 (premium)
  final int currentStreak;     // consecutive days
  final int longestStreak;
  final int totalXp;
  final int dailyXp;
  final int dailyGoalXp;       // default 50
  final League currentLeague;  // Bronze, Silver, Gold, Diamond
  final int gems;              // virtual currency
  final Set<String> earnedBadges;
  final DateTime lastHeartRefill;
  final bool streakFreezeAvailable;
}
```

### 8.2 XP Rules

| Action | XP |
|---|---|
| Lesson completed (perfect) | 20 |
| Lesson completed (≥80% accuracy) | 15 |
| Lesson completed (<80% accuracy) | 10 |
| SRS review session (per card) | 2 |
| Daily streak milestone (per day) | 5 × streak_days |
| Badge unlocked | varies (10-50) |
| Mock exam completed | 50 |
| Pronunciation drill (score ≥ 80%) | 10 |

### 8.3 Heart Mechanics

- Start with 5 hearts (max 5 for free tier)
- Lose 1 heart per wrong answer in lessons
- 0 hearts = must wait (timer) or practice SRS to earn back
- Hearts regenerate: 1 per 30 minutes (configurable)
- Streak Freeze: spend gems to protect streak on missed days

### 8.4 League System

| League | XP Threshold (weekly) | Promotion |
|---|---|---|
| Bronze | 0 | Top 10 → Silver |
| Silver | 100 | Top 10 → Gold |
| Gold | 300 | Top 5 → Platinum |
| Platinum | 600 | Top 5 → Diamond |
| Diamond | 1000 | Top 1 → Legend |

Note: For a single-user app, leagues can be simulated with AI "opponents" or deferred to a future community feature.

### 8.5 Czech-Specific Badges

| Badge ID | Name | Criteria | XP |
|---|---|---|---|
| `case_nominative` | First Case | Complete Unit 3 with 80%+ | 10 |
| `case_accusative` | Object Master | Complete Unit 6 with 80%+ | 15 |
| `case_genitive` | Possession Pro | Complete Unit 12 with 80%+ | 20 |
| `case_dative` | The Giver | Complete Unit 13 with 80%+ | 20 |
| `case_locative` | Where Am I? | Complete Unit 14 with 80%+ | 20 |
| `case_instrumental` | By Means Of | Complete Unit 15 with 80%+ | 20 |
| `case_all` | Case Collector | Master all 7 cases | 50 |
| `verb_byt` | To Be Master | Perfect conjugation of být | 10 |
| `verb_past` | Time Traveler | Complete Unit 17 with 80%+ | 25 |
| `verb_aspect` | Aspect Eye | Complete Unit 18 with 80%+ | 25 |
| `pronunciation_rz` | The ř Badge | Score ≥ 80% on ř pronunciation drill | 15 |
| `streak_7` | Week Warrior | 7-day streak | 20 |
| `streak_30` | Monthly Master | 30-day streak | 50 |
| `mock_a1_pass` | A1 Certified | Pass CCE-A1 mock exam | 50 |
| `mock_a2_pass` | A2 Certified | Pass CCE-A2 mock exam | 100 |

---

## 9. Pronunciation Scoring Engine

### 9.1 Pipeline

```
User records audio
     │
     ▼
┌──────────────┐
│  Vosk STT    │──→ text transcription
└──────────────┘
     │
     ▼
┌──────────────┐      ┌──────────────┐
│  Normalize   │      │ Expected text│
│  (lowercase, │      │ (from lesson │
│   strip punct│      │  exercise)  │
│   strip diacritics
│   for comparison)  │              │
└──────────────┘      └──────────────┘
     │                       │
     └───────────┬───────────┘
                 ▼
         ┌──────────────┐
         │ Word Alignment│
         │ (Levenshtein  │
         │  distance)    │
         └──────┬───────┘
                │
        ┌───────┴───────┐
        ▼               ▼
┌──────────────┐ ┌──────────────┐
│ Per-word score│ │ Phonetic    │
│ (match/mismatch)│ │ scoring   │
└──────────────┘ │ (ř, ě,     │
                  │  vowel length)│
                  └──────┬───────┘
                         │
                         ▼
                 ┌──────────────┐
                 │  Result      │
                 │  - overall % │
                 │  - per-word  │
                 │  - problem   │
                 │    sounds    │
                 │  - feedback  │
                 └──────────────┘
```

### 9.2 Czech Phoneme Mapping

Czech orthography → approximate IPA for scoring:

| Czech | IPA | Notes |
|---|---|---|
| a, e, i, o, u | a, ɛ, i, o, u | short vowels |
| á, é, í, ó, ú/ů | aː, ɛː, iː, oː, uː | long vowels (meaning-changing!) |
| ř | r̝ | unique Czech sound, highest weight |
| ě | jɛ | softens preceding consonant (dě, tě, ně) |
| č, š, ž, ď, ť, ň | tʃ, ʃ, ʒ, ɟ, c, ɲ | palatalized consonants |
| ch | x | digraph |
| h, g | ɦ, g | voiced glottal |
| c, j | ts, j | |

### 9.3 Scoring Algorithm (Pseudocode)

```
score_pronunciation(expected_text, actual_text):
    expected_phonemes = text_to_phonemes(expected_text)
    actual_phonemes = text_to_phonemes(actual_text)

    # Dynamic time warping on phoneme sequences
    alignment = dtw_align(expected_phonemes, actual_phonemes)

    # Weighted scoring
    weights = {
        'ř': 3.0,      # highest weight — signature sound
        'ě': 2.5,      # softening effect
        'long_vowel': 2.5,  # meaning-changing
        'palatalized': 2.0,
        'other': 1.0
    }

    total_weight = 0
    correct_weight = 0
    problem_sounds = []

    for (exp_phoneme, act_phoneme) in alignment:
        w = get_weight(exp_phoneme, weights)
        total_weight += w
        if phonemes_match(exp_phoneme, act_phoneme):
            correct_weight += w
        else:
            problem_sounds.append({
                phoneme: exp_phoneme,
                word: get_word_for_phoneme(exp_phoneme),
                score: phoneme_similarity(exp_phoneme, act_phoneme)
            })

    overall_score = correct_weight / total_weight

    return PronunciationResult(
        overall_score: overall_score,
        problem_sounds: problem_sounds,
        feedback: generate_feedback(problem_sounds)
    )
```

### 9.4 Implementation Phases

- **Phase 1 (MVP):** Text comparison only (expected vs transcribed). Simple word match/mismatch. No phoneme-level scoring.
- **Phase 2:** Add Czech phoneme mapping + weighted scoring for ř, ě, vowel length.
- **Phase 3:** MFCC-based acoustic comparison (compare user's audio waveform to reference audio) for true pronunciation scoring.

---

## 10. Spaced Repetition (SM-2) Integration

### 10.1 Card States

```dart
enum CardState { new_, learning, review, relearning }

class SrsCard {
  final String id;
  final CardType cardType;    // vocabulary or grammar
  final double stability;     // scheduled interval in days
  final double difficulty;    // SM-2 ease factor
  final DateTime due;         // next review date
  final int reps;              // total repetitions
  final CardState state;
  final DateTime? lastReview;
}
```

### 10.2 Two SRS Tracks

| Track | Content | Review Format |
|---|---|---|
| **Vocabulary SRS** | Individual words/phrases | Flashcard: Czech audio → recall meaning, or English → type Czech |
| **Grammar SRS** | Grammar patterns | Exercise: "Decline 'žena' in dative" or "Choose correct aspect" |

Both tracks use the same SM-2-style scheduler with separate card pools. The
learner sees a mixed review session that interleaves vocabulary and grammar
cards. Adopting real FSRS later requires an explicit stored-state migration.

### 10.3 FSRS Configuration

```dart
final defaultFSRSConfig = FsrsConfig(
  requestRetention: 0.9,    // target 90% recall probability
  maximumInterval: 365,    // cap at 1 year
  enableFuzzing: true,      // add randomness to avoid clustering
  enableShortTerm: true,    // short-term memory tracking
);
```

---

## 11. LLM API Contracts

### 11.1 Conversation Response Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["tutor_reply_cz", "tutor_reply_en", "corrections", "new_vocabulary"],
  "properties": {
    "tutor_reply_cz": {
      "type": "string",
      "description": "Tutor's response in Czech, level-appropriate"
    },
    "tutor_reply_en": {
      "type": "string",
      "description": "English translation of tutor's response"
    },
    "corrections": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "user_said", "correct", "rule", "severity"],
        "properties": {
          "type": {
            "type": "string",
            "enum": ["case", "verb_conjugation", "aspect", "word_order", "gender_agreement", "spelling", "vowel_length"]
          },
          "user_said": { "type": "string" },
          "correct": { "type": "string" },
          "rule": { "type": "string", "description": "Brief explanation of the grammar rule" },
          "severity": {
            "type": "string",
            "enum": ["error", "minor", "stylistic"]
          }
        }
      }
    },
    "new_vocabulary": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["cz", "en"],
        "properties": {
          "cz": { "type": "string" },
          "en": { "type": "string" },
          "ipa": { "type": "string" }
        }
      }
    }
  }
}
```

### 11.2 Grammar Check Response Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["corrected_text", "errors"],
  "properties": {
    "corrected_text": { "type": "string" },
    "errors": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "original", "correction", "explanation"],
        "properties": {
          "type": {
            "type": "string",
            "enum": ["case", "verb_conjugation", "aspect", "word_order", "gender_agreement", "spelling", "vowel_length", "preposition"]
          },
          "original": { "type": "string" },
          "correction": { "type": "string" },
          "explanation": { "type": "string" }
        }
      }
    }
  }
}
```

### 11.3 Exam Writing Evaluation Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["score", "feedback", "errors"],
  "properties": {
    "score": {
      "type": "object",
      "properties": {
        "grammar": { "type": "number", "minimum": 0, "maximum": 100 },
        "vocabulary": { "type": "number", "minimum": 0, "maximum": 100 },
        "coherence": { "type": "number", "minimum": 0, "maximum": 100 },
        "overall": { "type": "number", "minimum": 0, "maximum": 100 }
      }
    },
    "feedback": { "type": "string" },
    "errors": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": { "type": "string" },
          "original": { "type": "string" },
          "correction": { "type": "string" },
          "explanation": { "type": "string" }
        }
      }
    }
  }
}
```

### 11.4 Prompt Templates

**Conversation Practice (A1):**
```
System: You are a patient Czech language tutor for a CEFR A1 learner.

Rules:
- Respond ONLY in Czech at A1 level (very simple vocabulary, short sentences)
- Maximum 3 sentences per response
- If the learner makes an error, correct it and explain the rule in English
- Scenario: {scenario_description}
- You are playing the role of: {role_description}

Return JSON matching this schema: {schema_json}

Conversation history:
{history}
```

**Grammar Explanation:**
```
System: You are a Czech grammar expert. Explain the error to a CEFR {level} learner.

User's sentence: "{user_sentence}"
Correct version: "{correct_sentence}"
Error type: {error_type}

Explain the grammar rule briefly (2-3 sentences) in English, with a Czech example.
Return JSON: {"explanation": "...", "rule_name": "...", "example_cz": "...", "example_en": "..."}
```

**Writing Evaluation:**
```
System: You are a CCE exam evaluator. Assess the learner's Czech writing at {level} level.

Task: {writing_task_description}
Learner's text: "{learner_text}"

Evaluate grammar, vocabulary, and coherence (0-100 each).
Return JSON matching this schema: {schema_json}
```

---

## 12. Audio Pipeline

### 12.1 Recording Flow

```
User taps "Record" button
     │
     ▼
┌────────────────────────┐
│ record package          │
│ Record PCM/WAV         │
│ Sample rate: 16kHz     │
│ Channels: mono         │
│ Bit depth: 16-bit      │
└───────────┬────────────┘
            │
            ▼
┌────────────────────────┐
│ Audio File Manager      │
│ Save to temp dir:       │
│ {cache}/recording_      │
│ {timestamp}.wav        │
└───────────┬────────────┘
            │
    ┌───────┴───────┐
    ▼               ▼
[Vosk STT]     [Whisper API]
(local)        (if needed)
    │               │
    └───────┬───────┘
            ▼
    Transcribed text
```

### 12.2 Playback Flow

```
Text to speak (from lesson or LLM response)
     │
     ▼
┌────────────────────────┐
│ TTS Cache Check        │
│ hash(text + voice)     │
└───────────┬────────────┘
            │
    ┌───────┴───────┐
    ▼ (cache hit)   ▼ (cache miss)
[Play cached     [Synthesize via
 .mp3 file]      Edge TTS / Google]
    │               │
    │               ▼
    │      ┌────────────────┐
    │      │ Save to cache  │
    │      │ tts_{hash}.mp3 │
    │      └───────┬────────┘
    │              │
    └──────┬───────┘
           ▼
    just_audio playback
```

### 12.3 Vosk Czech Model Integration

**Approach:** Platform channels wrapping Vosk native libraries.

**Android:**
- `libvosk-android` (.aar) bundled in `android/app/libs/`
- Kotlin MethodChannel handler
- Model: `vosk-model-small-cs-0.4-rhasspy` (44MB) in `assets/vosk-models/`

**iOS:**
- `libvosk-ios` (framework) via CocoaPods or manual integration
- Swift MethodChannel handler
- Same model bundled in `assets/vosk-models/`

**macOS:**
- Reuse iOS framework or compile `libvosk` from source for macOS
- Same MethodChannel approach

**Windows:**
- `libvosk` compiled for Windows (MSVC)
- C++ plugin via platform channel
- Model bundled in assets

**Dart interface:**
```dart
class VoskSttEngine implements SttService {
  static const _channel = MethodChannel('com.eminentsite.czechify/vosk');

  Future<void> init() async {
    await _channel.invokeMethod('init', {
      'modelPath': await _getModelPath(),
      'sampleRate': 16000,
    });
  }

  @override
  Future<String> transcribe(String audioPath) async {
    final result = await _channel.invokeMethod<String>('transcribe', {
      'audioPath': audioPath,
    });
    final json = jsonDecode(result!);
    return json['text'] as String;
  }
}
```

### 12.4 Audio Formats

| Purpose | Format | Why |
|---|---|---|
| Recording | WAV (PCM 16-bit, 16kHz, mono) | Vosk/Whisper compatible, no encoding overhead |
| TTS cache | MP3 | Smaller files, just_audio handles natively |
| UI sounds | MP3 in assets | Small, universal |

---

## 13. Platform-Specific Configurations

### 13.1 iOS

```
Info.plist:
- NSMicrophoneUsageDescription: "Needed for pronunciation exercises and AI conversation practice"
- NSSpeechRecognitionUsageDescription: "Needed for Czech speech recognition"

Audio Session:
- Category: .playAndRecord
- Mode: .spokenAudio
- Options: [.defaultToSpeaker, .allowBluetooth]
```

### 13.2 Android

```
AndroidManifest.xml:
- <uses-permission android:name="android.permission.RECORD_AUDIO" />
- <uses-permission android:name="android.permission.INTERNET" />
- <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

minSdkVersion: 23 (Android 6.0)
targetSdkVersion: 35

Audio:
- AudioFormat: ENCODING_PCM_16BIT
- Sample rate: 16000 Hz
- Channel: CHANNEL_IN_MONO
```

### 13.3 macOS

```
Info.plist (macOS):
- NSMicrophoneUsageDescription: "Needed for pronunciation exercises"
- App Sandbox: YES — must enable network + audio entitlements

.entitlements:
- com.apple.security.device.audio-input = true
- com.apple.security.network.client = true

Window:
- Default size: 900×640
- Min size: 400×600
- Supports multiple windows: NO (single window)
```

### 13.4 Windows

```
pubspec.yaml:
  flutter:
    platform: windows  # ensure Windows is built

Requirements:
- Visual Studio 2022 with C++ desktop workload
- Windows 10+ (Build 1903+)

Microphone:
- No special permissions needed (Windows allows mic access by default)
- But Windows settings may block mic — handle gracefully with error message
```

---

## 14. Project Structure

```
czechify/
├── lib/
│   ├── main.dart                     # App entry, provider scope, router
│   ├── app.dart                      # MaterialApp.router, theme
│   │
│   ├── core/                         # Shared utilities
│   │   ├── constants.dart
│   │   ├── extensions/               # Dart extensions
│   │   │   ├── string_ext.dart
│   │   │   └── datetime_ext.dart
│   │   ├── errors/                   # Custom exceptions
│   │   │   ├── app_exceptions.dart
│   │   │   └── failures.dart
│   │   ├── utils/
│   │   │   ├── audio_hasher.dart
│   │   │   ├── phoneme_mapper.dart
│   │   │   └── text_normalizer.dart
│   │   └── theme/                    # App-wide theming
│   │       ├── app_theme.dart
│   │       └── app_colors.dart
│   │
│   ├── domain/                       # Business logic (no Flutter, no I/O)
│   │   ├── entities/
│   │   │   ├── unit.dart
│   │   │   ├── lesson.dart
│   │   │   ├── exercise.dart
│   │   │   ├── flashcard.dart
│   │   │   ├── srs_card.dart
│   │   │   ├── chat_message.dart
│   │   │   ├── badge.dart
│   │   │   ├── gamification_state.dart
│   │   │   ├── pronunciation_result.dart
│   │   │   ├── exam_result.dart
│   │   │   └── progress_state.dart
│   │   │
│   │   ├── usecases/                  # Use case implementations
│   │   │   ├── complete_lesson.dart
│   │   │   ├── review_card.dart
│   │   │   ├── start_conversation.dart
│   │   │   ├── assess_pronunciation.dart
│   │   │   ├── take_mock_exam.dart
│   │   │   └── update_streak.dart
│   │   │
│   │   ├── engines/                  # Core algorithms
│   │   │   ├── srs_scheduler.dart
│   │   │   ├── gamification_engine.dart
│   │   │   ├── pronunciation_scorer.dart
│   │   │   ├── llm_orchestrator.dart
│   │   │   ├── curriculum_tracker.dart
│   │   │   └── xp_calculator.dart
│   │   │
│   │   └── repositories/             # Abstract interfaces
│   │       ├── curriculum_repository.dart
│   │       ├── vocabulary_repository.dart
│   │       ├── conversation_repository.dart
│   │       ├── progress_repository.dart
│   │       ├── exam_repository.dart
│   │       ├── stt_service.dart
│   │       ├── tts_service.dart
│   │       └── llm_service.dart
│   │
│   ├── data/                         # Implements domain interfaces
│   │   ├── database/
│   │   │   ├── database.dart         # Drift database definition
│   │   │   ├── tables/               # Drift table definitions
│   │   │   │   ├── units.dart
│   │   │   │   ├── lessons.dart
│   │   │   │   ├── exercises.dart
│   │   │   │   ├── flashcards.dart
│   │   │   │   ├── srs_cards.dart
│   │   │   │   ├── chat_messages.dart
│   │   │   │   ├── exam_results.dart
│   │   │   │   ├── grammar_rules.dart
│   │   │   │   └── user_progress.dart
│   │   │   └── daos/                  # Data access objects
│   │   │       ├── curriculum_dao.dart
│   │   │       ├── vocabulary_dao.dart
│   │   │       └── progress_dao.dart
│   │   │
│   │   ├── repositories/             # Concrete implementations
│   │   │   ├── drift_curriculum_repository.dart
│   │   │   ├── drift_vocabulary_repository.dart
│   │   │   ├── drift_conversation_repository.dart
│   │   │   ├── drift_progress_repository.dart
│   │   │   └── drift_exam_repository.dart
│   │   │
│   │   ├── services/                 # External service implementations
│   │   │   ├── stt/
│   │   │   │   ├── vosk_stt_engine.dart
│   │   │   │   ├── whisper_stt_engine.dart
│   │   │   │   └── stt_manager.dart
│   │   │   ├── tts/
│   │   │   │   ├── edge_tts_engine.dart
│   │   │   │   ├── google_tts_engine.dart
│   │   │   │   ├── tts_manager.dart
│   │   │   │   └── tts_cache.dart
│   │   │   └── llm/
│   │   │       ├── deepseek_provider.dart
│   │   │       ├── gemini_provider.dart
│   │   │       ├── openai_provider.dart
│   │   │       └── llm_provider_chain.dart
│   │   │
│   │   ├── datasources/
│   │   │   ├── hive_local_datasource.dart
│   │   │   ├── secure_storage_datasource.dart
│   │   │   └── asset_content_loader.dart
│   │   │
│   │   └── seeds/
│   │       └── content_seeder.dart   # Loads JSON curriculum into Drift
│   │
│   ├── presentation/                 # UI layer
│   │   ├── routes/
│   │   │   ├── app_router.dart
│   │   │   └── app_scaffold.dart     # AdaptiveScaffold (mobile/desktop)
│   │   │
│   │   ├── providers/                # Riverpod providers
│   │   │   ├── curriculum_providers.dart
│   │   │   ├── srs_providers.dart
│   │   │   ├── chat_providers.dart
│   │   │   ├── pronunciation_providers.dart
│   │   │   ├── gamification_providers.dart
│   │   │   ├── exam_providers.dart
│   │   │   └── settings_providers.dart
│   │   │
│   │   ├── screens/
│   │   │   ├── onboarding/
│   │   │   ├── home/
│   │   │   ├── curriculum/
│   │   │   ├── lesson/
│   │   │   ├── review/
│   │   │   ├── chat/
│   │   │   ├── pronunciation/
│   │   │   ├── exam/
│   │   │   ├── stats/
│   │   │   └── settings/
│   │   │
│   │   └── widgets/                  # Reusable widgets
│   │       ├── lesson/
│   │       │   ├── exercise_widget.dart       # Base widget
│   │       │   ├── multiple_choice_widget.dart
│   │       │   ├── fill_blank_widget.dart
│   │       │   ├── word_order_widget.dart
│   │       │   ├── translation_widget.dart
│   │       │   ├── dictation_widget.dart
│   │       │   ├── pronunciation_widget.dart
│   │       │   ├── declension_table_widget.dart
│   │       │   ├── aspect_recognition_widget.dart
│   │       │   └── preposition_case_widget.dart
│   │       ├── common/
│   │       │   ├── progress_bar.dart
│   │       │   ├── hearts_display.dart
│   │       │   ├── streak_indicator.dart
│   │       │   ├── xp_badge.dart
│   │       │   ├── record_button.dart
│   │       │   ├── audio_player_button.dart
│   │       │   └── grammar_tip_card.dart
│   │       └── chat/
│   │           ├── chat_bubble.dart
│   │           ├── correction_card.dart
│   │           └── new_vocab_chip.dart
│   │
│   └── l10n/                         # Localization (EN base, CZ target)
│       ├── app_en.arb
│       └── app_cz.arb
│
├── assets/
│   ├── curriculum/                   # JSON content packs
│   │   ├── a1_units.json
│   │   ├── a2_units.json
│   │   ├── lessons/
│   │   ├── grammar_rules.json
│   │   └── exams/
│   ├── vocabulary/
│   ├── audio/                        # UI sounds, pre-recorded phrases
│   ├── images/                       # Flashcard images
│   └── vosk-models/
│       └── vosk-model-small-cs-0.4-rhasspy/
│
├── android/
├── ios/
├── macos/
├── windows/
├── test/
│   ├── domain/
│   │   ├── engines/
│   │   │   ├── srs_scheduler_test.dart
│   │   │   ├── gamification_engine_test.dart
│   │   │   ├── pronunciation_scorer_test.dart
│   │   │   └── llm_orchestrator_test.dart
│   │   └── usecases/
│   ├── data/
│   │   ├── repositories/
│   │   └── services/
│   └── presentation/
│       └── widgets/
│
├── pubspec.yaml
├── analysis_options.yaml
└── ARCHITECTURE.md                   # This document
```

---

## 15. Dependency Graph

### 15.1 pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State Management & Routing
  flutter_riverpod: ^3.0.0          # or hooks_riverpod
  riverpod_annotation: ^3.0.0       # code generation
  go_router: ^14.0.0

  # Database & Storage
  drift: ^2.20.0
  sqlite3_flutter_libs: ^0.5.0
  hive: ^4.0.0                      # or shared_preferences
  hive_flutter: ^1.0.0
  flutter_secure_storage: ^9.0.0

  # Audio
  record: ^5.0.0
  just_audio: ^0.9.39
  audio_session: ^0.1.0             # audio session management

  # Speech
  speech_to_text: ^7.0.0            # OS-native STT (fallback)
  flutter_tts: ^4.0.0               # OS-native TTS (fallback)

  # SRS
  dart_fsrs: ^1.0.0                 # or fsrs: ^1.0.0 (check pub.dev)

  # Networking
  dio: ^5.4.0
  retrofit: ^4.0.0                  # typed API client (optional)

  # Utilities
  json_annotation: ^4.8.0
  freezed_annotation: ^2.4.0
  collection: ^1.18.0
  path: ^1.9.0
  path_provider: ^2.1.0
  crypto: ^3.0.0                    # SHA256 for TTS cache hashing
  logging: ^1.2.0

  # Localization
  intl: ^0.19.0
  flutter_localizations:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.0
  drift_dev: ^2.20.0
  json_serializable: ^6.7.0
  freezed: ^2.4.0
  hive_generator: ^2.0.0           # if using Hive with codegen

  # Linting
  flutter_lints: ^4.0.0
  dart_code_metrics: ^5.1.0
```

### 15.2 Native Dependencies

| Platform | Library | Purpose |
|---|---|---|
| Android | `libvosk-android` (AAR) | On-device STT |
| iOS | `libvosk-ios` (framework) | On-device STT |
| macOS | `libvosk` (compiled) | On-device STT |
| Windows | `libvosk` (DLL) | On-device STT |

---

## 16. Offline Mode Strategy

### 16.1 What Works Offline

| Feature | Offline? | Mechanism |
|---|---|---|
| Lessons (exercises) | ✅ | Content bundled in assets, loaded into Drift on first launch |
| SRS Review | ✅ | All card states in local SQLite |
| Pronunciation drills (basic) | ✅ | Vosk on-device STT + text comparison |
| AI Conversation | ❌ | Requires LLM API |
| Pronunciation (advanced) | ❌ | MFCC comparison needs reference audio (can be bundled) |
| Mock exam (reading/listening) | ✅ | Pre-bundled exam content |
| Mock exam (writing/speaking) | ❌ | Requires LLM for evaluation |
| TTS | ⚠️ | Cached phrases work; new text needs Edge TTS (online) |
| Gamification | ✅ | All state is local |

### 16.2 Connectivity-Aware Behavior

```dart
class ConnectivityAwareExecutor {
  final ConnectivityChecker _connectivity;

  Future<T> executeOnline<T>({
    required Future<T> Function() online,
    required T Function() offline,
  }) async {
    if (await _connectivity.hasInternet) {
      try {
        return await online();
      } catch (_) {
        return offline();
      }
    }
    return offline();
  }
}
```

When offline:
- AI conversation shows "Connect to internet for AI tutor" with a button to review past conversations
- Pronunciation falls back to basic text comparison (Vosk still works offline)
- TTS plays cached audio only; uncached text uses `flutter_tts` (OS-native, offline)
- Writing evaluation deferred until connection restored

---

## 17. Security & API Key Management

### 17.1 API Key Storage

```dart
class SecureStorageDataSource {
  final FlutterSecureStorage _storage;

  Future<void> saveApiKey(String provider, String key) async {
    await _storage.write(key: 'api_key_$provider', value: key);
  }

  Future<String?> getApiKey(String provider) async {
    return _storage.read(key: 'api_key_$provider');
  }

  Future<void> deleteApiKey(String provider) async {
    await _storage.delete(key: 'api_key_$provider');
  }
}
```

### 17.2 Key Providers

| Provider | Key Name | Purpose |
|---|---|---|
| `deepseek` | `api_key_deepseek` | LLM conversation, grammar check |
| `openai` | `api_key_openai` | Whisper API fallback, GPT fallback |
| `google_tts` | `api_key_google_tts` | Google Cloud TTS (Chirp3-HD) |
| `gemini` | `api_key_gemini` | Gemini LLM fallback |

### 17.3 Onboarding API Key Entry

The app is self-hosted (user provides their own API keys). Onboarding screen:
1. "Enter your DeepSeek API key" (recommended — cheapest)
2. "Enter your OpenAI API key" (optional — for Whisper fallback)
3. "Enter your Google Cloud TTS key" (optional — for high-quality voices)
4. Validation: app makes a test API call to verify each key
5. Keys stored in flutter_secure_storage (encrypted on-device)

### 17.4 No Server, No Analytics

- No backend server — all processing is on-device or direct API calls
- No analytics tracking — this is a personal app
- No user accounts — single-user, local-first

---

## 18. Testing Strategy

### 18.1 Test Pyramid

```
                    ┌───────────┐
                    │  E2E (5%) │   Integration tests: full lesson flow, mock exam
                    ├───────────┤
                    │ Widget(20%)│  Widget tests: exercise widgets, screen navigation
                    ├───────────┤
                    │  Unit(75%) │  Domain logic: FSRS, gamification, pronunciation
                    └───────────┘
```

### 18.2 Key Test Targets

| Area | Test Type | What to Verify |
|---|---|---|
| FSRS Scheduler | Unit | Card scheduling math, due date calculation, state transitions |
| Gamification Engine | Unit | XP calculation, heart deduction, streak logic, badge unlock criteria |
| Pronunciation Scorer | Unit | Text normalization, word alignment, phoneme mapping, scoring weights |
| LLM Orchestrator | Unit | Prompt building, JSON response parsing, error handling |
| Curriculum Tracker | Unit | Lesson unlock logic, completion calculation, CEFR estimate |
| Exercise Widgets | Widget | All exercise types render correctly, accept input, validate answers |
| Lesson Flow | Integration | Complete a full lesson: exercises → scoring → SRS update → XP |
| Mock Exam | Integration | Full exam flow: start → timed sections → submit → results |
| Database | Integration | Content seeding, card updates, conversation persistence |

### 18.3 Mocking Strategy

```dart
// Use mocktail for all external dependencies
class MockCurriculumRepository extends Mock implements CurriculumRepository {}
class MockSttService extends Mock implements SttService {}
class MockLlmService extends Mock implements LlmService {}

// Domain tests use mocks — pure logic testing
// Widget tests use provider overrides with mock repositories
// Integration tests use in-memory Drift database
```

---

## 19. Build & Deployment

### 19.1 Development Environment

```bash
# Setup
flutter create czechify --platforms=ios,android,macos,windows
cd czechify

# Code generation (run after model/interface changes)
dart run build_runner build --delete-conflicting-outputs

# Run on device
flutter run -d <device_id>

# Run on macOS
flutter run -d macos

# Run on Windows
flutter run -d windows
```

### 19.2 Build Commands

```bash
# Android APK
flutter build apk --release
flutter build appbundle --release    # for Play Store

# iOS
flutter build ios --release
# Archive via Xcode for App Store

# macOS
flutter build macos --release
# .app bundle in build/macos/Build/Products/Release/

# Windows
flutter build windows --release
# .exe in build/windows/runner/Release/
```

### 19.3 Vosk Model Bundling

The Vosk Czech model (44MB) is bundled as a Flutter asset and extracted to the app's documents directory on first launch:

```dart
class ContentSeeder {
  Future<void> extractVoskModel() async {
    final modelDir = await _getModelDir();
    if (!modelDir.existsSync()) {
      final assetData = await rootBundle.load('assets/vosk-models/vosk-model-small-cs-0.4-rhasspy.zip');
      // Extract ZIP to modelDir
      await _extractZip(assetData, modelDir);
    }
  }
}
```

### 19.4 Content Pack Versioning

```dart
class ContentSeeder {
  Future<void> seedIfNeeded() async {
    final currentVersion = await _hive.get('content.curriculum_version');
    final appVersion = '1.0.0'; // from pubspec

    if (currentVersion != appVersion) {
      await _seedCurriculumFromAssets();
      await _hive.put('content.curriculum_version', appVersion);
    }
  }
}
```

---

## 20. Roadmap

### Phase 1: MVP — Core Learning Loop (Weeks 1-6)

**Goal:** A learner can complete lessons, do SRS review, and see progress.

- [ ] Flutter project scaffolding + directory structure
- [ ] Drift database schema + content seeder
- [ ] Curriculum content: Units 1-3 (sounds, greetings, gender/nominative)
- [ ] Exercise types: multiple_choice, fill_blank, translation, word_order
- [ ] Lesson player screen with hearts + progress bar
- [ ] SRS review screen with dart-fsrs
- [ ] Gamification: XP, streak, hearts (no leagues/badges yet)
- [ ] Home dashboard: streak, XP, daily goal, continue button
- [ ] `flutter_tts` for basic Czech audio (OS-native, free)
- [ ] Unit tests for FSRS scheduler, gamification engine

### Phase 2: Audio & AI (Weeks 7-10)

**Goal:** Pronunciation practice and AI conversation.

- [ ] Vosk Czech model integration (platform channels)
- [ ] Record button widget + audio capture
- [ ] Pronunciation scoring engine (text comparison, Phase 1 algorithm)
- [ ] Pronunciation exercise widget with visual feedback
- [ ] LLM orchestrator + DeepSeek API integration
- [ ] AI conversation screen (role-play scenarios)
- [ ] Edge TTS integration (free, higher quality than OS TTS)
- [ ] TTS audio caching
- [ ] Conversation history persistence (Drift)
- [ ] Unit tests for pronunciation scorer, LLM orchestrator

### Phase 3: Full Curriculum + Exam Prep (Weeks 11-16)

**Goal:** Complete A1+A2 curriculum and CCE mock exams.

- [ ] Curriculum content: Units 4-10 (A1 complete)
- [ ] Curriculum content: Units 11-21 (A2 complete)
- [ ] All exercise types (declension table, aspect recognition, v/na drill, preposition+case)
- [ ] Czech-specific badges + badge unlock system
- [ ] Mock exam mode (timed sections, CCE format)
- [ ] Speaking exam simulator (AI examiner)
- [ ] Writing task practice (AI evaluation)
- [ ] Stats/progress screen with CEFR level estimate
- [ ] Google Cloud TTS integration (Chirp3-HD, optional)
- [ ] Whisper API integration (cloud STT fallback)
- [ ] Integration tests for lesson flow, mock exam

### Phase 4: Polish & Desktop (Weeks 17-20)

**Goal:** Production-ready app on all platforms.

- [ ] Responsive layout (desktop navigation rail)
- [ ] Offline mode handling (connectivity-aware execution)
- [ ] Settings screen (TTS voice, STT engine, API keys, theme, daily goal)
- [ ] Onboarding flow (level assessment, goal setting, API key entry)
- [ ] Dark/light theme
- [ ] Localization (EN base, CZ target language labels)
- [ ] Pronunciation scoring Phase 2 (Czech phoneme mapping + weighted scoring)
- [ ] Performance optimization (lazy loading, image caching)
- [ ] E2E integration tests
- [ ] macOS build + testing
- [ ] Windows build + testing
- [ ] App Store / Play Store metadata and screenshots

### Future (Post-MVP)

- [ ] Pronunciation scoring Phase 3 (MFCC acoustic comparison)
- [ ] Image-based vocabulary (camera scan → Czech label)
- [ ] AI-generated reading passages
- [ ] B1 curriculum expansion
- [ ] Community features (leaderboards with real users)
- [ ] Wearable companion (Watch OS for quick SRS review)
- [ ] Grammar rule explorer (browsable reference)

---

## Appendix A: Czech Language Quick Reference

### Cases at a Glance

| Case | Czech Name | Key Function | Example |
|---|---|---|---|
| Nominative | 1. pád (kdo/co) | Subject | *Žena* pije kávu. |
| Genitive | 2. pád (koho/čeho) | Possession, quantity | Kniha *ženy*. |
| Dative | 3. pád (komu/čemu) | Recipient, experiencer | Dám to *ženě*. |
| Accusative | 4. pád (koho/co) | Direct object | Vidím *ženu*. |
| Vocative | 5. pád (oslovujeme) | Address (excluded from A1/A2) | *Ženo!* |
| Locative | 6. pád (o kom/o čem) | Location, topic | O *ženě*. |
| Instrumental | 7. pád (kým/čím) | Means, profession | S *ženou*. |

### Verb Conjugation Paradigms

**být (to be) — A1:**
| Person | Singular | Plural |
|---|---|---|
| 1st | jsem | jsme |
| 2nd | jsi | jste |
| 3rd | je | jsou |

**dělat (to do) — -á class, A1:**
| Person | Singular | Plural |
|---|---|---|
| 1st | dělám | děláme |
| 2nd | děláš | děláte |
| 3rd | dělá | dělají |

**prosit (to ask) — -í class, A1:**
| Person | Singular | Plural |
|---|---|---|
| 1st | prosím | prosíme |
| 2nd | prosíš | prosíte |
| 3rd | prosí | prosí |

---

## Appendix B: Cost Estimate Summary

| Feature | Solution | Monthly Cost (Personal Use) |
|---|---|---|
| Speech Recognition | Vosk (free) + Whisper API fallback | ~$2 |
| AI Conversation | DeepSeek-V3 (~$0.008/session) | ~$0.25 |
| Text-to-Speech | Edge TTS (free) / Google Chirp3-HD (1M free chars/mo) | $0–$2 |
| Spaced Repetition | dart-fsrs (free, open source) | $0 |
| Grammar Checking | DeepSeek + hunspell-cs (free) | ~$1 |
| **Total** | | **~$3–5/month** |

---

*This document is a living architecture. Update it as implementation reveals new constraints and opportunities.*
