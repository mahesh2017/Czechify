# Teaching Content Plan — Unit Intros & Teaching Cards

**Status:** PLAN for review. Nothing here is built into the app yet — awaiting go-ahead.

## What this covers

For every unit we add two things at the **start of the unit's first lesson**, before the practice exercises:

1. **Intro narration** — one short English "Welcome to Unit X…" script per unit. Spoken (English TTS for now; later re-voiced by a cartoon character as an `.mp3` per unit). It sets up what the unit is about and why it matters.
2. **Teaching card** — a "Learn" presentation (same pattern as Unit 1's alphabet card and Unit 9's numbers card): a heading, a short English explanation, and a set of **tappable rows** where each row shows a Czech form + its meaning and plays the Czech audio on tap. Grammar units present the key pattern/table as rows; vocabulary units present the core word set.

**Conventions in this doc**
- *Intro:* the narration script (English).
- *Teach:* the teaching-card content — heading, body, and the rows to present (Czech — meaning).
- Rows play Czech audio; the surrounding explanation is English.
- ✅ = already built. The rest are proposals for your review/editing.

**Technical note (for the build phase):** the intro is a new `intro_audio` field on the teaching card (English text → TTS now, swappable for a character `.mp3` later). Grammar tables reuse the existing tappable-row model (label + Czech form + audio); a couple of units may want a small 2-column table variant, flagged below.

---

# A1 — Beginner (Units 1–15)

## Unit 1 — Sounds & Pronunciation ✅ (alphabet card built; intro to add)
**Intro:** "Welcome to Czech! Every language starts with its sounds, so before words and sentences, let's meet the Czech alphabet. You'll hear how each letter is *named* and how it *sounds* inside real words — including the famous Czech ř. Listen, repeat, and don't worry about perfection. Let's begin!"
**Teach:** *(built)* The Czech alphabet — every letter with its name ('beh', 'tseh'…), the sound in words, and an example. "Play the whole alphabet" recites the names.

## Unit 2 — Greetings & Introductions
**Intro:** "Welcome to Unit 2! Now you can make sounds, let's use them to meet people. You'll learn how to say hello and goodbye, please and thank you — and the big Czech question: do you use the polite form or the friendly one? Let's say ahoj!"
**Teach — "First Words: Greetings & Politeness":** Czech has a *formal* (vy) and *informal* (ty) register — use vy with strangers, ty with friends.
- Dobrý den — Good day / Hello (formal)
- Ahoj — Hi / Bye (informal)
- Dobré ráno — Good morning
- Dobrý večer — Good evening
- Na shledanou — Goodbye (formal)
- Děkuji — Thank you
- Prosím — Please / You're welcome
- Promiňte — Excuse me / Sorry
- Ano — Yes · Ne — No
- Jak se máte? — How are you? (formal) · Jak se máš? (informal)
- Těší mě — Nice to meet you

## Unit 3 — Gender & Nominative Case
**Intro:** "Welcome to Unit 3! Here's the first big idea in Czech: every noun has a *gender* — masculine, feminine, or neuter. It's not about biology; it's about the word's ending, and it shapes almost everything else. Let's learn to spot them."
**Teach — "The Three Genders":** you can usually tell a noun's gender from its ending. Pattern with "To je…" (This is…).
- Masculine (often ends in a consonant): **muž** (man), **student**, **dům** (house), **hrad** (castle)
- Feminine (often ends in **-a**): **žena** (woman), **káva** (coffee), **kniha** (book), **škola** (school)
- Neuter (often ends in **-o / -e**): **auto** (car), **okno** (window), **město** (city), **moře** (sea)
- Pattern: **To je muž. To je žena. To je auto.** (This is a…)

## Unit 4 — Present Tense: být & mít
**Intro:** "Welcome to Unit 4! Two little verbs do a huge amount of work in Czech: být, 'to be', and mít, 'to have'. Learn these two and you can already say who you are and what you've got. Let's conjugate!"
**Teach — "být (to be) & mít (to have)":** *(two short tables as tappable rows)*
- být: **jsem** (I am), **jsi** (you are), **je** (he/she/it is), **jsme** (we are), **jste** (you are, pl/formal), **jsou** (they are)
- mít: **mám** (I have), **máš**, **má**, **máme**, **máte**, **mají**
- Note: Czech usually drops the pronoun — "Jsem student" not "Já jsem student."

## Unit 5 — Present Tense: Regular Verbs
**Intro:** "Welcome to Unit 5! Now for regular verbs — the engine of everyday sentences. Czech verbs fall into three tidy patterns based on their endings. Learn one model verb from each and you can conjugate hundreds. Let's go!"
**Teach — "Three Verb Classes":** present-tense endings by class, with a model verb (já / ty / on forms).
- **-á class** — *dělat* (to do): dělám, děláš, dělá, děláme, děláte, dělají
- **-í class** — *mluvit* (to speak): mluvím, mluvíš, mluví, mluvíme, mluvíte, mluví
- **-e/-ě class** — *číst* (to read): čtu, čteš, čte, čteme, čtete, čtou
- Everyday verbs: pracovat (work), rozumět (understand), bydlet (live/reside)

## Unit 6 — Accusative Case
**Intro:** "Welcome to Unit 6! When something *receives* the action — 'I see a man', 'I want coffee' — Czech changes the word's ending. That's the accusative case. It's the first case you'll use constantly. Let's see it in action."
**Teach — "The Object Case (Accusative)":** the direct object changes ending; masculine inanimate & neuter stay the same.
- Feminine **-a → -u**: káva → Dám si **kávu** (I'll have a coffee)
- Masculine animate **+ -a**: muž → Vidím **muže** (I see a man)
- Masculine inanimate — **no change**: dům → Vidím **dům**
- Neuter — **no change**: auto → Mám **auto**
- Common verbs that take it: mít, vidět, chtít, dát si, kupovat

## Unit 7 — Pronouns & Possessives
**Intro:** "Welcome to Unit 7! You've been dropping pronouns — now let's meet them properly, plus the words for 'my', 'your', 'our'. Careful: 'my' changes shape to match the noun's gender. Let's sort them out."
**Teach — "Pronouns & 'my/your'":**
- Personal: **já** (I), **ty** (you), **on** (he), **ona** (she), **ono** (it), **my** (we), **vy** (you pl/formal), **oni** (they)
- Possessive (m / f / n): **můj / moje / moje** (my), **tvůj / tvoje / tvoje** (your), **náš / naše / naše** (our), **váš / vaše / vaše** (your pl)
- **jeho** (his), **její** (her), **jejich** (their) — these don't change
- Example: **můj** dům, **moje** kniha, **moje** auto

## Unit 8 — Family & Basic Descriptions
**Intro:** "Welcome to Unit 8! Time to talk about the people in your life and describe the world around you. You'll meet family words and learn how adjectives 'agree' — a good adjective becomes dobrý, dobrá, or dobré depending on the noun. Let's meet the family."
**Teach — "Family & Describing Things":**
- Family: **matka** (mother), **otec** (father), **bratr** (brother), **sestra** (sister), **syn** (son), **dcera** (daughter), **babička** (grandma), **dědeček** (grandpa), **rodina** (family)
- Adjective agreement (m / f / n): **dobrý / dobrá / dobré** (good), **velký / velká / velké** (big), **malý / malá / malé** (small), **nový / nová / nové** (new)
- Example: **velký** dům, **velká** rodina, **velké** auto

## Unit 9 — Numbers, Time & Dates ✅ (numbers card built; intro to add)
**Intro:** "Welcome to Unit 9! Numbers unlock daily life in Czech — prices, phone numbers, telling the time. You'll learn 0 to 20, then how to count by tens, and how to build everything in between. Let's count: nula, jedna, dva…!"
**Teach:** *(built)* Czech numbers 0–20 + tens (30–100), each with the word, a pronunciation hint, and audio.

## Unit 10 — Daily Routine & Reflexive Verbs
**Intro:** "Welcome to Unit 10! Some Czech verbs come with a little word — se or si — that turns them 'back on yourself': I wash *myself*, I'm called… You'll use these to describe your whole day. Let's walk through a morning."
**Teach — "Reflexive Verbs (se / si) & Daily Routine":**
- **jmenovat se** — to be called: Jmenuju **se** Adam
- **mýt se** — to wash · **sprchovat se** — to shower · **dívat se** — to watch
- **oblékat se** — to get dressed · **cítit se** — to feel
- Routine verbs: **vstávat** (get up), **snídat** (have breakfast), **pracovat** (work), **spát** (sleep)
- Note: se/si is separate — "Ráno **se** sprchuju."

## Unit 11 — Food, Drink & Restaurants
**Intro:** "Welcome to Unit 11! Let's eat. You'll learn the words for common food and drink, and how to order politely in a Czech restaurant with 'Dám si…' — 'I'll have…'. Dobrou chuť — enjoy your meal!"
**Teach — "Food, Drink & Ordering":**
- Food: **chléb** (bread), **maso** (meat), **sýr** (cheese), **polévka** (soup), **zelenina** (vegetables), **ovoce** (fruit)
- Drink: **voda** (water), **káva** (coffee), **čaj** (tea), **pivo** (beer), **víno** (wine), **mléko** (milk)
- Ordering: **Dám si…** (I'll have…), **Chtěl bych…** (I'd like…), **Zaplatím** (I'll pay), **jídelní lístek** (menu)
- Example: **Dám si kávu a chléb.**

## Unit 12 — Shopping, Prices & Clothes
**Intro:** "Welcome to Unit 12! Now let's go shopping. The key question is 'Kolik to stojí?' — 'How much does it cost?' — and you'll learn colors, sizes, and clothes so you can find exactly what you want. Let's hit the shops."
**Teach — "Shopping: Prices, Colors & Clothes":**
- Key phrases: **Kolik to stojí?** (How much?), **Chci…** (I want…), **korun** (crowns/CZK), **velikost** (size), **levný / drahý** (cheap / expensive)
- Colors: **červená** (red), **modrá** (blue), **zelená** (green), **žlutá** (yellow), **černá** (black), **bílá** (white)
- Clothes: **tričko** (t-shirt), **kalhoty** (trousers), **boty** (shoes), **bunda** (jacket), **šaty** (dress)

## Unit 13 — Hobbies & Free Time
**Intro:** "Welcome to Unit 13! What do you like to do? In Czech you say it with 'mám rád' (I like) and 'rád' + a verb (I like doing). You'll talk about sports, music, and how often you do them. Let's have some fun."
**Teach — "Likes & Hobbies":**
- Liking: **mám rád / mám ráda** (I like — m/f), **rád / ráda + verb** (I like doing), **Co rád děláš?** (What do you like to do?)
- Hobbies: **sport**, **hudba** (music), **čtení** (reading), **film**, **vaření** (cooking), **cestování** (travel)
- Frequency: **často** (often), **někdy** (sometimes), **vždy** (always), **nikdy** (never)
- Example: **Rád čtu.** / **Ráda sportuju.**

## Unit 14 — Directions, Places & Transport
**Intro:** "Welcome to Unit 14! Let's find our way around town. You'll learn the places you need, how to ask 'Kde je…?' — 'Where is…?' — and the words for left, right, and straight ahead, plus how to get there. Let's explore the city."
**Teach — "Around Town: Places, Directions & Transport":**
- Places: **nádraží** (station), **obchod** (shop), **restaurace** (restaurant), **banka** (bank), **pošta** (post office), **náměstí** (square)
- Directions: **Kde je…?** (Where is…?), **vlevo** (left), **vpravo** (right), **rovně** (straight), **blízko** (near), **daleko** (far)
- Transport: **autobus**, **tramvaj**, **vlak** (train), **metro**, **jít pěšky** (go on foot)

## Unit 15 — Weather, Seasons & Travel
**Intro:** "Welcome to Unit 15, the last of your beginner journey! Let's talk about the weather and the seasons — and take your first step into the past tense, so you can say where you *were*. Then you're ready for the A1 exam. Let's finish strong!"
**Teach — "Weather, Seasons & 'I was…'":**
- Weather: **Je hezky** (It's nice), **Je ošklivo** (It's bad), **Prší** (It's raining), **Sněží** (It's snowing), **Je zima / horko** (It's cold / hot)
- Seasons: **jaro** (spring), **léto** (summer), **podzim** (autumn), **zima** (winter)
- Past-tense taster: **byl jsem** (I was, m) / **byla jsem** (I was, f) — Byl jsem v Praze.

---

# A2 — Elementary (Units 16–27)

## Unit 16 — Genitive Case
**Intro:** "Welcome to Unit 16, and to A2! You already know the accusative — now meet the genitive, the 'of' case. It shows possession (my brother's book), quantities, and follows lots of prepositions. It's everywhere in real Czech. Let's dive in."
**Teach — "The 'of' Case (Genitive)":**
- Possession: **kniha bratra** (brother's book), **auto matky** (mother's car)
- Endings (m / f / n): bratr → bratr**a**, žena → žen**y**, město → měst**a**
- Prepositions that trigger it: **bez** (without), **do** (into/to), **od** (from), **z/ze** (from/out of), **u** (at)
- Quantities: **hodně** (a lot of), **málo** (few), **sklenice vody** (a glass of water)

## Unit 17 — Dative Case
**Intro:** "Welcome to Unit 17! The dative is the 'to/for' case — the person who *receives* something. It's also how Czech says you like something (líbí se mi) and that something tastes good. Let's give it a go."
**Teach — "The 'to / for' Case (Dative)":**
- Indirect object: **Dávám kamarádovi knihu** (I give my friend a book)
- Endings (m / f): kamarád → kamarád**ovi**, žena → žen**ě**
- Dative verbs: **pomáhat** (help), **rozumět** (understand), **telefonovat** (call)
- Special: **líbí se mi** (I like it), **chutná mi** (it tastes good to me)

## Unit 18 — Locative & Instrumental Cases
**Intro:** "Welcome to Unit 18! Two more cases complete the set. The locative tells *where* (v Praze — in Prague) and always follows a preposition. The instrumental tells *with what/whom* and how you travel. Let's finish the case system."
**Teach — "Locative (where) & Instrumental (with)":**
- Locative — always after v/na/o: **v Praze** (in Prague), **na náměstí** (at the square), **o filmu** (about a film)
- Instrumental — with/means: **s kamarádem** (with a friend), **autobusem** (by bus), **pracuju jako učitel** (I work as a teacher)
- *Flag: a small 2-column table (case → ending) may read better than plain rows here.*

## Unit 19 — Past Tense (Full)
**Intro:** "Welcome to Unit 19! Now you can talk about yesterday. The Czech past tense is friendly — take the verb, add an -l ending, and match it to gender. You'll also meet motion verbs and a first taste of aspect. Let's look back."
**Teach — "The Past Tense":**
- Formula: verb stem + **-l** + být helper: **dělal jsem** (I did, m), **dělala jsem** (f), **dělali jsme** (we did)
- být: **byl / byla / byli** jsem/jsi/…
- Motion: **šel / šla / šli** (went, on foot), **jel / jela / jeli** (went, by vehicle)
- Time markers: **včera** (yesterday), **minulý týden** (last week)

## Unit 20 — Future Tense & Conditional
**Intro:** "Welcome to Unit 20! Let's talk about tomorrow — and about wishes. You'll build the future two ways, and learn the polite conditional: 'chtěl bych' — 'I would like'. Very useful for being polite in Czech. Let's plan ahead."
**Teach — "Future & 'I would…'":**
- Imperfective future: **budu** + infinitive — budu pracovat (I will work): budu, budeš, bude, budeme, budete, budou
- Perfective future (one action): **napíšu** (I'll write), **udělám** (I'll do)
- Conditional: **bych, bys, by, bychom, byste, by** — **Chtěl bych…** (I'd like), **Mohl bych…?** (Could I…?)

## Unit 21 — Comparisons & Advanced Adjectives
**Intro:** "Welcome to Unit 21! Bigger, better, best. You'll learn to compare things — add -ější or -ší for 'more', nej- for 'most' — plus the irregular ones every learner needs. Let's compare."
**Teach — "Comparative & Superlative":**
- Comparative **-ější / -ší**: rychlý → **rychlejší** (faster), starý → **starší** (older)
- Superlative **nej-**: **nejrychlejší** (fastest), **nejstarší** (oldest)
- 'than' = **než**: Praha je větší **než** Brno.
- Irregulars: dobrý → **lepší** → nejlepší; špatný → **horší**; velký → **větší**; malý → **menší**

## Unit 22 — Complex Sentences & Conjunctions
**Intro:** "Welcome to Unit 22! Time to join short sentences into real, flowing Czech using words like 'because', 'when', and 'that'. A couple of them change the word order — we'll show you which. Let's connect our ideas."
**Teach — "Joining Words (Conjunctions)":**
- **že** (that): Myslím, **že** je to dobré.
- **protože** (because): …**protože** mám čas.
- **když** (when): **Když** prší, jsem doma.
- **jestli** (if/whether), **až** (when, future), **aby** (so that — needs conditional: abych, abys…)

## Unit 23 — Modal Verbs & Permission
**Intro:** "Welcome to Unit 23! Modal verbs let you say what you must, can, may, and want to do. Learn these four and your Czech instantly sounds more natural and grown-up. Let's see what you *can* do."
**Teach — "Modal Verbs":**
- **muset** (must): musím, musíš, musí… — Musím jít.
- **moct** (can/be able): můžu, můžeš, může…
- **smět** (be allowed): smím, smíš, smí…
- **chtít** (want): chci, chceš, chce…
- Pattern: modal + infinitive — **Můžu vám pomoct?**

## Unit 24 — Health & Body
**Intro:** "Welcome to Unit 24! Let's take care of ourselves. You'll learn the parts of the body and how to say what hurts — 'Bolí mě…' — so you can handle a visit to the doctor or pharmacy. Feel better soon!"
**Teach — "Body & Health":**
- Body: **hlava** (head), **ruka** (hand/arm), **noha** (leg/foot), **oko** (eye), **ucho** (ear), **břicho** (belly), **záda** (back), **zub** (tooth)
- Health: **Bolí mě hlava** (My head hurts), **Jsem nemocný/á** (I'm sick), **lékař / doktor** (doctor), **lékárna** (pharmacy), **lék** (medicine)

## Unit 25 — Work, Professions & Education
**Intro:** "Welcome to Unit 25! Let's talk about work and study. You'll learn the words for common jobs and how to describe what you do — perfect for interviews and small talk. Let's get to work."
**Teach — "Jobs & Study":**
- Professions: **učitel/ka** (teacher), **lékař/ka** (doctor), **inženýr** (engineer), **prodavač/ka** (shop assistant), **řidič** (driver), **student/ka**
- Work: **pracuju jako…** (I work as…), **kancelář** (office), **kolega** (colleague), **plat** (salary)
- Study: **studovat** (to study), **univerzita**, **zkouška** (exam), **škola**

## Unit 26 — Housing & Home
**Intro:** "Welcome to Unit 26! Where do you live? You'll learn the rooms of a home, the furniture in them, and how to describe where things are. Handy for renting a flat in Czechia. Welcome home."
**Teach — "Home & Rooms":**
- Rooms: **kuchyně** (kitchen), **ložnice** (bedroom), **koupelna** (bathroom), **obývák** (living room), **záchod** (toilet)
- Furniture: **stůl** (table), **židle** (chair), **postel** (bed), **skříň** (wardrobe), **lednička** (fridge)
- Phrases: **Bydlím v bytě** (I live in a flat), **pronájem** (rent), **Kde je…?**

## Unit 27 — Verbs of Motion & Prefixed Verbs
**Intro:** "Welcome to Unit 27, your last A2 topic! Czech is picky about movement: 'jít' vs 'jet', one-time vs repeated. Add a prefix and the meaning shifts again. It's tricky but powerful — let's master motion."
**Teach — "Verbs of Motion":**
- **jít** (go on foot, now) vs **chodit** (go on foot, regularly)
- **jet** (go by vehicle, now) vs **jezdit** (go by vehicle, regularly)
- Prefixed: **přijít** (arrive), **odejít** (leave), **dojít** (reach), **přijet / odjet**
- Example: **Chodím** do práce pěšky, ale dnes **jedu** autobusem.

---

# Exam Prep & Review (Units 28–31)

These don't introduce a new grammar concept, so their "teaching card" is a **strategy/recap card** rather than a new-concept presentation.

## Unit 28 — A1 Exam Preparation
**Intro:** "Welcome to Unit 28! You've reached the A1 exam prep. Let's look at what the real test looks like — reading, listening, writing, and speaking — and pick up a few tactics so you walk in confident. Let's get exam-ready."
**Teach — "How the A1 Exam Works":** the four parts (reading, listening, writing, speaking), timing, and 3–4 practical tips (read questions first, don't panic on unknown words, answer everything). *Recap card — no Czech rows needed.*

## Unit 29 — A2 Exam Preparation
**Intro:** "Welcome to Unit 29! Time to prepare for the A2 exam — the level you need for permanent residence. We'll walk through each section and the strategies that matter most. You've got this."
**Teach — "How the A2 Exam Works":** section breakdown + tips, oriented to the permanent-residence exam format. *Recap card.*

## Unit 30 — A1 Review & Consolidation
**Intro:** "Welcome to Unit 30! Let's tie your A1 knowledge together — genders, the nominative and accusative, the present tense — so it all clicks as one system before you move on. A quick recap, then practice."
**Teach — "A1 in a Nutshell":** a compact recap of gender endings, nominative vs accusative, and present-tense classes, linking back to Units 3–6. *Recap card, optionally a few tappable example sentences.*

## Unit 31 — A2 Review & Consolidation
**Intro:** "Welcome to Unit 31, the finish line! Let's consolidate the whole case system and all the tenses you've learned across A2. When this clicks, you're ready for real-world Czech. Congratulations on getting here!"
**Teach — "A2 in a Nutshell":** recap of the seven cases at a glance and past/future/conditional, linking back to Units 16–20. *Recap card.*

---

## Build plan (once approved)

1. Add an `intro_audio` field to the teaching-card model + a small "▶ Intro" play control at the top of the card (English TTS now; `.mp3` per unit later).
2. For each unit's first lesson, insert a teaching card (id block 951–999) as the first exercise, with the content above.
3. Reuse the existing tappable-row `items` model; add a lightweight 2-column table variant only where flagged (Units 18, and any grammar table that reads better as a grid).
4. Bump `bundledContentRevision` once so all units re-seed together.
5. Update golden-count tests; verify on device unit by unit.

**Suggested order:** A1 first (Units 2–8, 10–15 — since 1 and 9 are done), then A2 (16–27), then exam/review (28–31).
