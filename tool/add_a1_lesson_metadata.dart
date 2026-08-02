import 'dart:convert';
import 'dart:io';

const _units = <int>[1, 2, 3, 11, 12, 13, 14, 15, 28, 30];

const _canDo = <int, List<String>>{
  1: [
    'connect useful Czech words to their sounds and pictures.',
    'hear first-syllable stress and meaningful vowel length.',
    'use Czech spelling clues to predict familiar sounds.',
    'ask for repetition, slower speech, meaning, or spelling.',
  ],
  2: [
    'choose a formal or friendly greeting.',
    'ask and answer names naturally.',
    'ask and say where someone is from.',
    'complete a short formal or friendly first meeting.',
  ],
  3: [
    'ask who a person is or what a thing is.',
    'learn familiar nouns with ten, ta, or to.',
    'identify people and things in a short exchange.',
    'identify a new scene with kdo/co questions and answers.',
  ],
  11: [
    'choose something suitable to eat and drink.',
    'say what I eat, drink, like, or avoid.',
    'ask for the bill and say how I will pay.',
    'complete a polite restaurant order from greeting to payment.',
  ],
  12: [
    'identify useful colours and clothes.',
    'ask about price and size.',
    'try something on and decide whether to take it.',
    'complete a short clothes-shop purchase.',
  ],
  13: [
    'say which activities I like.',
    'ask and answer what someone does in free time.',
    'say how often I do familiar activities.',
    'suggest and agree on a simple free-time plan.',
  ],
  14: [
    'ask where a familiar place is.',
    'understand and give a short route.',
    'choose and describe simple transport.',
    'guide a visitor to a destination.',
  ],
  15: [
    'understand and describe today’s weather.',
    'connect seasons and weather to simple plans.',
    'prepare and describe a short trip.',
    'give a short update about weather and travel.',
  ],
  28: [
    'read and complete a simple everyday form.',
    'listen for essential travel details.',
    'write a clear short practical message.',
    'combine A1 reading, listening, writing, and speaking skills.',
  ],
  30: [
    'reuse A1 Czech in a café situation.',
    'reuse A1 Czech while choosing and buying something.',
    'reuse A1 Czech to ask for and give directions.',
    'combine A1 language in a final real-life mission.',
  ],
};

const _recycles = <int, List<String>>{
  1: [],
  2: ['Czech sound clues', 'Prosím pomalu', 'Ještě jednou, prosím'],
  3: ['greetings', 'names', 'To je…', 'Czech sound clues'],
  11: ['food and drink', 'Dám si…', 'Máte…?', 'numbers and prices'],
  12: ['colours', 'numbers and prices', 'chci/kupuju', 'polite questions'],
  13: ['present-tense activities', 'time and days', 'Ano/Ne', 'simple plans'],
  14: ['places', 'Kde…?', 'time', 'simple questions', 'transport words'],
  15: ['days and time', 'places', 'transport', 'present-tense activities'],
  28: [
    'personal details',
    'time and numbers',
    'travel',
    'messages',
    'descriptions',
  ],
  30: ['food', 'shopping', 'directions', 'transport', 'meeting plans'],
};

const _descriptions = <int, List<String>>{
  11: [
    'Read a simple menu and choose food and drink for a real situation.',
    'Use familiar food and drink phrases to describe simple preferences.',
    'Complete the final steps of a restaurant visit: bill, payment, and thanks.',
    'Bring menu reading, ordering, listening, and speaking into one restaurant mission.',
  ],
  12: [
    'Connect colours, clothes, and visual details before entering a shop exchange.',
    'Listen and ask for the price and size of a specific item.',
    'Use fitting-room language to try, compare, accept, or reject an item.',
    'Bring colour, size, price, and payment into one shopping mission.',
  ],
  13: [
    'Express simple likes and dislikes through familiar free-time activities.',
    'Ask and answer about sports, music, reading, and other interests.',
    'Use always, often, sometimes, and never in meaningful personal statements.',
    'Suggest an activity, respond, and agree on a simple free-time plan.',
  ],
  14: [
    'Use a town scene to ask where a useful place is.',
    'Follow and reconstruct a short walking route with direction words.',
    'Choose suitable transport and say how to reach a destination.',
    'Combine place, route, and transport language to guide a visitor.',
  ],
  15: [
    'Listen to a short forecast and describe today’s weather.',
    'Connect seasons and weather conditions to everyday plans.',
    'Use weather and transport details to prepare a short trip.',
    'Combine past location, current weather, and a future plan in a travel update.',
  ],
  28: [
    'Practise reading and completing a simple everyday form. Independent course practice, not official examination material.',
    'Practise listening for time, platform, destination, and other essential details. No external result is predicted.',
    'Practise writing a short functional message with a greeting, reason, and closing.',
    'Complete independent four-skills A1 practice with no official-exam affiliation or result claim.',
  ],
  30: [
    'Retrieve food, drink, price, and politeness language in a new café situation.',
    'Retrieve colour, size, price, and decision language in a new shopping situation.',
    'Retrieve place, direction, and transport language in a new route situation.',
    'Bring the A1 course together in one personal meeting and travel mission.',
  ],
};

void main() {
  const encoder = JsonEncoder.withIndent('  ');
  for (final unit in _units) {
    for (var lesson = 1; lesson <= 4; lesson++) {
      final lessonNumber = unit == 1 ? lesson - 1 : lesson;
      final path =
          'assets/curriculum/lessons/unit${unit.toString().padLeft(2, '0')}_lesson${lessonNumber.toString().padLeft(2, '0')}.json';
      final file = File(path);
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final exercises = (data['exercises'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final newLanguage = <String>{};
      for (final exercise in exercises.where((e) => e['type'] == 'teaching')) {
        final items =
            (exercise['data'] as Map<String, dynamic>)['items']
                as List<dynamic>? ??
            const [];
        for (final item in items.cast<Map<String, dynamic>>()) {
          final value = item['cz'] ?? item['say'] ?? item['name_say'];
          if (value is String && value.trim().isNotEmpty) {
            newLanguage.add(value.trim());
          }
        }
      }
      data['can_do'] = _canDo[unit]![lesson - 1];
      data['new_language'] = newLanguage.toList();
      data['recycles'] = _recycles[unit]!;
      data['exit_task'] = _canDo[unit]![lesson - 1];
      final descriptions = _descriptions[unit];
      if (descriptions != null) {
        data['description'] = descriptions[lesson - 1];
      }
      file.writeAsStringSync('${encoder.convert(data)}\n');
    }
  }
}
