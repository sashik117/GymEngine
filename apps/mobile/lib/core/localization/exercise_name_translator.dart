String translateExerciseNameUk(String value) {
  final tokens = _tokenizeExerciseName(value);
  if (tokens.isEmpty) {
    return value;
  }

  final translated = <String>[];
  var index = 0;
  while (index < tokens.length) {
    final phrase = _matchPhrase(tokens, index);
    if (phrase != null) {
      if (phrase.translation.isNotEmpty) {
        translated.add(phrase.translation);
      }
      index += phrase.tokens.length;
      continue;
    }

    final token = tokens[index];
    final word = _tokenTranslations[token] ?? _fallbackToken(token);
    if (word.isNotEmpty) {
      translated.add(word);
    }
    index += 1;
  }

  final result = _tidyExerciseName(translated.join(' '));
  if (result.isEmpty) {
    return value;
  }
  return _capitalizeFirst(result);
}

class _ExercisePhrase {
  const _ExercisePhrase(this.tokens, this.translation);

  final List<String> tokens;
  final String translation;
}

final _sortedPhrases = [..._exercisePhrases]
  ..sort((a, b) => b.tokens.length.compareTo(a.tokens.length));

_ExercisePhrase? _matchPhrase(List<String> tokens, int index) {
  for (final phrase in _sortedPhrases) {
    if (index + phrase.tokens.length > tokens.length) {
      continue;
    }
    var matches = true;
    for (var offset = 0; offset < phrase.tokens.length; offset += 1) {
      if (tokens[index + offset] != phrase.tokens[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return phrase;
    }
  }
  return null;
}

List<String> _tokenizeExerciseName(String value) {
  var text = value
      .toLowerCase()
      .replaceAll(RegExp(r'\((male|female)\)', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\b(male|female)\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\bversion\s*[- ]*\d+\b', caseSensitive: false), ' ')
      .replaceAll('&', ' and ')
      .replaceAll('+', ' and ')
      .replaceAll('°', ' degree ')
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9/]+'), ' ');

  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) {
    return const [];
  }

  return RegExp(
    r'[a-z]+|\d+(?:/\d+)?',
  ).allMatches(text).map((match) => match.group(0)!).toList();
}

String _tidyExerciseName(String value) {
  var text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  final replacements = {
    'з з ': 'з ',
    'на на ': 'на ',
    'у у ': 'у ',
    'в в ': 'в ',
    'і і ': 'і ',
    'тяга верхнього блока тяга верхнього блока': 'тяга верхнього блока',
    'підтягування зворотним хватом зворотним хватом':
        'підтягування зворотним хватом',
    'зворотним хватом підтягування зворотним хватом':
        'підтягування зворотним хватом',
    'вузьким хватом підтягування зворотним хватом':
        'підтягування вузьким зворотним хватом',
    'підйом підйом': 'підйом',
    'згинання згинання': 'згинання',
    'розгинання розгинання': 'розгинання',
    'скручування скручування': 'скручування',
    'вправа вправа': 'вправа',
  };

  var changed = true;
  while (changed) {
    changed = false;
    for (final entry in replacements.entries) {
      final next = text.replaceAll(entry.key, entry.value);
      if (next != text) {
        text = next;
        changed = true;
      }
    }
  }

  return text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' ,', ',')
      .replaceAll(' .', '.')
      .trim();
}

String _capitalizeFirst(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}

String _fallbackToken(String token) {
  if (RegExp(r'^\d+(?:/\d+)?$').hasMatch(token)) {
    return token;
  }
  return _transliterateLatinToUk(token);
}

String _transliterateLatinToUk(String value) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < value.length) {
    final triple = index + 3 <= value.length
        ? value.substring(index, index + 3)
        : '';
    final pair = index + 2 <= value.length
        ? value.substring(index, index + 2)
        : '';
    if (_latinTriples[triple] case final mapped?) {
      buffer.write(mapped);
      index += 3;
      continue;
    }
    if (_latinPairs[pair] case final mapped?) {
      buffer.write(mapped);
      index += 2;
      continue;
    }
    buffer.write(_latinSingles[value[index]] ?? value[index]);
    index += 1;
  }
  return buffer.toString();
}

const _exercisePhrases = [
  _ExercisePhrase([
    'alternate',
    'lateral',
    'pulldown',
  ], 'почергова тяга верхнього блока в сторони'),
  _ExercisePhrase([
    'assisted',
    'close',
    'grip',
    'underhand',
    'chin',
    'up',
  ], 'підтягування вузьким зворотним хватом з підтримкою'),
  _ExercisePhrase(['1', 'to', '2', 'jump', 'box'], 'стрибок на тумбу 1 до 2'),
  _ExercisePhrase([
    '45',
    'degree',
    'hyperextension',
  ], 'гіперекстензія 45 градусів'),
  _ExercisePhrase([
    'dumbbell',
    'incline',
    'bench',
    'press',
  ], 'жим гантелей лежачи під кутом'),
  _ExercisePhrase([
    'cable',
    'rope',
    'triceps',
    'pushdown',
  ], 'розгинання канатом на трицепс у кросовері'),
  _ExercisePhrase([
    'ankle',
    'dorsal',
    'flexion',
    'articulations',
  ], 'мобілізація гомілкостопа: дорсальне згинання'),
  _ExercisePhrase([
    'kettlebell',
    'turkish',
    'get',
    'up',
  ], 'турецький підйом з гирею'),
  _ExercisePhrase([
    'resistance',
    'band',
    'hip',
    'abduction',
  ], 'відведення стегна з резинкою'),
  _ExercisePhrase([
    'smith',
    'machine',
    'standing',
    'calf',
    'raise',
  ], 'підйом на ікри стоячи у Сміті'),
  _ExercisePhrase(['dumbbell', 'bench', 'press'], 'жим гантелей лежачи'),
  _ExercisePhrase(['barbell', 'bench', 'press'], 'жим штанги лежачи'),
  _ExercisePhrase(['smith', 'bench', 'press'], 'жим у Сміті лежачи'),
  _ExercisePhrase(['incline', 'bench', 'press'], 'жим лежачи під кутом'),
  _ExercisePhrase(['decline', 'bench', 'press'], 'жим лежачи вниз головою'),
  _ExercisePhrase([
    'close',
    'grip',
    'bench',
    'press',
  ], 'жим лежачи вузьким хватом'),
  _ExercisePhrase(['chest', 'press'], 'жим на груди'),
  _ExercisePhrase(['shoulder', 'press'], 'жим на плечі'),
  _ExercisePhrase(['overhead', 'press'], 'жим над головою'),
  _ExercisePhrase(['military', 'press'], 'армійський жим'),
  _ExercisePhrase(['arnold', 'press'], 'жим Арнольда'),
  _ExercisePhrase(['squeeze', 'press'], 'жим зі стисканням'),
  _ExercisePhrase(['svend', 'press'], 'жим Свенда'),
  _ExercisePhrase(['z', 'press'], 'зет-жим'),
  _ExercisePhrase(['bench', 'press'], 'жим лежачи'),
  _ExercisePhrase(['leg', 'press'], 'жим ногами'),
  _ExercisePhrase(['front', 'squat'], 'фронтальні присідання'),
  _ExercisePhrase(['split', 'squat'], 'спліт-присідання'),
  _ExercisePhrase(['bulgarian', 'split', 'squat'], 'болгарські випади'),
  _ExercisePhrase(['goblet', 'squat'], 'гоблет-присідання'),
  _ExercisePhrase(['hack', 'squat'], 'гак-присідання'),
  _ExercisePhrase(['box', 'squat'], 'присідання на коробку'),
  _ExercisePhrase(['pistol', 'squat'], 'присідання пістолетиком'),
  _ExercisePhrase(['sissy', 'squat'], 'сіссі-присідання'),
  _ExercisePhrase(['sumo', 'squat'], 'сумо-присідання'),
  _ExercisePhrase(['leg', 'extension'], 'розгинання ніг'),
  _ExercisePhrase(['leg', 'curl'], 'згинання ніг'),
  _ExercisePhrase(['lying', 'leg', 'curl'], 'згинання ніг лежачи'),
  _ExercisePhrase(['seated', 'leg', 'curl'], 'згинання ніг сидячи'),
  _ExercisePhrase(['standing', 'leg', 'curl'], 'згинання ніг стоячи'),
  _ExercisePhrase(['calf', 'raise'], 'підйом на ікри'),
  _ExercisePhrase(['standing', 'calf', 'raise'], 'підйом на ікри стоячи'),
  _ExercisePhrase(['seated', 'calf', 'raise'], 'підйом на ікри сидячи'),
  _ExercisePhrase(['donkey', 'calf', 'raise'], 'підйом на ікри в нахилі'),
  _ExercisePhrase(['toe', 'raise'], 'підйом носків'),
  _ExercisePhrase(['romanian', 'deadlift'], 'румунська тяга'),
  _ExercisePhrase(['stiff', 'leg', 'deadlift'], 'тяга на прямих ногах'),
  _ExercisePhrase(['straight', 'leg', 'deadlift'], 'тяга на прямих ногах'),
  _ExercisePhrase(['single', 'leg', 'deadlift'], 'тяга на одній нозі'),
  _ExercisePhrase(['sumo', 'deadlift'], 'сумо-тяга'),
  _ExercisePhrase(['trap', 'bar', 'deadlift'], 'тяга з треп-грифом'),
  _ExercisePhrase(['deadlift'], 'станова тяга'),
  _ExercisePhrase(['good', 'morning'], 'нахили зі штангою'),
  _ExercisePhrase(['hip', 'thrust'], 'хіп-траст'),
  _ExercisePhrase(['glute', 'bridge'], 'сідничний міст'),
  _ExercisePhrase(['hip', 'abduction'], 'відведення стегна'),
  _ExercisePhrase(['hip', 'adduction'], 'приведення стегна'),
  _ExercisePhrase(['leg', 'abduction'], 'відведення ноги'),
  _ExercisePhrase(['leg', 'adduction'], 'приведення ноги'),
  _ExercisePhrase(['cable', 'kickback'], 'відведення ноги назад у кросовері'),
  _ExercisePhrase(['glute', 'kickback'], 'відведення ноги назад на сідниці'),
  _ExercisePhrase(['frog', 'pump'], 'фрог-памп'),
  _ExercisePhrase(['clamshell'], 'розкриття стегна лежачи'),
  _ExercisePhrase(['lat', 'pulldown'], 'тяга верхнього блока'),
  _ExercisePhrase(['lateral', 'pulldown'], 'тяга верхнього блока в сторони'),
  _ExercisePhrase(['straight', 'arm', 'pulldown'], 'тяга прямими руками'),
  _ExercisePhrase(['close', 'grip', 'pulldown'], 'тяга блока вузьким хватом'),
  _ExercisePhrase(['wide', 'grip', 'pulldown'], 'тяга блока широким хватом'),
  _ExercisePhrase(['seated', 'row'], 'горизонтальна тяга сидячи'),
  _ExercisePhrase(['bent', 'over', 'row'], 'тяга в нахилі'),
  _ExercisePhrase(['one', 'arm', 'row'], 'тяга однією рукою'),
  _ExercisePhrase(['t', 'bar', 'row'], 'тяга Т-грифа'),
  _ExercisePhrase(['upright', 'row'], 'тяга до підборіддя'),
  _ExercisePhrase(['inverted', 'row'], 'австралійські підтягування'),
  _ExercisePhrase(['renegade', 'row'], 'ренегатська тяга'),
  _ExercisePhrase(['face', 'pull'], 'тяга до обличчя'),
  _ExercisePhrase(['pull', 'up'], 'підтягування'),
  _ExercisePhrase(['chin', 'up'], 'підтягування зворотним хватом'),
  _ExercisePhrase(['muscle', 'up'], 'вихід силою'),
  _ExercisePhrase([
    'close',
    'grip',
    'underhand',
    'chin',
    'up',
  ], 'підтягування вузьким зворотним хватом'),
  _ExercisePhrase([
    'close',
    'grip',
    'chin',
    'up',
  ], 'підтягування вузьким зворотним хватом'),
  _ExercisePhrase([
    'wide',
    'grip',
    'pull',
    'up',
  ], 'підтягування широким хватом'),
  _ExercisePhrase(['archer', 'pull', 'up'], 'підтягування лучника'),
  _ExercisePhrase(['biceps', 'curl'], 'згинання на біцепс'),
  _ExercisePhrase(['barbell', 'curl'], 'згинання рук зі штангою'),
  _ExercisePhrase(['dumbbell', 'curl'], 'згинання рук з гантелями'),
  _ExercisePhrase(['hammer', 'curl'], 'молоткове згинання'),
  _ExercisePhrase(['preacher', 'curl'], 'згинання на лаві Скотта'),
  _ExercisePhrase(['concentration', 'curl'], 'концентроване згинання'),
  _ExercisePhrase(['spider', 'curl'], 'павуче згинання'),
  _ExercisePhrase(['reverse', 'curl'], 'зворотне згинання'),
  _ExercisePhrase(['wrist', 'curl'], 'згинання запʼясть'),
  _ExercisePhrase(['reverse', 'wrist', 'curl'], 'зворотне згинання запʼясть'),
  _ExercisePhrase(['triceps', 'pushdown'], 'розгинання на трицепс вниз'),
  _ExercisePhrase(['rope', 'pushdown'], 'розгинання канатом на трицепс'),
  _ExercisePhrase(['triceps', 'extension'], 'розгинання на трицепс'),
  _ExercisePhrase([
    'overhead',
    'triceps',
    'extension',
  ], 'розгинання трицепса над головою'),
  _ExercisePhrase(['skull', 'crusher'], 'французький жим лежачи'),
  _ExercisePhrase(['french', 'press'], 'французький жим'),
  _ExercisePhrase(['triceps', 'dip'], 'віджимання на трицепс'),
  _ExercisePhrase(['chest', 'dip'], 'віджимання на брусах для грудей'),
  _ExercisePhrase(['bench', 'dip'], 'зворотні віджимання від лави'),
  _ExercisePhrase(['push', 'up'], 'віджимання'),
  _ExercisePhrase(['close', 'grip', 'push', 'up'], 'віджимання вузьким хватом'),
  _ExercisePhrase(['decline', 'push', 'up'], 'віджимання з ногами вище'),
  _ExercisePhrase(['incline', 'push', 'up'], 'віджимання з руками вище'),
  _ExercisePhrase(['diamond', 'push', 'up'], 'діамантові віджимання'),
  _ExercisePhrase(['pike', 'push', 'up'], 'пайк-віджимання'),
  _ExercisePhrase(['lateral', 'raise'], 'підйом рук у сторони'),
  _ExercisePhrase(['front', 'raise'], 'підйом рук перед собою'),
  _ExercisePhrase(['rear', 'delt', 'fly'], 'розведення на задню дельту'),
  _ExercisePhrase(['reverse', 'fly'], 'зворотне розведення'),
  _ExercisePhrase(['chest', 'fly'], 'розведення на груди'),
  _ExercisePhrase(['pec', 'deck'], 'пек-дек'),
  _ExercisePhrase(['shrug'], 'шраги'),
  _ExercisePhrase(['external', 'rotation'], 'зовнішня ротація'),
  _ExercisePhrase(['internal', 'rotation'], 'внутрішня ротація'),
  _ExercisePhrase(['shoulder', 'rotation'], 'ротація плеча'),
  _ExercisePhrase(['crunch'], 'скручування'),
  _ExercisePhrase(['cable', 'crunch'], 'скручування в кросовері'),
  _ExercisePhrase(['bicycle', 'crunch'], 'велосипедні скручування'),
  _ExercisePhrase(['reverse', 'crunch'], 'зворотні скручування'),
  _ExercisePhrase(['sit', 'up'], 'підйом корпусу'),
  _ExercisePhrase(['leg', 'raise'], 'підйом ніг'),
  _ExercisePhrase(['hanging', 'leg', 'raise'], 'підйом ніг у висі'),
  _ExercisePhrase(['knee', 'raise'], 'підйом колін'),
  _ExercisePhrase(['hanging', 'knee', 'raise'], 'підйом колін у висі'),
  _ExercisePhrase(['russian', 'twist'], 'російські скручування'),
  _ExercisePhrase(['wood', 'chop'], 'дроворуб'),
  _ExercisePhrase(['pallof', 'press'], 'жим Палофа'),
  _ExercisePhrase(['ab', 'wheel'], 'ролик для преса'),
  _ExercisePhrase(['rollout'], 'викат ролика'),
  _ExercisePhrase(['mountain', 'climber'], 'альпініст'),
  _ExercisePhrase(['dead', 'bug'], 'мертвий жук'),
  _ExercisePhrase(['bird', 'dog'], 'берд-дог'),
  _ExercisePhrase(['hollow', 'hold'], 'холлоу-холд'),
  _ExercisePhrase(['side', 'plank'], 'бокова планка'),
  _ExercisePhrase(['front', 'plank'], 'передня планка'),
  _ExercisePhrase(['plank'], 'планка'),
  _ExercisePhrase(['back', 'extension'], 'гіперекстензія'),
  _ExercisePhrase(['hyperextension'], 'гіперекстензія'),
  _ExercisePhrase(['45', 'degree'], '45 градусів'),
  _ExercisePhrase(['90', '90'], '90/90'),
  _ExercisePhrase(['jump', 'squat'], 'присідання з вистрибуванням'),
  _ExercisePhrase(['box', 'jump'], 'стрибок на тумбу'),
  _ExercisePhrase(['jump', 'box'], 'стрибок на тумбу'),
  _ExercisePhrase(['jumping', 'jack'], 'джампінг-джек'),
  _ExercisePhrase(['jump', 'rope'], 'стрибки зі скакалкою'),
  _ExercisePhrase(['step', 'up'], 'зашагування'),
  _ExercisePhrase(['burpee'], 'берпі'),
  _ExercisePhrase(['battle', 'rope'], 'бойові канати'),
  _ExercisePhrase(['battling', 'ropes'], 'бойові канати'),
  _ExercisePhrase(['farmer', 'carry'], 'прогулянка фермера'),
  _ExercisePhrase(['suitcase', 'carry'], 'перенесення валізою'),
  _ExercisePhrase(['clean', 'and', 'jerk'], 'поштовх штанги'),
  _ExercisePhrase(['clean'], 'взяття на груди'),
  _ExercisePhrase(['snatch'], 'ривок'),
  _ExercisePhrase(['swing'], 'махи'),
  _ExercisePhrase(['turkish', 'get', 'up'], 'турецький підйом'),
  _ExercisePhrase(['stretch'], 'розтяжка'),
  _ExercisePhrase(['hamstring', 'stretch'], 'розтяжка біцепса стегна'),
  _ExercisePhrase(['calf', 'stretch'], 'розтяжка литок'),
  _ExercisePhrase(['hip', 'flexor', 'stretch'], 'розтяжка згиначів стегна'),
  _ExercisePhrase(['quad', 'stretch'], 'розтяжка квадрицепса'),
  _ExercisePhrase(['chest', 'stretch'], 'розтяжка грудей'),
  _ExercisePhrase(['shoulder', 'stretch'], 'розтяжка плечей'),
  _ExercisePhrase(['cobra', 'stretch'], 'кобра'),
  _ExercisePhrase(['child', 'pose'], 'поза дитини'),
  _ExercisePhrase(['downward', 'dog'], 'собака мордою вниз'),
  _ExercisePhrase(['cat', 'cow'], 'кішка-корова'),
  _ExercisePhrase(['neck', 'flexion'], 'згинання шиї'),
  _ExercisePhrase(['neck', 'extension'], 'розгинання шиї'),
  _ExercisePhrase(['dorsal', 'flexion'], 'дорсальне згинання'),
  _ExercisePhrase(['plantar', 'flexion'], 'підошовне згинання'),
  _ExercisePhrase(['ankle', 'mobility'], 'мобільність гомілкостопа'),
  _ExercisePhrase(['articulations'], 'мобілізація суглоба'),
  _ExercisePhrase(['low', 'bar', 'position'], 'нижнє положення грифа'),
  _ExercisePhrase(['high', 'bar', 'position'], 'верхнє положення грифа'),
  _ExercisePhrase(['full', 'range', 'of', 'motion'], 'повна амплітуда'),
  _ExercisePhrase(['range', 'of', 'motion'], 'амплітуда руху'),
  _ExercisePhrase(['body', 'weight'], 'з власною вагою'),
  _ExercisePhrase(['resistance', 'band'], 'з резинкою'),
  _ExercisePhrase(['stability', 'ball'], 'на фітболі'),
  _ExercisePhrase(['medicine', 'ball'], 'з медболом'),
  _ExercisePhrase(['swiss', 'ball'], 'на фітболі'),
  _ExercisePhrase(['ez', 'bar'], 'з ізі-грифом'),
  _ExercisePhrase(['v', 'bar'], 'з ві-рукояттю'),
  _ExercisePhrase(['t', 'bar'], 'з Т-грифом'),
  _ExercisePhrase(['trap', 'bar'], 'з треп-грифом'),
  _ExercisePhrase(['smith', 'machine'], 'у машині Сміта'),
  _ExercisePhrase(['sled', 'machine'], 'на платформі'),
  _ExercisePhrase(['leverage', 'machine'], 'у важільному тренажері'),
  _ExercisePhrase(['suspension'], 'на петлях'),
];

const _tokenTranslations = {
  'a': '',
  'an': '',
  'the': '',
  'of': '',
  'for': 'для',
  'and': 'і',
  'or': 'або',
  'with': 'з',
  'without': 'без',
  'on': 'на',
  'in': 'у',
  'to': 'до',
  'from': 'з',
  'over': 'над',
  'under': 'під',
  'behind': 'за',
  'between': 'між',
  'against': 'до',
  'using': 'з',
  'body': 'корпус',
  'bodyweight': 'з власною вагою',
  'weight': 'вага',
  'weighted': 'з вагою',
  'assisted': 'з підтримкою',
  'support': 'опора',
  'supported': 'з опорою',
  'exercise': 'вправа',
  'variation': 'варіант',
  'position': 'позиція',
  'motion': 'рух',
  'range': 'амплітуда',
  'full': 'повна',
  'half': 'половинний',
  'partial': 'часткова амплітуда',
  'static': 'статичний',
  'dynamic': 'динамічний',
  'isometric': 'ізометричний',
  'alternate': 'почерговий',
  'alternating': 'почерговий',
  'reverse': 'зворотний',
  'revers': 'зворотний',
  'inverted': 'перевернутий',
  'prone': 'лежачи обличчям вниз',
  'supine': 'лежачи на спині',
  'seated': 'сидячи',
  'sitting': 'сидячи',
  'standing': 'стоячи',
  'lying': 'лежачи',
  'kneeling': 'на колінах',
  'hanging': 'у висі',
  'walking': 'у ходьбі',
  'running': 'біг',
  'single': 'однією',
  'one': 'однією',
  'two': 'двома',
  'double': 'подвійний',
  'both': 'двома',
  'left': 'ліва',
  'right': 'права',
  'front': 'передній',
  'rear': 'задній',
  'back': 'спина',
  'side': 'боковий',
  'lateral': 'боковий',
  'medial': 'внутрішній',
  'inner': 'внутрішній',
  'outer': 'зовнішній',
  'high': 'високий',
  'low': 'низький',
  'lower': 'нижній',
  'upper': 'верхній',
  'middle': 'середній',
  'wide': 'широкий',
  'narrow': 'вузький',
  'close': 'вузький',
  'neutral': 'нейтральний',
  'underhand': 'зворотним хватом',
  'overhand': 'прямим хватом',
  'grip': 'хват',
  'palms': 'долоні',
  'palm': 'долоня',
  'hand': 'рука',
  'hands': 'руки',
  'finger': 'палець',
  'fingers': 'пальці',
  'wrist': 'запʼястя',
  'forearm': 'передпліччя',
  'forearms': 'передпліччя',
  'elbow': 'лікоть',
  'elbows': 'лікті',
  'arm': 'рука',
  'arms': 'руки',
  'bicep': 'біцепс',
  'biceps': 'біцепс',
  'tricep': 'трицепс',
  'triceps': 'трицепс',
  'shoulder': 'плече',
  'shoulders': 'плечі',
  'delt': 'дельта',
  'delts': 'дельти',
  'chest': 'груди',
  'pec': 'грудні',
  'lat': 'найширші',
  'lats': 'найширші',
  'spine': 'хребет',
  'neck': 'шия',
  'trap': 'трапеція',
  'traps': 'трапеції',
  'waist': 'прес',
  'core': 'кор',
  'abs': 'прес',
  'abdominal': 'прес',
  'oblique': 'косі мʼязи',
  'glute': 'сідниця',
  'glutes': 'сідниці',
  'hip': 'стегно',
  'hips': 'стегна',
  'butt': 'сідниці',
  'leg': 'нога',
  'legs': 'ноги',
  'quad': 'квадрицепс',
  'quads': 'квадрицепси',
  'quadriceps': 'квадрицепси',
  'hamstring': 'біцепс стегна',
  'hamstrings': 'біцепс стегна',
  'adductor': 'привідні мʼязи',
  'adductors': 'привідні мʼязи',
  'abductor': 'відвідні мʼязи',
  'abductors': 'відвідні мʼязи',
  'knee': 'коліно',
  'knees': 'коліна',
  'ankle': 'гомілкостоп',
  'foot': 'стопа',
  'feet': 'стопи',
  'heel': 'пʼята',
  'toe': 'носок',
  'toes': 'носки',
  'calf': 'ікра',
  'calves': 'ікри',
  'dumbbell': 'з гантелями',
  'barbell': 'зі штангою',
  'cable': 'у кросовері',
  'band': 'з резинкою',
  'lever': 'у тренажері',
  'machine': 'тренажер',
  'smith': 'Сміт',
  'sled': 'платформа',
  'kettlebell': 'з гирею',
  'ball': 'мʼяч',
  'bench': 'лава',
  'box': 'тумба',
  'bar': 'гриф',
  'rope': 'канат',
  'ropes': 'канати',
  'towel': 'рушник',
  'chair': 'стілець',
  'wall': 'стіна',
  'floor': 'підлога',
  'rack': 'стійка',
  'landmine': 'лендмайн',
  'bosu': 'босу',
  'trx': 'трх',
  'press': 'жим',
  'squat': 'присідання',
  'lunge': 'випад',
  'row': 'тяга',
  'pulldown': 'тяга верхнього блока',
  'pull': 'тягнути',
  'push': 'відштовхування',
  'curl': 'згинання',
  'extension': 'розгинання',
  'raise': 'підйом',
  'fly': 'розведення',
  'dip': 'віджимання на брусах',
  'bridge': 'міст',
  'thrust': 'поштовх тазом',
  'kickback': 'відведення назад',
  'abduction': 'відведення',
  'adduction': 'приведення',
  'rotation': 'ротація',
  'rotational': 'ротаційний',
  'flexion': 'згинання',
  'extensor': 'розгинач',
  'flexor': 'згинач',
  'bend': 'нахил',
  'twist': 'скручування',
  'twisting': 'скручування',
  'crunch': 'скручування',
  'plank': 'планка',
  'roll': 'перекат',
  'rollout': 'викат',
  'hold': 'утримання',
  'hang': 'вис',
  'lift': 'підйом',
  'deadlift': 'станова тяга',
  'jump': 'стрибок',
  'run': 'біг',
  'walk': 'ходьба',
  'step': 'крок',
  'touch': 'дотик',
  'tap': 'дотик',
  'reach': 'дотягування',
  'kick': 'удар ногою',
  'kicks': 'удари ногами',
  'boxing': 'бокс',
  'kickboxing': 'кікбоксинг',
  'yoga': 'йога',
  'pose': 'поза',
  'stretching': 'розтяжка',
  'strongman': 'стронгмен',
  'cardio': 'кардіо',
  'power': 'силовий',
  'clean': 'взяття',
  'jerk': 'поштовх',
  'snatch': 'ривок',
  'swing': 'мах',
  'circles': 'кола',
  'around': 'навколо',
  'through': 'через',
  'forward': 'вперед',
  'down': 'вниз',
  'up': 'вгору',
  'horizontal': 'горизонтальний',
  'vertical': 'вертикальний',
  'diagonal': 'діагональний',
  'incline': 'під кутом вгору',
  'decline': 'під кутом вниз',
  'flat': 'горизонтально',
  'normal': 'звичайний',
  'classic': 'класичний',
  'nordic': 'нордичний',
  'sumo': 'сумо',
  'romanian': 'румунський',
  'arnold': 'Арнольда',
  'hammer': 'молотковий',
  'preacher': 'на лаві Скотта',
  'spider': 'павучий',
  'russian': 'російський',
  'pallof': 'Палофа',
  'ez': 'ізі',
  'v': 'ві',
  't': 'Т',
  'x': 'ікс',
};

const _latinTriples = {'sch': 'ш', 'tch': 'ч'};

const _latinPairs = {
  'sh': 'ш',
  'ch': 'ч',
  'zh': 'ж',
  'kh': 'х',
  'ts': 'ц',
  'ya': 'я',
  'yu': 'ю',
  'ye': 'є',
  'yi': 'ї',
  'yo': 'йо',
  'ph': 'ф',
  'th': 'т',
  'ck': 'к',
  'qu': 'кв',
  'ng': 'нг',
  'ee': 'і',
  'oo': 'у',
};

const _latinSingles = {
  'a': 'а',
  'b': 'б',
  'c': 'к',
  'd': 'д',
  'e': 'е',
  'f': 'ф',
  'g': 'г',
  'h': 'х',
  'i': 'і',
  'j': 'дж',
  'k': 'к',
  'l': 'л',
  'm': 'м',
  'n': 'н',
  'o': 'о',
  'p': 'п',
  'q': 'к',
  'r': 'р',
  's': 'с',
  't': 'т',
  'u': 'у',
  'v': 'в',
  'w': 'в',
  'x': 'кс',
  'y': 'й',
  'z': 'з',
};
