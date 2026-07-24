# Teaching Content Plan — Unit Intros & Teaching Cards

**Status:** PLAN for review. Nothing here is built into the app yet — awaiting go-ahead.

## What this covers

For every unit we add two things at the **start of the unit's first lesson**, before the practice exercises:

1. **Intro narration** — one short English script per unit, each with its **own distinctive opening** (a question, a scenario, a bold hook — never the same "Welcome to Unit X" formula twice). Spoken (English TTS for now; later re-voiced by a cartoon character as an `.mp3` per unit). It sets up what the unit is about and why it matters.
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
**Intro:** "Every language begins with its sounds — and Czech has a few that will surprise you, including one no other language on earth uses. Let's meet the alphabet letter by letter: how each one is named, and how it comes alive inside real words."
**Teach:** *(built)* The Czech alphabet — every letter with its name ('beh', 'tseh'…), the sound in words, and an example. "Play the whole alphabet" recites the names.

## Unit 2 — Greetings & Introductions
**Intro:** "The very first thing you'll say in a new country is hello — so let's make yours sound natural. You'll pick up the greetings, the pleases and thank-yous, and the one choice Czechs make every time they speak: formal, or friendly?"
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
**Intro:** "Here's the idea that unlocks Czech: every noun has a gender — masculine, feminine, or neuter. It's nothing to do with biology and everything to do with the ending. Learn to read those endings and the whole language starts to line up."
**Teach — "The Three Genders":** you can usually tell a noun's gender from its ending. Pattern with "To je…" (This is…).
- Masculine (often ends in a consonant): **muž** (man), **student**, **dům** (house), **hrad** (castle)
- Feminine (often ends in **-a**): **žena** (woman), **káva** (coffee), **kniha** (book), **škola** (school)
- Neuter (often ends in **-o / -e**): **auto** (car), **okno** (window), **město** (city), **moře** (sea)
- Pattern: **To je muž. To je žena. To je auto.** (This is a…)

## Unit 4 — Present Tense: být & mít
**Intro:** "Two tiny verbs do an enormous amount of work in Czech: 'to be' and 'to have'. Master their six little forms and you can already introduce yourself, describe people, and say what's yours."
**Teach — "být (to be) & mít (to have)":** *(two short tables as tappable rows)*
- být: **jsem** (I am), **jsi** (you are), **je** (he/she/it is), **jsme** (we are), **jste** (you are, pl/formal), **jsou** (they are)
- mít: **mám** (I have), **máš**, **má**, **máme**, **máte**, **mají**
- Note: Czech usually drops the pronoun — "Jsem student" not "Já jsem student."

## Unit 5 — Present Tense: Regular Verbs
**Intro:** "Actions are the heartbeat of every sentence. The good news: Czech verbs sort themselves into just three neat patterns — learn one model from each and you can conjugate hundreds more."
**Teach — "Three Verb Classes":** present-tense endings by class, with a model verb (já / ty / on forms).
- **-á class** — *dělat* (to do): dělám, děláš, dělá, děláme, děláte, dělají
- **-í class** — *mluvit* (to speak): mluvím, mluvíš, mluví, mluvíme, mluvíte, mluví
- **-e/-ě class** — *číst* (to read): čtu, čteš, čte, čteme, čtete, čtou
- Everyday verbs: pracovat (work), rozumět (understand), bydlet (live/reside)

## Unit 6 — Accusative Case
**Intro:** "'I see a man.' 'I'll have a coffee.' The moment something receives an action, Czech reshapes its ending — and this is the case you'll reach for a dozen times a day."
**Teach — "The Object Case (Accusative)":** the direct object changes ending; masculine inanimate & neuter stay the same.
- Feminine **-a → -u**: káva → Dám si **kávu** (I'll have a coffee)
- Masculine animate **+ -a**: muž → Vidím **muže** (I see a man)
- Masculine inanimate — **no change**: dům → Vidím **dům**
- Neuter — **no change**: auto → Mám **auto**
- Common verbs that take it: mít, vidět, chtít, dát si, kupovat

## Unit 7 — Pronouns & Possessives
**Intro:** "I, you, mine, yours — the small words we lean on constantly. Czech adds a twist: 'my' changes shape to match whatever you're talking about. Let's untangle it together."
**Teach — "Pronouns & 'my/your'":**
- Personal: **já** (I), **ty** (you), **on** (he), **ona** (she), **ono** (it), **my** (we), **vy** (you pl/formal), **oni** (they)
- Possessive (m / f / n): **můj / moje / moje** (my), **tvůj / tvoje / tvoje** (your), **náš / naše / naše** (our), **váš / vaše / vaše** (your pl)
- **jeho** (his), **její** (her), **jejich** (their) — these don't change
- Example: **můj** dům, **moje** kniha, **moje** auto

## Unit 8 — Family & Basic Descriptions
**Intro:** "Let's talk about the people you love and the world around you. You'll gather the family words — and discover how Czech adjectives quietly shift to 'agree' with their noun."
**Teach — "Family & Describing Things":**
- Family: **matka** (mother), **otec** (father), **bratr** (brother), **sestra** (sister), **syn** (son), **dcera** (daughter), **babička** (grandma), **dědeček** (grandpa), **rodina** (family)
- Adjective agreement (m / f / n): **dobrý / dobrá / dobré** (good), **velký / velká / velké** (big), **malý / malá / malé** (small), **nový / nová / nové** (new)
- Example: **velký** dům, **velká** rodina, **velké** auto

## Unit 9 — Numbers, Time & Dates ✅ (numbers card built; intro to add)
**Intro:** "Prices, phone numbers, the time on the clock — none of it works without numbers. Let's count from zero, learn the tens, and crack the simple trick for everything in between."
**Teach:** *(built)* Czech numbers 0–20 + tens (30–100), each with the word, a pronunciation hint, and audio.

## Unit 10 — Daily Routine & Reflexive Verbs
**Intro:** "Some Czech verbs fold back on the speaker — I wash myself, I'm called… That little word, se or si, is the key to narrating your whole day, from waking up to lights out."
**Teach — "Reflexive Verbs (se / si) & Daily Routine":**
- **jmenovat se** — to be called: Jmenuju **se** Adam
- **mýt se** — to wash · **sprchovat se** — to shower · **dívat se** — to watch
- **oblékat se** — to get dressed · **cítit se** — to feel
- Routine verbs: **vstávat** (get up), **snídat** (have breakfast), **pracovat** (work), **spát** (sleep)
- Note: se/si is separate — "Ráno **se** sprchuju."

## Unit 11 — Food, Drink & Restaurants
**Intro:** "Few things feel as good as ordering a meal in the local language. Stock up on food and drink words, then learn the magic phrase — 'Dám si…' — that turns a menu into dinner."
**Teach — "Food, Drink & Ordering":**
- Food: **chléb** (bread), **maso** (meat), **sýr** (cheese), **polévka** (soup), **zelenina** (vegetables), **ovoce** (fruit)
- Drink: **voda** (water), **káva** (coffee), **čaj** (tea), **pivo** (beer), **víno** (wine), **mléko** (milk)
- Ordering: **Dám si…** (I'll have…), **Chtěl bych…** (I'd like…), **Zaplatím** (I'll pay), **jídelní lístek** (menu)
- Example: **Dám si kávu a chléb.**

## Unit 12 — Shopping, Prices & Clothes
**Intro:** "'Kolik to stojí?' — three words that'll rescue you in any Czech shop. Add colors, sizes, and clothes, and you can find exactly what you want and know what it costs."
**Teach — "Shopping: Prices, Colors & Clothes":**
- Key phrases: **Kolik to stojí?** (How much?), **Chci…** (I want…), **korun** (crowns/CZK), **velikost** (size), **levný / drahý** (cheap / expensive)
- Colors: **červená** (red), **modrá** (blue), **zelená** (green), **žlutá** (yellow), **černá** (black), **bílá** (white)
- Clothes: **tričko** (t-shirt), **kalhoty** (trousers), **boty** (shoes), **bunda** (jacket), **šaty** (dress)

## Unit 13 — Hobbies & Free Time
**Intro:** "What do you love doing on a free afternoon? Czech has a charming way to say it — 'mám rád', I like — and soon you'll chat about sports, music, and how often you indulge."
**Teach — "Likes & Hobbies":**
- Liking: **mám rád / mám ráda** (I like — m/f), **rád / ráda + verb** (I like doing), **Co rád děláš?** (What do you like to do?)
- Hobbies: **sport**, **hudba** (music), **čtení** (reading), **film**, **vaření** (cooking), **cestování** (travel)
- Frequency: **často** (often), **někdy** (sometimes), **vždy** (always), **nikdy** (never)
- Example: **Rád čtu.** / **Ráda sportuju.**

## Unit 14 — Directions, Places & Transport
**Intro:** "Being lost in a new city is no fun — so let's make sure you never are. You'll learn the places you need, how to ask 'Where is…?', and how to get there on foot, tram, or train."
**Teach — "Around Town: Places, Directions & Transport":**
- Places: **nádraží** (station), **obchod** (shop), **restaurace** (restaurant), **banka** (bank), **pošta** (post office), **náměstí** (square)
- Directions: **Kde je…?** (Where is…?), **vlevo** (left), **vpravo** (right), **rovně** (straight), **blízko** (near), **daleko** (far)
- Transport: **autobus**, **tramvaj**, **vlak** (train), **metro**, **jít pěšky** (go on foot)

## Unit 15 — Weather, Seasons & Travel
**Intro:** "Small talk everywhere starts with the sky. You'll learn to chat about the weather and the seasons — and take your first step back in time with the past tense, ready for the A1 exam."
**Teach — "Weather, Seasons & 'I was…'":**
- Weather: **Je hezky** (It's nice), **Je ošklivo** (It's bad), **Prší** (It's raining), **Sněží** (It's snowing), **Je zima / horko** (It's cold / hot)
- Seasons: **jaro** (spring), **léto** (summer), **podzim** (autumn), **zima** (winter)
- Past-tense taster: **byl jsem** (I was, m) / **byla jsem** (I was, f) — Byl jsem v Praze.

---

# A2 — Elementary (Units 16–27)

## Unit 16 — Genitive Case
**Intro:** "Meet the 'of' case — the one that shows possession, counts quantities, and trails behind half the prepositions in Czech. It's the workhorse that carries you into A2."
**Teach — "The 'of' Case (Genitive)":**
- Possession: **kniha bratra** (brother's book), **auto matky** (mother's car)
- Endings (m / f / n): bratr → bratr**a**, žena → žen**y**, město → měst**a**
- Prepositions that trigger it: **bez** (without), **do** (into/to), **od** (from), **z/ze** (from/out of), **u** (at)
- Quantities: **hodně** (a lot of), **málo** (few), **sklenice vody** (a glass of water)

## Unit 17 — Dative Case
**Intro:** "Who gets the book, the phone call, the helping hand? That's the dative — the 'to and for' case. It even powers the Czech way of saying you like something."
**Teach — "The 'to / for' Case (Dative)":**
- Indirect object: **Dávám kamarádovi knihu** (I give my friend a book)
- Endings (m / f): kamarád → kamarád**ovi**, žena → žen**ě**
- Dative verbs: **pomáhat** (help), **rozumět** (understand), **telefonovat** (call)
- Special: **líbí se mi** (I like it), **chutná mi** (it tastes good to me)

## Unit 18 — Locative & Instrumental Cases
**Intro:** "Two cases left to complete the set. One pins down exactly where you are; the other tells us with what — or with whom — you're doing it. Finish these and the puzzle is solved."
**Teach — "Locative (where) & Instrumental (with)":**
- Locative — always after v/na/o: **v Praze** (in Prague), **na náměstí** (at the square), **o filmu** (about a film)
- Instrumental — with/means: **s kamarádem** (with a friend), **autobusem** (by bus), **pracuju jako učitel** (I work as a teacher)
- *Flag: a small 2-column table (case → ending) may read better than plain rows here.*

## Unit 19 — Past Tense (Full)
**Intro:** "Yesterday is finally within reach. The Czech past tense is refreshingly kind — take a verb, add an -l, match the gender, done. Let's talk about what already happened."
**Teach — "The Past Tense":**
- Formula: verb stem + **-l** + být helper: **dělal jsem** (I did, m), **dělala jsem** (f), **dělali jsme** (we did)
- být: **byl / byla / byli** jsem/jsi/…
- Motion: **šel / šla / šli** (went, on foot), **jel / jela / jeli** (went, by vehicle)
- Time markers: **včera** (yesterday), **minulý týden** (last week)

## Unit 20 — Future Tense & Conditional
**Intro:** "Now let's turn to tomorrow — and to wishes. You'll build the future two different ways and learn the polite little word that makes 'I would like' possible. Very Czech, very useful."
**Teach — "Future & 'I would…'":**
- Imperfective future: **budu** + infinitive — budu pracovat (I will work): budu, budeš, bude, budeme, budete, budou
- Perfective future (one action): **napíšu** (I'll write), **udělám** (I'll do)
- Conditional: **bych, bys, by, bychom, byste, by** — **Chtěl bych…** (I'd like), **Mohl bych…?** (Could I…?)

## Unit 21 — Comparisons & Advanced Adjectives
**Intro:** "Bigger, better, best. Learn a couple of endings and you can rank anything — cities, coffees, your two favourite pubs — plus the handful of irregulars every learner needs."
**Teach — "Comparative & Superlative":**
- Comparative **-ější / -ší**: rychlý → **rychlejší** (faster), starý → **starší** (older)
- Superlative **nej-**: **nejrychlejší** (fastest), **nejstarší** (oldest)
- 'than' = **než**: Praha je větší **než** Brno.
- Irregulars: dobrý → **lepší** → nejlepší; špatný → **horší**; velký → **větší**; malý → **menší**

## Unit 22 — Complex Sentences & Conjunctions
**Intro:** "Real fluency isn't longer words — it's smoother sentences. With 'because', 'when', and 'that', you'll stitch your short lines into flowing Czech, and dodge one sneaky word-order trap."
**Teach — "Joining Words (Conjunctions)":**
- **že** (that): Myslím, **že** je to dobré.
- **protože** (because): …**protože** mám čas.
- **když** (when): **Když** prší, jsem doma.
- **jestli** (if/whether), **až** (when, future), **aby** (so that — needs conditional: abych, abys…)

## Unit 23 — Modal Verbs & Permission
**Intro:** "Must, can, may, want — four verbs that instantly make you sound more grown-up in Czech. Snap them in front of any action and watch your sentences level up."
**Teach — "Modal Verbs":**
- **muset** (must): musím, musíš, musí… — Musím jít.
- **moct** (can/be able): můžu, můžeš, může…
- **smět** (be allowed): smím, smíš, smí…
- **chtít** (want): chci, chceš, chce…
- Pattern: modal + infinitive — **Můžu vám pomoct?**

## Unit 24 — Health & Body
**Intro:** "Sooner or later, everyone needs to say what hurts. Learn the parts of the body and the phrase 'Bolí mě…', and a Czech doctor's visit stops being scary."
**Teach — "Body & Health":**
- Body: **hlava** (head), **ruka** (hand/arm), **noha** (leg/foot), **oko** (eye), **ucho** (ear), **břicho** (belly), **záda** (back), **zub** (tooth)
- Health: **Bolí mě hlava** (My head hurts), **Jsem nemocný/á** (I'm sick), **lékař / doktor** (doctor), **lékárna** (pharmacy), **lék** (medicine)

## Unit 25 — Work, Professions & Education
**Intro:** "'So, what do you do?' It's the question at every party and interview. Let's give you the professions, the workplace words, and a confident answer."
**Teach — "Jobs & Study":**
- Professions: **učitel/ka** (teacher), **lékař/ka** (doctor), **inženýr** (engineer), **prodavač/ka** (shop assistant), **řidič** (driver), **student/ka**
- Work: **pracuju jako…** (I work as…), **kancelář** (office), **kolega** (colleague), **plat** (salary)
- Study: **studovat** (to study), **univerzita**, **zkouška** (exam), **škola**

## Unit 26 — Housing & Home
**Intro:** "Hunting for a flat in Czechia? This is your survival kit — the rooms, the furniture, and how to say where everything is. Let's make yourself at home."
**Teach — "Home & Rooms":**
- Rooms: **kuchyně** (kitchen), **ložnice** (bedroom), **koupelna** (bathroom), **obývák** (living room), **záchod** (toilet)
- Furniture: **stůl** (table), **židle** (chair), **postel** (bed), **skříň** (wardrobe), **lednička** (fridge)
- Phrases: **Bydlím v bytě** (I live in a flat), **pronájem** (rent), **Kde je…?**

## Unit 27 — Verbs of Motion & Prefixed Verbs
**Intro:** "Czech is famously fussy about movement: on foot or by car, once or every day — and a single prefix can shift the meaning again. It's the trickiest corner of A2, and the most satisfying to crack."
**Teach — "Verbs of Motion":**
- **jít** (go on foot, now) vs **chodit** (go on foot, regularly)
- **jet** (go by vehicle, now) vs **jezdit** (go by vehicle, regularly)
- Prefixed: **přijít** (arrive), **odejít** (leave), **dojít** (reach), **přijet / odjet**
- Example: **Chodím** do práce pěšky, ale dnes **jedu** autobusem.

---

# Exam Prep & Review (Units 28–31)

These don't introduce a new grammar concept, so their "teaching card" is a **strategy/recap card** rather than a new-concept presentation.

## Unit 28 — A1 Exam Preparation
**Intro:** "You've built the foundations — now let's aim them at the exam. We'll walk through exactly what the A1 test asks of you and the tactics that turn nerves into confidence."
**Teach — "How the A1 Exam Works":** the four parts (reading, listening, writing, speaking), timing, and 3–4 practical tips (read questions first, don't panic on unknown words, answer everything). *Recap card — no Czech rows needed.*

## Unit 29 — A2 Exam Preparation
**Intro:** "This is the big one: the A2 exam that opens the door to permanent residence. Let's demystify every section and sharpen the strategies that matter most."
**Teach — "How the A2 Exam Works":** section breakdown + tips, oriented to the permanent-residence exam format. *Recap card.*

## Unit 30 — A1 Review & Consolidation
**Intro:** "Before you move on, let's make everything click as one system — genders, cases, and the present tense working together instead of as separate rules."
**Teach — "A1 in a Nutshell":** a compact recap of gender endings, nominative vs accusative, and present-tense classes, linking back to Units 3–6. *Recap card, optionally a few tappable example sentences.*

## Unit 31 — A2 Review & Consolidation
**Intro:** "The finish line. Let's bring the whole case system and every tense together one last time — because once this clicks, you're ready for Czech out in the wild."
**Teach — "A2 in a Nutshell":** recap of the seven cases at a glance and past/future/conditional, linking back to Units 16–20. *Recap card.*

---

## Build plan (once approved)

1. Add an `intro_audio` field to the teaching-card model + a small "▶ Intro" play control at the top of the card (English TTS now; `.mp3` per unit later).
2. For each unit's first lesson, insert a teaching card (id block 951–999) as the first exercise, with the content above.
3. Reuse the existing tappable-row `items` model; add a lightweight 2-column table variant only where flagged (Units 18, and any grammar table that reads better as a grid).
4. Bump `bundledContentRevision` once so all units re-seed together.
5. Update golden-count tests; verify on device unit by unit.

**Suggested order:** A1 first (Units 2–8, 10–15 — since 1 and 9 are done), then A2 (16–27), then exam/review (28–31).
