import 'dart:math';

import '../models/life_event.dart';

/// ピッチの外の出来事の一覧と、その選び方。
///
/// 数を揃えることより、「選んだことが後に残る」ことを優先している。
/// どれも効きは小さいが、10年ぶんの選択が積み上がると、
/// 同じ成績の選手でも別の人生になる。
class LifeEvents {
  LifeEvents({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 1試合ごとに出来事が起きる確率。
  static const double chancePerMatch = 0.12;

  /// 今の状況で起こりうる出来事から1つ引く。
  ///
  /// [seen] に入っている一度きりの出来事は除く。
  LifeEvent? pick(LifeContext context, {Set<String> seen = const {}}) {
    final candidates = [
      for (final e in catalogue)
        if (e.requirement.matches(context) && !(e.once && seen.contains(e.id)))
          e,
    ];
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }

  /// 出来事が起きるかどうか。
  bool fires() => _random.nextDouble() < chancePerMatch;

  static const List<LifeEvent> catalogue = [
    LifeEvent(
      id: 'media',
      title: '試合後のインタビュー',
      body: '記者が、監督の起用法について答えを迫ってくる。'
          'カメラは回ったままだ。',
      once: false,
      choices: [
        LifeChoice(
          label: '思っていることを言う',
          outcome: '見出しになった。応援する声も、呆れる声もある。',
          effect: LifeEffect(fame: 4, manager: -6, morale: 3, temper: 1),
        ),
        LifeChoice(
          label: '当たり障りなく流す',
          outcome: '何も起きなかった。それでいい日もある。',
          effect: LifeEffect(),
        ),
        LifeChoice(
          label: 'チームメイトを立てる',
          outcome: 'ロッカールームでの評判が少し上がった。',
          effect: LifeEffect(teammates: 5, manager: 2, fame: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'chant',
      title: '自分のチャントができた',
      body: 'ゴール裏が、あなたの名前で歌をつくった。'
          '試合前に、その歌がスタンドから降ってくる。',
      requirement: LifeRequirement(minFame: 40),
      choices: [
        LifeChoice(
          label: 'ゴール裏に応える',
          outcome: 'あの日から、ここは自分の場所になった。',
          effect: LifeEffect(morale: 10, fame: 3, confidence: 1),
        ),
        LifeChoice(
          label: '照れて手を上げるだけ',
          outcome: 'それでも、歌は鳴りやまなかった。',
          effect: LifeEffect(morale: 5),
        ),
      ],
    ),
    LifeEvent(
      id: 'ultras',
      title: '練習場に来た一団',
      body: '連敗が続き、熱心なサポーターが練習場の前を塞いでいる。'
          '中には、言葉が過ぎる者もいる。',
      requirement: LifeRequirement(minAge: 20),
      once: false,
      choices: [
        LifeChoice(
          label: '前に出て話を聞く',
          outcome: '罵声は止み、代わりに拍手が起きた。長い話になった。',
          effect: LifeEffect(morale: -4, fame: 3, teammates: 6, confidence: 1),
        ),
        LifeChoice(
          label: 'バスの窓から見ている',
          outcome: '何も言わずに通り過ぎた。後味は良くない。',
          effect: LifeEffect(morale: -6),
        ),
        LifeChoice(
          label: 'クラブに任せる',
          outcome: '警備が入って解散した。それが正しい対応ではあった。',
          effect: LifeEffect(morale: -2, manager: 2),
        ),
      ],
    ),
    LifeEvent(
      id: 'family',
      title: '身内からの電話',
      body: '親戚を名乗る人物から、代理人を替えろと言われている。'
          '「もっと良い話を持ってこられる人がいる」らしい。',
      requirement: LifeRequirement(minAge: 19, minFame: 25),
      choices: [
        LifeChoice(
          label: '話だけ聞いて断る',
          outcome: '角は立ったが、仕事は仕事だと伝えた。',
          effect: LifeEffect(morale: -3, professionalism: 1),
        ),
        LifeChoice(
          label: '任せてみる',
          outcome: '数か月、何も進まなかった。授業料だと思うことにした。',
          effect: LifeEffect(money: -300, morale: -5),
        ),
        LifeChoice(
          label: '電話に出るのをやめる',
          outcome: '静かになった。少しだけ、後ろめたい。',
          effect: LifeEffect(morale: -2, temper: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'friend',
      title: '親友の退団',
      body: '同じ日に加入し、同じ部屋で遠征を過ごしてきた選手が、'
          '今日クラブを去る。',
      requirement: LifeRequirement(minAge: 20),
      choices: [
        LifeChoice(
          label: '空港まで送る',
          outcome: '「向こうでも見てるからな」と言われた。',
          effect: LifeEffect(morale: -5, teammates: 4),
        ),
        LifeChoice(
          label: '練習を優先する',
          outcome: 'そういうものだ、と自分に言い聞かせた。',
          effect: LifeEffect(morale: -8, professionalism: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'dm',
      title: '深夜のDM',
      body: '負けた日に限って、知らない相手からの言葉が届く。'
          '大半は読むに堪えないものだ。',
      requirement: LifeRequirement(minFame: 30),
      once: false,
      choices: [
        LifeChoice(
          label: 'アプリを消す',
          outcome: '数日で、驚くほど気にならなくなった。',
          effect: LifeEffect(morale: 4, fame: -2, professionalism: 1),
        ),
        LifeChoice(
          label: '言い返す',
          outcome: 'そのやり取りが切り抜かれ、記事になった。',
          effect: LifeEffect(morale: -6, fame: 5, temper: 1),
        ),
        LifeChoice(
          label: 'スクリーンショットを公表する',
          outcome: '同じ思いをしていた選手たちから連絡が来た。',
          effect: LifeEffect(morale: 2, fame: 4, teammates: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'fame',
      title: '有名税',
      body: '食事に出れば写真を求められ、断れば不機嫌だと書かれる。'
          '自宅の前で待たれていた日もある。',
      requirement: LifeRequirement(minFame: 55),
      once: false,
      choices: [
        LifeChoice(
          label: '警備を付ける',
          outcome: '静かになった。金はかかる。',
          effect: LifeEffect(money: -400, morale: 6),
        ),
        LifeChoice(
          label: '気にせず今まで通り暮らす',
          outcome: '街の人には好かれた。落ち着かない日は続く。',
          effect: LifeEffect(fame: 3, morale: -4),
        ),
      ],
    ),
    LifeEvent(
      id: 'charity',
      title: '財団の話',
      body: '育った街に、子どものためのグラウンドを作らないかと'
          '声をかけられた。金も時間もかかる。',
      requirement: LifeRequirement(minAge: 25, minSavings: 3000),
      choices: [
        LifeChoice(
          label: '私財を出して設立する',
          outcome: '自分の名前の付いたグラウンドで、子どもが走っている。',
          effect: LifeEffect(
              money: -2000,
              fame: 8,
              morale: 10,
              ambition: -1,
              special: LifeSpecial.foundCharity),
        ),
        LifeChoice(
          label: '現役の間は見送る',
          outcome: '今はサッカーに集中する、と伝えた。',
          effect: LifeEffect(professionalism: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'milestone',
      title: '家族の節目',
      body: '大事な日と、アウェイの試合が重なった。'
          '本人は「気にしないで」と言っている。',
      requirement: LifeRequirement(minAge: 24),
      once: false,
      choices: [
        LifeChoice(
          label: '試合に行く',
          outcome: '勝った。写真だけが手元に残った。',
          effect: LifeEffect(morale: -6, professionalism: 1),
        ),
        LifeChoice(
          label: '欠場を願い出る',
          outcome: '監督は渋い顔をしたが、行ってこいと言った。',
          effect: LifeEffect(morale: 12, manager: -6, condition: 10),
        ),
      ],
    ),
    LifeEvent(
      id: 'abroad',
      title: '言葉と食事',
      body: '練習の指示が半分も分からない。'
          '食事も合わず、体重が落ちてきた。',
      requirement: LifeRequirement(abroad: true),
      choices: [
        LifeChoice(
          label: '語学の時間を作る',
          outcome: '半年後、冗談が分かるようになった。',
          effect: LifeEffect(
              morale: 6, teammates: 8, condition: -5, professionalism: 1),
        ),
        LifeChoice(
          label: '同郷の選手とだけ過ごす',
          outcome: '楽ではある。輪の外に居る感じは消えない。',
          effect: LifeEffect(morale: 3, teammates: -5),
        ),
      ],
    ),
    LifeEvent(
      id: 'injuryFear',
      title: '同じ場所',
      body: '復帰して数試合。競り合いの瞬間に、'
          'あの時と同じ体勢になるのが怖い。',
      requirement: LifeRequirement(afterInjury: true),
      once: false,
      choices: [
        LifeChoice(
          label: '思い切り踏み込む',
          outcome: '何も起きなかった。それで、ようやく戻ってこられた。',
          effect: LifeEffect(morale: 8, confidence: 1),
        ),
        LifeChoice(
          label: '当たりを避けて組み立てる',
          outcome: '無難にこなした。監督は物足りなさそうだった。',
          effect: LifeEffect(manager: -3, morale: -2),
        ),
      ],
    ),
    LifeEvent(
      id: 'mental',
      title: '眠れない夜',
      body: '試合のミスが頭から離れず、朝まで眠れない日が続いている。'
          'クラブには相談窓口がある。',
      requirement: LifeRequirement(lowMorale: true),
      once: false,
      choices: [
        LifeChoice(
          label: '専門家に相談する',
          outcome: '話すだけで、少し軽くなった。続けることにした。',
          effect: LifeEffect(morale: 18, condition: 5, professionalism: 1),
        ),
        LifeChoice(
          label: '誰にも言わない',
          outcome: '何とかなる、と思うことにした。',
          effect: LifeEffect(morale: -6, confidence: -1),
        ),
      ],
    ),
    LifeEvent(
      id: 'sponsor',
      title: 'スパイクの話',
      body: 'ブランドから、専属契約の打診が来ている。'
          '露出は増えるが、拘束も増える。',
      requirement: LifeRequirement(needsSponsorOffer: true),
      once: false,
      choices: [
        LifeChoice(
          label: '契約する',
          outcome: '自分の名前が入ったスパイクが店頭に並ぶ。',
          effect: LifeEffect(fame: 5, special: LifeSpecial.acceptSponsor),
        ),
        LifeChoice(
          label: '断る',
          outcome: '履き慣れたものを使い続けることにした。',
          effect: LifeEffect(morale: 3, special: LifeSpecial.declineSponsor),
        ),
      ],
    ),
    LifeEvent(
      id: 'captain',
      title: '腕章',
      body: '監督に呼ばれた。来季のキャプテンをやってほしい、と言う。'
          '責任は重い。',
      requirement: LifeRequirement(needsCaptaincy: true),
      choices: [
        LifeChoice(
          label: '受ける',
          outcome: 'ロッカールームの空気が、自分に向くようになった。',
          effect: LifeEffect(
              manager: 8,
              teammates: 10,
              morale: 5,
              ambition: 1,
              special: LifeSpecial.takeCaptain),
        ),
        LifeChoice(
          label: '自分より相応しい人がいると伝える',
          outcome: '監督は頷いた。プレーで引っ張れ、と言われた。',
          effect: LifeEffect(
              teammates: 4, special: LifeSpecial.declineCaptain),
        ),
      ],
    ),
    LifeEvent(
      id: 'veteran',
      title: '若手が寄ってくる',
      body: '練習後、若い選手が質問に来るようになった。'
          '自分が同じことを聞いていたのは、そう昔でもない。',
      requirement: LifeRequirement(minAge: 31),
      choices: [
        LifeChoice(
          label: '時間を取って教える',
          outcome: '自分の言葉で説明すると、分かっていなかったことに気づいた。',
          effect: LifeEffect(
              teammates: 10, morale: 6, professionalism: 1, condition: -5),
        ),
        LifeChoice(
          label: '自分のことに集中する',
          outcome: '現役でいる時間は、もう長くない。',
          effect: LifeEffect(condition: 5, ambition: 1, teammates: -3),
        ),
      ],
    ),
  ];
}
