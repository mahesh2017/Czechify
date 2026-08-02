import 'dart:convert';
import 'dart:io';

typedef Pair = ({String cz, String en});

class Focus {
  const Focus({
    required this.title,
    required this.description,
    required this.canDo,
    required this.items,
    required this.transcript,
    required this.listenQuestion,
    required this.listenOptions,
    required this.readingCz,
    required this.readingEn,
    required this.readingQuestion,
    required this.readingOptions,
    required this.partnerCues,
    required this.writingPrompt,
    this.transferTranscript,
    this.transferQuestion,
    this.transferOptions,
  });

  final String title;
  final String description;
  final String canDo;
  final List<Pair> items;
  final String transcript;
  final String listenQuestion;
  final List<String> listenOptions;
  final String readingCz;
  final String readingEn;
  final String readingQuestion;
  final List<String> readingOptions;
  final List<String> partnerCues;
  final String writingPrompt;
  final String? transferTranscript;
  final String? transferQuestion;
  final List<String>? transferOptions;
}

class UnitPlan {
  const UnitPlan({
    required this.unit,
    required this.recycles,
    required this.sceneImage,
    required this.diagramImage,
    required this.imageLabel,
    required this.missionPrompt,
    required this.focuses,
  });

  final int unit;
  final List<String> recycles;
  final String sceneImage;
  final String diagramImage;
  final String imageLabel;
  final String missionPrompt;
  final List<Focus> focuses;
}

Pair p(String cz, String en) => (cz: cz, en: en);

final plans = <UnitPlan>[
  UnitPlan(
    unit: 4,
    recycles: ['Dobrý den', 'Jmenuju se…', 'To je…', 'ten/ta/to'],
    sceneImage: 'assets/images/unit04/profile_inventory_v1.png',
    diagramImage: 'assets/images/unit04/identity_pattern_v1.png',
    imageLabel: 'Identity and possessions: statement, question, and negative',
    missionPrompt:
        'Record a 20–30 second profile: introduce yourself, say where you are, and name something you have and something you do not have.',
    focuses: [
      Focus(
        title: 'Meet a New Colleague',
        description:
            'Understand a short workplace introduction and exchange identity and possession facts.',
        canDo: 'introduce myself and say what I have at work.',
        items: [
          p('Jsem nová kolegyně.', 'I am a new colleague.'),
          p('Jsem student.', 'I am a student.'),
          p('Mám notebook.', 'I have a laptop.'),
          p('Nemám klíč.', 'I do not have a key.'),
        ],
        transcript:
            'Dobrý den, jsem Eva. Jsem nová kolegyně. Mám notebook, ale nemám klíč.',
        listenQuestion: 'What does Eva not have?',
        listenOptions: ['A key', 'A laptop', 'A telephone'],
        readingCz:
            'To je Marek. Je nový kolega. Má telefon a kartu. Dnes není doma.',
        readingEn:
            'This is Marek. He is a new colleague. He has a phone and a card. Today he is not at home.',
        readingQuestion: 'Which two things does Marek have?',
        readingOptions: [
          'A phone and a card',
          'A key and a car',
          'Coffee and a book',
        ],
        partnerCues: ['Dobrý den. Jste tady nová?', 'Máte klíč?'],
        writingPrompt:
            'Write three short facts: who you are, one thing you have, and one thing you do not have.',
        transferTranscript: 'Tomáš je učitel. Dnes je doma a nemá telefon.',
        transferQuestion: 'Where is Tomáš today?',
        transferOptions: ['At home', 'At school', 'At a café'],
      ),
      Focus(
        title: 'Say It, Ask It, Negate It',
        description:
            'Turn useful být and mít statements into simple questions and negatives.',
        canDo: 'ask and answer simple questions with být and mít.',
        items: [
          p('Jsi doma?', 'Are you at home?'),
          p('Nejsem doma.', 'I am not at home.'),
          p('Máš auto?', 'Do you have a car?'),
          p('Nemám auto.', 'I do not have a car.'),
        ],
        transcript:
            'Jsi doma? Ne, nejsem doma. Jsem v práci. Máš auto? Ne, nemám auto.',
        listenQuestion: 'Where is the second speaker?',
        listenOptions: ['At work', 'At home', 'In a car'],
        readingCz: 'Petra není studentka. Je učitelka. Nemá auto, ale má kolo.',
        readingEn:
            'Petra is not a student. She is a teacher. She does not have a car, but she has a bicycle.',
        readingQuestion: 'What does Petra have?',
        readingOptions: ['A bicycle', 'A car', 'A laptop'],
        partnerCues: ['Jsi student?', 'Máš auto?'],
        writingPrompt:
            'Write two questions and two truthful answers with jsi/jste and máš/máte.',
        transferTranscript: 'Nejsem v kanceláři. Jsem doma a mám tady počítač.',
        transferQuestion: 'What is at home with the speaker?',
        transferOptions: ['A computer', 'A bicycle', 'A key'],
      ),
      Focus(
        title: 'A Short Profile Interview',
        description:
            'Listen for contrasting personal details and conduct a short profile interview.',
        canDo: 'exchange several identity and possession details.',
        items: [
          p('Jste student?', 'Are you a student?'),
          p('Ano, jsem.', 'Yes, I am.'),
          p('Máte telefon?', 'Do you have a phone?'),
          p('Ano, mám.', 'Yes, I do.'),
        ],
        transcript:
            'Jste student? Ano, jsem. Jste z Prahy? Ne, nejsem. Máte telefon? Ano, mám.',
        listenQuestion: 'Which answer is negative?',
        listenOptions: [
          'The answer about Prague',
          'The answer about studying',
          'The answer about the phone',
        ],
        readingCz:
            'Lucie je z Brna. Je studentka a má nový batoh. Nemá notebook.',
        readingEn:
            'Lucie is from Brno. She is a student and has a new backpack. She does not have a laptop.',
        readingQuestion: 'Which item does Lucie not have?',
        readingOptions: ['A laptop', 'A backpack', 'A phone'],
        partnerCues: ['Jste student?', 'Máte telefon?'],
        writingPrompt:
            'Create a four-question mini interview about identity, origin, and possessions.',
        transferTranscript:
            'Jmenuju se David. Nejsem učitel. Jsem student a mám nový telefon.',
        transferQuestion: 'What is David?',
        transferOptions: ['A student', 'A teacher', 'A doctor'],
      ),
      Focus(
        title: 'Mission: My Profile',
        description:
            'Bring introductions, být, mít, questions, and negatives into one personal profile.',
        canDo: 'give and answer a useful personal profile.',
        items: [
          p('Jmenuju se…', 'My name is…'),
          p('Jsem z…', 'I am from…'),
          p('Mám…', 'I have…'),
          p('Nemám…', 'I do not have…'),
        ],
        transcript:
            'Jmenuju se Nina. Jsem z Polska. Jsem doma. Mám telefon, ale nemám auto.',
        listenQuestion: 'Which possession is missing?',
        listenOptions: ['A car', 'A phone', 'A key'],
        readingCz: 'Profil: Adam, student, Praha. Má kolo a klíče. Nemá auto.',
        readingEn:
            'Profile: Adam, student, Prague. He has a bicycle and keys. He does not have a car.',
        readingQuestion: 'Which statement about Adam is true?',
        readingOptions: ['He has a bicycle', 'He has a car', 'He is a teacher'],
        partnerCues: ['Jak se jmenujete?', 'Co máte?'],
        writingPrompt:
            'Write a four-line personal profile that you can use as your speaking plan.',
      ),
    ],
  ),
  UnitPlan(
    unit: 5,
    recycles: ['Jmenuju se…', 'Jsem…', 'Jste…?', 'Ano/Ne'],
    sceneImage: 'assets/images/unit05/activity_profiles_v1.png',
    diagramImage: 'assets/images/unit05/activity_questions_v1.png',
    imageLabel: 'Everyday activity profiles and matching questions',
    missionPrompt:
        'Record four personal activity answers: what you do, where you live, which language you speak, and what you understand.',
    focuses: [
      Focus(
        title: 'Meet People in Action',
        description:
            'Understand short profiles about working, studying, living, and speaking.',
        canDo: 'say what I do and where I live.',
        items: [
          p('Pracuju v Praze.', 'I work in Prague.'),
          p('Studuju češtinu.', 'I study Czech.'),
          p('Bydlím v Brně.', 'I live in Brno.'),
          p('Mluvím anglicky.', 'I speak English.'),
        ],
        transcript:
            'Jmenuju se Sara. Bydlím v Brně, studuju češtinu a mluvím anglicky.',
        listenQuestion: 'Where does Sara live?',
        listenOptions: ['In Brno', 'In Prague', 'In Ostrava'],
        readingCz:
            'Pavel bydlí v Praze. Pracuje v hotelu a mluví česky a německy.',
        readingEn:
            'Pavel lives in Prague. He works in a hotel and speaks Czech and German.',
        readingQuestion: 'Where does Pavel work?',
        readingOptions: ['In a hotel', 'In a school', 'In a bank'],
        partnerCues: ['Co děláte?', 'Kde bydlíte?'],
        writingPrompt:
            'Write three sentences about where you live, work or study, and one language you speak.',
        transferTranscript: 'Eva pracuje v kavárně a bydlí v Olomouci.',
        transferQuestion: 'Where does Eva work?',
        transferOptions: ['In a café', 'In a hotel', 'At home'],
      ),
      Focus(
        title: 'Ask About Everyday Activities',
        description:
            'Use friendly and formal questions to learn what another person does.',
        canDo: 'ask what someone does, where they live, and what they speak.',
        items: [
          p('Co děláš?', 'What do you do?'),
          p('Kde bydlíš?', 'Where do you live?'),
          p('Co děláte?', 'What do you do? (formal)'),
          p('Kde bydlíte?', 'Where do you live? (formal)'),
        ],
        transcript:
            'Co děláte? Pracuju v obchodě. Kde bydlíte? Bydlím v Plzni.',
        listenQuestion: 'Where does the speaker live?',
        listenOptions: ['In Plzeň', 'In Prague', 'In Brno'],
        readingCz:
            'Ahoj, jsem Mila. Studuju medicínu. Bydlím v Praze a mluvím ukrajinsky.',
        readingEn:
            'Hi, I am Mila. I study medicine. I live in Prague and speak Ukrainian.',
        readingQuestion: 'What does Mila study?',
        readingOptions: ['Medicine', 'Czech', 'Music'],
        partnerCues: ['Co děláš?', 'Kde bydlíš?'],
        writingPrompt:
            'Write one friendly and one formal question about everyday activities.',
        transferTranscript: 'Kde bydlíš? Bydlím v Liberci. Co děláš? Studuju.',
        transferQuestion: 'What does the second speaker do?',
        transferOptions: ['Studies', 'Works', 'Reads'],
      ),
      Focus(
        title: 'Match Voices to Profiles',
        description:
            'Listen for activity, place, and language details in several short profiles.',
        canDo: 'identify a person from activity and language clues.',
        items: [
          p('Čtu česky.', 'I read in Czech.'),
          p('Rozumím trochu.', 'I understand a little.'),
          p('Nemluvím dobře česky.', 'I do not speak Czech well.'),
          p('Pracuju doma.', 'I work at home.'),
        ],
        transcript:
            'Pracuju doma. Čtu česky a rozumím trochu, ale nemluvím dobře česky.',
        listenQuestion: 'How well does the speaker understand?',
        listenOptions: ['A little', 'Not at all', 'Perfectly'],
        readingCz:
            'Profil B: Amir pracuje v restauraci. Mluví anglicky a trochu česky.',
        readingEn:
            'Profile B: Amir works in a restaurant. He speaks English and a little Czech.',
        readingQuestion: 'Which language does Amir speak only a little?',
        readingOptions: ['Czech', 'English', 'German'],
        partnerCues: ['Rozumíš česky?', 'Pracuješ doma?'],
        writingPrompt:
            'Create a short profile with one activity, one language, and an understanding level.',
        transferTranscript:
            'Lena studuje v Brně. Mluví polsky a česky rozumí dobře.',
        transferQuestion: 'Which language does Lena understand well?',
        transferOptions: ['Czech', 'Polish', 'English'],
      ),
      Focus(
        title: 'Mission: What Do You Do?',
        description:
            'Combine activity questions and personal answers in one natural exchange.',
        canDo: 'hold a short conversation about everyday activities.',
        items: [
          p('Pracuju…', 'I work…'),
          p('Bydlím…', 'I live…'),
          p('Mluvím…', 'I speak…'),
          p('Rozumím…', 'I understand…'),
        ],
        transcript:
            'Pracuju v kanceláři, bydlím v Praze, mluvím anglicky a rozumím trochu česky.',
        listenQuestion: 'What does the speaker understand?',
        listenOptions: ['A little Czech', 'A little English', 'No Czech'],
        readingCz: 'Vizitka: Hana, Brno, učitelka. Mluví česky a anglicky.',
        readingEn:
            'Profile card: Hana, Brno, teacher. She speaks Czech and English.',
        readingQuestion: 'What is Hana’s job?',
        readingOptions: ['Teacher', 'Student', 'Doctor'],
        partnerCues: ['Co děláte?', 'Jakými jazyky mluvíte?'],
        writingPrompt:
            'Write four personal answers as a speaking plan for the final mission.',
      ),
    ],
  ),
  UnitPlan(
    unit: 6,
    recycles: ['Dobrý den', 'Máte…?', 'Ano/Ne', 'Prosím', 'Nerozumím'],
    sceneImage: 'assets/images/unit06/cafe_counter_v1.png',
    diagramImage: 'assets/images/unit06/request_pattern_v1.png',
    imageLabel: 'Polite request pattern and common object-form changes',
    missionPrompt:
        'Record a polite two-item order: greet, ask whether an item is available, order food and drink, and close politely.',
    focuses: [
      Focus(
        title: 'At the Café Counter',
        description:
            'Understand a simple café exchange and request food and drink politely.',
        canDo: 'order one food and one drink politely.',
        items: [
          p('Dám si kávu.', 'I will have coffee.'),
          p('Dám si čaj.', 'I will have tea.'),
          p('Vodu, prosím.', 'Water, please.'),
          p('Máte polévku?', 'Do you have soup?'),
        ],
        transcript:
            'Dobrý den. Máte polévku? Ano. Dám si polévku a vodu, prosím.',
        listenQuestion: 'What does the customer order to drink?',
        listenOptions: ['Water', 'Coffee', 'Tea'],
        readingCz:
            'Dnes máme rajčatovou polévku, kuře s rýží, kávu, čaj a vodu.',
        readingEn:
            'Today we have tomato soup, chicken with rice, coffee, tea, and water.',
        readingQuestion: 'Which main dish is available?',
        readingOptions: ['Chicken with rice', 'Fish with potatoes', 'Pizza'],
        partnerCues: ['Dobrý den. Co si dáte?', 'A co k pití?'],
        writingPrompt: 'Write a polite café order with one food and one drink.',
        transferTranscript: 'Prosím jednu kávu a jeden čaj. Polévku nechci.',
        transferQuestion: 'How many drinks are ordered?',
        transferOptions: ['Two', 'One', 'Three'],
      ),
      Focus(
        title: 'Choose the Useful Object Form',
        description:
            'Notice common object-form changes inside requests without memorising a full case table.',
        canDo: 'use common food and drink words after chci and dám si.',
        items: [
          p('káva → kávu', 'coffee: object form'),
          p('voda → vodu', 'water: object form'),
          p('polévka → polévku', 'soup: object form'),
          p('pivo → pivo', 'beer: unchanged object form'),
        ],
        transcript: 'Chci kávu a vodu. Petr chce pivo a polévku.',
        listenQuestion: 'What does Petr want with beer?',
        listenOptions: ['Soup', 'Coffee', 'Water'],
        readingCz: 'Anna chce kávu. David chce čaj. Eva si dá vodu a pivo.',
        readingEn:
            'Anna wants coffee. David wants tea. Eva will have water and beer.',
        readingQuestion: 'Who wants tea?',
        readingOptions: ['David', 'Anna', 'Eva'],
        partnerCues: ['Co chcete?', 'A co si dáte k pití?'],
        writingPrompt:
            'Write four short requests using kávu, vodu, polévku, and one unchanged noun.',
        transferTranscript: 'Máte limonádu? Ano. Tak si dám limonádu, prosím.',
        transferQuestion: 'What does the customer choose?',
        transferOptions: ['Lemonade', 'Water', 'Soup'],
      ),
      Focus(
        title: 'Handle a Simple Order',
        description:
            'Confirm availability, accept an alternative, and repair a misunderstanding.',
        canDo: 'confirm or change a simple order.',
        items: [
          p('Ano, máme.', 'Yes, we have it.'),
          p('Bohužel nemáme.', 'Unfortunately, we do not have it.'),
          p('Tak si dám čaj.', 'Then I will have tea.'),
          p('Ještě jednou, prosím.', 'Once again, please.'),
        ],
        transcript:
            'Máte kávu? Bohužel nemáme. Tak si dám čaj. Ještě jednou, prosím? Čaj.',
        listenQuestion: 'Why does the customer choose tea?',
        listenOptions: [
          'Coffee is unavailable',
          'Tea is free',
          'Water is unavailable',
        ],
        readingCz:
            'Kavárna: Káva dnes není. Máme čaj, vodu a pomerančovou limonádu.',
        readingEn:
            'Café: Coffee is unavailable today. We have tea, water, and orange lemonade.',
        readingQuestion: 'Which drink is unavailable?',
        readingOptions: ['Coffee', 'Tea', 'Lemonade'],
        partnerCues: ['Bohužel kávu nemáme.', 'Dáte si čaj?'],
        writingPrompt:
            'Write a two-line response accepting an alternative when your first choice is unavailable.',
        transferTranscript: 'Promiňte, nerozumím. Máte vodu? Ano, máme.',
        transferQuestion: 'Which repair phrase is used?',
        transferOptions: ['Promiňte, nerozumím', 'Na shledanou', 'Těší mě'],
      ),
      Focus(
        title: 'Mission: Order Two Items',
        description:
            'Combine greeting, availability, ordering, repair, and thanks in one café mission.',
        canDo: 'complete a short café order even when one item changes.',
        items: [
          p('Dobrý den.', 'Hello.'),
          p('Máte…?', 'Do you have…?'),
          p('Dám si…, prosím.', 'I will have…, please.'),
          p('Děkuju. Na shledanou.', 'Thank you. Goodbye.'),
        ],
        transcript:
            'Dobrý den. Máte polévku? Ano. Dám si polévku a čaj, prosím. Děkuju.',
        listenQuestion: 'Which two items are ordered?',
        listenOptions: ['Soup and tea', 'Coffee and cake', 'Water and bread'],
        readingCz: 'Objednávka: jedna polévka, jeden čaj. Cena: 145 Kč.',
        readingEn: 'Order: one soup, one tea. Price: 145 CZK.',
        readingQuestion: 'How much does the order cost?',
        readingOptions: ['145 CZK', '125 CZK', '154 CZK'],
        partnerCues: ['Dobrý den. Co si dáte?', 'Je to všechno?'],
        writingPrompt:
            'Write your complete café mission as four short lines before recording it.',
      ),
    ],
  ),
  UnitPlan(
    unit: 7,
    recycles: ['To je…', 'ten/ta/to', 'Mám/Nemám', 'Ano/Ne'],
    sceneImage: 'assets/images/unit07/lost_property_v1.png',
    diagramImage: 'assets/images/unit07/ownership_pattern_v1.png',
    imageLabel: 'Ownership words matched to common belongings',
    missionPrompt:
        'Record two ownership questions and answers, then return one item to yourself and one to another person.',
    focuses: [
      Focus(
        title: 'At Lost Property',
        description:
            'Recognise common belongings and ask whether an item belongs to someone.',
        canDo: 'ask whether a common item is mine or yours.',
        items: [
          p('To je můj telefon.', 'That is my phone.'),
          p('To je moje taška.', 'That is my bag.'),
          p('Je to váš klíč?', 'Is it your key?'),
          p('Ano, je můj.', 'Yes, it is mine.'),
        ],
        transcript:
            'Dobrý den. Je to váš klíč? Ano, je můj. A ta taška? Ta není moje.',
        listenQuestion: 'Which item belongs to the speaker?',
        listenOptions: ['The key', 'The bag', 'The phone'],
        readingCz:
            'Nalezené věci: černý telefon, modrá taška, dva klíče a kniha.',
        readingEn:
            'Found items: a black phone, a blue bag, two keys, and a book.',
        readingQuestion: 'Which item is blue?',
        readingOptions: ['The bag', 'The phone', 'The book'],
        partnerCues: ['Je to váš telefon?', 'A je to vaše taška?'],
        writingPrompt: 'Write labels for three belongings using můj or moje.',
        transferTranscript: 'Tahle kniha je moje, ale ten telefon není můj.',
        transferQuestion: 'Which item belongs to the speaker?',
        transferOptions: ['The book', 'The phone', 'Both items'],
      ),
      Focus(
        title: 'Name the Owner',
        description: 'Use your, his, and her in short ownership statements.',
        canDo: 'identify whether something is yours, his, or hers.',
        items: [
          p('To je tvůj batoh.', 'That is your backpack.'),
          p('To je tvoje kniha.', 'That is your book.'),
          p('To je jeho kolo.', 'That is his bicycle.'),
          p('To je její telefon.', 'That is her phone.'),
        ],
        transcript: 'Batoh je tvůj. Kolo je jeho a telefon je její.',
        listenQuestion: 'Which item belongs to her?',
        listenOptions: ['The phone', 'The bicycle', 'The backpack'],
        readingCz:
            'Anna má knihu a Petr má kolo. To je její kniha a jeho kolo.',
        readingEn:
            'Anna has a book and Petr has a bicycle. That is her book and his bicycle.',
        readingQuestion: 'Who owns the bicycle?',
        readingOptions: ['Petr', 'Anna', 'Both'],
        partnerCues: ['Je to můj batoh?', 'Čí je ten telefon?'],
        writingPrompt:
            'Write four ownership sentences using tvůj/tvoje, jeho, and její.',
        transferTranscript: 'To není moje taška. Je tvoje. Můj batoh je tady.',
        transferQuestion: 'What belongs to the speaker?',
        transferOptions: ['The backpack', 'The bag', 'Both'],
      ),
      Focus(
        title: 'Return the Right Item',
        description:
            'Follow ownership clues and return several items to the correct people.',
        canDo: 'return an item to the correct owner.',
        items: [
          p('Tady je váš telefon.', 'Here is your phone.'),
          p('Tady je vaše taška.', 'Here is your bag.'),
          p('Děkuju, je můj.', 'Thank you, it is mine.'),
          p('Ne, není můj.', 'No, it is not mine.'),
        ],
        transcript:
            'Tady je vaše taška. Děkuju, je moje. A telefon? Ne, není můj.',
        listenQuestion: 'Which item is rejected?',
        listenOptions: ['The phone', 'The bag', 'The key'],
        readingCz: 'Pokoj 12: telefon pana Nováka. Pokoj 14: taška paní Malé.',
        readingEn: 'Room 12: Mr Novák’s phone. Room 14: Ms Malá’s bag.',
        readingQuestion: 'Which item goes to room 14?',
        readingOptions: ['The bag', 'The phone', 'The key'],
        partnerCues: ['Tady je váš telefon.', 'A je tahle taška vaše?'],
        writingPrompt:
            'Write two short exchanges that return one correct item and reject one wrong item.',
        transferTranscript: 'Klíče jsou jeho. Kniha je její. Taška je moje.',
        transferQuestion: 'Which item belongs to the speaker?',
        transferOptions: ['The bag', 'The keys', 'The book'],
      ),
      Focus(
        title: 'Mission: Whose Is It?',
        description:
            'Combine questions, ownership clues, and polite returns in a lost-property mission.',
        canDo: 'solve a short lost-property situation.',
        items: [
          p('Čí je to?', 'Whose is it?'),
          p('Je to moje.', 'It is mine.'),
          p('To je jeho.', 'That is his.'),
          p('Tady máte.', 'Here you are.'),
        ],
        transcript:
            'Čí je ta kniha? Je moje. A ten telefon? To je jeho. Tady máte.',
        listenQuestion: 'Which item belongs to him?',
        listenOptions: ['The phone', 'The book', 'The bag'],
        readingCz:
            'Ztráty a nálezy: Jana – kniha; Omar – telefon; já – černá taška.',
        readingEn: 'Lost property: Jana – book; Omar – phone; me – black bag.',
        readingQuestion: 'Who owns the phone?',
        readingOptions: ['Omar', 'Jana', 'The narrator'],
        partnerCues: ['Čí je ta kniha?', 'A čí je ten telefon?'],
        writingPrompt:
            'Write a four-line lost-property solution to use as your speaking plan.',
      ),
    ],
  ),
  UnitPlan(
    unit: 8,
    recycles: ['Kdo je to?', 'To je…', 'můj/moje', 'je', 'má'],
    sceneImage: 'assets/images/unit08/family_people_v1.png',
    diagramImage: 'assets/images/unit08/people_description_v1.png',
    imageLabel: 'Family relationships and simple description agreement',
    missionPrompt:
        'Record a short introduction to three important people. Say who they are and give at least two simple descriptions.',
    focuses: [
      Focus(
        title: 'Meet the People in the Photo',
        description:
            'Identify close family and other important people in a photo.',
        canDo: 'introduce common family members.',
        items: [
          p('To je moje maminka.', 'This is my mother.'),
          p('To je můj tatínek.', 'This is my father.'),
          p('To je moje sestra.', 'This is my sister.'),
          p('To je můj bratr.', 'This is my brother.'),
        ],
        transcript:
            'To je moje rodina. Tohle je moje maminka, můj tatínek a moje sestra Klára.',
        listenQuestion: 'What is the sister’s name?',
        listenOptions: ['Klára', 'Anna', 'Petra'],
        readingCz: 'Na fotografii je Pavel, jeho žena Jana a jejich syn Matěj.',
        readingEn:
            'In the photograph are Pavel, his wife Jana, and their son Matěj.',
        readingQuestion: 'Who is Matěj?',
        readingOptions: ['Their son', 'Their brother', 'Their father'],
        partnerCues: ['Kdo je to?', 'A kdo je tahle žena?'],
        writingPrompt: 'Label four people in a photo with To je můj/moje…',
        transferTranscript:
            'Mám jednoho bratra a dvě sestry. Bratr se jmenuje Adam.',
        transferQuestion: 'How many sisters does the speaker have?',
        transferOptions: ['Two', 'One', 'Three'],
      ),
      Focus(
        title: 'Describe Someone Simply',
        description:
            'Connect a person to one or two useful qualities with basic agreement.',
        canDo: 'give a simple description of a man or woman.',
        items: [
          p('Petr je milý.', 'Petr is kind.'),
          p('Anna je milá.', 'Anna is kind.'),
          p('Bratr je mladý.', 'The brother is young.'),
          p('Sestra je mladá.', 'The sister is young.'),
        ],
        transcript:
            'To je Anna. Je milá a mladá. Její bratr Petr je také mladý.',
        listenQuestion: 'Who is described as kind?',
        listenOptions: ['Anna', 'Petr', 'Both people'],
        readingCz: 'Můj dědeček je starý a milý. Moje babička je také milá.',
        readingEn:
            'My grandfather is old and kind. My grandmother is also kind.',
        readingQuestion: 'Which quality describes both grandparents?',
        readingOptions: ['Kind', 'Young', 'Tall'],
        partnerCues: ['Jaký je Petr?', 'Jaká je Anna?'],
        writingPrompt:
            'Write two descriptions of a man and two of a woman using matching adjective forms.',
        transferTranscript: 'Moje kamarádka je veselá a můj kamarád je klidný.',
        transferQuestion: 'Who is cheerful?',
        transferOptions: ['The female friend', 'The male friend', 'Both'],
      ),
      Focus(
        title: 'Tell a Short Family Story',
        description:
            'Combine relationships, names, places, and descriptions in a short story.',
        canDo: 'tell several connected facts about people I know.',
        items: [
          p('Moje sestra se jmenuje Eva.', 'My sister’s name is Eva.'),
          p('Bydlí v Brně.', 'She lives in Brno.'),
          p('Je studentka.', 'She is a student.'),
          p('Má ráda hudbu.', 'She likes music.'),
        ],
        transcript:
            'Moje sestra se jmenuje Eva. Bydlí v Brně, je studentka a má ráda hudbu.',
        listenQuestion: 'What does Eva like?',
        listenOptions: ['Music', 'Sport', 'Books'],
        readingCz:
            'Můj kamarád Amir bydlí v Praze. Pracuje v hotelu a je velmi milý.',
        readingEn:
            'My friend Amir lives in Prague. He works in a hotel and is very kind.',
        readingQuestion: 'Where does Amir work?',
        readingOptions: ['In a hotel', 'In a restaurant', 'At school'],
        partnerCues: ['Jak se jmenuje vaše sestra?', 'Co dělá?'],
        writingPrompt:
            'Write four connected sentences about one family member or friend.',
        transferTranscript:
            'Můj bratr David pracuje doma. Mluví anglicky a rád čte.',
        transferQuestion: 'Where does David work?',
        transferOptions: ['At home', 'In a hotel', 'In a shop'],
      ),
      Focus(
        title: 'Mission: Introduce Three People',
        description:
            'Bring relationships, ownership, identity, activities, and descriptions together.',
        canDo: 'introduce and describe three important people.',
        items: [
          p('To je moje rodina.', 'This is my family.'),
          p('To je můj kamarád.', 'This is my friend.'),
          p('Jmenuje se…', 'His/her name is…'),
          p('Je milý/milá.', 'He/she is kind.'),
        ],
        transcript:
            'To je moje rodina. Moje maminka se jmenuje Jana. Je milá. Můj bratr Adam je student.',
        listenQuestion: 'Who is a student?',
        listenOptions: ['Adam', 'Jana', 'The narrator'],
        readingCz:
            'Lidé pro misi: maminka Jana – milá; bratr Adam – student; kamarád Leo – veselý.',
        readingEn:
            'People for the mission: mother Jana – kind; brother Adam – student; friend Leo – cheerful.',
        readingQuestion: 'Who is cheerful?',
        readingOptions: ['Leo', 'Adam', 'Jana'],
        partnerCues: ['Kdo je to?', 'Jaký nebo jaká je?'],
        writingPrompt:
            'Prepare three people cards with relationship, name, and one description.',
      ),
    ],
  ),
  UnitPlan(
    unit: 9,
    recycles: ['Mám…', 'Kde…?', 'dnes/zítra', 'Ano, dobře'],
    sceneImage: 'assets/images/unit09/making_a_plan_v1.png',
    diagramImage: 'assets/images/unit09/time_plan_v1.png',
    imageLabel: 'Phone numbers, clock time, and a simple meeting plan',
    missionPrompt:
        'Record a simple plan: exchange a contact detail, propose a day and time, name the meeting place, and confirm it.',
    focuses: [
      Focus(
        title: 'Hear the Important Numbers',
        description:
            'Recognise grouped phone numbers and distinguish similar number details.',
        canDo: 'understand and say a simple telephone number.',
        items: [
          p('nula, jedna, dva, tři', 'zero, one, two, three'),
          p('deset, jedenáct, dvanáct', 'ten, eleven, twelve'),
          p('dvacet, třicet, čtyřicet', 'twenty, thirty, forty'),
          p('Moje číslo je…', 'My number is…'),
        ],
        transcript:
            'Moje telefonní číslo je sedm set dva, čtyři sta třicet, osm set patnáct.',
        listenQuestion: 'Which is the final number group?',
        listenOptions: ['815', '850', '518'],
        readingCz: 'Kontakt: Eva Malá, telefon 702 430 815, kancelář 12.',
        readingEn: 'Contact: Eva Malá, telephone 702 430 815, office 12.',
        readingQuestion: 'What is Eva’s office number?',
        readingOptions: ['12', '15', '30'],
        partnerCues: ['Jaké máte telefonní číslo?', 'Můžete to zopakovat?'],
        writingPrompt:
            'Write your phone number in three spoken groups and add one repetition request.',
        transferTranscript:
            'Prosím číslo šest set osm, dvě stě čtyřicet, devět set jedenáct.',
        transferQuestion: 'What is the middle group?',
        transferOptions: ['240', '608', '911'],
      ),
      Focus(
        title: 'What Time Shall We Meet?',
        description: 'Ask for the time and propose a clear meeting hour.',
        canDo: 'ask and say when to meet.',
        items: [
          p('Kolik je hodin?', 'What time is it?'),
          p('Je deset hodin.', 'It is ten o’clock.'),
          p('V kolik se sejdeme?', 'What time shall we meet?'),
          p('V pět hodin.', 'At five o’clock.'),
        ],
        transcript:
            'V kolik se sejdeme? V pět hodin. Dobře, v sedmnáct hodin u metra.',
        listenQuestion: 'Which 24-hour time is confirmed?',
        listenOptions: ['17:00', '15:00', '19:00'],
        readingCz: 'Kavárna je otevřená od 8:00 do 18:00. Schůzka je v 16:30.',
        readingEn:
            'The café is open from 8:00 to 18:00. The meeting is at 16:30.',
        readingQuestion: 'When is the meeting?',
        readingOptions: ['16:30', '18:00', '8:00'],
        partnerCues: ['V kolik se sejdeme?', 'Můžeme v pět?'],
        writingPrompt:
            'Write one question and two possible meeting times in Czech.',
        transferTranscript: 'Kurz začíná v šest večer a končí v půl osmé.',
        transferQuestion: 'When does the course start?',
        transferOptions: ['At 18:00', 'At 19:30', 'At 16:00'],
      ),
      Focus(
        title: 'Confirm a Simple Plan',
        description:
            'Combine day, time, and place, then confirm or change one detail.',
        canDo: 'confirm a day, time, and meeting place.',
        items: [
          p('Můžeme v úterý?', 'Can we meet on Tuesday?'),
          p('Ano, v šest.', 'Yes, at six.'),
          p('Sejdeme se u metra.', 'We will meet by the metro.'),
          p('Platí.', 'Agreed.'),
        ],
        transcript:
            'Můžeme v úterý? Ano, v šest. Sejdeme se u metra. Dobře, platí.',
        listenQuestion: 'Where will they meet?',
        listenOptions: ['By the metro', 'At the station', 'In a café'],
        readingCz:
            'Zpráva: Ve středu nemůžu. Můžeme ve čtvrtek v 17:30 před knihovnou?',
        readingEn:
            'Message: I cannot on Wednesday. Can we meet Thursday at 17:30 in front of the library?',
        readingQuestion: 'Which day is proposed?',
        readingOptions: ['Thursday', 'Wednesday', 'Tuesday'],
        partnerCues: ['Můžeme ve středu?', 'Kde se sejdeme?'],
        writingPrompt:
            'Write a three-line message proposing a day, time, and place.',
        transferTranscript:
            'V pátek nemám čas. Sejdeme se v sobotu v deset u nádraží.',
        transferQuestion: 'Which day is the meeting?',
        transferOptions: ['Saturday', 'Friday', 'Sunday'],
      ),
      Focus(
        title: 'Mission: Arrange a Meeting',
        description:
            'Use numbers, contact details, time, and confirmation in one practical plan.',
        canDo: 'arrange and confirm a simple meeting.',
        items: [
          p('Máš čas zítra?', 'Do you have time tomorrow?'),
          p('V kolik?', 'At what time?'),
          p('Kde se sejdeme?', 'Where shall we meet?'),
          p('Dobře, platí.', 'Good, agreed.'),
        ],
        transcript:
            'Máš čas zítra? Ano. V kolik? V sedmnáct třicet. Sejdeme se v kavárně.',
        listenQuestion: 'What time is the meeting?',
        listenOptions: ['17:30', '16:30', '18:30'],
        readingCz: 'Plán: sobota 10:00, kavárna Luna, telefon 603 218 440.',
        readingEn: 'Plan: Saturday 10:00, Café Luna, telephone 603 218 440.',
        readingQuestion: 'Where is the meeting?',
        readingOptions: ['Café Luna', 'The station', 'The library'],
        partnerCues: ['Máš čas zítra?', 'Kde se sejdeme?'],
        writingPrompt:
            'Prepare a complete meeting message with day, time, place, and confirmation.',
      ),
    ],
  ),
  UnitPlan(
    unit: 10,
    recycles: ['time and days', 'pracuju/studuju', 'doma', 'mám', 'potom'],
    sceneImage: 'assets/images/unit10/daily_routine_storyboard_v1.png',
    diagramImage: 'assets/images/unit10/routine_sequence_v1.png',
    imageLabel: 'A daily routine timeline with se and si in natural position',
    missionPrompt:
        'Record a five-sentence daily routine from morning to night. Include times, potom, and one se or si expression.',
    focuses: [
      Focus(
        title: 'See a Day in Six Steps',
        description:
            'Follow a simple routine from waking up to going to sleep.',
        canDo: 'understand the main steps in a daily routine.',
        items: [
          p('Ráno vstávám.', 'I get up in the morning.'),
          p('Snídám v sedm.', 'I eat breakfast at seven.'),
          p('Potom pracuju.', 'Then I work.'),
          p('Večer spím.', 'I sleep at night.'),
        ],
        transcript:
            'Ráno vstávám v šest. Snídám v sedm, potom pracuju a večer jdu spát v deset.',
        listenQuestion: 'When does the speaker get up?',
        listenOptions: ['At six', 'At seven', 'At ten'],
        readingCz:
            'Marta ráno vstává, pije čaj a jede do práce. Večer čte a spí.',
        readingEn:
            'Marta gets up in the morning, drinks tea, and goes to work. In the evening she reads and sleeps.',
        readingQuestion: 'What does Marta drink?',
        readingOptions: ['Tea', 'Coffee', 'Water'],
        partnerCues: ['V kolik vstáváš?', 'Co děláš potom?'],
        writingPrompt: 'Write four routine steps using ráno, potom, and večer.',
        transferTranscript:
            'Petr vstává v sedm, pracuje od devíti a spí v jedenáct.',
        transferQuestion: 'When does Petr go to sleep?',
        transferOptions: ['At eleven', 'At nine', 'At seven'],
      ),
      Focus(
        title: 'Put the Routine in Order',
        description:
            'Place se and si naturally while ordering morning activities.',
        canDo: 'describe a short morning sequence with se and si.',
        items: [
          p('Ráno se sprchuju.', 'I shower in the morning.'),
          p('Potom se oblékám.', 'Then I get dressed.'),
          p('Čistím si zuby.', 'I brush my teeth.'),
          p('Dělám si kávu.', 'I make myself coffee.'),
        ],
        transcript:
            'Ráno se sprchuju, potom se oblékám, čistím si zuby a dělám si kávu.',
        listenQuestion: 'What happens immediately after showering?',
        listenOptions: ['Getting dressed', 'Making coffee', 'Brushing teeth'],
        readingCz:
            'Nejdřív si čistím zuby. Potom se oblékám a dělám si snídani.',
        readingEn:
            'First I brush my teeth. Then I get dressed and make breakfast.',
        readingQuestion: 'What happens first?',
        readingOptions: [
          'Brushing teeth',
          'Getting dressed',
          'Making breakfast',
        ],
        partnerCues: ['Co děláš ráno?', 'A co děláš potom?'],
        writingPrompt:
            'Write a four-step morning routine with two se or si expressions.',
        transferTranscript: 'Eva se nejdřív obléká a potom si dělá čaj.',
        transferQuestion: 'What does Eva make?',
        transferOptions: ['Tea', 'Coffee', 'Breakfast'],
      ),
      Focus(
        title: 'Compare Two Days',
        description: 'Listen for differences between a workday and a free day.',
        canDo: 'identify and describe differences between two routines.',
        items: [
          p('V pracovní den vstávám brzy.', 'On a workday I get up early.'),
          p('O víkendu vstávám pozdě.', 'At the weekend I get up late.'),
          p('Odpoledne sportuju.', 'I exercise in the afternoon.'),
          p('Večer se dívám na film.', 'In the evening I watch a film.'),
        ],
        transcript:
            'V pracovní den vstávám v šest. O víkendu vstávám v devět a odpoledne sportuju.',
        listenQuestion: 'When does the speaker get up at the weekend?',
        listenOptions: ['At nine', 'At six', 'At seven'],
        readingCz:
            'Anna pracuje v pondělí. Vstává brzy. V sobotu nepracuje, dlouho spí a večer se dívá na film.',
        readingEn:
            'Anna works on Monday. She gets up early. On Saturday she does not work, sleeps late, and watches a film in the evening.',
        readingQuestion: 'What does Anna watch on Saturday evening?',
        readingOptions: ['A film', 'Sport', 'Television news'],
        partnerCues: ['Kdy vstáváš v pracovní den?', 'A co děláš o víkendu?'],
        writingPrompt:
            'Write two differences between your weekday and weekend routines.',
        transferTranscript:
            'Ve středu pracuju doma. Ráno vstávám v sedm a večer čtu.',
        transferQuestion: 'Where does the speaker work on Wednesday?',
        transferOptions: ['At home', 'In an office', 'In a café'],
      ),
      Focus(
        title: 'Mission: My Daily Routine',
        description:
            'Combine sequence, time, activities, and reflexive chunks in a personal routine.',
        canDo: 'tell a connected five-sentence story about my day.',
        items: [
          p('Ráno…', 'In the morning…'),
          p('Potom…', 'Then…'),
          p('Odpoledne…', 'In the afternoon…'),
          p('Večer…', 'In the evening…'),
        ],
        transcript:
            'Ráno vstávám v sedm a sprchuju se. Potom pracuju. Odpoledne sportuju a večer čtu.',
        listenQuestion: 'When does the speaker exercise?',
        listenOptions: ['In the afternoon', 'In the morning', 'In the evening'],
        readingCz:
            'Plán dne: 7:00 vstávám; 8:00 práce; 12:00 oběd; 18:00 sport; 22:30 spím.',
        readingEn:
            'Daily plan: 7:00 get up; 8:00 work; 12:00 lunch; 18:00 exercise; 22:30 sleep.',
        readingQuestion: 'What happens at 18:00?',
        readingOptions: ['Exercise', 'Lunch', 'Sleep'],
        partnerCues: ['Co děláš ráno?', 'Co děláš večer?'],
        writingPrompt:
            'Prepare five connected sentences about your real day before recording them.',
      ),
    ],
  ),
];

void main() {
  const encoder = JsonEncoder.withIndent('  ');
  for (final plan in plans) {
    for (var index = 0; index < plan.focuses.length; index++) {
      final focus = plan.focuses[index];
      final lessonNumber = index + 1;
      final lessonId = plan.unit * 100 + lessonNumber;
      final exerciseBase = plan.unit * 1000 + index * 100;
      final image = index.isEven ? plan.sceneImage : plan.diagramImage;
      final lesson = <String, dynamic>{
        'id': lessonId,
        'unit_id': plan.unit,
        'order_in_unit': index,
        'title': focus.title,
        'description': focus.description,
        'can_do': focus.canDo,
        'new_language': focus.items.map((item) => item.cz).toList(),
        'recycles': plan.recycles,
        'exit_task': focus.canDo,
        'duration_min': 12,
        'lesson_type': index == 3
            ? 'mission'
            : ['introduction', 'practice', 'application'][index],
        'is_review': index == 3,
        'exercises': _exercises(
          plan: plan,
          focus: focus,
          lessonId: lessonId,
          exerciseBase: exerciseBase,
          image: image,
          mission: index == 3,
        ),
      };
      final unit = plan.unit.toString().padLeft(2, '0');
      final lessonNo = lessonNumber.toString().padLeft(2, '0');
      final file = File(
        'assets/curriculum/lessons/unit${unit}_lesson$lessonNo.json',
      );
      file.writeAsStringSync('${encoder.convert(lesson)}\n');
    }
  }
}

List<Map<String, dynamic>> _exercises({
  required UnitPlan plan,
  required Focus focus,
  required int lessonId,
  required int exerciseBase,
  required String image,
  required bool mission,
}) {
  final model = focus.items.map((item) => item.cz).join(' ');
  final fill = _fillFrom(focus.items.first.cz);
  final order = _wordOrder(focus.items[1].cz);
  final dialogue = _dialogue(focus);
  final exercises = <Map<String, dynamic>>[
    _exercise(
      exerciseBase,
      lessonId,
      'teaching',
      'Learn the mission language',
      {
        'type': 'teaching',
        'style': 'list',
        'heading': focus.title,
        'body': focus.description,
        'play_all_label': 'Hear the useful chunks',
        'items': [
          for (final item in focus.items) {'cz': item.cz, 'en': item.en},
        ],
      },
      '',
      0,
    ),
    _exercise(
      exerciseBase + 1,
      lessonId,
      'listening_comprehension',
      'Listen for meaning and one detail',
      {
        'type': 'listening_comprehension',
        'prompt_en':
            'Listen first for the situation, then for the requested detail.',
        'transcript_cz': focus.transcript,
        'image': image,
        'image_label': plan.imageLabel,
        'questions': [
          {
            'question_en':
                'Which lesson situation does this recording belong to?',
            'options': [
              focus.title,
              'Asking for directions',
              'Talking about the weather',
            ],
            'correct_index': 0,
          },
          {
            'question_en': focus.listenQuestion,
            'options': focus.listenOptions,
            'correct_index': 0,
          },
        ],
      },
      focus.listenOptions.first,
      15,
    ),
    _exercise(
      exerciseBase + 2,
      lessonId,
      'reading_comprehension',
      'Read for a useful detail',
      {
        'type': 'reading_comprehension',
        'prompt_en':
            'Read the short functional text and find the requested detail.',
        'image': image,
        'image_label': plan.imageLabel,
        'text_cz': focus.readingCz,
        'text_en': focus.readingEn,
        'questions': [
          {
            'question_en': focus.readingQuestion,
            'options': focus.readingOptions,
            'correct_index': 0,
          },
          {
            'question_en': 'Which text best summarizes the situation?',
            'options': [
              focus.readingEn,
              'The people are asking for directions.',
              'The speaker is describing the weather.',
            ],
            'correct_index': 0,
          },
        ],
      },
      focus.readingOptions.first,
      15,
    ),
    _exercise(
      exerciseBase + 3,
      lessonId,
      'matching',
      'Match the Czech chunks to their meanings',
      {
        'type': 'matching',
        'pairs': [
          for (final item in focus.items) {'left': item.cz, 'right': item.en},
        ],
        'explanation': 'Keep each useful Czech chunk connected to its meaning.',
      },
      focus.items.map((item) => '${item.cz}–${item.en}').join('; '),
      10,
    ),
    _exercise(
      exerciseBase + 4,
      lessonId,
      'multiple_choice',
      'Choose the phrase that completes the lesson goal',
      {
        'type': 'multiple_choice',
        'question_cz': 'Která věta se hodí do této situace?',
        'question_en': 'Which phrase belongs in this lesson situation?',
        'options': [
          focus.items.first.cz,
          'Je tam nádraží.',
          'Dnes prší.',
          'Kolik to stojí?',
        ],
        'correct_index': 0,
        'explanation':
            'Choose the phrase that performs this lesson’s communicative goal.',
      },
      focus.items.first.cz,
      10,
    ),
    _exercise(
      exerciseBase + 5,
      lessonId,
      'fill_blank',
      'Complete the useful chunk',
      {
        'type': 'fill_blank',
        'sentence': fill.$1,
        'blank_count': 1,
        'blank_answers': [
          [fill.$2],
        ],
        'explanation': 'Retrieve the missing word from the complete chunk.',
      },
      fill.$2,
      10,
    ),
    _exercise(
      exerciseBase + 6,
      lessonId,
      'word_order',
      'Build a natural Czech sentence',
      {
        'type': 'word_order',
        'words': order.$1,
        'correct_order': order.$2,
        'translation_en': focus.items[1].en,
        'explanation': 'Rebuild the complete phrase in natural Czech order.',
      },
      focus.items[1].cz,
      10,
    ),
    _exercise(
      exerciseBase + 7,
      lessonId,
      'dictation',
      'Listen and type the key sentence',
      {
        'type': 'dictation',
        'expected_text': focus.items[2].cz,
        'language': 'cs-CZ',
        'note': 'Listen for the full phrase before typing.',
      },
      focus.items[2].cz,
      10,
    ),
    _exercise(
      exerciseBase + 8,
      lessonId,
      'pronunciation',
      'Rehearse a useful phrase',
      {
        'type': 'pronunciation',
        'target_text': focus.items[3].cz,
        'focus_sounds': ['first_syllable_stress', 'vowel_length'],
        'min_score': 0.5,
        'translation_en': focus.items[3].en,
      },
      focus.items[3].cz,
      15,
    ),
    _exercise(
      exerciseBase + 9,
      lessonId,
      'dialogue',
      'Complete and hear the short exchange',
      {
        'type': 'dialogue',
        'scenario': focus.title,
        'image': image,
        'image_label': plan.imageLabel,
        'lines': dialogue.$1,
        'blank_answers': dialogue.$2,
        'explanation': 'Use complete chunks that answer each partner cue.',
      },
      '${focus.items[0].cz} | ${focus.items[1].cz}',
      15,
    ),
    _exercise(
      exerciseBase + 10,
      lessonId,
      'writing_task',
      'Write a useful personal response',
      {
        'type': 'writing_task',
        'prompt_en': focus.writingPrompt,
        'prompt_cz': 'Napište krátkou odpověď česky.',
        'min_words': 4,
        'max_words': 40,
        'key_vocab': focus.items.map((item) => item.cz).toList(),
        'sample_answer': model,
      },
      model,
      0,
    ),
  ];

  if (mission) {
    exercises.add(
      _exercise(
        exerciseBase + 11,
        lessonId,
        'speaking_task',
        'Record the unit mission',
        {
          'type': 'speaking_task',
          'prompt_en': plan.missionPrompt,
          'prompt_cz': 'Dokončete krátkou misi česky.',
          'image': image,
          'image_label': plan.imageLabel,
          'min_duration_seconds': 20,
          'max_duration_seconds': 40,
          'expected_phrases': focus.items.map((item) => item.cz).toList(),
        },
        model,
        20,
      ),
    );
  } else {
    exercises.add(
      _exercise(
        exerciseBase + 11,
        lessonId,
        'listening_comprehension',
        'Listen in a new context',
        {
          'type': 'listening_comprehension',
          'prompt_en':
              'Transfer the lesson language to a new speaker and context.',
          'transcript_cz': focus.transferTranscript!,
          'questions': [
            {
              'question_en': focus.transferQuestion!,
              'options': focus.transferOptions!,
              'correct_index': 0,
            },
          ],
        },
        focus.transferOptions!.first,
        15,
      ),
    );
  }
  return exercises;
}

Map<String, dynamic> _exercise(
  int id,
  int lessonId,
  String type,
  String prompt,
  Map<String, dynamic> data,
  String answerKey,
  int xp,
) => {
  'id': id,
  'lesson_id': lessonId,
  'type': type,
  'prompt': prompt,
  'data': data,
  'answer_key': answerKey,
  'xp_reward': xp,
};

(String, String) _fillFrom(String sentence) {
  final words = sentence.split(' ');
  final targetIndex = words.length > 2 ? 1 : 0;
  final target = words[targetIndex].replaceAll(RegExp(r'[.,?!]'), '');
  words[targetIndex] = words[targetIndex].replaceFirst(target, '___');
  return (words.join(' '), target);
}

(List<String>, List<int>) _wordOrder(String sentence) {
  final original = sentence.split(' ');
  final words = original.reversed.toList();
  final correctOrder = [for (var i = original.length - 1; i >= 0; i--) i];
  return (words, correctOrder);
}

(List<Map<String, String>>, List<List<String>>) _dialogue(Focus focus) => (
  [
    {'speaker': 'partner', 'text': focus.partnerCues[0]},
    {'speaker': 'you', 'text': '___'},
    {'speaker': 'partner', 'text': focus.partnerCues[1]},
    {'speaker': 'you', 'text': '___'},
  ],
  [
    [focus.items[0].cz],
    [focus.items[1].cz],
  ],
);
