# Czechify audit implementation plan

**Created:** 22 July 2026

**Source audit:** [COMPREHENSIVE_PRODUCT_LEARNING_AUDIT_2026-07-22.md](COMPREHENSIVE_PRODUCT_LEARNING_AUDIT_2026-07-22.md)

**Objective:** turn the audit into a release-safe, measurable implementation program. The order below protects learner data and trust first, then improves learning efficacy. New curriculum breadth is intentionally deferred until the existing course can render, score, persist, and explain its evidence reliably.

## Delivery rules

1. Every change must have an automated regression test or a documented reason why only device/human validation is possible.
2. Content is executable product code: schema, semantic, render, and answer-path validation are release gates.
3. Completion, XP, mastery, CEFR evidence, and official-exam evidence remain separate concepts.
4. Cloud capability is based on authenticated server health/capability, not the presence of a client object.
5. Learning outcomes are evaluated after delay and transfer; same-session correctness is a diagnostic, not proof of mastery.
6. Database and content-release changes are backward compatible, reversible, and verified before remote deployment.
7. Work is delivered in small vertical slices. A phase gate must pass before dependent work becomes the default learner path.

## Status legend

- `TODO`: not started.
- `ACTIVE`: currently being implemented.
- `BLOCKED`: requires an external decision, credential, specialist, or device.
- `DONE`: implementation and stated verification complete.

## Phase 0 — Release safety and truthful behavior

**Target:** 0–2 weeks

**Exit gate:** zero known deterministic render/schema crashes; no fake/stale scores; account operations are recoverable; exam/privacy claims match actual behavior; critical flows have production-composition tests.

### 0A. Exercise runtime contracts — `DONE`

| Work item | Dependency | Acceptance evidence | Status |
|---|---|---|---|
| Give viewport-dependent exercise types bounded height while preserving scrolling for intrinsically sized exercises | None | Matching, error correction, reading, listening, and writing render through the production lesson viewport without flex exceptions | DONE |
| Add a regression harness for the production lesson exercise viewport | Layout fix | Tests cover all bounded-height types plus an intrinsically scrolling control case | DONE |
| Add asset-wide typed/schema validation | Contract design | All 726 exercises validate; failures identify file, exercise ID, JSON path, expected shape | DONE |
| Repair four declension-table assets | Validator | IDs 6002, 6005, 6007, 6009 render and submit | DONE |
| Normalize incompatible word-order assets | Validator | All 39 word-order exercises, including the audited IDs, validate and render | DONE |
| Normalize all dialogue assets to one schema | Validator | 36/36 dialogues expose the intended inputs and accepted answers | DONE |
| Add semantic rules for index bounds, blank/answer cardinality, answer constructibility, and stable order | Base validator | Invalid publication is rejected before seeding | DONE |

### 0B. Pronunciation safety — `ENGINEERING DONE / HUMAN VALIDATION OPEN`

| Work item | Dependency | Acceptance evidence | Status |
|---|---|---|---|
| Make expected text immutable and exercise-scoped | None | All 47 lesson items assess their own target; no prior result appears | DONE |
| Replace shared booleans with an attempt-ID state machine | Target fix | Manual stop, rapid retry, dispose, stale completion, denial, and timeout tests pass | DONE |
| Treat skip as skipped and make XP idempotent | Attempt model | Skip never changes correctness/mastery; one reward grant per accepted attempt | DONE |
| Disable unavailable cloud speech and implement native/degraded fallback | Reactive backend capability | Linked environment without `whisper-proxy` never hard-fails into the missing function | DONE |
| Secure and type-check `whisper-proxy` before deployment | Privacy/quotas/secret | Auth, byte/duration limits, timeout, model/language allowlist, user/project quotas, spend cap, smoke test | DONE |
| Update audio privacy disclosure and just-in-time consent | Product/legal review | Disclosure names processor, purpose, data, retention, fallback, and controls | DONE in product; legal wording still requires owner review |

### 0C. Exam correctness and claims — `ENGINEERING DONE / SPECIALIST GATE OPEN`

| Work item | Dependency | Acceptance evidence | Status |
|---|---|---|---|
| Replace force-cast speaking dispatch with typed task variants | Exam schema | All 17 speaking items parse; all six banks avoid missing-field dispatch | DONE |
| Give every writing/speaking task independent response, controller, score, rubric, and evaluator provenance | Exam model | Multi-task exams grade every available response; navigation restores exact text/state | DONE |
| Remove canned passing AI evaluation and unconditional completion XP | Evidence/reward policy | Unavailable evaluator produces unscored practice, never a pass | DONE |
| Choose CCE or permanent-residence A2 as the supported exam product | Product decision | One versioned official blueprint is named; no mixed timings/points/eligibility | DONE — permanent-residence A2 practice product selected |
| Rebuild scoring/timing/pass rules from primary sources | Exam choice | Every subtest, task, point, timer, and threshold matches signed-off blueprint | BLOCKED |
| Obtain current Czech exam-specialist review | Rebuilt simulation | Reviewer checklist and version/date recorded | BLOCKED |

### 0D. Account and sync integrity — `DONE`

| Work item | Dependency | Acceptance evidence | Status |
|---|---|---|---|
| Stage account switching; retain old local state until new session/data install succeeds | None | Injected install failure leaves prior account intact | DONE |
| Define and implement one export/delete inventory | Privacy review | DB, preferences, queues, temporary audio, and provider memory are covered; install-scoped device ID is intentionally retained | DONE |
| Reseed/scope SRS correctly after reset | Account clear | Review deck remains usable after delete/switch/reset | DONE |
| Replace device-clock pull cursor with server-owned monotonic revision | Backend migration design | Clock-skew/concurrent-device tests cannot strand changes | DONE (client + tests); remote migration applied & verified on linked project |
| Use stable UUIDs and sync custom cards before dependent SRS records | Sync revision | Two devices cannot collide or poison pull progress | DONE (client + tests); `custom_cards` remote table applied & verified on linked project |
| Move learning actions toward immutable idempotent events | Revision/canonical response | Duplicate delivery is harmless; concurrent legitimate attempts are preserved | DONE — UUID-keyed lesson/exercise/evidence events and reward ledger |

## Phase 1 — Reliable evidence, persistence, and content delivery — `DONE`

**Target:** weeks 2–6

**Exit gate:** visible progress/rewards survive restart; retries cannot double-count; review scheduling uses committed state; remote content is immutable, verified, atomic, and reversible.

### 1A. Attempts, rewards, and lesson state — `DONE`

- Introduce immutable attempt IDs and phases: initial, immediate repair, delayed transfer. **DONE for initial and immediate repair; delayed-transfer delivery is a later learning-loop feature**
- Make `onExerciseAnswered` accept one outcome per exercise/phase. **DONE**
- Make nullable feedback fields explicitly clearable. **DONE**
- Await the completion transaction before success UI/unlock. **DONE**
- Replace fixed-versus-displayed XP divergence with an idempotent reward ledger. **DONE for lesson completion and review ratings; currently unused activity hooks award nothing**
- Separate activity XP from mastery evidence. **DONE**
- Make lesson exam timers enforce or explicitly label non-enforcement. **DONE: practice uses an explicitly non-enforcing pace target**

### 1B. Review correctness — `DONE`

- Await review persistence and update UI from the committed result. **DONE**
- Requeue the newly scheduled card state, not the stale session copy. **DONE**
- Consume the daily new-card allowance on first committed review. **DONE**
- Add local natural-key uniqueness and atomic upsert. **DONE**
- Rename the simplified SM-2 scheduler honestly; do not claim FSRS. **DONE**
- Add crash/restart, rapid-tap, repeated-Again, duplicate-delivery, and day-boundary tests. **DONE**

### 1C. Progress evidence — `DONE for the Phase 1 evidence model`

- Separate exposure, completion, first-pass accuracy, supported repair, delayed retention, and transfer. **PARTIAL:** completion, initial response, and immediate repair are distinct; delayed retention/transfer remain later learning-loop work.
- Compute unit coverage against all required lessons, not completed rows only. **DONE**
- Replace “Reached A1/A2” with a dated, skill-specific evidence profile and confidence. **DONE**
- Make unlock prerequisites explicit and independent from XP. **DONE**
- Add concept-level error tracking for case, gender, aspect, word order, vowel length, register, and communicative function. **DONE for explicit curriculum metadata; recurrence-driven routing remains Phase 2C**

### 1D. Content releases — `DONE`

- Store immutable `(pack_key, version)` rows and normalized manifest items. **DONE locally and on the linked project**
- Fetch only exact referenced versions. **DONE**
- Verify per-pack and aggregate hashes before installation. **DONE**
- Install into staging and atomically switch active release. **DONE locally**
- Reconcile retired managed content without destroying learner history. **DONE**
- Persist active/previous releases and test rollback/corruption/partial download. **DONE locally and against the linked Supabase schema**
- Account for current Supabase behavior where newly created public tables may require explicit Data API grants; enable RLS and grant only the intended roles.

### Phase 1D first-slice evidence — 23 July 2026

- The former remote path trusted mutable `curriculum_packs` rows, ignored manifest versions and checksums, fetched every published row, and silently fell back to pack-level delivery when manifest loading failed. Remote installation now fails closed unless a published release and normalized item set are available.
- Added immutable `curriculum_pack_versions` keyed by `(pack_key, version)` and normalized `content_release_items` with an exact composite foreign key over pack key, version, and checksum. A database trigger rejects pack-version updates and deletes.
- Both delivery tables have RLS enabled and explicit read-only grants for `anon` and `authenticated`. Policies expose only items in published releases and the exact pack versions referenced by a published release.
- The client fetches the selected release’s normalized items, selects candidate rows by manifest keys, retains only exact referenced versions, and rejects missing, extra, wrong-version, or identity-mismatched packs.
- Added deterministic canonical-JSON SHA-256 verification for every pack and a release checksum over pack checksums sorted by pack key. Curriculum contract validation and local Drift installation occur only after both cryptographic gates pass.
- Focused Flutter tests cover key-order-independent canonical hashing, valid exact releases, corrupted content, wrong versions, incomplete membership, and aggregate tampering. The existing atomic-install failure test remains green.
- Added rollback-only pgTAP coverage for schema existence, RLS, Data API grants, exact-version foreign keys, immutability, and published anonymous reads. Local execution is pending because the Docker daemon is unavailable; this is not recorded as a database pass.
- Flutter analysis reports no issues, `git diff --check` is clean, and the full Flutter suite passes 178/178 tests for this slice.
- Drift schema v12 retains the active and immediately previous verified release plus their exact JSON payloads. Partial unique indexes enforce at most one active and one previous pointer.
- Release payloads are contract-checked and cryptographically verified in memory before installation. Curriculum upserts, SRS reconciliation, release caching, and the active-pointer switch then share one Drift transaction.
- Offline rollback re-verifies the retained previous payload before reinstalling it. A successful rollback swaps active/previous, making the rollback itself reversible.
- A failed installation rolls back curriculum rows, cached packs, and release pointers together, then restores the in-memory source to the still-active verified release.
- Only two release caches are retained. Installing a third release deletes the oldest cached pack rows before its parent release row, preserving foreign-key integrity.
- Migration tests cover v1/v4→v12. Release tests cover two-release switching, offline rollback, failed-install pointer/content preservation, source restoration, and third-release pruning.
- After the local rollback slice, Flutter analysis reports no issues, `git diff --check` is clean, and the full Flutter suite passes 181/181 tests.
- Drift schema v13 adds reversible `is_active` release membership to units, lessons, exercises, grammar rules, and managed vocabulary. Installation first retires the managed set, then reactivates only rows present in the verified release within the same transaction.
- Curriculum, grammar, vocabulary, review-card, due-count, progress-denominator, and content-health queries now exclude retired rows. User-created flashcards remain active because reconciliation is restricted to the managed ID range.
- Retirement preserves the raw content anchors, SRS scheduling state, lesson progress, lesson attempts, and exercise attempts. This avoids foreign-key deletion and keeps historical learning evidence interpretable.
- Rollback reactivates content present in the previous release. Regression coverage proves a release-specific exercise disappears after the next release and returns after offline rollback.
- Migration coverage now exercises v1/v4→v13, including every managed table’s active-release column.
- After managed-content reconciliation, Flutter analysis reports no issues, `git diff --check` is clean, and the full Flutter suite passes 182/182 tests.

### 1E. Platform quality gates — `DONE`

- Add Deno lint/type-check/tests and deployed function smoke tests. **DONE**
- Add Supabase migration reset, pgTAP/RLS/advisor/catalog assertions. **DONE in CI; linked pgTAP and schema lint also executed**
- Add 320/375/tablet, light/dark, 1×/2× text, semantics, and keyboard tests. **DONE for the startup/recovery critical path, alongside the asset-wide lesson viewport suite**
- Add Android/iOS and advertised desktop build checks. **DONE in the CI matrix; Android, iOS, and macOS also built locally**
- Add changed-line coverage, dependency/security/license, and content-publication reports. **DONE in CI**
- Add privacy-preserving error diagnostics with content/release IDs and sanitized state transitions. **DONE**

### Phase 1 completion evidence — 23 July 2026

- Review attempts, SRS state, a rating-specific reward-ledger entry, and the gamification projection now commit in one Drift transaction. Replaying the review ID returns without changing scheduling or XP.
- Restart coverage closes and reopens a file-backed database, proves the review and XP survived, and proves redelivery cannot award twice. Rapid-tap, failed-commit retry, repeated-Again, daily quota, and day-boundary coverage remain green.
- The exam-practice clock now says “Pace target” and explicitly announces that practice continues after the target; it no longer presents a false enforced timeout.
- The linked migration `20260723112713_immutable_content_release_items.sql` was applied successfully. Local and remote migration histories match.
- The complete linked pgTAP suite passes 42/42 assertions across RLS, grants, sync, quota controls, immutable pack versions, exact release membership, and anonymous published reads. Linked database lint reports no schema errors.
- **Reproducibility fix — 23 July 2026 (found by running pgTAP on a clean local DB with Docker).** The 42/42 result above only held against the linked project, where hosted Supabase's event trigger had auto-granted `service_role` DML on the content-release tables. A clean migration-only database (CI `supabase db reset`, a fresh environment) had no such grant, so `content_releases.test.sql` failed with "permission denied for table curriculum_pack_versions" and CI's pgTAP gate would have been red. Migration `20260723220000_grant_service_role_content_publishing.sql` grants `service_role` explicit DML on `curriculum_pack_versions`, `content_release_items`, and `content_releases` so the schema is self-contained; immutability is still enforced by the pack-version trigger. After the fix a clean `supabase db reset` + `supabase test db` passes 42/42 (`Result: PASS`).
- All nine Edge Function TypeScript files pass Deno formatting and lint; all three entry points type-check; 10/10 policy tests pass. Whisper now rejects malformed, oversized, unsupported-language, and overlong-prompt requests and does not expose upstream error bodies.
- Both deployed functions intentionally enabled in the linked project (`deepseek-proxy` and `account-data`) are reachable and reject unauthenticated smoke requests with HTTP 401. Cloud Whisper remains undeployed under the privacy decision gate.
- Startup recovery passes at 320, 375, and 768 logical pixels in light and dark themes with 2× text, an actionable semantic button, and keyboard activation. Its layout scrolls safely at constrained sizes.
- Error diagnostics record only allowlisted event, content/release identifier, error type, and state-transition fields; tests prove learner text, email-like data, arbitrary metadata, and exception messages are excluded.
- CI now enforces Flutter analysis/tests/coverage, 80% changed-line coverage on pull requests, dependency vulnerability/license review, content-publication evidence, Deno gates, clean Supabase reset plus pgTAP/lint, and Android/iOS/macOS/Windows build smoke checks.
- The incompatible `record` 5.x platform package set discovered by the Android build was upgraded to the compatible 6.2.1 line. Android, macOS, and unsigned iOS debug builds all succeed.
- Final Flutter analysis reports no issues; the full suite passes 192/192 tests and emits LCOV evidence (5,225/13,503 lines, 38.7% overall). The baseline is intentionally recorded rather than presented as strong coverage; pull requests now enforce 80% coverage on changed lines while broader legacy coverage is raised incrementally.
- Final Deno formatting/lint/type-check and 10/10 Edge policy tests pass, and `git diff --check` is clean.

## Phase 2 — Retained communicative learning

**Target:** weeks 6–12

**Exit gate:** the product demonstrates improved seven-day performance on novel tasks, not only same-session completion.

### 2A. Placement and routing — `IMPLEMENTED`

- Build a short adaptive diagnostic sampling reading, listening, constructed response, and optional speaking. **DONE for the required reading/listening/constructed-response diagnostic; speaking remains optional and is deferred until Phase 3 human validation**
- Provisionally unlock appropriate content and let learners override placement. **DONE**
- Re-estimate from early delayed evidence. **DONE; completed delayed novel tasks automatically update the persisted skill estimate and inferred unit while preserving learner override**
- Select next work from skill/component evidence rather than a purely linear path. **DONE for durable support/delayed evidence and home routing**

### 2B. Lesson loop — `IMPLEMENTED FOUNDATION`

- Convert priority units to model → notice → retrieve → use → repair → vary → delayed transfer. **DONE as an executable loop and lesson-session repair contract; failed first attempts create restart-safe seven-day transfer work**
- Add application lessons for clinic, housing, food/allergies, directions, school/work messages, and service interactions. **Existing shipped application content is retained; linguistic review remains a publication gate**
- Implement the feedback ladder: signal → self-repair → cue → explanation → immediate variant → spaced analogue → novel task. **DONE in engine and lesson UI, including nonpunitive repair and progressive reveal**
- Track hint, transcript, translation, and replay dependence. **DONE for available hint, transcript, and replay surfaces; translation remains an enum-backed contract until a reviewed translation-support surface ships**

### Phase 2 first-slice evidence — 23 July 2026

- Added an adaptive placement engine that balances required skill samples, targets item difficulty from observed performance, distinguishes independent from scaffolded success, supports learner override, and revises estimates from delayed novel-task evidence.
- Added a learner-facing nine-item reading, listening, and constructed-response diagnostic. Listening requires audio before answering and counts extra playback as support dependence. Results are explicitly labeled provisional rather than CEFR attainment.
- Placement profiles persist in Drift schema v14, survive restart/account export, clear with learner data, provisionally unlock curriculum through the chosen unit, and can be overridden by the learner.
- Replaced the linear home recommendation with an evidence router. Failed delayed transfer outranks new work; independent errors and scaffold dependence raise priority; XP and streaks are absent from the contract.
- Added append-only, idempotent learning evidence with skill, learning-loop phase, correctness, novelty, support use, concept keys, latency, and timestamp. Restart tests prove exact support metadata survives.
- Added an executable model → notice → retrieve → use → repair → vary → seven-day delayed-transfer state machine and the graduated feedback ladder. Supported retrieval cannot skip independent repair.
- Lesson answers now emit support-aware retrieval/repair evidence. The error-correction “Show hint” control no longer displays its hint before the learner asks for it, and use is recorded separately from correctness.

### 2C. Contextual SRS — `IMPLEMENTED FOUNDATION`

- Canonicalize lemma, sense, part of speech, morphology, register, and pronunciation source. **DONE in Drift schema v16 and seed/repository contracts; legacy fields are retained for compatibility**
- Resolve accidental vocabulary duplicates and IPA conflicts through dual review. **AUDITED; automated merging is prohibited because duplicate spellings include different senses and IPA conventions. Qualified dual review remains a human publication gate**
- Require overt retrieval before reveal where accessible. **DONE for production vocabulary cards**
- Schedule chunks, cloze, morphology, grammar patterns, and recurring concept errors. **Contextual cloze and grammar natural keys DONE; canonical fields now provide the seam for reviewed morphology/chunk expansion**
- Experiment with smaller contextual batches and optimize delayed production per minute. **Default new-card batch reduced from 15 to 8 and session cap from 30 to 20; effectiveness remains an experiment, not a proven claim**

### 2D. Input and output — `IMPLEMENTED FOUNDATION / HUMAN GATES OPEN`

- Activate linguistically reviewed graded reading with learner topic choice. **Content and review workflow remain a qualified-linguist gate; the app must not label unreviewed text as reviewed**
- Ship native-speaker/reviewed audio with multiple voices and natural connected speech. **Open production dependency; device TTS is clearly a fallback and is not represented as native-speaker audio**
- Use gist-first listening and delayed/fading transcript/gloss support. **DONE; transcript starts hidden and transcript/replay dependence is recorded separately from correctness**
- Add writing cycles: plan → draft → analytic feedback → revision → transfer prompt. **Draft/revision cycle and honest unscored open-writing result DONE; delayed novel-task queue provides the transfer seam**
- Add outcome-based speaking missions with interaction, clarification, repair, and register. **Existing speaking-task contract remains provisional pending the Phase 3 human-validation gate**

### Phase 2 engineering closeout — 23 July 2026

- The required placement diagnostic, learner override, evidence-driven router, and persisted automatic re-estimation from delayed novel tasks are implemented.
- Lesson correctness and scaffold dependence are separate evidence. The UI uses progressive self-repair, does not charge hearts for repair attempts, and creates idempotent seven-day novel-transfer assignments from first-pass errors.
- Listening is now gist-first. Transcripts are hidden until requested, repeat playback and transcript reveal are recorded as supports, and supported success cannot masquerade as independent performance.
- Production review requires an overt answer before reveal, uses contextual cloze where examples exist, and runs smaller batches. Drift v16 adds canonical lexical identity, morphology/register metadata, and pronunciation provenance.
- Open writing now requires a first draft and revision and remains explicitly unscored without an objective key; no proficiency result is fabricated.
- `flutter analyze --fatal-infos` reports no issues; the full Flutter suite passes 207/207 tests, including schema v1/v4→v16, restart-safe delayed transfer, placement re-estimation, listening support, and writing-cycle coverage.
- Phase 2's engineering foundation is complete. Its product exit gate—demonstrated improvement on seven-day novel tasks—cannot be declared from implementation tests. It requires elapsed-time learner evidence. Native/reviewed audio, qualified Czech content review, dual review of vocabulary/IPA conflicts, and validated speaking/writing judgments remain explicit human dependencies and route into Phase 3 rather than being represented as completed.

## Phase 3 — Human validation and official assessment

**Target:** months 3–6

**Exit gate:** key automated measurements agree acceptably with qualified human judgments, and any exam simulation has a versioned specialist approval.

### 3A. Speech and writing validation — `TODO`

- Define pronunciation targets around intelligibility/comprehensibility, Czech vowel length/contrasts, stress groups, and prosody.
- Collect consented, representative samples across L1s, microphones, noise conditions, and proficiency.
- Compare automated measures with blinded Czech listener ratings; publish error/fairness bounds.
- Validate analytic writing/speaking rubrics and evaluator consistency.
- Keep transcript match clearly labeled until these gates pass.

### 3B. Official exam simulation — `TODO`

- Version banks by official product, blueprint, and effective date.
- Record raw task/subtest points, responses, time, supports, evaluator provenance, and pass rule.
- Require 100% bank completion tests and current specialist sign-off.
- Show “practice, not an official result” and never convert app XP/mastery into certification language.

### 3C. Learning experiments — `TODO`

- Response-required contextual review vs current reveal/self-rating.
- Smaller contextual vocabulary batches vs current 29–60-item presentation.
- Information-gap task vs fixed dialogue completion.
- Self-repair ladder vs immediate full correction.
- Nonpunitive productive practice vs hearts default-on.
- Effort-first/faded transcript vs transcript visible immediately.
- Adaptive placement vs mandatory Unit 1.

Primary outcomes are 7-/30-day unscaffolded task success, cued production, new-voice listening transfer, response latency, support dependence, error recurrence, self-repair, communicative goal completion, and learning gain per minute. XP, streak, and session completion are guardrail/engagement measures only.

## Cross-phase decision log

| Decision | Owner needed | Deadline | Default if undecided |
|---|---|---|---|
| Supported official exam: CCE or Czech permanent-residence A2 — decision brief in [EXAM_PRODUCT_DECISION_2026-07-23.md](EXAM_PRODUCT_DECISION_2026-07-23.md) (recommends permanent-residence A2; existing `exam_bank_a2.json` is that exam mislabeled as CCE). Awaiting owner sign-off. | Product + Czech exam specialist | Before Phase 0C content rebuild | Relabel all exams as informal practice |
| Cloud audio processor/retention/consent | Product/privacy owner | Before any cloud speech deployment | Keep cloud speech disabled |
| Mastery terminology and CEFR claim policy | Product + applied linguist | Before Phase 1C UI | Use “practice evidence,” skill-specific and dated |
| Human-review workflow for Czech/IPA | Content owner | Before new content release | Freeze expansion; fix only verified errata |
| Learning analytics consent/retention | Product/privacy owner | Before Phase 2 experiments | Local-only aggregate metrics |

## First implementation slice

This plan begins with Phase 0A because it removes a deterministic failure affecting 67 shipped exercises and creates the regression seam needed for later asset-wide testing. The first slice is complete only when:

- the production lesson player selects bounded or scrolling composition from exercise behavior;
- matching, error correction, reading, listening, and writing render without unbounded-flex exceptions;
- regression tests exercise that exact composition;
- analysis and the focused/full test suite pass;
- this plan records the completed evidence.

### First-slice evidence — 22 July 2026

- Added `LessonExerciseViewport`, which gives matching, error correction, reading comprehension, listening comprehension, and writing tasks bounded height while retaining outer scrolling for other exercise types.
- Replaced the unconditional `SingleChildScrollView` composition in `LessonPlayerScreen` with the new viewport contract.
- Added a regression test that loads and renders all 67 affected shipped exercises through that contract at a phone-sized viewport.
- `flutter analyze --fatal-infos`: no issues.
- Full Flutter suite: 137/137 tests passed (135 existing plus two new viewport tests).
- No Supabase schema or remote state was changed in this slice. The current changelog was reviewed; later migrations must explicitly account for the April 2026 change that can leave newly created public tables unexposed to the Data API until grants are applied, independently of RLS.

### Curriculum-contract evidence — 23 July 2026

- Added a production `CurriculumContractValidator` and made both bundled and remote snapshots pass it before they can replace the active curriculum packs.
- The validator now enforces common metadata and identity rules across every shipped lesson exercise, plus executable contracts for declension tables, word order, and dialogue exercises. Failures include pack, exercise ID, JSON path, and a precise reason.
- Repaired all four malformed declension tables and normalized all 39 word-order exercises. This also removed invalid indices and corrected several answer/order contradictions and unnatural or semantically incorrect sentences discovered by the validator.
- Migrated all 36 dialogues to one unambiguous contract: each `___` blank has its own ordered list of accepted alternatives. The UI now renders and evaluates every blank independently.
- Extended type-specific validation to every shipped exercise family, including option bounds, required runtime fields, comprehension question structure, writing limits, speaking duration, matching pairs, pronunciation targets, and error-correction answers.
- Migrated all 144 fill-blank exercises to one explicit per-blank alternatives contract. This repaired numerous multi-blank exercises that the old widget could never score correctly, and removed accidental extra inputs caused by underscores in explanatory text.
- Repaired four error-correction exercises that accepted valid answers but omitted the canonical correction required by their widget.
- Added asset-wide render coverage for all 726 exercises, plus interaction tests for multi-blank dialogue and fill-blank scoring.
- Fixed a speaking-task phone-width overflow exposed by the complete render gate.
- The render harness exposed and now guards a separate lifecycle defect: consecutive exercises of the same type reused stale widget state. Exercise widgets are keyed by exercise ID.
- All lesson JSON files parse with `jq`; `git diff --check` is clean; `flutter analyze --fatal-infos` reports no issues; the full Flutter suite passes 146/146 tests.
- No Supabase schema, deployment, or remote data was changed in this slice.

### Pronunciation-safety evidence — 23 July 2026

- Every recording attempt now captures an immutable expected text and monotonic attempt ID. Lesson pronunciation widgets scope the provider to their own `target_text`.
- Changing exercises, resetting, or manually stopping invalidates the active attempt; late asynchronous completions cannot overwrite the current exercise or display a prior result.
- Removed the provider-level pronunciation XP grant that occurred as soon as transcription completed. Lesson rewards remain tied to the learner submitting the exercise result, avoiding the previous double/rejected-attempt reward path.
- Added controlled async tests for target leakage and late completion after manual stop.
- Introduced explicit `correct`, `incorrect`, and `skipped` exercise outcomes. Pronunciation skip is now neutral: no correctness evidence, heart loss, XP, or mistake re-queue, with a neutral feedback banner.
- Lesson sessions accept only the first callback for each exercise presentation, preventing duplicate counts and XP from rapid taps or repeated asynchronous callbacks.
- Added tests for neutral duplicate skip, duplicate correct-result XP, rapid reset/retry, and provider disposal with an in-flight result.
- `flutter analyze --fatal-infos` reports no issues; the full Flutter suite passes 152/152 tests.
- No Supabase schema, function, deployment, or remote data was changed. Cloud capability and `whisper-proxy` hardening remain later Phase 0B slices.

### Exam-correctness evidence — 23 July 2026

- Replaced speaking-task force casts with typed read-aloud, prompted-response, and open-response variants. All 17 speaking tasks across all six banks pass a complete-bank contract test.
- Writing responses now retain independent controllers, text, evaluation state, errors, and scores per section/question. Speaking transcripts and scores are likewise question-scoped.
- Productive section scores are weighted by each task's declared points. If any required productive task lacks an evaluator result, the attempt is explicitly incomplete/unscored and can never pass.
- Open speaking responses expose their review criteria and preserve a transcript but do not fabricate an automatic score. Prompted tasks report transparent phrase coverage; read-aloud tasks are labeled transcript comparison rather than validated pronunciation assessment.
- Removed unconditional mock-exam completion XP and changed official-sounding result language to informal practice evidence.
- The supported official blueprint, primary-source scoring rebuild, and current Czech exam-specialist approval remain explicitly blocked decisions.

### Account-integrity evidence — 23 July 2026

- Existing-account authentication completes before mutation. Account transition then pauses background sync, retains the previous session, and clears/installs learner rows inside a Drift transaction.
- Strict pull failures now propagate during account installation. The database transaction rolls back the previous learner state, and the prior session is restored; a regression test injects a pull failure and verifies the old row remains.
- Ordinary sync triggers are no-ops during an account transition, preventing an old-account outbox from being pushed under the new session.
- Export now includes all local preferences alongside the complete learner-owned Drift inventory and cloud export.
- Successful switch/delete clears account-scoped onboarding/profile/review preferences, temporary pronunciation recordings and export files, and invalidates in-memory learner providers. The secure installation device ID is deliberately retained because it identifies the installation, not an account, and sync requires it for echo suppression.
- Clearing learner data immediately recreates fresh SRS rows for bundled vocabulary, so review remains usable without waiting for an app restart.
- `flutter analyze --fatal-infos` reports no issues; `git diff --check` is clean; the full Flutter suite passes 157/157 tests.
- No Supabase schema, function deployment, or remote data was changed.

### Cloud-speech fallback evidence — 23 July 2026

- Cloud speech capability is now reactive: `WhisperService.isAvailable` requires an authenticated backend session (`currentUser != null`) rather than merely a non-null client object, honoring the rule that cloud capability is authenticated server capability, not client presence.
- Introduced `CloudTranscriber`, `AudioRecorderPort`, and `LiveTranscriber` ports (`lib/domain/repositories/speech_ports.dart`). `WhisperService`, `AudioRecorderService`, and `NativeSttService` implement them; `PronunciationAssessor` now depends on the ports, making the cloud/native decision unit-testable without device hardware.
- `PronunciationAssessor.assess` wraps the Whisper path in a runtime guard. A linked environment whose `whisper-proxy` function is undeployed (or a transient function/network error) is caught, the in-progress recording is cleaned up, and the assessment degrades to on-device recognition with `usedWhisper = false` instead of throwing the missing-function error up to the exercise.
- Added `pronunciation_fallback_test.dart`: proves an unavailable transcriber never records and routes straight to native STT, and that a runtime cloud failure degrades to native STT (recording cleaned up, no hard failure). Cloud Whisper remains undeployed under the privacy decision gate; this slice makes the client fail-safe regardless.
- `flutter analyze --fatal-infos` reports no issues; `git diff --check` is clean; the full Flutter suite passes 209/209 tests (207 prior plus two fallback tests).
- No Supabase schema, function deployment, or remote data was changed.

### Phase 0D sync-integrity evidence — 23 July 2026

- **Root cause (found via the graphify knowledge graph + the live Supabase schema).** The pull cursor ordered by `(updated_at, sync_id)`. `updated_at` is written by the client wall clock; `sync_id` is `bigint generated always as identity`, assigned on INSERT only and never bumped on UPDATE (confirmed against all five sync tables on the linked project). A device with a lagging clock, or any row updated after another device advanced its cursor, could be stranded and never pulled again.
- **Server-owned monotonic revision.** Added migration `20260723140000_add_server_owned_sync_revision.sql`: a per-table sequence plus a `BEFORE INSERT OR UPDATE` trigger that stamps `revision` on every write to `lesson_progress`, `earned_badges`, `user_progress`, `srs_cards`, and `gamification_state`, with backfill, `NOT NULL`, and a `(user_id, revision)` index. Rollback steps are documented in the migration header.
- The client now paginates and cursors purely by `revision` (`SupabaseSyncBackend.pullPage`, `SyncService._pull`, `PullCursor`). Legacy `(updated_at, sync_id)` cursors are treated as absent so installations restart pulling from the beginning; this is safe because domain merges are monotonic and idempotent.
- **Remote apply (done).** The migration is applied and verified on the linked project (`pxhjcazremdnsdzpeajo`): `revision` is `NOT NULL` on all five tables, all five `_stamp_revision` triggers, sequences, and `(user_id, revision)` indexes exist, and existing rows backfilled with zero nulls. The first apply failed because the pre-existing `keep_newest_sync_row` last-write-wins trigger (returns `OLD` for any non-newer UPDATE) silently skipped the backfill; the migration now disables that trigger for the backfill only. The client's `.order('revision')` now has its column live in production.
- **Custom-card collision.** `addManualCard` allocated `content_key` from the local `MAX(id)+1` (≥ 900001); two devices' first manual cards both produced `content_key='900001'` for different words, poisoning each other's SRS state on sync. Drift schema v17 adds `flashcards.content_uid`; manual cards now get a UUID at creation and sync their SRS by that stable key, while managed/seeded cards keep their deterministic id. Existing manual rows (id ≥ 900000) are backfilled with a UUID in the migration.
- Full cross-device propagation of custom-card *definitions* is now implemented. A `custom_cards` sync entity carries `(content_uid, word_cz, word_en, ipa)`; the definition is enqueued at card creation so FIFO push places it before any later SRS review row. On pull, `custom_cards` is ordered before `srs_cards` in `_conflictKeys`, so `mergeCustomCard` materializes the local flashcard (allocating a fresh local id under the same stable `content_uid`) before `mergeSrsCard` attaches its scheduling. `mergeSrsCard` now resolves a non-numeric `content_key` to a local flashcard by `content_uid`; if the definition is not yet present the SRS row is safely ignored rather than mis-attached. Remote table migration `20260723210000_add_custom_cards_sync.sql` (RLS owner policy, authenticated-only grants — `anon` revoked, `keep_newest_sync_row` + `stamp_sync_revision` triggers, `(user_id, revision)` index) is **applied and verified** on the linked project via `supabase db push`. (The revision migration had been applied via MCP under version `20260723204836`; local files were renamed to match remote history, and `custom_cards` moved to `20260723210000` to keep ordering linear.)
- Round-trip tests cover: creation enqueues the definition; a second device materializes the card via `mergeCustomCard` and then attaches SRS state via `mergeSrsCard` keyed by UUID; and an SRS row with no local definition is dropped rather than mis-attached.
- **Verification.** New/updated tests: revision pagination, a clock-skew regression proving a lower-`updated_at`/higher-`revision` row is never stranded, and custom-card UUID vs managed-id sync keying. Migration coverage now exercises v1/v4→v17 including `content_uid`. `flutter analyze --fatal-infos` reports no issues; `git diff --check` is clean; the full suite passes 212/212.

### Phase 1A first-slice evidence — 23 July 2026

- Added schema v9 with immutable `lesson_attempts`, keyed by a caller-generated UUID and carrying the lesson, unit, evidence phase, score, outcome counts, start time, and commit time.
- Added immutable `exercise_attempts`: every exercise presentation receives a UUID and records its exercise, outcome, answer time, parent lesson attempt, and evidence phase. Main-pass answers are `initial`; end-of-lesson mistake re-asks are `immediate_repair`. The model also reserves `delayed_transfer` for the later transfer loop without falsely treating same-session repair as retention.
- Added an append-only `reward_ledger` with deterministic reward IDs and natural-key uniqueness. Lesson-attempt evidence, its activity-XP reward, aggregate lesson progress, gamification totals, and both sync-outbox mutations now commit in one Drift transaction.
- Replaying the same attempt UUID is a complete no-op: it cannot add another attempt, reward, aggregate attempt count, or XP.
- The lesson player no longer shows success or unlocks downstream state while persistence is still running. It shows a disabled “Saving…” action, exposes a retryable save error, and reaches completion only after the commit succeeds.
- Nullable feedback fields now have an explicit clear path, preventing explanations, answers, grammar references, or outcomes from leaking into the next exercise.
- Learner export and account clearing now include immutable lesson-attempt, exercise-attempt, and reward-ledger evidence.
- Added duplicate replay, distinct-attempt, initial/repair phase, reward-total, transaction rollback, feedback-clearing, export/reset, and v1/v4→v9 migration coverage.
- `flutter analyze --fatal-infos` reports no issues; `git diff --check` is clean; the full Flutter suite passes 160/160 tests.
- No Supabase schema, function deployment, or remote data was changed.

### Phase 1B first-slice evidence — 23 July 2026

- Review rating is now single-flight and awaited. The card does not advance, counters do not change, and rewards are not requested until the scheduled SRS state commits successfully.
- A failed write leaves the same revealed card in place with a visible retryable error. Rapid repeated rating taps while a commit is active produce one repository mutation.
- “Again” now appends a `SessionCard` built from the committed scheduled card. Subsequent scheduling therefore starts from the new relearning state rather than the stale session snapshot.
- Schema v10 adds partial unique indexes for vocabulary-card and grammar-pattern natural keys. The migration deterministically removes legacy duplicates before installing the constraints.
- `upsertSrsCard` now resolves and updates by domain identity inside a transaction instead of relying on the local autoincrement ID conflict target.
- Added controlled delayed-write, duplicate-tap, failed-write, vocabulary-key, grammar-key, and v1/v4→v10 migration coverage.
- `flutter analyze --fatal-infos` reports no issues; `git diff --check` is clean; the full Flutter suite passes 164/164 tests.
- Schema v11 adds immutable, UUID-keyed `review_attempts`. A first review of a `newCard` is marked as an introduction; later ratings and repeated “Again” reviews are retained as evidence without consuming another new-card slot.
- Session planning and the due-card badge now derive today’s allowance from committed review rows. Opening or abandoning a session has no quota effect, duplicate review delivery is a no-op, and the count resets at the local calendar-day boundary.
- Review attempts participate in learner export and account clearing. Focused tests cover first commit, duplicate delivery, later ratings, and next-day counts.
- Removed the remaining in-code FSRS labels; the product now consistently describes the implemented scheduler as simplified SM-2.
- After schema v11 and committed quota accounting, `flutter analyze --fatal-infos` reports no issues, `git diff --check` is clean, and the full Flutter suite passes 165/165 tests.

### Phase 1C first-slice evidence — 23 July 2026

- Unit practice scores now divide summed best lesson scores by every required lesson in the unit. One perfect completion in a two-lesson unit therefore reports 50%, not the previous misleading 100%.
- Phase coverage now uses completed required lessons over all required lessons in that phase. Units and lessons outside the phase cannot inflate the result.
- `ProgressSnapshot` carries completed/required lesson counts by unit and the timestamp of the latest committed lesson evidence.
- Replaced “Reached A1/A2,” “CEFR level,” and “Unit mastery” in the stats experience with dated “course practice evidence,” required-lesson coverage, and coverage-adjusted unit evidence. The UI explicitly says this is course activity rather than CEFR certification.
- The exam-prep lesson result no longer fabricates identical reading/listening/writing/speaking section scores or claims an exam pass. It reports lesson exercise accuracy, a course track, and an informal practice target.
- Renamed certification-style mock-exam badges and remaining onboarding/home claims to informal practice milestones.
- Added repository and tracker regression tests proving full curriculum denominators and correct phase scoping.
- `flutter analyze --fatal-infos` reports no issues; `git diff --check` is clean; the full Flutter suite passes 168/168 tests.
- Added component evidence derived from immutable exercise presentations and shipped content metadata. The profile currently separates reading, listening, writing, speaking, pronunciation, word order, case forms, vocabulary recall, and grammar, plus each declared grammar-rule ID.
- First-pass attempts and same-session repairs have independent denominators and accuracy. Skips count as exposure but never as correct or incorrect evidence.
- Evidence depth is a transparent sample-size band (`none`, `limited`, `growing`, `substantial`), explicitly not a mastery judgment. The stats UI shows the number of first attempts alongside first-pass and repair performance.
- Grammar-rule evidence retains the reviewed rule name while using the stable grammar-rule ID as its component key, creating a safe seam for later concept-error routing.
- Repository regression coverage proves that an initial error followed by a successful repair remains 0% first-pass and 100% repair rather than being collapsed into a misleading success.
- Added concept-error evidence for grammatical case, gender, verb aspect, word order, vowel length, register, and explicitly tagged communicative functions. Classification requires a matching exercise type, linked grammar-rule metadata, or explicit `concept_tags` / `communicative_function`; generic speaking and pronunciation failures are deliberately not diagnosed.
- Concept errors count only incorrect first attempts. A repair is credited only when a later correct immediate-repair presentation matches the same concept, exercise, and lesson attempt, preventing unrelated successes from erasing an error.
- The stats profile now lists “Concepts to revisit” with first-pass errors and same-session repairs, while describing the result as curriculum-linked practice evidence rather than a proficiency diagnosis.
- After concept-error routing, `flutter analyze --fatal-infos` reports no issues, `git diff --check` is clean, and the full Flutter suite passes 172/172 tests.
- Added a single `CurriculumAccessPolicy` that materializes auditable prerequisite lesson IDs from the ordered curriculum and evaluates them only against committed lesson completion. XP, streaks, hearts, badges, and self-reported performance are not policy inputs.
- Fixed the curriculum screen so opening a unit no longer opens every lesson inside it. The first lesson is available initially; each later lesson requires all earlier lessons, and a later unit requires all lessons in earlier units.
- Continue Learning, unit display, lesson tiles, review-card introduction, and direct lesson URLs now consume the same access graph. A direct URL to locked material shows a prerequisite message instead of loading the lesson.
- Regression tests cover initial access, sequential lesson and unit unlock, auditable prerequisite sets, and an out-of-sequence completion that cannot bypass an earlier requirement.
- After centralizing curriculum access, `flutter analyze --fatal-infos` reports no issues, `git diff --check` is clean, and the full Flutter suite passes 175/175 tests.
