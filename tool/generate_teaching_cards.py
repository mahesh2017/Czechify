#!/usr/bin/env python3
"""
Insert a teaching card (intro narration + heading/body + tappable rows) as the
FIRST exercise of each unit's first lesson.

Content is transcribed from docs/TEACHING_CONTENT_PLAN.md. Units 1 and 9 already
have their teaching cards built (alphabet / numbers) — for those we only patch in
the `intro` narration. Every other unit gets a fresh "list"-style card.

Idempotent: re-running replaces the generated card rather than stacking a second.
Teaching-card exercise id = 90000 + unit_id (a range with no existing ids).

Usage:  python3 tool/generate_teaching_cards.py
"""

import json, os, glob

LESSONS = os.path.join(os.path.dirname(__file__), '..', 'assets', 'curriculum', 'lessons')

# ── Intros for the two already-built cards (Units 1 & 9): patch-only ──────────
INTRO_ONLY = {
    1: "Every language begins with its sounds — and Czech has a few that will "
       "surprise you, including one no other language on earth uses. Let's meet "
       "the alphabet letter by letter: how each one is named, and how it comes "
       "alive inside real words.",
    9: "Prices, phone numbers, the time on the clock — none of it works without "
       "numbers. Let's count from zero, learn the tens, and crack the simple "
       "trick for everything in between.",
}

# ── Full cards for every other unit ──────────────────────────────────────────
# Each: (heading, body, intro, [(cz, en), ...])
UNITS = {
2: ("First Words: Greetings & Politeness",
    "Czech has a formal (vy) and an informal (ty) register — use vy with "
    "strangers, ty with friends. Tap any line to hear it.",
    "The very first thing you'll say in a new country is hello — so let's make "
    "yours sound natural. You'll pick up the greetings, the pleases and "
    "thank-yous, and the one choice Czechs make every time they speak: formal, "
    "or friendly?",
    [("Dobrý den", "Good day / Hello (formal)"),
     ("Ahoj", "Hi / Bye (informal)"),
     ("Dobré ráno", "Good morning"),
     ("Dobrý večer", "Good evening"),
     ("Na shledanou", "Goodbye (formal)"),
     ("Děkuji", "Thank you"),
     ("Prosím", "Please / You're welcome"),
     ("Promiňte", "Excuse me / Sorry"),
     ("Ano", "Yes"),
     ("Ne", "No"),
     ("Jak se máte?", "How are you? (formal)"),
     ("Jak se máš?", "How are you? (informal)"),
     ("Těší mě", "Nice to meet you")]),

3: ("The Three Genders",
    "You can usually tell a noun's gender from its ending. Practise with "
    "\"To je…\" (This is…).",
    "Here's the idea that unlocks Czech: every noun has a gender — masculine, "
    "feminine, or neuter. It's nothing to do with biology and everything to do "
    "with the ending. Learn to read those endings and the whole language starts "
    "to line up.",
    [("muž", "man (masculine — ends in a consonant)"),
     ("dům", "house (masculine)"),
     ("hrad", "castle (masculine)"),
     ("žena", "woman (feminine — ends in -a)"),
     ("káva", "coffee (feminine)"),
     ("kniha", "book (feminine)"),
     ("auto", "car (neuter — ends in -o)"),
     ("okno", "window (neuter)"),
     ("město", "city (neuter)"),
     ("moře", "sea (neuter — ends in -e)"),
     ("To je muž.", "This is a man."),
     ("To je žena.", "This is a woman."),
     ("To je auto.", "This is a car.")]),

4: ("být (to be) & mít (to have)",
    "Two tiny verbs, all six forms each. Czech usually drops the pronoun — "
    "\"Jsem student,\" not \"Já jsem student.\"",
    "Two tiny verbs do an enormous amount of work in Czech: 'to be' and 'to "
    "have'. Master their six little forms and you can already introduce "
    "yourself, describe people, and say what's yours.",
    [("jsem", "I am"),
     ("jsi", "you are (informal)"),
     ("je", "he / she / it is"),
     ("jsme", "we are"),
     ("jste", "you are (plural / formal)"),
     ("jsou", "they are"),
     ("mám", "I have"),
     ("máš", "you have (informal)"),
     ("má", "he / she / it has"),
     ("máme", "we have"),
     ("máte", "you have (plural / formal)"),
     ("mají", "they have")]),

5: ("Three Verb Classes",
    "Present-tense verbs fall into three patterns. Learn one model from each "
    "(já / ty / on… forms).",
    "Actions are the heartbeat of every sentence. The good news: Czech verbs "
    "sort themselves into just three neat patterns — learn one model from each "
    "and you can conjugate hundreds more.",
    [("dělám", "I do (-á class: dělat)"),
     ("děláš", "you do"),
     ("dělá", "he / she does"),
     ("děláme", "we do"),
     ("děláte", "you do (plural)"),
     ("dělají", "they do"),
     ("mluvím", "I speak (-í class: mluvit)"),
     ("mluvíš", "you speak"),
     ("mluví", "he / she speaks"),
     ("čtu", "I read (-e class: číst)"),
     ("čteš", "you read"),
     ("čte", "he / she reads"),
     ("čtou", "they read"),
     ("pracovat", "to work"),
     ("rozumět", "to understand"),
     ("bydlet", "to live / reside")]),

6: ("The Object Case (Accusative)",
    "When something receives the action, its ending can change. Masculine "
    "inanimate and neuter nouns stay the same.",
    "'I see a man.' 'I'll have a coffee.' The moment something receives an "
    "action, Czech reshapes its ending — and this is the case you'll reach for "
    "a dozen times a day.",
    [("Dám si kávu.", "I'll have a coffee (feminine -a → -u)"),
     ("Vidím muže.", "I see a man (masculine animate, + -a)"),
     ("Vidím dům.", "I see a house (masculine inanimate — no change)"),
     ("Mám auto.", "I have a car (neuter — no change)"),
     ("chtít", "to want (takes the accusative)"),
     ("kupovat", "to buy (takes the accusative)")]),

7: ("Pronouns & \"my / your\"",
    "The little words we lean on constantly — and \"my,\" which changes shape "
    "to match its noun.",
    "I, you, mine, yours — the small words we lean on constantly. Czech adds a "
    "twist: 'my' changes shape to match whatever you're talking about. Let's "
    "untangle it together.",
    [("já", "I"), ("ty", "you (informal)"), ("on", "he"), ("ona", "she"),
     ("ono", "it"), ("my", "we"), ("vy", "you (plural / formal)"),
     ("oni", "they"),
     ("můj", "my (with a masculine noun)"),
     ("moje", "my (with a feminine or neuter noun)"),
     ("tvůj", "your (masculine)"),
     ("náš", "our (masculine)"),
     ("váš", "your (plural, masculine)"),
     ("jeho", "his (never changes)"),
     ("její", "her (never changes)"),
     ("jejich", "their (never changes)")]),

8: ("Family & Describing Things",
    "The family words — and how Czech adjectives quietly shift to agree with "
    "their noun (m / f / n).",
    "Let's talk about the people you love and the world around you. You'll "
    "gather the family words — and discover how Czech adjectives quietly shift "
    "to 'agree' with their noun.",
    [("matka", "mother"), ("otec", "father"), ("bratr", "brother"),
     ("sestra", "sister"), ("syn", "son"), ("dcera", "daughter"),
     ("babička", "grandma"), ("dědeček", "grandpa"), ("rodina", "family"),
     ("dobrý", "good (adjective, masculine)"),
     ("velký dům", "a big house (masculine ending)"),
     ("velká rodina", "a big family (feminine ending)"),
     ("velké auto", "a big car (neuter ending)")]),

10: ("Reflexive Verbs (se / si) & Daily Routine",
     "Some verbs fold back on the speaker with a little se or si. They narrate "
     "your whole day.",
     "Some Czech verbs fold back on the speaker — I wash myself, I'm called… "
     "That little word, se or si, is the key to narrating your whole day, from "
     "waking up to lights out.",
     [("jmenovat se", "to be called"),
      ("Jmenuju se Adam.", "My name is Adam."),
      ("mýt se", "to wash (oneself)"),
      ("sprchovat se", "to shower"),
      ("dívat se", "to watch"),
      ("oblékat se", "to get dressed"),
      ("cítit se", "to feel"),
      ("vstávat", "to get up"),
      ("snídat", "to have breakfast"),
      ("spát", "to sleep"),
      ("Ráno se sprchuju.", "In the morning I take a shower.")]),

11: ("Food, Drink & Ordering",
     "Stock up on food and drink words, then the magic phrase — \"Dám si…\" — "
     "that turns a menu into dinner.",
     "Few things feel as good as ordering a meal in the local language. Stock "
     "up on food and drink words, then learn the magic phrase — 'Dám si…' — "
     "that turns a menu into dinner.",
     [("chléb", "bread"), ("maso", "meat"), ("sýr", "cheese"),
      ("polévka", "soup"), ("zelenina", "vegetables"), ("ovoce", "fruit"),
      ("voda", "water"), ("káva", "coffee"), ("čaj", "tea"),
      ("pivo", "beer"), ("víno", "wine"), ("mléko", "milk"),
      ("Dám si…", "I'll have… (ordering)"),
      ("Chtěl bych…", "I'd like…"),
      ("Zaplatím.", "I'll pay."),
      ("jídelní lístek", "menu"),
      ("Dám si kávu a chléb.", "I'll have a coffee and bread.")]),

12: ("Shopping: Prices, Colors & Clothes",
     "Three words to rescue you in any shop — plus colors, sizes, and clothes.",
     "'Kolik to stojí?' — three words that'll rescue you in any Czech shop. Add "
     "colors, sizes, and clothes, and you can find exactly what you want and "
     "know what it costs.",
     [("Kolik to stojí?", "How much is it?"),
      ("Chci…", "I want…"),
      ("korun", "crowns (CZK)"),
      ("velikost", "size"),
      ("levný", "cheap"),
      ("drahý", "expensive"),
      ("červená", "red"), ("modrá", "blue"), ("zelená", "green"),
      ("žlutá", "yellow"), ("černá", "black"), ("bílá", "white"),
      ("tričko", "t-shirt"), ("kalhoty", "trousers"), ("boty", "shoes"),
      ("bunda", "jacket"), ("šaty", "dress")]),

13: ("Likes & Hobbies",
     "The charming Czech way to say you like something — \"mám rád\" — plus "
     "hobbies and how often you do them.",
     "What do you love doing on a free afternoon? Czech has a charming way to "
     "say it — 'mám rád', I like — and soon you'll chat about sports, music, "
     "and how often you indulge.",
     [("mám rád", "I like (male speaker)"),
      ("mám ráda", "I like (female speaker)"),
      ("Co rád děláš?", "What do you like to do?"),
      ("sport", "sport"), ("hudba", "music"), ("čtení", "reading"),
      ("film", "film"), ("vaření", "cooking"), ("cestování", "travel"),
      ("často", "often"), ("někdy", "sometimes"), ("vždy", "always"),
      ("nikdy", "never"),
      ("Rád čtu.", "I like reading. (male)"),
      ("Ráda sportuju.", "I like doing sport. (female)")]),

14: ("Around Town: Places, Directions & Transport",
     "The places you need, how to ask \"Where is…?\", and how to get there.",
     "Being lost in a new city is no fun — so let's make sure you never are. "
     "You'll learn the places you need, how to ask 'Where is…?', and how to get "
     "there on foot, tram, or train.",
     [("nádraží", "station"), ("obchod", "shop"),
      ("restaurace", "restaurant"), ("banka", "bank"),
      ("pošta", "post office"), ("náměstí", "square"),
      ("Kde je…?", "Where is…?"),
      ("vlevo", "left"), ("vpravo", "right"), ("rovně", "straight ahead"),
      ("blízko", "near"), ("daleko", "far"),
      ("autobus", "bus"), ("tramvaj", "tram"), ("vlak", "train"),
      ("metro", "metro"), ("jít pěšky", "to go on foot")]),

15: ("Weather, Seasons & \"I was…\"",
     "Chat about the sky and the seasons — and take your first step into the "
     "past tense, ready for the A1 exam.",
     "Small talk everywhere starts with the sky. You'll learn to chat about the "
     "weather and the seasons — and take your first step back in time with the "
     "past tense, ready for the A1 exam.",
     [("Je hezky.", "It's nice (weather)."),
      ("Je ošklivo.", "It's bad (weather)."),
      ("Prší.", "It's raining."),
      ("Sněží.", "It's snowing."),
      ("Je zima.", "It's cold."),
      ("Je horko.", "It's hot."),
      ("jaro", "spring"), ("léto", "summer"),
      ("podzim", "autumn"), ("zima", "winter"),
      ("Byl jsem v Praze.", "I was in Prague. (male)"),
      ("Byla jsem v Praze.", "I was in Prague. (female)")]),

16: ("The \"of\" Case (Genitive)",
     "The case that shows possession, counts quantities, and trails half the "
     "prepositions in Czech.",
     "Meet the 'of' case — the one that shows possession, counts quantities, "
     "and trails behind half the prepositions in Czech. It's the workhorse that "
     "carries you into A2.",
     [("kniha bratra", "the brother's book"),
      ("auto matky", "the mother's car"),
      ("bez", "without"), ("do", "into / to"), ("od", "from"),
      ("z", "from / out of"), ("u", "at"),
      ("hodně", "a lot of"), ("málo", "few"),
      ("sklenice vody", "a glass of water")]),

17: ("The \"to / for\" Case (Dative)",
     "Who gets the book, the call, the helping hand? It even powers the Czech "
     "way of saying you like something.",
     "Who gets the book, the phone call, the helping hand? That's the dative — "
     "the 'to and for' case. It even powers the Czech way of saying you like "
     "something.",
     [("Dávám kamarádovi knihu.", "I give my friend a book."),
      ("pomáhat", "to help"),
      ("rozumět", "to understand"),
      ("telefonovat", "to call"),
      ("líbí se mi", "I like it"),
      ("chutná mi", "it tastes good to me")]),

18: ("Locative (where) & Instrumental (with)",
     "Two cases to complete the set: one pins down where you are, the other "
     "tells us with what — or whom.",
     "Two cases left to complete the set. One pins down exactly where you are; "
     "the other tells us with what — or with whom — you're doing it. Finish "
     "these and the puzzle is solved.",
     [("v Praze", "in Prague (locative — after v)"),
      ("na náměstí", "at the square (locative — after na)"),
      ("o filmu", "about a film (locative — after o)"),
      ("s kamarádem", "with a friend (instrumental)"),
      ("autobusem", "by bus (instrumental — means)"),
      ("pracuju jako učitel", "I work as a teacher (instrumental)")]),

19: ("The Past Tense",
     "Take a verb, add -l, match the gender — done. Let's talk about what "
     "already happened.",
     "Yesterday is finally within reach. The Czech past tense is refreshingly "
     "kind — take a verb, add an -l, match the gender, done. Let's talk about "
     "what already happened.",
     [("dělal jsem", "I did (male)"),
      ("dělala jsem", "I did (female)"),
      ("dělali jsme", "we did"),
      ("byl jsem", "I was (male)"),
      ("byla jsem", "I was (female)"),
      ("šel", "went, on foot (male)"),
      ("šla", "went, on foot (female)"),
      ("jel", "went, by vehicle (male)"),
      ("včera", "yesterday"),
      ("minulý týden", "last week")]),

20: ("Future & \"I would…\"",
     "Build the future two ways, and learn the polite little word behind "
     "\"I would like.\"",
     "Now let's turn to tomorrow — and to wishes. You'll build the future two "
     "different ways and learn the polite little word that makes 'I would like' "
     "possible. Very Czech, very useful.",
     [("budu pracovat", "I will work (budu + infinitive)"),
      ("budeš", "you will"),
      ("bude", "he / she will"),
      ("budeme", "we will"),
      ("napíšu", "I'll write (one finished action)"),
      ("udělám", "I'll do (one finished action)"),
      ("Chtěl bych…", "I'd like…"),
      ("Mohl bych…?", "Could I…?")]),

21: ("Comparative & Superlative",
     "Learn a couple of endings and you can rank anything — plus the handful of "
     "irregulars every learner needs.",
     "Bigger, better, best. Learn a couple of endings and you can rank anything "
     "— cities, coffees, your two favourite pubs — plus the handful of "
     "irregulars every learner needs.",
     [("rychlejší", "faster (-ejší)"),
      ("starší", "older (-ší)"),
      ("nejrychlejší", "fastest (nej-)"),
      ("nejstarší", "oldest"),
      ("Praha je větší než Brno.", "Prague is bigger than Brno."),
      ("lepší", "better (irregular: dobrý)"),
      ("nejlepší", "best"),
      ("horší", "worse (irregular: špatný)"),
      ("větší", "bigger (irregular: velký)"),
      ("menší", "smaller (irregular: malý)")]),

22: ("Joining Words (Conjunctions)",
     "With \"because,\" \"when,\" and \"that,\" you'll stitch short lines into "
     "flowing Czech.",
     "Real fluency isn't longer words — it's smoother sentences. With "
     "'because', 'when', and 'that', you'll stitch your short lines into "
     "flowing Czech, and dodge one sneaky word-order trap.",
     [("že", "that"),
      ("Myslím, že je to dobré.", "I think (that) it's good."),
      ("protože", "because"),
      ("když", "when"),
      ("Když prší, jsem doma.", "When it rains, I'm at home."),
      ("jestli", "if / whether"),
      ("až", "when (in the future)"),
      ("aby", "so that (needs the conditional)")]),

23: ("Modal Verbs",
     "Must, can, may, want — snap them in front of any action and your "
     "sentences level up.",
     "Must, can, may, want — four verbs that instantly make you sound more "
     "grown-up in Czech. Snap them in front of any action and watch your "
     "sentences level up.",
     [("muset", "must / to have to"),
      ("Musím jít.", "I have to go."),
      ("moct", "can / to be able"),
      ("můžu", "I can"),
      ("smět", "to be allowed"),
      ("smím", "I may"),
      ("chtít", "to want"),
      ("chci", "I want"),
      ("Můžu vám pomoct?", "Can I help you?")]),

24: ("Body & Health",
     "The parts of the body and the phrase \"Bolí mě…\" — so a doctor's visit "
     "stops being scary.",
     "Sooner or later, everyone needs to say what hurts. Learn the parts of the "
     "body and the phrase 'Bolí mě…', and a Czech doctor's visit stops being "
     "scary.",
     [("hlava", "head"), ("ruka", "hand / arm"), ("noha", "leg / foot"),
      ("oko", "eye"), ("ucho", "ear"), ("břicho", "belly"),
      ("záda", "back"), ("zub", "tooth"),
      ("Bolí mě hlava.", "My head hurts."),
      ("Jsem nemocný.", "I'm sick. (male)"),
      ("lékař", "doctor"),
      ("lékárna", "pharmacy"),
      ("lék", "medicine")]),

25: ("Jobs & Study",
     "The professions, the workplace words, and a confident answer to "
     "\"So, what do you do?\"",
     "'So, what do you do?' It's the question at every party and interview. "
     "Let's give you the professions, the workplace words, and a confident "
     "answer.",
     [("učitel", "teacher (male)"),
      ("učitelka", "teacher (female)"),
      ("lékař", "doctor"),
      ("inženýr", "engineer"),
      ("prodavač", "shop assistant"),
      ("řidič", "driver"),
      ("student", "student"),
      ("Pracuju jako…", "I work as…"),
      ("kancelář", "office"),
      ("kolega", "colleague"),
      ("plat", "salary"),
      ("studovat", "to study"),
      ("univerzita", "university"),
      ("zkouška", "exam")]),

26: ("Home & Rooms",
     "The rooms, the furniture, and how to say where everything is. Let's make "
     "yourself at home.",
     "Hunting for a flat in Czechia? This is your survival kit — the rooms, the "
     "furniture, and how to say where everything is. Let's make yourself at "
     "home.",
     [("kuchyně", "kitchen"), ("ložnice", "bedroom"),
      ("koupelna", "bathroom"), ("obývák", "living room"),
      ("záchod", "toilet"),
      ("stůl", "table"), ("židle", "chair"), ("postel", "bed"),
      ("skříň", "wardrobe"), ("lednička", "fridge"),
      ("Bydlím v bytě.", "I live in a flat."),
      ("pronájem", "rent"),
      ("Kde je…?", "Where is…?")]),

27: ("Verbs of Motion",
     "On foot or by car, once or every day — and a single prefix shifts the "
     "meaning again.",
     "Czech is famously fussy about movement: on foot or by car, once or every "
     "day — and a single prefix can shift the meaning again. It's the trickiest "
     "corner of A2, and the most satisfying to crack.",
     [("jít", "to go on foot (now)"),
      ("chodit", "to go on foot (regularly)"),
      ("jet", "to go by vehicle (now)"),
      ("jezdit", "to go by vehicle (regularly)"),
      ("přijít", "to arrive (on foot)"),
      ("odejít", "to leave (on foot)"),
      ("přijet", "to arrive (by vehicle)"),
      ("odjet", "to leave (by vehicle)"),
      ("Chodím do práce pěšky.", "I walk to work."),
      ("Dnes jedu autobusem.", "Today I'm going by bus.")]),

28: ("How the A1 Exam Works",
     "The A1 exam has four parts — reading, listening, writing, and speaking. "
     "Three tips carry you through: read the questions first so you know what to "
     "look for; don't freeze on an unknown word — the context usually gives it "
     "away; and answer everything, because a guess always beats a blank.",
     "You've built the foundations — now let's aim them at the exam. We'll walk "
     "through exactly what the A1 test asks of you and the tactics that turn "
     "nerves into confidence.",
     []),

29: ("How the A2 Exam Works",
     "The A2 exam — the one that opens the door to permanent residence — also "
     "covers reading, listening, writing, and speaking, at a higher level. "
     "Watch your time in each section, lean on context for unfamiliar words, "
     "and keep your written and spoken answers clear, complete, and on-topic.",
     "This is the big one: the A2 exam that opens the door to permanent "
     "residence. Let's demystify every section and sharpen the strategies that "
     "matter most.",
     []),

30: ("A1 in a Nutshell",
     "Everything from A1 as one system: gender endings, nominative vs. "
     "accusative, and the three present-tense verb classes working together. "
     "Tap the examples to hear them.",
     "Before you move on, let's make everything click as one system — genders, "
     "cases, and the present tense working together instead of as separate "
     "rules.",
     [("To je káva.", "This is a coffee. (nominative)"),
      ("Dám si kávu.", "I'll have a coffee. (accusative)"),
      ("Mám dobrého kamaráda.", "I have a good friend. (adjective agrees)"),
      ("Dělám. Mluvím. Čtu.", "I do. I speak. I read. (three verb classes)")]),

31: ("A2 in a Nutshell",
     "The whole case system and every tense together: the seven cases at a "
     "glance, plus past, future, and conditional. Tap the examples to hear "
     "them.",
     "The finish line. Let's bring the whole case system and every tense "
     "together one last time — because once this clicks, you're ready for Czech "
     "out in the wild.",
     [("kniha bratra", "the brother's book (genitive)"),
      ("Dávám kamarádovi dárek.", "I give my friend a gift. (dative)"),
      ("Byl jsem v Praze.", "I was in Prague. (past)"),
      ("Budu pracovat.", "I will work. (future)"),
      ("Chtěl bych kávu.", "I'd like a coffee. (conditional)")]),
}


def first_lesson_file(unit_id):
    """The lesson file with the smallest order_in_unit for this unit."""
    best = None
    for f in glob.glob(os.path.join(LESSONS, '*.json')):
        d = json.load(open(f))
        if d.get('unit_id') != unit_id:
            continue
        order = d.get('order_in_unit', 99)
        if best is None or order < best[0]:
            best = (order, f, d)
    return best  # (order, path, data)


def build_card(unit_id, lesson_id, heading, body, intro, rows):
    items = [{"cz": cz, "en": en} for cz, en in rows]
    data = {
        "type": "teaching",
        "heading": heading,
        "body": body,
        "intro": intro,
        "style": "list",
    }
    if items:
        data["play_all_label"] = "Play all"
        data["items"] = items
    return {
        "id": 90000 + unit_id,
        "lesson_id": lesson_id,
        "type": "teaching",
        "prompt": heading,
        "data": data,
        "xp_reward": 0,
    }


def main():
    changed = 0

    # 1. Patch intros into the already-built cards (Units 1 & 9).
    for unit_id, intro in INTRO_ONLY.items():
        order, path, d = first_lesson_file(unit_id)
        ex0 = d['exercises'][0]
        assert ex0['type'] == 'teaching', f"unit {unit_id} first ex is not teaching"
        if ex0['data'].get('intro') != intro:
            ex0['data']['intro'] = intro
            json.dump(d, open(path, 'w'), ensure_ascii=False, indent=2)
            print(f"unit {unit_id:2}: patched intro into {os.path.basename(path)}")
            changed += 1

    # 2. Insert / replace the generated card for every other unit.
    for unit_id, (heading, body, intro, rows) in sorted(UNITS.items()):
        order, path, d = first_lesson_file(unit_id)
        lesson_id = d['id']
        card = build_card(unit_id, lesson_id, heading, body, intro, rows)
        exs = d['exercises']
        gen_id = 90000 + unit_id
        if exs and exs[0].get('id') == gen_id:
            exs[0] = card              # replace generated card
            action = "replaced"
        else:
            # Defensive: drop any stray generated card elsewhere, then prepend.
            d['exercises'] = [e for e in exs if e.get('id') != gen_id]
            d['exercises'].insert(0, card)
            action = "inserted"
        json.dump(d, open(path, 'w'), ensure_ascii=False, indent=2)
        print(f"unit {unit_id:2}: {action} card ({len(rows)} rows) → "
              f"{os.path.basename(path)}")
        changed += 1

    print(f"\nDone. {changed} lesson files updated.")


if __name__ == '__main__':
    main()
