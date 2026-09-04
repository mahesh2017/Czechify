# Czechify: comprehensive code, content, security, and learning-experience audit

**Audit date:** 22 July 2026

**Repository state reviewed:** commit `4e69ee7891b5b51ccdb447a6c8bb63e8c8d67e1c`

**Product:** Czechify (`czechify`)

**Scope:** Flutter application, bundled curriculum, local Drift database, Supabase schema and linked project, Edge Functions, sync, exams, speech, accessibility, tests, and instructional design

**Decision:** **Do not present the current build as a reliable exam-preparation or CEFR-attainment product yet. Hold a broad public release until the P0 items below are resolved.**

---

## 1. Executive assessment

Czechify has a better foundation than its defect list may initially suggest. It has a clear layered architecture, a substantial A1/A2 corpus, offline-first storage, immediate exercise feedback, mistake retries, due-first spaced review, Czech TTS, and practical AI conversation scenarios. Static analysis is clean and all 135 current tests pass.

The problem is that the tests mostly prove isolated implementation units, while several contracts between **real curriculum assets, production screen composition, asynchronous state, and deployed services** are broken. As a result, a green test suite coexists with deterministic failures in core learning flows:

- 67 exercises across five types are composed under unbounded height and can fail with a Flutter `RenderFlex` exception.
- Only 17 of 36 dialogue exercises match the renderer's schema; 16 cannot accept an answer and three can null-cast.
- Every one of the six mock exams eventually reaches a speaking item that can crash; five exams contain a second writing task that is never graded.
- All 47 in-lesson pronunciation exercises use an empty or stale target, and the production cloud function they prefer is not deployed in the linked Supabase project.
- Four declension tables, at least 11 word-order items, and three additional dialogue items violate their widget contracts.
- All six open speaking lessons compare Czech speech with English placeholder answer metadata.
- Account switching/deletion can lose local state, incompletely erase promised data, or permanently empty the review deck.
- Multi-device sync can silently strand updates because conflict resolution and pull cursors trust device clocks.

There is also a product-validity problem. Current progress mostly measures completion and short-term answer matching, but the UI turns that into “Reached A1/A2.” Mock exams combine incompatible official formats and scoring rules. Pronunciation feedback is transcript similarity described as phonetic diagnosis. These claims go beyond the evidence the product collects.

The right response is not to discard the product. It is to establish a trustworthy core, then redirect the learning loop from content completion toward **retained, unscaffolded communicative performance**. The highest-value sequence is:

1. Eliminate crashes, schema drift, data-loss paths, false service availability, and inaccurate privacy/exam claims.
2. Make every answer, review, score, and content release idempotent and auditable.
3. Replace the single completion-derived level with a skill evidence profile.
4. Add placement, contextual retrieval, real listening, application lessons, self-repair, and delayed transfer.
5. Validate speech and open-response scoring against qualified Czech human raters before presenting it as proficiency evidence.

### Release priorities at a glance

| Priority | Meaning | Count in this report | Release posture |
|---|---:|---:|---|
| P0 | Deterministic failure, data/trust risk, paid-endpoint abuse risk, or materially invalid assessment | 10 issue groups | Block public/exam-readiness release |
| P1 | Major correctness or learning-validity defect | 15 issue groups | Resolve in the next product cycle |
| P2 | Important quality, accessibility, maintainability, or growth opportunity | 10 issue groups | Plan after the trusted core |

The counts are issue groups, not individual occurrences. For example, one schema issue group covers dozens of affected exercises.

---

## 2. What was examined and how

This was a read-only product and code audit except for creation of this document. It combined:

- repository-wide code and asset inspection;
- semantic checks over all curriculum/vocabulary JSON, not only JSON syntax;
- production widget-composition analysis;
- review of progress, SRS, gamification, sync, privacy, account, and content-release paths;
- read-only inspection of the linked Supabase project's migrations, deployed functions, secret-name inventory, release rows, database plan, and security advisor;
- comparison with official OpenAI, Supabase, Council of Europe, Charles University CCE, Czech permanent-residence exam, and Czech phonetics sources;
- synthesis of systematic reviews and meta-analyses on spacing, retrieval, corrective feedback, task-based instruction, extensive reading, pronunciation instruction, captioned input, and gamification.

### Verification performed

| Check | Result |
|---|---|
| `flutter analyze --fatal-infos` | Passed with zero issues |
| `flutter test --reporter expanded` | All 135 tests passed |
| `flutter test --coverage` | Passed |
| Instrumented production-line coverage | 3,336 / 10,195 = 32.7% |
| Non-generated instrumented coverage | 1,969 / 4,635 = 42.5% |
| Non-generated Dart footprint | 125 files; about 20,984 lines |
| Major user-flow screen coverage | No coverage for lesson player, mock exam, chat, review, home, curriculum, stats, settings, or account screens |
| Bundled content inventory | 31 units, 60 lessons, 726 exercises, 1,458 vocabulary records |
| Supabase migration history | Local and linked histories aligned |
| Linked Supabase security advisor | No findings |
| Edge Function type-checking | Not run: Deno is unavailable in this environment |
| Local database reset/pgTAP | Not run: Docker is unavailable |

Passing analysis and tests are valuable, but they are not evidence that real content can traverse real screens. The most important test gap is `test/exercise_widget_test.dart:43-141`: it mounts synthetic, idealized exercise maps under bounded layout instead of loading every shipped asset through `LessonPlayerScreen`.

### Evidence labels

- **Confirmed** means the code/data path or linked configuration was directly verified.
- **Deterministic** means ordinary execution reaches a type/layout/state failure without requiring a rare race.
- **Risk** means the design permits a failure but device/deployment testing is still required to observe it.
- **Learning-validity concern** means the implementation works mechanically but the measurement does not support the claim made to the learner.

### Important limitations

This is not a substitute for real-device testing, a full penetration test, a production-data audit, or a native Czech linguistic review. No learner rows or secrets were inspected. Auth-dashboard settings were not available. Speech quality was not tested across microphones or L1 backgrounds. The corpus examples below are high-confidence findings, not a complete linguistic errata list. A qualified Czech applied linguist and phonetician should review all published content.

---

## 3. Product strengths to preserve

The remediation should retain these sound foundations:

- Presentation, provider, domain, and data responsibilities are generally separated.
- Drift provides a credible offline-first base, and bundled content installation is transactional.
- The app can teach a broad A1/A2 scope: 31 units, 60 lessons, 14 exercise types, and 1,458 vocabulary records.
- Immediate corrective feedback and an end-of-lesson mistake loop are already present in `lesson_providers.dart:200-270`.
- Review planning is due-first, caps new items, gates cards to learned lessons, previews intervals, and repeats “Again” items in-session.
- Dictation supports replay and slower audio.
- Czech TTS has voice selection, rate control, caching, and native/neural fallback.
- Six AI scenarios emphasize practical contexts and include corrections, translation, suggested replies, and vocabulary-to-review flow.
- Pure engines for scheduling, grading, and scoring are relatively easy to test once their product semantics are corrected.
- Current public Supabase tables have RLS enabled; owner policies use `USING` and `WITH CHECK`; secrets were not found in client code; and the current security advisor is clean.
- Sync mutations and local outbox insertion are transactional, and sync already includes serialization, deterministic pagination, retry/backoff, and dead-letter concepts.

These strengths make the recovery tractable. The priority is to test the seams and correct what the product claims—not to rewrite everything.

---

## 4. P0 release blockers

### P0-1 — Production lesson composition breaks five exercise types

**Status:** Confirmed, deterministic

**Affected content:** 67 exercises: 22 matching, 19 error-correction, 10 reading-comprehension, 10 listening-comprehension, and 6 writing tasks.

`lesson_player_screen.dart:241-260` wraps every exercise in a vertical `SingleChildScrollView`. Five exercise widgets place `Expanded` at their root or inside a root `Column`:

- `matching_view.dart:160-205`
- `error_correction_view.dart:150-175`
- `reading_comprehension_view.dart:86-101`
- `listening_comprehension_view.dart:27-70`
- `writing_task_view.dart:129-188`

A flex child cannot take remaining height when its vertical constraint is unbounded. Flutter raises the familiar non-zero-flex/unbounded-height `RenderFlex` assertion; release rendering is likewise unreliable. The dispatcher test misses this because `exercise_widget_test.dart:43-73` mounts each widget in a bounded `Scaffold`, not through the production player.

**Required fix**

- Make the lesson player own scrolling, and make exercise roots intrinsically sized; or provide a bounded viewport intentionally and remove nested flex assumptions.
- Add a parameterized integration/widget test that loads every one of the 726 shipped exercises through the production lesson shell at phone, tablet, and large-text sizes.
- Fail the content build on any render exception.

**Acceptance test:** every shipped exercise can render, accept an answer, show feedback, advance, and restore after navigation at 320 px width and 2× text scale in light and dark themes.

### P0-2 — Curriculum JSON and widget contracts have diverged

**Status:** Confirmed, deterministic

**Impact:** crashes, impossible exercises, or wrong answers despite valid JSON.

The runtime consumes dynamic maps with unchecked casts. There is no discriminated, versioned schema shared by authoring, publication, and rendering. Directly verified mismatches include:

| Type | Asset reality | Renderer expectation | Affected items |
|---|---|---|---:|
| Declension table | `noun`, `nominative`, `accusative`, scalar top-level `answer_key` | `cases` list, map `answer_key`, `word` | 4; IDs 6002, 6005, 6007, 6009 |
| Word order, new shape | `shuffled`/`scrambled`; `correct_order` is a word list | `words`; `correct_order` is an integer list | 8; IDs 13012, 13022, 22009, 22022, 25010, 26010, 26023, 31015 |
| Word order, mixed-language | Czech and English tokens separated by `—`; answer points past truncated Czech list | all referenced indices remain valid | ID 9011 |
| Word order, distractor sentinel | `correct_order` includes `-1` | every value is used as a list index | IDs 24011, 24023 |
| Dialogue, alternate shape | `text_cz`, `blank`, per-line accepted answers | `text`, `___`, top-level accepted answers | 3; IDs 23019, 24013, 27023 |
| Dialogue, no blank marker | lines render but no input is created | one or more `___` markers | 16 more dialogues |

Only 17 of 36 dialogue assets are compatible. The other 16 blankless dialogues expose no input and therefore always fail; the remaining three null-cast. `dialogue_view.dart:38-65,101-133` demonstrates the hard-coded contract.

There are content errors even within schema-compatible data. ID 10017's order generates “Večer večeřím vracím domů a se” while its explanation gives “Večer se vracím domů a večeřím.” ID 13012 teaches the unnatural “Máš rád dívat se na filmy?” rather than, for example, “Díváš se rád na filmy?” or “Rád se díváš na filmy?”

**Required fix**

- Define a versioned JSON Schema or typed authoring model for each exercise variant.
- Generate Dart discriminated models and validators; reject unknown/missing fields before insertion.
- Validate reference ranges, blank/answer cardinality, locale, minimum/maximum lengths, and answer constructibility.
- Render every published item in CI and run a scripted answer path.
- Migrate existing assets once; do not add more renderer fallbacks that make the contract ambiguous.

**Acceptance test:** publication is impossible unless every item passes schema, semantic, render, interaction, and answer-key checks.

### P0-3 — In-lesson pronunciation is functionally broken

**Status:** Confirmed, deterministic

**Affected content:** all 47 pronunciation exercises.

`PronunciationView` starts recording at `pronunciation_view.dart:32-50` without calling `setExpectedText(targetText)`. The shared provider begins with an empty expected string at `pronunciation_providers.dart:52-70`, so a lesson assesses an empty target or a target left by another screen. The provider's `copyWith` cannot clear a previous result (`pronunciation_providers.dart:26-43`), and the view rehydrates that stale result during build (`pronunciation_view.dart:82-87`).

The UI explicitly lets the learner tap to stop, but both assessor paths are fixed-duration flows. In the Whisper path (`stt_providers.dart:107-162`), manual stop changes recorder state, while the original future still waits ten seconds and later returns an empty result. `isProcessing` is never set true, so the promised “Analyzing” state never appears. A second recording can start before the first future wakes; the stale future can then stop or score the second recording and overwrite newer state. The native path has the same conceptual stop problem at `stt_providers.dart:315-355`.

Recorder/transcription cleanup is not protected by `finally` (`stt_providers.dart:111-151`; `audio_recorder.dart:42-54,86-95`). A transcription or parse exception can leave a temporary WAV behind, and a later path can overwrite the only tracked filename without removing the prior file.

Skipping calls the lesson callback with `isCorrect: true` (`pronunciation_view.dart:206-221`), inflating accuracy, completion, and XP. Pronunciation also awards XP independently per attempt (`pronunciation_providers.dart:81-83`), enabling repeated reward without demonstrated learning.

**Required fix**

- Make assessment state exercise-scoped and pass the target as an immutable argument, not shared mutable state.
- Implement an explicit state machine: idle → recording → stopping → processing → result/error, with a unique attempt ID and cancellation of stale completions.
- Treat skip as skipped/unsupported evidence, never correct.
- Award progress once, idempotently, after a valid result.
- Add tests for manual stop, rapid retry, navigation during recording, denial of microphone permission, offline mode, cloud failure, and stale-future completion.

### P0-4 — The preferred cloud transcription path is unavailable and broken

**Status:** Confirmed in code and in the linked Supabase project as of 22 July 2026.

The client constructs Whisper whenever a Supabase client object exists (`stt_providers.dart:21`; `whisper_service.dart:74`) and then invokes `whisper-proxy` (`whisper_service.dart:103`). In the linked project, only `deepseek-proxy` and `account-data` were deployed; `whisper-proxy` was absent and the secret-name inventory had no `OPENAI_API_KEY`. Nevertheless, client availability is reported as true. A failed cloud invocation is not caught and routed to native recognition.

The function would still be broken if deployed:

- `supabase/functions/whisper-proxy/index.ts:24` uses `const prompt = (body.prompt as string) | undefined;`. This is bitwise OR and converts the intended Czech prompt to numeric zero.
- `@ts-nocheck` at line 1 suppresses the type error.
- It requests `verbose_json` but not `timestamp_granularities[]=word`.
- It reads `segments[].words` and invents a `probability` property. The current OpenAI transcription contract returns requested word timestamps in top-level `words` entries containing word/start/end, not a pronunciation probability.
- The client defaults missing probabilities to zero and then uses them to penalize a pronunciation score.
- It imports an unused, unpinned `esm.sh` dependency and has no lockfile.
- The client reads and base64-encodes the entire WAV in memory, with no client timeout, cancellation, or size cap.

The official [OpenAI transcription API](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create) documents the word-timestamp request and response. Even correctly parsed ASR timestamps would not be acoustic pronunciation scores.

**Required fix:** until a validated feature exists, deliberately disable cloud speech and use a clearly labeled transcription-match fallback. If cloud speech is retained, expose server capability/health, add timeout/cancellation/size limits, pin and type-check the function, add deployment smoke tests, and fall back safely.

### P0-5 — The speech endpoint is a cost, abuse, and privacy risk if enabled

**Status:** Confirmed code risk; endpoint is currently absent from the linked project.

`whisper-proxy` has no explicit user lookup, per-user audio allowance, burst limit, project daily budget, decoded byte/duration limit, language/model allowlist, request timeout, or concurrency control. `verify_jwt = true` is helpful but not sufficient: the app automatically creates anonymous users, and anonymous users carry the authenticated role. Any valid anonymous session could consume paid OpenAI work.

The endpoint also accepts a whole arbitrary base64 body, decodes it in memory, and can return upstream detail. The existing `deepseek-proxy` is materially stronger because it validates auth and applies user/project rate limits and a timeout, though its quota ordering has its own issue described later.

The trust issue is equally important. `PRIVACY.md:34-55` and the in-app disclosure at `settings_screen.dart:372-383` say text goes to DeepSeek and speech uses OS/Apple/Google services. The default implementation now records raw audio and intends to send it through Supabase to OpenAI, without an OpenAI/audio-cloud disclosure or just-in-time consent.

**Required fix:** update privacy text and consent before any deployment; explicitly authenticate; cap encoded/decoded size and audio duration; reserve quota atomically; impose user, project, burst, concurrency, and spend ceilings; add upstream timeout/cancellation; restrict parameters; and monitor anonymous-account abuse. See Supabase's current guidance on [anonymous authentication](https://supabase.com/docs/guides/auth/auth-anonymous) and [Edge Function authentication](https://supabase.com/docs/guides/functions/auth).

### P0-6 — All six mock exams have crashing or ignored tasks

**Status:** Confirmed, deterministic.

`mock_exam_screen.dart:661-663` force-casts `question['target_text'] as String`. Eleven of 17 speaking questions do not have this field because they are monologue, picture-description, or role-play tasks. Every shipped exam contains at least one missing target and will eventually reach this failure.

Five of six exams contain two writing tasks, but:

- one global `_writingScore` and evaluation state are shared by the section (`mock_exam_screen.dart:41-48`);
- `_writingSectionText()` reads question zero only (`:205-211`);
- the prompt helper likewise uses only the first task (`:214-220`);
- the text field has no controller/key/restored initial value (`:550-579`), so visible text can leak or disappear across questions;
- task two is not independently evaluated and never contributes evidence.

Speaking has the same single-global-score flaw: one read-aloud transcript-similarity result stands in for all speaking tasks and all 40 speaking points. A pending AI evaluation or recording can race section navigation or timer completion. If no LLM is available, the fake evaluator gives any non-empty writing response a canned 70 (`llm_providers.dart:12-47`) that can count toward a pass. Empty or failed attempts still receive 50 XP (`mock_exam_screen.dart:171-195`).

**Required fix:** temporarily relabel these as informal practice, not a mock certification exam. Give every task stable state, controller, evidence, analytic criteria, raw points, and failure handling. Score all tasks and each subtest independently. Do not let a mock fallback produce a passing credential signal. Persist exam ID, version, answers, timings, hints, raw points, feedback, and evaluator provenance.

### P0-7 — Exam branding, blueprint, and pass rules are materially inaccurate

**Status:** Confirmed learning/trust issue.

The UI labels the experience “CCE,” while the A2 metadata also invokes permanent residence and an April 2026 change. The app uses reading 40, writing 25, listening 40, and speaking 15 minutes, then permits written-section compensation and requires 60% for combined written work plus 60% speaking (`exam_grader.dart:51-70,121-136`).

That does not match the current official CCE A2 blueprint: reading 40 minutes, listening 25–30, writing 40, speaking 12–15, with at least 60% in **each subtest**, as documented by [Charles University CCE](https://ujop.cuni.cz/UJOPEN-70.html?ujopcmsid=12%3Aczech-language-certificate-exam-cce). Nor does it match the distinct Czech permanent-residence A2 examination, whose April 2026 update uses a 70-point written part (reading 25, listening 25, writing 20) and a 40-point speaking part, with a different task blueprint; see the official [A2 permanent-residence exam change](https://cestina-pro-cizince.cz/trvaly-pobyt/mn/zmena-zkousky-a2/).

`a1_units.json:207-220` describes an “official permanent residence A1 exam,” but the present residence requirement is A2. Mixing two official products can cause a learner to prepare for the wrong timing, task types, and pass rule.

**Required fix:** decide which exam is supported. Version each blueprint with source date and jurisdiction, reproduce its task/point/timing/pass specification exactly, show a clear “practice, not official result” disclaimer, and require specialist sign-off before claiming simulation fidelity.

### P0-8 — All six open speaking lessons are effectively impossible to pass

**Status:** Confirmed, deterministic.

Every bundled `speaking_task` omits `expected_phrases`. `speaking_task_view.dart:44-48` falls back to the top-level `answerKey`, but those answer keys are English placeholders such as “Full spoken response…”. Czech ASR output is therefore compared with English metadata at `:86-111`, driving normal answers toward zero.

The renderer also ignores shipped `evaluation_criteria`, guiding questions, and minimum duration. Tasks request roughly 45–90 seconds, while recording is capped at about 15 seconds. The score is token/phrase overlap rather than task accomplishment, interaction, comprehensibility, range, or repair.

**Required fix:** do not auto-fail these tasks. In the short term, use learner recording, replay, an analytic self-checklist, and model language without a fabricated score. In the longer term, evaluate task completion against an explicit rubric and calibrated human judgments.

### P0-9 — Account switching and deletion can lose data or fail to erase it

**Status:** Confirmed; some branches require failure/offline conditions.

`account_service.dart:23-33` authenticates, clears local learner data, and only then installs the new session. If installation fails, the previous local data is already gone. The deletion path clears the local database before invoking a backend-dependent anonymous-session operation (`account_service.dart:71-75`), so an offline/unconfigured flow can destructively clear and still report failure.

`database.dart:92-107` deletes all SRS rows. `ContentSeeder.hasUsableLocalContent()` ignores SRS (`content_seeder.dart:41-63`), so startup can decide that content is healthy and never rebuild the review deck. SharedPreferences, secure device ID, audio caches, and in-memory providers are neither comprehensively cleared nor exported even though the privacy policy describes local learner data. Provider caches after a switch/delete can expose the prior account's chat or progress in memory.

**Required fix:** use a staged, recoverable account transition. Install/validate the new authenticated state before committing a scoped data switch; keep the old database until success or explicit confirmation. Define a single inventory for export and deletion, including database, preferences, secure storage, audio/cache files, queued sync, and in-memory state. Test offline delete, install failure, account A→B→A, and clean reseeding.

### P0-10 — Device-clock conflict resolution can permanently miss progress

**Status:** Confirmed architecture defect; reproduced through code/path analysis and linked query-plan inspection.

`sync_service.dart:79` sends device-authored timestamps. The LWW trigger in `20260720070007_establish_backend_security_baseline.sql:144` rejects an older/equal-losing write by returning the existing row. Pulling and cursor persistence depend solely on `(updated_at, sync_id)` (`sync_service.dart:43-61,175`). A rejected upsert is still acknowledged as success at `:133` without reconciling the canonical winner.

Consequences:

- a future-skewed clock can move a device cursor ahead of later legitimate changes;
- a slow-clock insertion can be born behind another device's cursor and never be seen;
- a stale upload can be silently rejected and removed from the outbox;
- legitimate concurrent attempts or whole gamification snapshots can overwrite each other.

Custom flashcards amplify this: `vocabulary_dao.dart:43` allocates `MAX(id)+1` starting at 900001. Two devices can assign the same ID to unrelated cards. Custom cards themselves are local-only, while the SRS row syncs the numeric ID as its content key; another device lacks the referenced flashcard and can fail its foreign key or poison the cursor boundary.

**Required fix:** use a server-owned monotonic change revision for pulls, stable UUIDs for user-created content, immutable idempotent learning events, and canonical server responses before acknowledging the outbox. Sync custom content before dependent schedules, quarantine a bad row rather than blocking a stream, and add clock-skew/concurrent-device tests.

---

## 5. P1 correctness and learning-validity issues

### P1-1 — Review rescheduling uses stale card state

`ReviewSessionNotifier.rateCard` advances synchronously and fire-and-forgets persistence (`review_providers.dart:274-318`). On “Again,” it appends the original `SessionCard`, not `result.card` (`:298-303`). When that item reappears, the scheduler starts from pre-rating repetitions, ease, interval, and lapse state. A second database write may race the first, so the final schedule can be wrong.

The daily new-card budget is consumed when the session is loaded (`:237-267`), not when the learner first rates a card. Opening and abandoning review can hide new cards for the rest of the day. The intended empty-due branch in the screen is unreachable because an empty plan is immediately marked complete.

**Fix:** make rating awaited and idempotent; update UI from the committed result; requeue the newly scheduled state; consume a daily slot on first committed review; add rapid-tap, crash/restart, and repeated-Again tests.

### P1-2 — Completion and mastery are not the same, but the app treats them as equivalent

Every finished lesson is persisted with `isCompleted = true` regardless of accuracy (`progress_dao.dart:18-55`). Both live and snapshot unit scores average only the completed rows (`drift_progress_repository.dart:13-35,54-70`), not all required lessons. One perfect lesson can make an otherwise untouched unit appear 100% mastered.

`curriculum_tracker.dart:3-57` then treats a 0.60 unit score and more than 80% of units plus an exam pass as A1/A2 attainment. `stats_screen.dart:112-178` says “CEFR level” and “Reached A1/A2.” CEFR proficiency is an uneven, evidence-based profile across reception, interaction, production, writing, and mediation; the [CEFR Companion Volume](https://rm.coe.int/common-european-framework-of-reference-for-languages-learning-teaching/16809ea0d4) also cautions that descriptors are not automatically assessment scales.

**Fix:** distinguish exposure, completion, first-attempt accuracy, supported mastery, delayed retention, and transfer. Replace the single badge with a skill evidence profile such as “estimated A2 reading practice evidence,” with confidence and date. Require coverage and recent unscaffolded evidence for every claimed skill.

### P1-3 — Lesson answer accounting is non-idempotent and feedback leaks

`lesson_providers.dart:200-237` mutates attempts, correctness, hearts, and progress every time `onExerciseAnswered` is called; it has no attempt/exercise token. Matching, listening, writing, and speaking expose retry or re-record controls after a callback, so one visible item can affect counters several times.

The lesson state's `copyWith` uses `??` for nullable feedback fields (`lesson_providers.dart:78-123`), so explanation, correct answer, or grammar rule cannot be explicitly cleared and may leak into the next exercise. Wrong items are queued for one retry, but a failed retry is not queued again or separately reported. Session accuracy mixes initial attempts with remediation, hiding first-pass performance.

**Fix:** model immutable attempts with IDs and phases; accept one outcome per phase; explicitly clear nullable state; report first-pass, after-feedback, and delayed-retention metrics separately.

### P1-4 — Completion, unlocking, and XP can lie to the learner

The UI enters completion before persistence succeeds and then launches persistence/gamification work without awaiting it (`lesson_providers.dart:304-336`). A database failure can leave a learner seeing completion and rewards that do not survive restart. Curriculum unlocking uses completion IDs (`curriculum_providers.dart:60-89`), so a skipped or failed lesson unlocks the next unit.

The completion screen sums exercise `xp_reward` values (`lesson_player_screen.dart:613-617`), while persisted gamification awards a fixed 10/15/20 by lesson accuracy (`gamification_providers.dart:265-284`; `gamification_engine.dart:23-27`). Pronunciation and exam paths add further activity-based XP. A zero-accuracy activity can still receive points.

The exam-preparation lesson timer at `lesson_player_screen.dart:651-723` is visual only. Expiry changes its label but does not notify the session, lock answers, submit, or record overtime, so a learner can continue indefinitely while believing the activity is timed.

**Fix:** commit a completion transaction before success UI, make reward grants idempotent with ledger IDs, show the value actually persisted, and unlock on explicit prerequisite evidence—not mere screen completion. Treat XP/streak as engagement, never mastery.

### P1-5 — The content-release system promises integrity it does not implement

The migration comment in `20260720130000_add_content_release_manifests.sql:3-18` promises versioned pack references, checksums, atomic releases, and rollback. `curriculum_pack_source.dart:110-152` fetches the latest manifest but ignores `packRefs`, per-pack versions/checksums, aggregate `contentChecksum`, and `previousRelease`; it fetches every published pack and selects only `pack_key,content`. The linked release currently references all 71 packs, but its declared aggregate checksum did not match documented/obvious SHA-256 aggregations.

`curriculum_packs` stores one mutable row per pack key, so older manifests cannot reliably name immutable old data. `ContentSeeder._installCurrentSnapshot` only upserts (`content_seeder.dart:75-87` and DAO `insertAllOnConflictUpdate` methods), so withdrawn lessons/cards remain forever. Startup downloads and reinstalls the remote snapshot on every launch without a local version comparison, and cached curriculum providers are not invalidated after refresh.

**Fix:** publish immutable `(pack_key, version)` rows; normalize release items with foreign keys; fetch exactly the manifest; verify every hash and aggregate before a single local transaction; persist active version; stage and atomically switch snapshots; reconcile removed managed content while preserving learner-history references; retain one verified rollback release.

### P1-6 — Corpus errors can teach durable mistakes

Examples directly verified:

- `unit31_lesson01.json:105-110` gives first-person future of *jít* as “půj” instead of **půjdu**.
- The same file marks a correction while later saying both forms can work (`:271`) and contains questionable person/register and lexical choices around `:305` and `:325`.
- `unit01_lesson01.json:15-43` says `ř` has no equivalent in any other language and that stress is always first-syllable without exceptions. Both are overstatements.
- Dormant `cultural_notes.json:6-20` says Czech is pronounced exactly as written, repeats absolute stress language, and claims “dum = stupidity.”
- `a2_vocabulary.json:8483-8503` and other entries contain the literal string `"null"` as gender; the UI displays it because it checks only actual null.
- `a2_vocabulary.json:4227-4235` translates Czech *ambulance* as English “ambulance,” though its example uses *sanitu*. Another entry at `:8858-8866` correctly gives outpatient clinic/surgery. This is a consequential medical false friend.
- `a2_vocabulary.json:9111-9119` gives *děkan* as `dɲɛkan`; Charles University's Czech phonetics materials use that word to illustrate the palatal stop [ɟ].
- Multiple IPA entries use English-style `oʊ`, inconsistent with the referenced Czech inventory.

Exact case-normalized analysis finds 272 duplicated Czech spellings covering 616 cards, leaving 344 excess records (23.6% of the 1,458-card corpus). In 164 duplicate groups, IPA strings disagree. Some duplicates may encode legitimate senses, but the current model does not reliably distinguish lemma, sense, register, morphology, or pronunciation convention.

Use the [Charles University Institute of Phonetics Czech overview](https://fonetika.ff.cuni.cz/en/czech-phonetics/) and [Czech IPA guide](https://fonetika.ff.cuni.cz/o-fonetice/foneticka-transkripce/transkripce-cj-ipa/) as authoritative starting points, then conduct a two-reviewer corpus audit.

### P1-7 — Open writing is scored as resemblance to one sample

`writing_task_view.dart:57-84` uses roughly 50% unique-token overlap with one sample, so a valid paraphrase can fail and a keyword list can pass. Shipped `required_elements`, `evaluation_criteria`, and maximum-word metadata are ignored. The getter ignores `sample_answer_cz` (`:53-55`). Two bundled references are shorter than their own minimum request: ID 28018 asks at least 40 words but its sample has 38; ID 29016 asks 50 but its sample has 47 under simple whitespace counting.

**Fix:** make the learner draft against a transparent analytic rubric—task fulfillment, required content, organization, range, accuracy, register, and intelligibility of meaning. Provide criterion-specific feedback, require revision, and then use a new transfer prompt. If no trustworthy evaluator is available, do not fabricate a pass; support self/peer review and save the draft.

### P1-8 — “Listening comprehension” often measures reading

`listening_comprehension_view.dart:41` reveals the full transcript and tells the learner to read it because audio is unavailable. The activity therefore cannot provide listening evidence. Transcript-first presentation also removes desirable effort and can create text dependence.

**Fix:** ship or generate vetted audio with native speaker QA. Use a gist-first listen, then detail question, optional replay/slower speed, and only then a transcript/gloss. Track whether support was used. Include multiple voices and normal connected speech.

### P1-9 — Pronunciation scoring is scientifically overclaimed

`pronunciation_scorer.dart:12-46,189-245` is word/character edit distance over an ASR transcript. “Problem sounds” are inferred by finding Czech letters inside low-similarity expected words and returning canned tips. It performs no acoustic phone, vowel-length, timing, stress-group, rhythm, or intelligibility analysis. Prompting ASR with the expected phrase biases recognition toward the answer; word confidence, even when available, is not pronunciation quality.

Research on general-purpose ASR cautions against treating recognition success as pronunciation assessment because results depend on lexical context, speaker, frequency, and system behavior; see [Cámara-Arenas et al. (2023)](https://www.lltjournal.org/item/10125-73512/) and the [Findings of EMNLP 2023 review](https://aclanthology.org/2023.findings-emnlp.557/).

**Fix:** immediately rename the result “transcript match” or “recognizer understood this phrase.” For real pronunciation support, progress from perception contrasts to controlled production, phrase prosody, and spontaneous speech. Validate every automated score against blinded Czech listener intelligibility/comprehensibility judgments across L1s, devices, noise levels, and target structures.

### P1-10 — The SRS is useful but mislabeled and too recognition-dependent

`srs_scheduler.dart:11-82` accurately describes a simplified SM-2-style algorithm, but `srs_cards.dart:4-15` and UI comments call it FSRS. Hard and Good both produce a one-day first interval, scheduling is day-granular, and the implementation has not been calibrated on this learner population.

Production cards ask “How do you say it?” but require no overt response before reveal (`srs_review_screen.dart:326-369,515-611`). Self-rating can therefore reward familiarity rather than retrieval. Only isolated vocabulary is seeded into SRS (`content_seeder.dart:334-403`); the grammar-card type is unused.

**Fix:** label the scheduler honestly; require typed, spoken, or accessible self-declared retrieval effort before reveal; schedule contextual cloze, chunks, morphology, sentence construction, and recurring concept errors; log latency, hints, and correctness; then calibrate scheduling on delayed recall rather than copying an algorithm brand.

### P1-11 — Remote/account data correctness has additional high-impact gaps

- Account export uses one unpaginated `.select('*')` per table (`account-data/index.ts:54`). [Supabase documents](https://supabase.com/docs/reference/dart/select) a default response maximum of 1,000 rows, so an active SRS/review history can be silently truncated. Keyset-paginate and report source/export counts.
- Local SRS has no unique constraint matching its semantic natural key (`srs_cards.dart:5`). Seeder and pull can create duplicates, while a later `getSingle` path can fail. Add a unique index and atomic upsert.
- Whole-row LWW loses concurrent progress. Attempt counts are merged with `max`, not event union (`progress_dao.dart:141`), and gamification syncs complete snapshots (`gamification_dao.dart:29`). Use immutable idempotent events and a server-authoritative reward ledger.
- Current direct authenticated CRUD is owner-isolated but effectively unbounded in row count and loose JSON values. Constrain identifiers/payload size, prefer validated RPC mutations for important state, and monitor anonymous users.
- Remote default privileges for database owners remain broad. Existing objects were explicitly hardened, but a future migration that omits revocation can expose a new object. Set hardened default privileges and assert the catalog in CI.

### P1-12 — Backend readiness is mutable but not reactive

`sync_providers.dart:22-51` exposes a mutable backend object through a plain provider while initialization runs in the background (`main.dart:68`). `llm_providers.dart:12` and the speech provider snapshot availability before the object mutates; Riverpod has no state change to invalidate them. A launch race can permanently select a mock/native service or falsely select cloud availability for that provider lifetime.

**Fix:** model readiness, auth, capabilities, and client as reactive state or `FutureProvider`; make dependents watch/await it; distinguish configured, authenticated, healthy, quota-available, offline, and degraded states.

### P1-13 — DeepSeek admission accounting penalizes failures and other users

`deepseek-proxy/index.ts:83-115` consumes project burst capacity before checking daily user quota, and both are charged before the upstream request. A daily-blocked user can reduce shared capacity; timeouts and 502s consume a learner's allowance.

**Fix:** implement one atomic admission/reservation operation; reject per-user exhaustion before shared reservation; complete or refund according to explicit success semantics; add idempotency and a hard project daily spend ceiling.

### P1-14 — Exercise order is accidental

The local exercise table has no explicit sequence column (`exercises.dart:4`), and lesson retrieval has no `orderBy` (`curriculum_dao.dart:52`). Current integer IDs may happen to preserve author intent, but SQL row order is not guaranteed. A content update or query-plan change can reorder scaffolding and assessment.

**Fix:** add stable `position` and optional prerequisite/variant metadata, validate uniqueness/contiguity per lesson, and order explicitly.

### P1-15 — CI does not test the systems most likely to fail

CI runs Flutter analysis and unit/widget tests only. It has no:

- curriculum schema or semantic validator;
- all-assets production render/interaction test;
- coverage floor or changed-line coverage;
- dark/large-text/narrow-screen accessibility matrix;
- Supabase migration reset, pgTAP, advisor, or schema-diff step;
- Edge Function lint, type-check, unit test, or deployed smoke test;
- multi-device sync/clock-skew/property test;
- release manifest/hash/rollback test;
- Android/iOS/desktop build matrix;
- dependency/security/license audit.

The latest Whisper feature has zero direct test coverage in `stt_providers.dart`, `whisper_service.dart`, or `audio_recorder.dart`. The README still reports 72 tests, which is itself evidence that documentation is not tied to a generated quality report.

---

## 6. P2 experience, accessibility, and maintainability findings

### P2-1 — Core interactions are not accessible enough

No explicit production `Semantics`, focus traversal, keyboard shortcut, or keyboard-navigation implementation was found. Important controls are raw `GestureDetector`s, including matching choices, comprehension answers, error chips, pronunciation record, SRS reveal, and settings theme selection. Built-in controls elsewhere inherit some semantics, but these custom surfaces do not expose reliable roles, labels, selected/disabled state, or focus behavior.

Czech character keys are 36 dp (`exercise_shared.dart:61-77`) and chat TTS is constrained to 28 dp (`chat_screen.dart:384-401`), below a robust 48 dp touch target. Fixed rows/columns are likely to overflow at narrow width or increased text scale.

Dark theme uses foreground `#F1EFE9` on hard-coded `grey50`, `green50`, `red50`, and `amber50` surfaces in several exercise/reference views; computed contrast is about 1.01–1.10:1. Light faint text `#85818E` on `#F6F4EF` is about 3.46:1, below 4.5:1 for normal text.

**Fix:** use semantic `Button`/`InkWell` controls, 48 dp targets, explicit labels/state, logical focus traversal and shortcuts, `ColorScheme` tokens only, responsive `Wrap`/`LayoutBuilder`, and automated semantics/contrast tests at 320 px and 2× text.

### P2-2 — Navigation contains broken and misleading states

- `/settings` is in the shell, but unknown destinations default to Home selection (`app_scaffold.dart:10-16,73-82`), so Settings marks Home active.
- Lesson routing uses unguarded `int.parse` (`app_router.dart:69-73`), so malformed deep links throw. Invalid exam levels silently select A1.
- Curriculum sends grammar navigation as `?unit=` (`curriculum_screen.dart:289-300`), while the router reads only `rule` (`app_router.dart:91-97`).
- There is no onboarding redirect guard; incomplete users can deep-link around it and completed users can return.
- The plain `ShellRoute` plus `context.go` can discard tab navigation/scroll state; `StatefulShellRoute.indexedStack` would make preservation explicit.
- The A1/A2 chips look like filters but are decorative, and curriculum “progress” reports unlocked rather than completed/mastered units.

### P2-3 — Loading failures are often disguised as empty success

Lesson and review initial loads lack useful error states; exceptions can leave an indefinite spinner. Several provider errors become plausible empty values such as “0 due,” “browse curriculum,” or “no lessons.” This prevents recovery and makes data loss look like completion.

Fill-blank has two additional interaction traps: it does not expose the existing Czech-character helper, and submitting from the first field of a multi-blank item can grade and disable every remaining field before they are completed. These should be covered by real multi-field asset tests, keyboard traversal, and clear per-field validation.

**Fix:** use explicit loading/empty/error/offline/stale states with retry and diagnostics. Never collapse a repository exception into a valid zero without recording and surfacing degradation.

### P2-4 — Settings and Home disagree about the daily goal

The settings screen writes the daily goal only to preference-backed settings (`settings_screen.dart:134-151`), while Home reads the gamification target (`home_screen.dart:85-90`). They diverge after a change. Home also paints 6% for a true zero (`home_screen.dart:280`), making progress visually nontruthful.

Use one source of truth and display zero as zero. If a minimum visual affordance is needed, separate it from the quantitative progress indicator.

### P2-5 — Onboarding does not place or route the learner

Onboarding asks learners to self-select a level and explicitly says lessons still begin at Unit 1 (`onboarding_screen.dart:299-330`). The selection only changes the AI tutor (`chat_providers.dart:113-136`); curriculum unlock remains linear. An experienced A1/A2 learner has no test-out path and poor time-to-value.

**Fix:** add a short adaptive diagnostic using receptive and constructed responses, listening, and optional speaking. Let users test out provisionally, then confirm or revise placement through early delayed evidence.

### P2-6 — The vocabulary load is large and decontextualized

Across 50 vocabulary-bearing lessons, the mean is 29.2 new records and two lessons present 60 before practice. There is no universal ideal batch size, but this is a poor default for retrieval and cognitive load. The 1,458 records also contain 23.6% excess duplicate entries under exact case-normalized spelling.

**Fix:** teach smaller contextual sets of high-utility chunks inside a story/task, interleave old material, and adapt batch size using delayed production per learning minute—not same-session completion.

### P2-7 — Valuable content is bundled but dormant

`reading_passages.json`, `cultural_notes.json`, and `srs_starter_deck.json` have no runtime references. Seventeen grammar SVG infographics are bundled without `flutter_svg` or code references. The 500-card starter deck contains contextual cloze material, but runtime seeds 1,458 mostly isolated vocabulary cards instead. These packs are also outside the required content-release inventory.

After linguistic QA, activate graded reading/listening and contextual review rather than adding more isolated drills. Remove truly unused assets from the binary or version them through the same release pipeline.

### P2-8 — Hearts default to punitive pressure

Comments describe hearts as opt-in pressure (`settings_providers.dart:20-22`), but the default is true (`:29-36,103`). Productive language practice requires risk-taking; mistakes are the data needed for adaptation. Blocking practice after errors can optimize avoidance rather than learning.

Make hearts opt-in or cosmetic, never block remediation/application, and evaluate them against voluntary production, later retention, and return—not only session length.

### P2-9 — Platform/account edges need hardening

- Android backups are enabled, while exclusions cover FlutterSecureStorage files but may not cover Supabase Flutter's default SharedPreferences auth token storage. Validate actual backup/restore and move auth to secure storage or exclude the real file.
- Password-recovery/email-verification callbacks use `ceskinapro://auth-callback`, but macOS and Windows do not register the scheme despite desktop support being advertised.
- Chat saves the learner message outside its `try`; a local database error can leave typing active indefinitely.
- Full conversation history is sent on every request despite a policy reference to “recent” context, increasing exposure, latency, and cost.
- Chat/mock-exam voice recognition is not consistently stopped on disposal.
- Adding chat vocabulary and its SRS row is not transactional.

### P2-10 — Maintainability and dependency risk are accumulating

Several screens are very large: mock exam about 1,056 lines, review 904, lesson 887, chat 616, stats 568, and settings 557. They mix orchestration, persistence timing, layout, and grading, making precisely the discovered state bugs harder to isolate.

Direct packages with newer major versions include `connectivity_plus`, `riverpod`, `flutter_secure_storage`, `go_router`, `just_audio`, `record`, and `share_plus`. `sqlite3_flutter_libs` is marked EOL upstream and transitive `js` is discontinued. These are not bugs by themselves; they require a tested upgrade plan. The root README, architecture counts, speech description, and release checklist are stale.

Refactor by behavior boundary—task state, recorder state, evaluator state, persistence transaction, and view—then add contract tests before dependency upgrades.

---

## 7. Learning-science assessment

### 7.1 There is no single “best method”

The strongest evidence does not support one branded method. Effective language learning combines:

- spaced practice over time;
- effortful retrieval before feedback;
- comprehensible, meaning-focused input;
- meaningful output and interaction;
- brief, targeted focus on form;
- corrective feedback and self-repair;
- varied practice followed by less-scaffolded transfer;
- enough fluency work that known language becomes fast and usable.

This aligns well with Paul Nation's “four strands”: roughly balanced meaning-focused input, meaning-focused output, language-focused learning, and fluency development. See Nation's [What Should Every EFL Teacher Know?](https://www.wgtn.ac.nz/lals/resources/paul-nations-resources/paul-nations-publications/publications/documents/What-Should-Every-ESL-Teacher-Know-13-Feb-2013.pdf).

### 7.2 What the evidence says

| Evidence strand | Research signal | Product implication |
|---|---|---|
| Distributed practice | Cepeda et al.'s broad review covered 317 experiments/839 assessments; L2-specific synthesis also finds meaningful delayed benefits and an interaction with retention interval. [Cepeda et al. (2006)](https://pubmed.ncbi.nlm.nih.gov/16719566/); [Kim & Webb (2022)](https://doi.org/10.1111/lang.12479) | Schedule retrieval over increasing intervals; evaluate after 7 and 30 days, not only today. |
| Practice testing/retrieval | Meta-analysis supports testing effects across many conditions. [Rowland (2014)](https://pubmed.ncbi.nlm.nih.gov/25150680/) | Require an answer before reveal; favor cued recall/production over recognition. |
| Corrective feedback | Meta-analyses find durable benefits, with effect depending on feedback and context. [Li (2010)](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1467-9922.2010.00561.x); [Lyster & Saito (2010)](https://doi.org/10.1017/S0272263109990520) | Use a feedback ladder that first prompts self-repair, then explains, retries, spaces, and transfers. |
| Explicit focus on form | Focused instruction can strongly improve targeted measures, but transfer must be tested separately. [Norris & Ortega (2000)](https://onlinelibrary.wiley.com/doi/abs/10.1111/0023-8333.00136) | Keep concise grammar explanations; immediately apply them in meaningful tasks. |
| Task-based instruction | Broad synthesis reports positive effects but substantial implementation variation. [Bryfonski & McKay (2019)](https://eric.ed.gov/?id=EJ1225836) | Add information gaps and real outcomes, not merely dialogue blanks labelled as conversation. |
| Extensive reading | Meta-analysis finds small-to-moderate gains, stronger when integrated and supported. [Jeon & Day (2016)](https://files.eric.ed.gov/fulltext/EJ1117026.pdf) | Activate graded readers with choice, glosses, and follow-up retrieval. |
| Captioned/multimedia input | Reviews find captions and multimedia glosses can support comprehension/vocabulary when scaffolds are designed well. [Montero Perez et al. (2013)](https://doi.org/10.1016/j.system.2013.07.013); [multimedia-gloss meta-meta-analysis](https://pubmed.ncbi.nlm.nih.gov/38870686/) | Reveal transcript/gloss after initial listening and track scaffold dependence. |
| Pronunciation instruction | Focused segmental and suprasegmental instruction can help, but monitored practice is not identical to spontaneous intelligibility. [Saito & Plonsky](https://kazuyasaito.net/LL2019.pdf) | Teach perception, controlled production, prosody, then spontaneous speech; validate with listeners. |
| Gamification | Effects are design- and outcome-dependent. [Sailer & Homner (2020)](https://link.springer.com/article/10.1007/s10648-019-09498-w) | Keep XP/streaks subordinate to retention and transfer; test for avoidance and inequity. |

### 7.3 Current exercise balance predicts limited transfer

Of 726 exercises:

| Category | Count | Share |
|---|---:|---:|
| Selected response | 276 | 38.0% |
| Tightly constrained response/dialogue | 371 | 51.1% |
| Read-aloud pronunciation | 47 | 6.5% |
| Dedicated reading/listening comprehension | 20 | 2.8% |
| Open writing/speaking | 12 | 1.7% |

The curriculum has 29 introduction lessons, 29 practice lessons, two review lessons, and **zero application lessons**, even though application is a supported type. This balance can generate high same-session accuracy without showing that the learner can understand a new speaker, formulate a message, repair misunderstanding, choose register, or complete a real task.

### 7.4 The target should be retained communicative ability

The Council of Europe's [CEFR Companion Volume](https://www.coe.int/en/web/common-european-framework-reference-languages/cefr-companion-volume-and-its-language-versions) emphasizes learners as social agents, action-oriented tasks, interaction, mediation, and plurilingual profiles. CEFR is a descriptive framework, not an instructional recipe and not permission to collapse all evidence into one level number.

For Czechify, the product objective should be:

> Help a learner complete personally relevant Czech tasks with decreasing support, increasing speed, and durable success—and show exactly what evidence supports that conclusion.

---

## 8. Recommended learning architecture

### 8.1 A better lesson loop

Every core lesson should culminate in a real outcome and follow a loop like this:

1. **Comprehensible model:** a short story, exchange, message, or audio with a reason to understand it.
2. **Notice:** draw attention to a small number of useful chunks, contrasts, or grammar features.
3. **Retrieve:** require cued recall/production before showing the answer.
4. **Use:** complete an information-gap or decision task in which Czech changes the outcome.
5. **Repair:** cue self-correction before showing an explanation/model.
6. **Vary:** retry a structurally similar but non-identical situation.
7. **Transfer later:** revisit days later with less scaffolding and a new speaker/context.

Examples:

- call a clinic, describe symptoms, understand a proposed time, and negotiate another;
- report a rental problem, clarify urgency, and agree on access;
- order food subject to an allergy and budget, ask a follow-up, and resolve an unavailable choice;
- use a map to ask/give directions, detect a misunderstanding, and repair it;
- interpret a school/work message and write an appropriate response in the right register.

A fixed missing word is practice for a component, not the final task.

### 8.2 A feedback ladder

Use the least help that enables learning:

1. signal where/what kind of problem occurred;
2. ask the learner to self-repair;
3. give a focused cue or contrast;
4. show a concise explanation and model;
5. retry immediately with a variant;
6. schedule an analogous item later;
7. test it inside a novel communicative task.

Store the underlying error concept—case after preposition, gender agreement, aspect, word order, vowel length, register, communicative function—not just “question 7 wrong.” This creates an actionable learner model.

### 8.3 A skill evidence profile

Replace “Reached A2” with a dated profile such as:

| Skill | Evidence | Support | Recency | Confidence |
|---|---|---|---|---|
| Reading everyday notices | 8/10 novel tasks | no glossary | 3 days | moderate |
| Listening for appointments | 6/10 across 3 voices | one replay | 8 days | low–moderate |
| Spoken interaction: services | 4/6 goal completions | two hints | today | preliminary |
| Writing short requests | rubric 11/20 then 15/20 after revision | spellcheck off | 14 days | low |
| Mediation | not yet sampled | — | — | none |

Raise estimates only with breadth, delayed unscaffolded success, and stable evidence. Let learners see why the app recommends the next activity.

### 8.4 Placement and adaptive routing

Create a 10–15 minute diagnostic that samples:

- high-information vocabulary/grammar in context;
- listening across at least two voices;
- reading for gist/detail;
- short constructed responses;
- optional recorded speaking with cautious, non-certifying interpretation.

Use it to provisionally unlock units and choose review seeds. Re-estimate after early learning and permit manual adjustment. Do not force a capable A2 learner through Unit 1.

### 8.5 Vocabulary and SRS redesign

- Represent lemma + sense + part of speech + morphology + register + pronunciation source; merge accidental duplicates.
- Teach chunks and collocations in context, not only isolated translations.
- Require retrieval before reveal; support typed, spoken, or accessible self-report modes.
- Schedule concepts and productive variants, not merely card IDs.
- Interleave new and old material, but control interference among near-synonyms.
- Use latency, hint use, error recurrence, and delayed outcome to tune scheduling.
- Measure retained production per minute when testing 10/15/20-item contextual batches against current 29–60-item presentations.

### 8.6 Listening and reading

- Activate linguistically reviewed graded passages.
- Provide native-speaker or expertly reviewed Czech audio with multiple ages/voices and natural connected speech.
- Ask gist before detail.
- Delay transcript/translation; make glossary and slower replay optional scaffolds.
- Fade support and track its use.
- Offer topic choice and an extensive-reading path, with light comprehension and later retrieval rather than a quiz after every sentence.

### 8.7 Speaking, pronunciation, and writing

For speaking, distinguish:

- **spoken production:** monologue/message;
- **spoken interaction:** turn-taking, clarification, question formation, repair;
- **pronunciation/intelligibility:** whether a listener can understand, including vowel length and Czech-specific contrasts;
- **fluency:** speed/pausing on already-known language.

Do not reduce all four to transcript edit distance.

For pronunciation, use perception discrimination → controlled word/phrase → listen/notice/record/compare → phrase prosody → spontaneous task. Provide exemplar and learner waveform/audio replay, but avoid fake phoneme precision. Any automatic score must be calibrated against blinded Czech listeners.

For writing, use plan → draft → analytic feedback → revision → new transfer prompt. Score every task separately and preserve revision history so improvement is visible.

### 8.8 Motivation without corrupting mastery

- Award XP for useful activity, but label it as activity.
- Never let skip, canned AI scores, or zero-accuracy completion improve mastery.
- Make hearts optional and non-blocking during productive practice.
- Celebrate self-repair, persistence, delayed recall, and real task completion—not only streak preservation.
- Offer recovery plans after a missed day rather than punishing streak loss.

---

## 9. Recommended implementation roadmap

### Phase 0 — Release safety and truth (0–2 weeks)

**Goal:** no deterministic failures, data-loss traps, or unsupported public claims.

1. Fix the five unbounded-flex exercise roots and add production-composition tests for all assets.
2. Freeze content publication; introduce schemas; migrate declension, word order, and dialogue data; verify all 726 items.
3. Disable or repair lesson pronunciation. Default to native/local degradation until the backend is deployed, secured, consented, and smoke-tested.
4. Update privacy disclosure for any audio/cloud path.
5. Relabel mock exams as informal practice; eliminate speaking crashes; preserve/evaluate every task; remove canned passing scores.
6. Choose CCE versus permanent-residence exam and correct every date, task, timing, point, and pass rule.
7. Make account transitions staged/recoverable and deletion/export inventory-complete.
8. Fix sync cursor architecture before promoting multi-device reliability.
9. Correct known high-risk Czech, medical, grammar, and IPA errors; start dual-review corpus QA.

**Exit gate:** zero known schema/render/runtime failures; zero stale/fake scoring paths; privacy and exam claims signed off; account A→B→delete and two-device tests pass.

### Phase 1 — Correct evidence and persistence (2–6 weeks)

1. Add immutable attempt/review/reward IDs and awaited commits.
2. Correct SRS requeue and quota consumption; add natural-key uniqueness.
3. Replace completion-derived mastery with skill/component evidence and confidence.
4. Implement immutable, verified content releases with exact manifests and rollback.
5. Add reactive backend capability state and real fallback behavior.
6. Add explicit exercise ordering.
7. Establish CI gates described in section 11.
8. Fix accessibility fundamentals, theme contrast, error states, navigation parsing, and settings goal truth.

**Exit gate:** a crash/retry/duplicate tap cannot double-count; all visible progress/rewards survive restart; releases are verifiable and reversible; major flows work with screen reader, keyboard, large text, narrow screen, offline, and denied permissions.

### Phase 2 — Retained communication (6–12 weeks)

1. Add placement and test-out.
2. Create application lessons for the highest-value Czech tasks.
3. Build the concept-error taxonomy and feedback ladder.
4. Introduce response-required contextual SRS.
5. Activate reviewed graded reading and real listen-first audio.
6. Implement writing revision cycles and interactive speaking missions.
7. Replace “CEFR attained” with an evidence profile.

**Exit gate:** the product can demonstrate seven-day transfer on novel tasks, not merely higher same-session accuracy.

### Phase 3 — Validation and optimization (3–6 months)

1. Run blinded human validation of speaking/pronunciation and writing rubrics.
2. Calibrate adaptive scheduling on Czechify retention data.
3. Review official exam simulations with a current specialist and version them by blueprint.
4. Run controlled product experiments below.
5. Upgrade dependencies behind contract tests and extract large screen state machines.

**Exit gate:** key automated scores correlate acceptably with qualified human judgments; learning changes improve delayed outcomes without harmful accessibility or retention tradeoffs.

---

## 10. Product experiments worth running

Experiments should pre-register a learning outcome, a time horizon, and guardrails. Session completion alone is not a learning outcome.

| Experiment | Primary outcome | Guardrails |
|---|---|---|
| Current reveal/self-rate cards vs response-required contextual review | 7- and 30-day production in a novel sentence | review time, accessibility, abandonment |
| Current 29–60-word presentation vs smaller contextual batches | retained meanings and cued production per learning minute | lesson completion, perceived overload |
| Fixed dialogue blanks vs outcome-based information-gap task | blinded goal-completion, interaction, and repair rating on a new scenario | anxiety, latency, task dropout |
| Immediate full correction vs self-repair ladder | recurrence on unseen structurally similar items one week later | frustration, total time |
| Hearts on by default vs nonpunitive productive practice | voluntary production attempts and later retention | return rate, abuse, well-being |
| Generic ASR transcript score vs cautiously designed feature feedback | agreement with blinded Czech listener intelligibility/comprehensibility | L1/device/noise fairness, false confidence |
| Transcript visible vs effort-first/faded transcript | delayed listening comprehension across a new voice | accessibility and completion |
| Linear Unit 1 start vs provisional adaptive placement | time to first appropriately difficult success and 30-day retention | placement regret and override rate |

Use randomized assignment where ethical and practical. Segment by prior Czech knowledge, L1, device, age/accessibility needs, and learning goal. Do not deploy a globally optimized intervention that harms a subgroup.

---

## 11. Metrics and release-quality system

### 11.1 North-star learning metrics

Prioritize:

- seven- and 30-day unscaffolded task success;
- cued productive recall, not recognition only;
- listening transfer to a new voice;
- response latency/fluency on known material;
- hint/transcript/translation dependence;
- error recurrence by knowledge component;
- self-repair rate;
- communicative goal completion and repair;
- learning gain per active minute;
- calibration between automated and qualified human scores.

Report XP, streak, sessions, and content completed as engagement metrics only.

### 11.2 Content publication gates

Every release should require:

1. JSON Schema validation and typed decode.
2. Referential integrity: unit/lesson/rule/card IDs, order, answer cardinality, index bounds.
3. Semantic checks: answer constructibility, non-empty blanks, duration/word-count consistency, locale, duplicate/sense policy, IPA convention.
4. Automated render and interaction of every item through the production shell.
5. Native Czech linguistic review by one author and one independent reviewer, with adjudication.
6. Audio/IPA review by a phonetically competent reviewer.
7. Immutable release manifest, per-pack hash, aggregate hash, staging install, and rollback drill.

### 11.3 CI gates

Add parallel jobs for:

- Flutter analyze, format, unit/widget/integration tests, changed-line coverage, and all-assets render tests;
- 320/375/tablet widths, 1×/2× text, light/dark, screen-reader semantics snapshots, keyboard traversal;
- Android/iOS and advertised desktop builds;
- Deno lint/type-check/unit tests and deployed Edge smoke tests;
- `supabase db reset`, migrations, pgTAP/RLS/advisor/catalog assertions, and generated schema diff;
- multi-device sync property tests with clock skew, concurrency, retry, duplicate delivery, and bad-row quarantine;
- content release corruption, partial download, deletion, and rollback tests;
- dependency vulnerability/license/EOL report.

### 11.4 Observability without violating privacy

The global Flutter error handler currently suppresses unhandled async errors (`main.dart:24-39`) without an evident crash-reporting path. Add privacy-preserving diagnostics with explicit consent/retention, release/content version, exercise type/ID, state transition, and sanitized error—not learner audio/text by default. Measure failures per task, not only app crashes.

---

## 12. Detailed acceptance checklist

### Exercises

- [ ] All 726 shipped exercises decode into versioned typed models.
- [ ] All render through the production lesson shell without exceptions.
- [ ] Every exercise has at least one constructible accepted answer.
- [ ] Retry, skip, rapid tap, back navigation, and restoration are idempotent.
- [ ] First-attempt and after-feedback results are separate.
- [ ] Sequence is explicit and stable.

### Speech

- [ ] Capability reflects actual deployed, authenticated, healthy service state.
- [ ] Manual stop, cancellation, permission denial, timeout, offline, and fallback work.
- [ ] Attempt IDs prevent stale completion.
- [ ] Raw audio processing is disclosed and consented.
- [ ] Endpoint has auth, byte/duration/model limits, quotas, timeout, concurrency, and spend cap.
- [ ] UI says transcript match unless human-validated pronunciation measurement exists.

### Exams

- [ ] One official exam product and version is named unambiguously.
- [ ] Blueprint, timing, points, and per-subtest pass rules match primary sources.
- [ ] Every task owns its response, score, rubric, time, and evaluator provenance.
- [ ] Offline/mock evaluation cannot award a credible pass.
- [ ] Every bank completes without a missing-field or state-leak failure.
- [ ] A qualified current exam specialist signs off.

### Data/account

- [ ] Two-device events survive skew, concurrency, retry, and duplicate delivery.
- [ ] User-created cards use stable UUIDs and sync before schedules.
- [ ] Export is complete beyond 1,000 rows and includes counts.
- [ ] Delete covers DB, prefs, secure storage, caches, queues, and provider memory.
- [ ] Account switch is staged and recoverable.
- [ ] SRS is correctly reseeded or scoped after reset.

### Learning claims

- [ ] Completion, activity, supported performance, retention, and transfer are distinct.
- [ ] CEFR wording is probabilistic, skill-specific, dated, and evidence-backed.
- [ ] XP/streak never changes mastery.
- [ ] Skip and evaluator failure never count as correct.
- [ ] Automated open-response scores are validated or clearly non-certifying.

---

## 13. Research and authoritative sources

### Standards, Czech, and exams

- Council of Europe, [CEFR Companion Volume and language versions](https://www.coe.int/en/web/common-european-framework-reference-languages/cefr-companion-volume-and-its-language-versions).
- Council of Europe, [CEFR Companion Volume PDF](https://rm.coe.int/common-european-framework-of-reference-for-languages-learning-teaching/16809ea0d4).
- Charles University, [current Czech Language Certificate Exam (CCE) information](https://ujop.cuni.cz/UJOPEN-70.html?ujopcmsid=12%3Aczech-language-certificate-exam-cce).
- Czech Ministry/official exam site, [2026 permanent-residence A2 exam change](https://cestina-pro-cizince.cz/trvaly-pobyt/mn/zmena-zkousky-a2/).
- Charles University Institute of Phonetics, [Czech phonetics](https://fonetika.ff.cuni.cz/en/czech-phonetics/) and [Czech IPA transcription](https://fonetika.ff.cuni.cz/o-fonetice/foneticka-transkripce/transkripce-cj-ipa/).

### Learning science

- Cepeda et al. (2006), [Distributed practice in verbal recall tasks: a review and quantitative synthesis](https://pubmed.ncbi.nlm.nih.gov/16719566/).
- Kim & Webb (2022), [Spacing effects in second-language vocabulary learning: a meta-analysis](https://doi.org/10.1111/lang.12479).
- Rowland (2014), [The effect of testing versus restudy on retention: a meta-analytic review](https://pubmed.ncbi.nlm.nih.gov/25150680/).
- Li (2010), [The effectiveness of corrective feedback in SLA: a meta-analysis](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1467-9922.2010.00561.x).
- Lyster & Saito (2010), [Oral feedback in classroom SLA: a meta-analysis](https://doi.org/10.1017/S0272263109990520).
- Norris & Ortega (2000), [Effectiveness of L2 instruction: a research synthesis and quantitative meta-analysis](https://onlinelibrary.wiley.com/doi/abs/10.1111/0023-8333.00136).
- Bryfonski & McKay (2019), [Task-based language teaching and learning: a meta-analysis](https://eric.ed.gov/?id=EJ1225836).
- Jeon & Day (2016), [The effectiveness of extensive reading on reading proficiency: a meta-analysis](https://files.eric.ed.gov/fulltext/EJ1117026.pdf).
- Sailer & Homner (2020), [The gamification of learning: a meta-analysis](https://link.springer.com/article/10.1007/s10648-019-09498-w).
- Saito & Plonsky, [Effects of second-language pronunciation teaching revisited](https://kazuyasaito.net/LL2019.pdf).
- Cámara-Arenas et al. (2023), [ASR and pronunciation assessment cautions](https://www.lltjournal.org/item/10125-73512/).
- [Automatic pronunciation assessment review, Findings of EMNLP 2023](https://aclanthology.org/2023.findings-emnlp.557/).

### Platform contracts and security

- OpenAI, [Audio transcription API reference](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create).
- Supabase, [Anonymous authentication](https://supabase.com/docs/guides/auth/auth-anonymous).
- Supabase, [Edge Function authentication](https://supabase.com/docs/guides/functions/auth).
- Supabase, [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).

---

## 14. Final product judgment

Czechify should not add more lessons until it can reliably render, score, persist, and linguistically defend the lessons it already has. Breadth is no longer the bottleneck; **trustworthy execution and evidence of transfer are**.

The near-term win is substantial: fixing the P0/P1 contract and state defects will turn a fragile but promising corpus into a credible learning platform. The longer-term differentiator should not be more XP, more multiple choice, or a more confident AI score. It should be a transparent system that helps a learner retrieve Czech, use it to accomplish real goals, repair mistakes, retain it weeks later, and understand exactly what they can do next.
