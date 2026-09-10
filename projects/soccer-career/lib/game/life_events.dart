import 'dart:math';

import '../models/attributes.dart';
import '../models/development.dart';
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
  ///
  /// 0.12 だと1シーズンに4回ほどで、間が空きすぎて「たまに何か出る画面」に
  /// なっていた。0.16 で6回前後。**それでも週の主役にはならない**
  /// （6節に1回しか判断が無い）。0.34 で12回前後、3節に1回。
  /// ここを上げるなら、出来事の数と「何に効くか」の表示が要る。
  /// 同じ話が続けて出ると、頻度そのものが安っぽく見える。
  static const double chancePerMatch = 0.24;

  /// 一緒に練習している相手の話が、何倍出やすいか。
  ///
  /// 週の選択（誰と組むか）が、ピッチの外にも返ってくる。
  static const int companionWeight = 3;

  /// 今の状況で起こりうる出来事から1つ引く。
  ///
  /// [seen] に入っている一度きりの出来事は除く。
  /// [recent] に入っている出来事は、続けて出さない。
  /// [with_] と一緒に練習している相手の話は出やすい。
  LifeEvent? pick(
    LifeContext context, {
    Set<String> seen = const {},
    List<String> recent = const [],
    PersonKind? with_,
  }) {
    final candidates = [
      for (final e in catalogue)
        if (e.requirement.matches(context) && !(e.once && seen.contains(e.id)))
          e,
    ];
    if (candidates.isEmpty) return null;
    // 直前に出た話は避ける。避けた結果ゼロになるなら、そのまま出す。
    final fresh = [
      for (final e in candidates)
        if (!recent.contains(e.id)) e,
    ];
    final pool = fresh.isEmpty ? candidates : fresh;
    // 組んでいる相手の話を厚くする。
    final weighted = [
      for (final e in pool)
        ...List.filled(
            with_ != null && e.person == with_ ? companionWeight : 1, e),
    ];
    return weighted[_random.nextInt(weighted.length)];
  }

  /// 出来事が起きるかどうか。
  bool fires() => _random.nextDouble() < chancePerMatch;

  static const List<LifeEvent> catalogue = [
    // ---- 人が出てくる ----
    LifeEvent(
      id: 'mentor-drill',
      title: '<mentor>の居残り',
      body: '練習が終わったピッチに<mentor>が残っていた。'
          '「一本だけ付き合え」と手招きされる。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.mentor),
      choices: [
        LifeChoice(
          label: '付き合う',
          outcome: '足の置き方を直された。翌日、体が覚えている。',
          effect: LifeEffect(
              train: Detail.ballControl, fatigue: 2),
        ),
        LifeChoice(
          label: '見て覚える',
          outcome: '横で見ていた。理屈のほうが先に入ってきた。',
          effect: LifeEffect(train: Detail.vision),
        ),
        LifeChoice(
          label: '今日は帰る',
          outcome: '体を休めた。無理をしない日があってもいい。',
          effect: LifeEffect(condition: 6),
        ),
      ],
    ),
    LifeEvent(
      id: 'mentor-secret',
      title: '<mentor>が教えてくれたこと',
      body: '「これは誰にも言うなよ」と、<mentor>が長年やってきた'
          '体の使い方を見せてくれた。',
      requirement: LifeRequirement(needsPerson: PersonKind.mentor, minAge: 19),
      choices: [
        LifeChoice(
          label: '盗む',
          outcome: '何度も真似た。自分のものになりつつある。',
          effect: LifeEffect(insight: Signature.shoulder, fatigue: 3),
        ),
        LifeChoice(
          label: '自分のやり方でいく',
          outcome: '真似はしなかった。その代わり、自分の形を突き詰めた。',
          effect: LifeEffect(train: Detail.strength, confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'mentor-retire',
      title: '<mentor>の引退',
      body: '<mentor>が今季限りで辞めると言った。'
          '「お前はまだやれる。俺のぶんまでやれ」',
      requirement: LifeRequirement(needsPerson: PersonKind.mentor, minAge: 22),
      choices: [
        LifeChoice(
          label: '受け取る',
          outcome: '背負うものが増えた。悪くない重さだ。',
          effect: LifeEffect(morale: 6, ambition: 1, professionalism: 1),
        ),
        LifeChoice(
          label: '静かに送り出す',
          outcome: '言葉は交わさなかった。それで十分だった。',
          effect: LifeEffect(morale: 3, teammates: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'competitor-clash',
      title: '<competitor>との衝突',
      body: '紅白戦で<competitor>と激しく当たった。'
          'ロッカールームの空気が固い。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.competitor),
      choices: [
        LifeChoice(
          label: '謝る',
          outcome: '先に頭を下げた。周りが安心したのが分かった。',
          effect: LifeEffect(teammates: 6),
        ),
        LifeChoice(
          label: '引かない',
          outcome: '目を逸らさなかった。次の練習の強度が上がった。',
          effect: LifeEffect(teammates: -4, morale: 3),
        ),
        LifeChoice(
          label: '結果で黙らせる',
          outcome: '何も言わずに走り込んだ。',
          effect: LifeEffect(fatigue: 4, morale: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'competitor-injury',
      title: '<competitor>が離脱した',
      body: '同じポジションを争う<competitor>が長期離脱した。'
          '出番は増える。',
      requirement: LifeRequirement(needsPerson: PersonKind.competitor),
      choices: [
        LifeChoice(
          label: '見舞いに行く',
          outcome: '短く話した。戻ってきたときにやり合えばいい。',
          effect: LifeEffect(teammates: 6, morale: 2),
        ),
        LifeChoice(
          label: 'この機を逃さない',
          outcome: '練習量を上げた。空いた場所は自分のものにする。',
          effect: LifeEffect(fatigue: 4, manager: 3, ambition: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'partner-drill',
      title: '<partner>との朝練',
      body: '<partner>から「朝、二人でやらないか」と誘われた。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.partner),
      choices: [
        LifeChoice(
          label: '毎朝やる',
          outcome: '呼吸が合ってきた。言わなくても動きが分かる。',
          effect: LifeEffect(
              train: Detail.shortPassing, fatigue: 3),
        ),
        LifeChoice(
          label: '週に一度だけ',
          outcome: '無理のない範囲で続けた。',
          effect: LifeEffect(train: Detail.vision, teammates: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'partner-trust',
      title: '<partner>の一言',
      body: '「お前が出してくれるなら、俺はどこへでも走る」'
          '<partner>がそう言った。',
      requirement: LifeRequirement(needsPerson: PersonKind.partner, minAge: 20),
      choices: [
        LifeChoice(
          label: 'それに応える',
          outcome: '見えていなかった場所が見えるようになった。',
          effect: LifeEffect(insight: Signature.noLook, morale: 4),
        ),
        LifeChoice(
          label: '自分で決める形も残す',
          outcome: '任せきりにはしない。最後は自分で決める。',
          effect: LifeEffect(train: Detail.finishing, confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'rival-news',
      title: '<rival>の活躍',
      body: '同期の<rival>が別のクラブで結果を出している。'
          '記事の見出しに名前が並んでいた。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.rival),
      choices: [
        LifeChoice(
          label: '焦る',
          outcome: '眠れなかった。翌朝、誰より早くグラウンドに出た。',
          effect: LifeEffect(fatigue: 4, morale: -2, manager: 3),
        ),
        LifeChoice(
          label: '自分の速さでいく',
          outcome: '比べても仕方がない。やることは変わらない。',
          effect: LifeEffect(morale: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'rival-meet',
      title: '<rival>と会った',
      body: 'オフに<rival>と食事を挟んで話した。'
          '互いに、まだ何も掴んでいないことを確かめ合った。',
      requirement: LifeRequirement(needsPerson: PersonKind.rival, minAge: 20),
      choices: [
        LifeChoice(
          label: '約束する',
          outcome: '「上で会おう」。安い言葉だが、腹は決まった。',
          effect: LifeEffect(ambition: 2, morale: 5),
        ),
        LifeChoice(
          label: '何も言わない',
          outcome: '言葉にしなかったぶん、体を動かした。',
          effect: LifeEffect(fatigue: 2, morale: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'manager-talk',
      title: '<manager>に呼ばれた',
      body: '監督室に呼ばれた。<manager>は、今の起用について'
          'どう思っているかを聞いてきた。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.manager),
      choices: [
        LifeChoice(
          label: '納得していないと言う',
          outcome: '空気は張り詰めたが、言いたいことは伝わった。',
          effect: LifeEffect(manager: -4),
        ),
        LifeChoice(
          label: '足りないところを聞く',
          outcome: '具体的に3つ挙げられた。やることが決まった。',
          effect: LifeEffect(manager: 6, morale: 2),
        ),
        LifeChoice(
          label: '任せますと答える',
          outcome: '何も変わらなかった。',
          effect: LifeEffect(manager: 2),
        ),
      ],
    ),
    LifeEvent(
      id: 'manager-role',
      title: '<manager>の構想',
      body: '<manager>が、来季の並びに自分をどう置くつもりかを'
          '図に書いて見せてくれた。',
      requirement: LifeRequirement(
          needsPerson: PersonKind.manager, minAge: 21, minOverall: 68),
      choices: [
        LifeChoice(
          label: 'その役をやり切る',
          outcome: '求められている動きを頭に入れた。',
          effect: LifeEffect(manager: 5, professionalism: 1),
        ),
        LifeChoice(
          label: 'もっと前でやりたいと言う',
          outcome: '検討すると言われた。可も不可もない。',
          effect: LifeEffect(manager: -2, ambition: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'agent-plan',
      title: '<agent>との打ち合わせ',
      body: '<agent>が資料を広げた。'
          '「このままだと、来年の話が薄い」',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.agent, minAge: 20),
      choices: [
        LifeChoice(
          label: '任せる',
          outcome: '動いてもらうことにした。手数料は先に消えた。',
          effect: LifeEffect(money: -200, fame: 4),
        ),
        LifeChoice(
          label: 'ピッチで示す',
          outcome: '売り込みより、結果のほうが早いと答えた。',
          effect: LifeEffect(fame: 2, morale: 2),
        ),
      ],
    ),

    // ---- 練習の中で起きる ----
    LifeEvent(
      id: 'drill-breakthrough',
      title: '感触',
      body: '同じ動きを繰り返しているうちに、'
          '急に体の使い方が分かった気がした。',
      once: false,
      choices: [
        LifeChoice(
          label: 'もう一度やってみる',
          outcome: '再現できた。まぐれではない。',
          effect: LifeEffect(train: Detail.agility, fatigue: 2),
        ),
        LifeChoice(
          label: '今日はここで止める',
          outcome: '感触を残したまま切り上げた。',
          effect: LifeEffect(train: Detail.agility, condition: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'drill-video',
      title: '映像を見る',
      body: '自分の試合の映像が渡された。見たくない場面もある。',
      once: false,
      choices: [
        LifeChoice(
          label: '失敗した場面から見る',
          outcome: '何度も止めて見た。理由が分かると、次が変わる。',
          effect: LifeEffect(
              train: Detail.gkPositioning, morale: -1),
        ),
        LifeChoice(
          label: '良かった場面を見る',
          outcome: '悪くない。自信は道具になる。',
          effect: LifeEffect(morale: 4),
        ),
        LifeChoice(
          label: '見ない',
          outcome: '頭を空にした。それが要る日もある。',
          effect: LifeEffect(condition: 5, fatigue: -3),
        ),
      ],
    ),
    LifeEvent(
      id: 'drill-strain',
      title: '違和感',
      body: '練習中、太ももに軽い違和感が出た。'
          '動けないほどではない。',
      once: false,
      choices: [
        LifeChoice(
          label: 'すぐ切り上げる',
          outcome: '大事を取った。翌日には引いていた。',
          effect: LifeEffect(condition: 10),
        ),
        LifeChoice(
          label: '最後までやる',
          outcome: 'やり切った。疲れは残った。',
          effect: LifeEffect(
              train: Detail.stamina, fatigue: 6, condition: -8),
        ),
      ],
    ),
    LifeEvent(
      id: 'drill-freekick',
      title: '誰もいないピッチ',
      body: '全体練習が終わったあと、ボールが1つ残っていた。',
      once: false,
      choices: [
        LifeChoice(
          label: '無回転を試す',
          outcome: '20本目で、初めて落ちた。',
          effect: LifeEffect(insight: Signature.knuckle, fatigue: 3),
        ),
        LifeChoice(
          label: '止めて蹴るを繰り返す',
          outcome: '地味な反復。だが、確実に残る。',
          effect: LifeEffect(train: Detail.shortPassing, fatigue: 2),
        ),
        LifeChoice(
          label: '片付けて帰る',
          outcome: '道具を片付けて帰った。',
          effect: LifeEffect(condition: 5),
        ),
      ],
    ),

    // ---- 外の世界 ----
    LifeEvent(
      id: 'kids-clinic',
      title: '子どもたちの前で',
      body: '地域のサッカー教室に呼ばれた。'
          '50人の子どもが待っている。',
      once: false,
      requirement: LifeRequirement(minFame: 20),
      choices: [
        LifeChoice(
          label: '本気で相手をする',
          outcome: '全員と一対一をやった。帰りは足が上がらなかった。',
          effect: LifeEffect(fame: 5, morale: 5, fatigue: 4),
        ),
        LifeChoice(
          label: '話をして帰る',
          outcome: '15分だけ話した。悪くない時間だった。',
          effect: LifeEffect(fame: 2, morale: 2),
        ),
      ],
    ),
    LifeEvent(
      id: 'old-coach',
      title: '恩師からの手紙',
      body: '育ててくれた指導者から手紙が届いた。'
          '「見ているよ」とだけ書いてあった。',
      requirement: LifeRequirement(minAge: 20),
      choices: [
        LifeChoice(
          label: '返事を書く',
          outcome: '長い返事になった。書きながら、原点を思い出した。',
          effect: LifeEffect(morale: 7, professionalism: 1),
        ),
        LifeChoice(
          label: '結果で返す',
          outcome: '手紙は机に置いたままにした。次の試合で返す。',
          effect: LifeEffect(morale: 4, ambition: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'night-out',
      title: '誘い',
      body: '同期に飲みに誘われた。明日はオフだ。',
      once: false,
      requirement: LifeRequirement(minAge: 19),
      choices: [
        LifeChoice(
          label: '行く',
          outcome: 'よく笑った。少し飲みすぎた。',
          effect: LifeEffect(morale: 6, condition: -10),
        ),
        LifeChoice(
          label: '一杯だけ',
          outcome: '顔を出して早めに帰った。',
          effect: LifeEffect(morale: 3, teammates: 3, condition: -3),
        ),
        LifeChoice(
          label: '断る',
          outcome: '家で映像を見た。',
          effect: LifeEffect(condition: 4),
        ),
      ],
    ),
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
    // ---- 自分が選んだことが返ってくる ----
    LifeEvent(
      id: 'push-body',
      title: '身体が重い',
      body: '追い込んだ翌朝、階段を降りるのに手すりを掴んだ。'
          'まだやれる、とも思う。',
      once: false,
      requirement: LifeRequirement(pushingHard: true),
      choices: [
        LifeChoice(
          label: '構わず追い込む',
          outcome: '振り切った。身体は正直に軋んだ。',
          effect: LifeEffect(
              train: Detail.stamina, fatigue: 8, condition: -6, ambition: 1),
        ),
        LifeChoice(
          label: '一日だけ落とす',
          outcome: '落とした日の翌日、身体が軽かった。',
          effect: LifeEffect(condition: 10, fatigue: -6),
        ),
        LifeChoice(
          label: 'トレーナーに診てもらう',
          outcome: '悪いところは無い、と言われた。それだけで少し楽になった。',
          effect: LifeEffect(condition: 5, morale: 4, professionalism: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'push-notice',
      title: '見ている人がいる',
      body: '誰も居ないはずの時間に走っていたら、'
          'クラブの職員が黙って水を置いていった。',
      once: false,
      requirement: LifeRequirement(pushingHard: true),
      choices: [
        LifeChoice(
          label: '礼を言って続ける',
          outcome: '見られていることが、少しだけ背中を押した。',
          effect: LifeEffect(morale: 6, professionalism: 1, fatigue: 3),
        ),
        LifeChoice(
          label: '切り上げる',
          outcome: '今日はここまで。明日も来る。',
          effect: LifeEffect(condition: 6),
        ),
      ],
    ),
    LifeEvent(
      id: 'promise-weight',
      title: '言葉の重さ',
      body: '記者に約束のことを蒸し返された。'
          '「あれ、本気ですか」と笑いを含んだ声で聞かれる。',
      once: false,
      requirement: LifeRequirement(promised: true),
      choices: [
        LifeChoice(
          label: 'もう一度言い切る',
          outcome: '逃げ道はもう無い。それでいい。',
          effect: LifeEffect(fame: 4, confidence: 1, morale: 4, manager: 2),
        ),
        LifeChoice(
          label: '笑ってかわす',
          outcome: '言葉を薄めた。少しだけ楽になった。',
          effect: LifeEffect(morale: 3, confidence: -1),
        ),
        LifeChoice(
          label: '結果で見せると答える',
          outcome: '余計なことは言わなかった。',
          effect: LifeEffect(professionalism: 1, teammates: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'promise-doubt',
      title: '眠れない夜',
      body: '口にした数字が、天井のあたりに浮かんでいる。'
          '取り消せないことだけは分かっている。',
      once: false,
      requirement: LifeRequirement(promised: true, lowCondition: true),
      choices: [
        LifeChoice(
          label: '映像を見返す',
          outcome: '止められた場面を数えた。眠るのは遅くなった。',
          effect: LifeEffect(train: Detail.vision, condition: -4),
        ),
        LifeChoice(
          label: '寝る',
          outcome: '考えても点は入らない。',
          effect: LifeEffect(condition: 8, morale: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'tired-choice',
      title: '出たいと言うか',
      body: '身体は限界に近い。次の試合、監督は使うつもりでいる。',
      once: false,
      requirement: LifeRequirement(lowCondition: true),
      choices: [
        LifeChoice(
          label: '出ると言う',
          outcome: '無理を通した。監督は頷いた。',
          effect:
              LifeEffect(manager: 5, teammates: 3, fatigue: 6, condition: -4),
        ),
        LifeChoice(
          label: '正直に伝える',
          outcome: '外された。身体は少し戻った。',
          effect: LifeEffect(manager: -4, condition: 12, fatigue: -6),
        ),
      ],
    ),
    // ---- 人との時間 ----
    LifeEvent(
      id: 'partner-dinner',
      title: '<partner>と飯を食う',
      body: '練習の帰り、<partner>が「行くか」と顎で示した。'
          '大した話はしない相手だが、居心地は悪くない。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.partner),
      choices: [
        LifeChoice(
          label: '付き合う',
          outcome: 'サッカーの話は半分もしなかった。',
          effect: LifeEffect(morale: 8, teammates: 5, condition: -3),
        ),
        LifeChoice(
          label: '映像を見たいと断る',
          outcome: '一人で画面に向かった。<partner>は何も言わなかった。',
          effect: LifeEffect(train: Detail.vision, teammates: -2),
        ),
      ],
    ),
    LifeEvent(
      id: 'competitor-advice',
      title: '<competitor>の一言',
      body: '自分が外れた試合の後、<competitor>が'
          '「あそこ、俺なら逆を向く」と言ってきた。悪意は無いらしい。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.competitor),
      choices: [
        LifeChoice(
          label: '素直に聞く',
          outcome: '確かに逆だった。悔しさは後から来た。',
          effect: LifeEffect(train: Detail.ballControl, temper: -1),
        ),
        LifeChoice(
          label: '言い返す',
          outcome: '譲らなかった。次で見せるしかない。',
          effect: LifeEffect(confidence: 1, teammates: -3),
        ),
        LifeChoice(
          label: '黙って練習に戻る',
          outcome: '言葉より、足を動かした。',
          effect: LifeEffect(train: Detail.stamina, professionalism: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'mentor-limit',
      title: '<mentor>の身体',
      body: '<mentor>がアイシングをしながら「もう戻らないところがある」と言った。'
          '笑っていたが、目は笑っていなかった。',
      requirement: LifeRequirement(needsPerson: PersonKind.mentor),
      choices: [
        LifeChoice(
          label: '自分の身体の使い方を聞く',
          outcome: '壊れる前にやることがある、と教わった。',
          effect: LifeEffect(professionalism: 2, condition: 5),
        ),
        LifeChoice(
          label: '何も言わずに隣に座る',
          outcome: 'しばらく黙っていた。それで十分だった。',
          effect: LifeEffect(morale: 6, teammates: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'manager-clash',
      title: '<manager>と噛み合わない',
      body: 'ミーティングで名指しされた。'
          '言っていることは分かる。ただ、自分のやり方とは違う。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.manager),
      choices: [
        LifeChoice(
          label: '飲み込んで合わせる',
          outcome: '違和感は残ったが、使われるほうを取った。',
          effect: LifeEffect(manager: 7, confidence: -1),
        ),
        LifeChoice(
          label: 'その場で反論する',
          outcome: '空気が固まった。何人かは、こちらを見ていた。',
          effect: LifeEffect(manager: -8, teammates: 5, temper: 1),
        ),
        LifeChoice(
          label: '後で二人で話す',
          outcome: '納得はしていないが、話は通じた。',
          effect: LifeEffect(manager: 3, professionalism: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'agent-offer-talk',
      title: '<agent>からの電話',
      body: '「動いている話がある」とだけ言われた。'
          '詳しくは言わない。今は言えない、ということらしい。',
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.agent, minAge: 21),
      choices: [
        LifeChoice(
          label: '任せると答える',
          outcome: '考えることが一つ減った。',
          effect: LifeEffect(morale: 5, ambition: 1),
        ),
        LifeChoice(
          label: '今は聞きたくないと言う',
          outcome: '目の前の試合に戻った。',
          effect: LifeEffect(professionalism: 1, condition: 3),
        ),
      ],
    ),
    // ---- 生活 ----
    LifeEvent(
      id: 'sleep',
      title: '眠れていない',
      body: '寝つきが悪い日が続いている。'
          '朝の重さは、練習の重さとは違う種類のものだ。',
      once: false,
      requirement: LifeRequirement(lowCondition: true),
      choices: [
        LifeChoice(
          label: '専門家に相談する（-40万円）',
          outcome: '寝る前の手順を変えただけで、驚くほど変わった。',
          effect: LifeEffect(money: -40, condition: 12, professionalism: 1),
        ),
        LifeChoice(
          label: '自分でどうにかする',
          outcome: '少しずつ戻ってきた。時間はかかった。',
          effect: LifeEffect(condition: 5),
        ),
      ],
    ),
    LifeEvent(
      id: 'hometown',
      title: '地元に帰る',
      body: 'オフの数日、育った街に戻った。'
          '通っていたグラウンドは、記憶より狭かった。',
      once: false,
      requirement: LifeRequirement(minAge: 22),
      choices: [
        LifeChoice(
          label: '子どもたちに混ざる',
          outcome: '本気で相手をしたら、息が上がった。',
          effect: LifeEffect(morale: 10, fame: 2, condition: -4),
        ),
        LifeChoice(
          label: '一人で歩く',
          outcome: 'ここから始まったのだと、静かに思い出した。',
          effect: LifeEffect(morale: 6, confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'boots',
      title: '道具を見直す',
      body: '同じモデルを何年も履いている。'
          '新しいものを試してみないか、と用具担当に言われた。',
      once: false,
      requirement: LifeRequirement(),
      choices: [
        LifeChoice(
          label: '試す（-20万円）',
          outcome: '足の感覚が変わった。慣れるまで少しかかりそうだ。',
          effect: LifeEffect(money: -20, train: Detail.agility),
        ),
        LifeChoice(
          label: '慣れたものを履く',
          outcome: '迷いは無い。それも一つの強さだ。',
          effect: LifeEffect(confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'video-night',
      title: '相手の映像',
      body: '次の相手の映像が配られた。'
          '見なくても試合はできる。見れば、何か見つかるかもしれない。',
      once: false,
      requirement: LifeRequirement(),
      choices: [
        LifeChoice(
          label: '遅くまで見る',
          outcome: '癖が一つ見つかった。眠いのは仕方がない。',
          effect: LifeEffect(train: Detail.vision, condition: -5, fatigue: 3),
        ),
        LifeChoice(
          label: '要点だけ確認する',
          outcome: '必要なことは頭に入れた。',
          effect: LifeEffect(train: Detail.marking, condition: -1),
        ),
        LifeChoice(
          label: '見ない',
          outcome: '自分のプレーに集中した。',
          effect: LifeEffect(condition: 4, confidence: 1),
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
