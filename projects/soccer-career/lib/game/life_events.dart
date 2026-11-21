import 'dart:math';

import '../l10n/lang.dart';
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
          with_ != null && e.person == with_ ? companionWeight : 1,
          e,
        ),
    ];
    return weighted[_random.nextInt(weighted.length)];
  }

  /// 出来事が起きるかどうか。
  bool fires() => _random.nextDouble() < chancePerMatch;

  /// **返事を待っている打診（スポンサー・腕章）。** あれば次の試合のあとに必ず出す。
  ///
  /// 打診はホームに「スポンサーの話が来ている」と出るのに、答える場は
  /// 出来事の抽選でしか来なかった。1試合 24% × 候補 数十件のうちの1件なので、
  /// 1シーズン待っても来ないことが多く、利用者から「選ぶ場所が無い」と
  /// 問い合わせが来た（2026-11-16）。来ていると見せた話は、すぐ答えさせる。
  LifeEvent? offerWaiting(LifeContext context) {
    for (final e in catalogue) {
      final r = e.requirement;
      if ((r.needsSponsorOffer || r.needsCaptaincy) && r.matches(context)) {
        return e;
      }
    }
    return null;
  }

  static const List<LifeEvent> catalogue = [
    // ---- 人が出てくる ----
    LifeEvent(
      id: 'mentor-drill',
      title: Say('<mentor>の居残り', 'Extra work with <mentor>'),
      body:
          Say('練習が終わったピッチに<mentor>が残っていた。'
          '「一本だけ付き合え」と手招きされる。', '<mentor> was still out on the pitch after training. He waves you over: just one more.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.mentor),
      choices: [
        LifeChoice(
          label: Say('付き合う', 'Join him'),
          outcome: Say('足の置き方を直された。翌日、体が覚えている。', 'He fixed where you plant your foot. The next day your body remembers.'),
          effect: LifeEffect(train: Detail.ballControl, fatigue: 2),
        ),
        LifeChoice(
          label: Say('見て覚える', 'Watch and learn'),
          outcome: Say('横で見ていた。理屈のほうが先に入ってきた。', 'You watched from beside him. The reasoning landed first.'),
          effect: LifeEffect(train: Detail.vision),
        ),
        LifeChoice(
          label: Say('今日は帰る', 'Head home today'),
          outcome: Say('体を休めた。無理をしない日があってもいい。', 'You rested. Some days it is right not to push.'),
          effect: LifeEffect(condition: 6),
        ),
      ],
    ),
    LifeEvent(
      id: 'mentor-secret',
      title: Say('<mentor>が教えてくれたこと', 'What <mentor> showed you'),
      body:
          Say('「これは誰にも言うなよ」と、<mentor>が長年やってきた'
          '体の使い方を見せてくれた。', 'Do not tell anyone, he said, and showed you how he has used his body all these years.'),
      requirement: LifeRequirement(needsPerson: PersonKind.mentor, minAge: 19),
      choices: [
        LifeChoice(
          label: Say('盗む', 'Take it'),
          outcome: Say('何度も真似た。自分のものになりつつある。', 'You copied it again and again. It is becoming yours.'),
          effect: LifeEffect(insight: Signature.shoulder, fatigue: 3),
        ),
        LifeChoice(
          label: Say('自分のやり方でいく', 'Stick to your own way'),
          outcome: Say('真似はしなかった。その代わり、自分の形を突き詰めた。', 'You did not copy it. Instead you sharpened your own.'),
          effect: LifeEffect(train: Detail.strength, confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'mentor-retire',
      title: Say('<mentor>の引退', '<mentor> retires'),
      body:
          Say('<mentor>が今季限りで辞めると言った。'
          '「お前はまだやれる。俺のぶんまでやれ」', '<mentor> says this is his last season. You can still go. Go for me too.'),
      requirement: LifeRequirement(needsPerson: PersonKind.mentor, minAge: 22),
      choices: [
        LifeChoice(
          label: Say('受け取る', 'Take it on'),
          outcome: Say('背負うものが増えた。悪くない重さだ。', 'You carry more now. It is not a bad weight.'),
          effect: LifeEffect(morale: 6, ambition: 1),
        ),
        LifeChoice(
          label: Say('静かに送り出す', 'See him off quietly'),
          outcome: Say('言葉は交わさなかった。それで十分だった。', 'Nothing was said. It did not need to be.'),
          effect: LifeEffect(morale: 3, teammates: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'competitor-clash',
      title: Say('<competitor>との衝突', 'A clash with <competitor>'),
      body:
          Say('紅白戦で<competitor>と激しく当たった。'
          'ロッカールームの空気が固い。', 'You went in hard on <competitor> in training. The dressing room is tense.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.competitor),
      choices: [
        LifeChoice(
          label: Say('謝る', 'Apologise'),
          outcome: Say('先に頭を下げた。周りが安心したのが分かった。', 'You bowed your head first. You could feel the room relax.'),
          effect: LifeEffect(teammates: 6),
        ),
        LifeChoice(
          label: Say('引かない', 'Do not back down'),
          outcome: Say('目を逸らさなかった。次の練習の強度が上がった。', 'You did not look away. The next session was fiercer.'),
          effect: LifeEffect(teammates: -4, morale: 3),
        ),
        LifeChoice(
          label: Say('結果で黙らせる', 'Let your results answer'),
          outcome: Say('何も言わずに走り込んだ。', 'You said nothing and ran.'),
          effect: LifeEffect(fatigue: 4, morale: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'competitor-injury',
      title: Say('<competitor>が離脱した', '<competitor> is out'),
      body:
          Say('同じポジションを争う<competitor>が長期離脱した。'
          '出番は増える。', '<competitor>, who plays your position, is out long term. There are more chances now.'),
      requirement: LifeRequirement(needsPerson: PersonKind.competitor),
      choices: [
        LifeChoice(
          label: Say('見舞いに行く', 'Go and see him'),
          outcome: Say('短く話した。戻ってきたときにやり合えばいい。', 'You spoke briefly. You can fight it out when he is back.'),
          effect: LifeEffect(teammates: 6, morale: 2),
        ),
        LifeChoice(
          label: Say('この機を逃さない', 'Seize the moment'),
          outcome: Say('練習量を上げた。空いた場所は自分のものにする。', 'You trained harder. The space that opened up is yours.'),
          effect: LifeEffect(fatigue: 4, manager: 3, ambition: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'partner-drill',
      title: Say('<partner>との朝練', 'Early sessions with <partner>'),
      body: Say('<partner>から「朝、二人でやらないか」と誘われた。', '<partner> asks if you want to work together in the mornings.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.partner),
      choices: [
        LifeChoice(
          label: Say('毎朝やる', 'Every morning'),
          outcome: Say('呼吸が合ってきた。言わなくても動きが分かる。', 'You are reading each other. No words needed.'),
          effect: LifeEffect(train: Detail.shortPassing, fatigue: 3),
        ),
        LifeChoice(
          label: Say('週に一度だけ', 'Once a week'),
          outcome: Say('無理のない範囲で続けた。', 'You kept it going at a sensible rate.'),
          effect: LifeEffect(train: Detail.vision, teammates: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'partner-trust',
      title: Say('<partner>の一言', 'A word from <partner>'),
      body:
          Say('「お前が出してくれるなら、俺はどこへでも走る」'
          '<partner>がそう言った。', 'If you play the ball, I will run anywhere, <partner> told you.'),
      requirement: LifeRequirement(needsPerson: PersonKind.partner, minAge: 20),
      choices: [
        LifeChoice(
          label: Say('それに応える', 'Repay it'),
          outcome: Say('見えていなかった場所が見えるようになった。', 'You started seeing spaces you had not seen before.'),
          effect: LifeEffect(insight: Signature.noLook, morale: 4),
        ),
        LifeChoice(
          label: Say('自分で決める形も残す', 'Keep finishing yourself too'),
          outcome: Say('任せきりにはしない。最後は自分で決める。', 'You do not hand it all over. The last ball is still yours.'),
          effect: LifeEffect(train: Detail.finishing, confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'rival-news',
      title: Say('<rival>の活躍', '<rival> is doing well'),
      body:
          Say('同期の<rival>が別のクラブで結果を出している。'
          '記事の見出しに名前が並んでいた。', '<rival>, from your intake, is delivering at another club. His name was in the headlines.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.rival),
      choices: [
        LifeChoice(
          label: Say('焦る', 'Panic'),
          outcome: Say('眠れなかった。翌朝、誰より早くグラウンドに出た。', 'You could not sleep. Next morning you were out on the grass before anyone.'),
          effect: LifeEffect(fatigue: 4, morale: -2, manager: 3),
        ),
        LifeChoice(
          label: Say('自分の速さでいく', 'Go at your own pace'),
          outcome: Say('比べても仕方がない。やることは変わらない。', 'There is no point comparing. The work is the same.'),
          effect: LifeEffect(morale: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'rival-meet',
      title: Say('<rival>と会った', 'A meeting with <rival>'),
      body:
          Say('オフに<rival>と食事を挟んで話した。'
          '互いに、まだ何も掴んでいないことを確かめ合った。', 'You had dinner with <rival> in the off-season. Neither of you has made it yet.'),
      requirement: LifeRequirement(needsPerson: PersonKind.rival, minAge: 20),
      choices: [
        LifeChoice(
          label: Say('約束する', 'Make a promise'),
          outcome: Say('「上で会おう」。安い言葉だが、腹は決まった。', 'See you at the top. Cheap words, but your mind is made up.'),
          effect: LifeEffect(ambition: 2, morale: 5),
        ),
        LifeChoice(
          label: Say('何も言わない', 'Say nothing'),
          outcome: Say('言葉にしなかったぶん、体を動かした。', 'You kept it in and put it into your body instead.'),
          effect: LifeEffect(fatigue: 2, morale: 3, teammates: 2),
        ),
      ],
    ),
    LifeEvent(
      id: 'manager-talk',
      title: Say('<manager>に呼ばれた', '<manager> calls you in'),
      body:
          Say('監督室に呼ばれた。<manager>は、今の起用について'
          'どう思っているかを聞いてきた。', 'Called to the office. <manager> asks how you feel about how you are being used.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.manager),
      choices: [
        LifeChoice(
          label: Say('納得していないと言う', 'Say you are not happy'),
          outcome: Say('空気は張り詰めたが、言いたいことは伝わった。', 'The air went tight, but you got your point across.'),
          effect: LifeEffect(manager: -4, morale: 5),
        ),
        LifeChoice(
          label: Say('足りないところを聞く', 'Ask what is missing'),
          outcome: Say('具体的に3つ挙げられた。やることが決まった。', 'He named three things. Now you know what to do.'),
          effect: LifeEffect(manager: 6, morale: 2),
        ),
        LifeChoice(
          label: Say('任せますと答える', 'Say it is up to him'),
          outcome: Say('何も変わらなかった。', 'Nothing changed.'),
          effect: LifeEffect(manager: 2, teammates: 2),
        ),
      ],
    ),
    LifeEvent(
      id: 'manager-role',
      title: Say('<manager>の構想', '<manager> plans'),
      body:
          Say('<manager>が、来季の並びに自分をどう置くつもりかを'
          '図に書いて見せてくれた。', '<manager> drew out where he sees you in next season\'s shape.'),
      requirement: LifeRequirement(
        needsPerson: PersonKind.manager,
        minAge: 21,
        minOverall: 68,
      ),
      choices: [
        LifeChoice(
          label: Say('その役をやり切る', 'Play that role fully'),
          outcome: Say('求められている動きを頭に入れた。', 'You put the movements he wants into your head.'),
          effect: LifeEffect(manager: 5),
        ),
        LifeChoice(
          label: Say('もっと前でやりたいと言う', 'Say you want to play higher'),
          outcome: Say('検討すると言われた。可も不可もない。', 'He said he would think about it. Nothing either way.'),
          effect: LifeEffect(manager: -2, ambition: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'agent-plan',
      title: Say('<agent>との打ち合わせ', 'A meeting with <agent>'),
      body:
          Say('<agent>が資料を広げた。'
          '「このままだと、来年の話が薄い」', '<agent> spread out the paperwork. As it stands, next year is thin.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.agent, minAge: 20),
      choices: [
        LifeChoice(
          label: Say('任せる', 'Leave it to him'),
          outcome: Say('動いてもらうことにした。手数料は先に消えた。', 'You let him work. The fee went first.'),
          effect: LifeEffect(money: -200, fame: 4),
        ),
        LifeChoice(
          label: Say('ピッチで示す', 'Show it on the pitch'),
          outcome: Say('売り込みより、結果のほうが早いと答えた。', 'You said results travel faster than a sales pitch.'),
          effect: LifeEffect(fame: 2, morale: 2),
        ),
      ],
    ),

    // ---- 練習の中で起きる ----
    LifeEvent(
      id: 'drill-breakthrough',
      title: Say('感触', 'A feeling'),
      body:
          Say('同じ動きを繰り返しているうちに、'
          '急に体の使い方が分かった気がした。', 'Repeating the same movement, you suddenly understood how to use your body.'),
      once: false,
      choices: [
        LifeChoice(
          label: Say('もう一度やってみる', 'Try it again'),
          outcome: Say('再現できた。まぐれではない。', 'You did it again. It was not a fluke.'),
          effect: LifeEffect(train: Detail.agility, trainAmount: 2, fatigue: 2),
        ),
        LifeChoice(
          label: Say('今日はここで止める', 'Stop here for today'),
          outcome: Say('感触を残したまま切り上げた。', 'You left while the feeling was still there.'),
          effect: LifeEffect(train: Detail.agility, condition: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'drill-video',
      title: Say('映像を見る', 'Watching the tape'),
      body: Say('自分の試合の映像が渡された。見たくない場面もある。', 'Footage of your own match. Some of it you would rather not see.'),
      once: false,
      choices: [
        LifeChoice(
          label: Say('失敗した場面から見る', 'Start with the mistakes'),
          outcome: Say('何度も止めて見た。理由が分かると、次が変わる。', 'You stopped and replayed it again and again. Once you know why, the next one changes.'),
          effect: LifeEffect(train: Detail.gkPositioning, morale: -1),
        ),
        LifeChoice(
          label: Say('良かった場面を見る', 'Start with the good bits'),
          outcome: Say('悪くない。自信は道具になる。', 'Not bad. Confidence is a tool.'),
          effect: LifeEffect(morale: 4),
        ),
        LifeChoice(
          label: Say('見ない', 'Do not watch'),
          outcome: Say('頭を空にした。それが要る日もある。', 'You emptied your head. Some days need that.'),
          effect: LifeEffect(condition: 5, fatigue: -3),
        ),
      ],
    ),
    LifeEvent(
      id: 'drill-strain',
      title: Say('違和感', 'Something feels off'),
      body:
          Say('練習中、太ももに軽い違和感が出た。'
          '動けないほどではない。', 'A slight twinge in your thigh in training. Not enough to stop you.'),
      once: false,
      choices: [
        LifeChoice(
          label: Say('すぐ切り上げる', 'Stop early'),
          outcome: Say('大事を取った。翌日には引いていた。', 'You took no chances. It had gone by the next day.'),
          effect: LifeEffect(condition: 10),
        ),
        LifeChoice(
          label: Say('最後までやる', 'Finish the session'),
          outcome: Say('やり切った。疲れは残った。', 'You got through it. The tiredness stayed.'),
          effect: LifeEffect(train: Detail.stamina, fatigue: 6, condition: -8),
        ),
      ],
    ),
    LifeEvent(
      id: 'drill-freekick',
      title: Say('誰もいないピッチ', 'An empty pitch'),
      body: Say('全体練習が終わったあと、ボールが1つ残っていた。', 'After the group session, one ball was left out.'),
      once: false,
      choices: [
        LifeChoice(
          label: Say('無回転を試す', 'Try a knuckleball'),
          outcome: Say('20本目で、初めて落ちた。', 'On the twentieth attempt, one finally dipped.'),
          effect: LifeEffect(insight: Signature.knuckle, fatigue: 3),
        ),
        LifeChoice(
          label: Say('止めて蹴るを繰り返す', 'Trap and strike, over and over'),
          outcome: Say('地味な反復。だが、確実に残る。', 'Dull repetition. But it stays with you.'),
          effect: LifeEffect(train: Detail.shortPassing, fatigue: 2),
        ),
        LifeChoice(
          label: Say('片付けて帰る', 'Pack up and go home'),
          outcome: Say('道具を片付けて帰った。', 'You put the gear away and went home.'),
          effect: LifeEffect(condition: 5),
        ),
      ],
    ),

    // ---- 外の世界 ----
    LifeEvent(
      id: 'kids-clinic',
      title: Say('子どもたちの前で', 'In front of the children'),
      body:
          Say('地域のサッカー教室に呼ばれた。'
          '50人の子どもが待っている。', 'You were invited to a local football school. Fifty children are waiting.'),
      once: false,
      requirement: LifeRequirement(minFame: 20),
      choices: [
        LifeChoice(
          label: Say('本気で相手をする', 'Give them everything'),
          outcome: Say('全員と一対一をやった。帰りは足が上がらなかった。', 'You played one against one with every single one. Your legs were gone by the end.'),
          effect: LifeEffect(fame: 5, morale: 5, fatigue: 4),
        ),
        LifeChoice(
          label: Say('話をして帰る', 'Talk to them and head off'),
          outcome: Say('15分だけ話した。悪くない時間だった。', 'Fifteen minutes of talking. It was time well spent.'),
          effect: LifeEffect(fame: 2, morale: 2),
        ),
      ],
    ),
    LifeEvent(
      id: 'old-coach',
      title: Say('恩師からの手紙', 'A letter from an old coach'),
      body:
          Say('育ててくれた指導者から手紙が届いた。'
          '「見ているよ」とだけ書いてあった。', 'A letter from the coach who brought you up. It said only: I am watching.'),
      requirement: LifeRequirement(minAge: 20),
      choices: [
        LifeChoice(
          label: Say('返事を書く', 'Write back'),
          outcome: Say('長い返事になった。書きながら、原点を思い出した。', 'It turned into a long reply. Writing it reminded you where you started.'),
          effect: LifeEffect(morale: 7),
        ),
        LifeChoice(
          label: Say('結果で返す', 'Answer with results'),
          outcome: Say('手紙は机に置いたままにした。次の試合で返す。', 'You left the letter on the desk. The next match is your reply.'),
          effect: LifeEffect(morale: 4, ambition: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'night-out',
      title: Say('誘い', 'An invitation'),
      body: Say('同期に飲みに誘われた。明日はオフだ。', 'Someone from your intake asks you out for a drink. Tomorrow is off.'),
      once: false,
      requirement: LifeRequirement(minAge: 19),
      choices: [
        LifeChoice(
          label: Say('行く', 'Go'),
          outcome: Say('よく笑った。少し飲みすぎた。', 'You laughed a lot. You drank a bit too much.'),
          effect: LifeEffect(morale: 6, condition: -10),
        ),
        LifeChoice(
          label: Say('一杯だけ', 'Just the one'),
          outcome: Say('顔を出して早めに帰った。', 'You showed your face and left early.'),
          effect: LifeEffect(morale: 3, teammates: 3, condition: -3),
        ),
        LifeChoice(
          label: Say('断る', 'Decline'),
          outcome: Say('家で映像を見た。', 'You watched footage at home.'),
          effect: LifeEffect(condition: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'media',
      title: Say('試合後のインタビュー', 'After the match'),
      body:
          Say('記者が、監督の起用法について答えを迫ってくる。'
          'カメラは回ったままだ。', 'A reporter pushes you on how the manager is using you. The camera is still rolling.'),
      once: false,
      choices: [
        LifeChoice(
          label: Say('思っていることを言う', 'Say what you think'),
          outcome: Say('見出しになった。応援する声も、呆れる声もある。', 'It made the headlines. Some backed you, some rolled their eyes.'),
          effect: LifeEffect(fame: 4, manager: -6, morale: 3, temper: 1),
        ),
        LifeChoice(
          label: Say('当たり障りなく流す', 'Give a safe answer'),
          outcome: Say('何も起きなかった。それでいい日もある。', 'Nothing happened. Some days that is fine.'),
          effect: LifeEffect(temper: -1),
        ),
        LifeChoice(
          label: Say('チームメイトを立てる', 'Credit your teammates'),
          outcome: Say('ロッカールームでの評判が少し上がった。', 'Your standing in the dressing room went up a little.'),
          effect: LifeEffect(teammates: 5, manager: 2, fame: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'chant',
      title: Say('自分のチャントができた', 'You have your own chant'),
      body:
          Say('ゴール裏が、あなたの名前で歌をつくった。'
          '試合前に、その歌がスタンドから降ってくる。', 'The stand behind the goal has made a song out of your name. It rains down before kick-off.'),
      requirement: LifeRequirement(minFame: 40),
      choices: [
        LifeChoice(
          label: Say('ゴール裏に応える', 'Salute the stand'),
          outcome: Say('あの日から、ここは自分の場所になった。', 'From that day, this place is yours.'),
          effect: LifeEffect(morale: 10, fame: 3, confidence: 1, fatigue: 2),
        ),
        LifeChoice(
          label: Say('照れて手を上げるだけ', 'Just raise a hand, embarrassed'),
          outcome: Say('それでも、歌は鳴りやまなかった。', 'The singing did not stop anyway.'),
          effect: LifeEffect(morale: 5),
        ),
      ],
    ),
    LifeEvent(
      id: 'ultras',
      title: Say('練習場に来た一団', 'A crowd at the training ground'),
      body:
          Say('連敗が続き、熱心なサポーターが練習場の前を塞いでいる。'
          '中には、言葉が過ぎる者もいる。', 'After a run of defeats, hard-core supporters are blocking the gate. Some go too far.'),
      requirement: LifeRequirement(minAge: 20),
      once: false,
      choices: [
        LifeChoice(
          label: Say('前に出て話を聞く', 'Go out and listen'),
          outcome: Say('罵声は止み、代わりに拍手が起きた。長い話になった。', 'The abuse stopped and turned into applause. It was a long conversation.'),
          effect: LifeEffect(
            morale: -4,
            fame: 3,
            teammates: 6,
            confidence: 1,
            fatigue: 3,
          ),
        ),
        LifeChoice(
          label: Say('バスの窓から見ている', 'Watch from the coach window'),
          outcome: Say('何も言わずに通り過ぎた。後味は良くない。', 'You drove past without a word. It leaves a taste.'),
          effect: LifeEffect(morale: -6),
        ),
        LifeChoice(
          label: Say('クラブに任せる', 'Leave it to the club'),
          outcome: Say('警備が入って解散した。それが正しい対応ではあった。', 'Security moved them on. It was the correct call.'),
          effect: LifeEffect(morale: -2, manager: 2, fame: -1),
        ),
      ],
    ),
    LifeEvent(
      id: 'family',
      title: Say('身内からの電話', 'A call from family'),
      body:
          Say('親戚を名乗る人物から、代理人を替えろと言われている。'
          '「もっと良い話を持ってこられる人がいる」らしい。', 'Someone claiming to be a relative says you should change agent. Apparently there is a better deal out there.'),
      requirement: LifeRequirement(minAge: 19, minFame: 25),
      choices: [
        LifeChoice(
          label: Say('話だけ聞いて断る', 'Hear them out and say no'),
          outcome: Say('角は立ったが、仕事は仕事だと伝えた。', 'It caused friction, but you said business is business.'),
          effect: LifeEffect(morale: -3),
        ),
        LifeChoice(
          label: Say('任せてみる', 'Give them a chance'),
          outcome: Say('数か月、何も進まなかった。授業料だと思うことにした。', 'Months went by with nothing. You chalked it up to tuition.'),
          effect: LifeEffect(money: -300, morale: 2),
        ),
        LifeChoice(
          label: Say('電話に出るのをやめる', 'Stop answering the phone'),
          outcome: Say('静かになった。少しだけ、後ろめたい。', 'It went quiet. You feel a little guilty.'),
          effect: LifeEffect(morale: -2, temper: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'friend',
      title: Say('親友の退団', 'A friend leaves'),
      body:
          Say('同じ日に加入し、同じ部屋で遠征を過ごしてきた選手が、'
          '今日クラブを去る。', 'A player who joined the same day and shared your room on every trip leaves the club today.'),
      requirement: LifeRequirement(minAge: 20),
      choices: [
        LifeChoice(
          label: Say('空港まで送る', 'Drive him to the airport'),
          outcome: Say('「向こうでも見てるからな」と言われた。', 'I will be watching from over there, he said.'),
          effect: LifeEffect(morale: -5, teammates: 4),
        ),
        LifeChoice(
          label: Say('練習を優先する', 'Put training first'),
          outcome: Say('そういうものだ、と自分に言い聞かせた。', 'That is how it is, you told yourself.'),
          effect: LifeEffect(morale: -8, train: Detail.stamina),
        ),
      ],
    ),
    LifeEvent(
      id: 'dm',
      title: Say('深夜のDM', 'A message at midnight'),
      body:
          Say('負けた日に限って、知らない相手からの言葉が届く。'
          '大半は読むに堪えないものだ。', 'It is always after a defeat that strangers write to you. Most of it is unreadable.'),
      requirement: LifeRequirement(minFame: 30),
      once: false,
      choices: [
        LifeChoice(
          label: Say('アプリを消す', 'Delete the app'),
          outcome: Say('数日で、驚くほど気にならなくなった。', 'Within days it stopped bothering you to a surprising degree.'),
          effect: LifeEffect(morale: 4, fame: -2),
        ),
        LifeChoice(
          label: Say('言い返す', 'Answer back'),
          outcome: Say('そのやり取りが切り抜かれ、記事になった。', 'The exchange was screenshotted and turned into an article.'),
          effect: LifeEffect(morale: -6, fame: 5, temper: 1),
        ),
        LifeChoice(
          label: Say('スクリーンショットを公表する', 'Post the screenshots'),
          outcome: Say('同じ思いをしていた選手たちから連絡が来た。', 'Other players who had been through the same thing got in touch.'),
          effect: LifeEffect(morale: 2, fame: 4, teammates: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'fame',
      title: Say('有名税', 'The price of fame'),
      body:
          Say('食事に出れば写真を求められ、断れば不機嫌だと書かれる。'
          '自宅の前で待たれていた日もある。', 'Go out to eat and people want photos; refuse and you are written up as moody. One day they were waiting outside your home.'),
      requirement: LifeRequirement(minFame: 55),
      once: false,
      choices: [
        LifeChoice(
          label: Say('警備を付ける', 'Hire security'),
          outcome: Say('静かになった。金はかかる。', 'It went quiet. It costs.'),
          effect: LifeEffect(money: -400, morale: 6),
        ),
        LifeChoice(
          label: Say('気にせず今まで通り暮らす', 'Carry on as before'),
          outcome: Say('街の人には好かれた。落ち着かない日は続く。', 'The town took to you. The unsettled days continue.'),
          effect: LifeEffect(fame: 3, morale: -4),
        ),
      ],
    ),
    LifeEvent(
      id: 'charity',
      title: Say('財団の話', 'A foundation'),
      body:
          Say('育った街に、子どものためのグラウンドを作らないかと'
          '声をかけられた。金も時間もかかる。', 'You are asked to build a pitch for children in the town you grew up in. It costs money and time.'),
      requirement: LifeRequirement(minAge: 25, minSavings: 3000),
      choices: [
        LifeChoice(
          label: Say('私財を出して設立する', 'Fund it yourself'),
          outcome: Say('自分の名前の付いたグラウンドで、子どもが走っている。', 'Children are running on a pitch with your name on it.'),
          effect: LifeEffect(
            money: -2000,
            fame: 8,
            morale: 10,
            ambition: -1,
            special: LifeSpecial.foundCharity,
          ),
        ),
        LifeChoice(
          label: Say('現役の間は見送る', 'Leave it until after you retire'),
          outcome: Say('今はサッカーに集中する、と伝えた。', 'You said you are focused on football for now.'),
          effect: LifeEffect(morale: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'milestone',
      title: Say('家族の節目', 'A family occasion'),
      body:
          Say('大事な日と、アウェイの試合が重なった。'
          '本人は「気にしないで」と言っている。', 'An important day clashes with an away match. They say not to worry about it.'),
      requirement: LifeRequirement(minAge: 24),
      once: false,
      choices: [
        LifeChoice(
          label: Say('試合に行く', 'Go to the match'),
          outcome: Say('勝った。写真だけが手元に残った。', 'You won. All you have is the photos.'),
          effect: LifeEffect(morale: -6),
        ),
        LifeChoice(
          label: Say('欠場を願い出る', 'Ask to be left out'),
          outcome: Say('監督は渋い顔をしたが、行ってこいと言った。', 'The manager pulled a face, but told you to go.'),
          effect: LifeEffect(morale: 12, manager: -6, condition: 10),
        ),
      ],
    ),
    LifeEvent(
      id: 'abroad',
      title: Say('言葉と食事', 'Words and food'),
      body:
          Say('練習の指示が半分も分からない。'
          '食事も合わず、体重が落ちてきた。', 'You understand barely half the instructions. The food does not suit you and you are losing weight.'),
      requirement: LifeRequirement(abroad: true),
      choices: [
        LifeChoice(
          label: Say('語学の時間を作る', 'Make time for the language'),
          outcome: Say('半年後、冗談が分かるようになった。', 'Six months later you get the jokes.'),
          effect: LifeEffect(morale: 6, teammates: 8, condition: -5),
        ),
        LifeChoice(
          label: Say('同郷の選手とだけ過ごす', 'Stick with players from home'),
          outcome: Say('楽ではある。輪の外に居る感じは消えない。', 'It is easier. The feeling of being outside the circle does not go.'),
          effect: LifeEffect(morale: 3, teammates: -5),
        ),
      ],
    ),
    LifeEvent(
      id: 'injuryFear',
      title: Say('同じ場所', 'The same spot'),
      body:
          Say('復帰して数試合。競り合いの瞬間に、'
          'あの時と同じ体勢になるのが怖い。', 'A few games back. In every duel you fear ending up in that same position.'),
      requirement: LifeRequirement(afterInjury: true),
      once: false,
      choices: [
        LifeChoice(
          label: Say('思い切り踏み込む', 'Push off it hard'),
          outcome: Say('何も起きなかった。それで、ようやく戻ってこられた。', 'Nothing happened. That was when you really came back.'),
          effect: LifeEffect(morale: 8, confidence: 1),
        ),
        LifeChoice(
          label: Say('当たりを避けて組み立てる', 'Avoid contact and play it safe'),
          outcome: Say('無難にこなした。監督は物足りなさそうだった。', 'You got through it. The manager looked unsatisfied.'),
          effect: LifeEffect(manager: -3, morale: -2, fatigue: -3),
        ),
      ],
    ),
    LifeEvent(
      id: 'mental',
      title: Say('眠れない夜', 'Sleepless nights'),
      body:
          Say('試合のミスが頭から離れず、朝まで眠れない日が続いている。'
          'クラブには相談窓口がある。', 'A mistake keeps replaying and you are awake until morning. The club has someone you can talk to.'),
      requirement: LifeRequirement(lowMorale: true),
      once: false,
      choices: [
        LifeChoice(
          label: Say('専門家に相談する', 'Talk to a professional'),
          outcome: Say('話すだけで、少し軽くなった。続けることにした。', 'Just talking made it lighter. You decided to keep going.'),
          effect: LifeEffect(morale: 18, condition: 5, money: -60),
        ),
        LifeChoice(
          label: Say('誰にも言わない', 'Tell nobody'),
          outcome: Say('何とかなる、と思うことにした。', 'You decided it would sort itself out.'),
          effect: LifeEffect(morale: -6, confidence: -1),
        ),
      ],
    ),
    LifeEvent(
      id: 'sponsor',
      title: Say('スパイクの話', 'A boot deal'),
      body:
          Say('ブランドから、専属契約の打診が来ている。'
          '年<sponsorAnnual>万円。露出は増えるが、拘束も増える。', 'A brand wants an exclusive deal. JPY <sponsorAnnual>0K a year. More exposure, but more obligations.'),
      requirement: LifeRequirement(needsSponsorOffer: true),
      once: false,
      choices: [
        LifeChoice(
          label: Say('契約する', 'Sign it'),
          outcome:
              Say('自分の名前が入ったスパイクが店頭に並ぶ。'
              '撮影とイベントで、オフは短くなった。', 'Boots with your name on them are in the shops. Shoots and events shortened your off-season.'),
          // **「拘束も増える」と書いてあるのに、失うものが無かった。**
          // 受ければ金と名前がただで増えるだけの選択になっていたので、
          // 本文どおり身体に返す。
          effect: LifeEffect(
            fame: 5,
            fatigue: 8,
            condition: -6,
            special: LifeSpecial.acceptSponsor,
          ),
        ),
        LifeChoice(
          label: Say('断る', 'Decline'),
          outcome: Say('履き慣れたものを使い続けることにした。', 'You stuck with the pair you are used to.'),
          effect: LifeEffect(morale: 3, special: LifeSpecial.declineSponsor),
        ),
      ],
    ),
    LifeEvent(
      id: 'captain',
      title: Say('腕章', 'The armband'),
      body:
          Say('監督に呼ばれた。来季のキャプテンをやってほしい、と言う。'
          '責任は重い。', 'The manager calls you in. He wants you as captain next season. It is a lot to carry.'),
      requirement: LifeRequirement(needsCaptaincy: true),
      // 腕章の打診は毎季来うる。一度きりにすると、一度断った後の打診に
      // 答える場が無くなり、「腕章の打診が来ている」が出たままになる。
      once: false,
      choices: [
        LifeChoice(
          label: Say('受ける', 'Accept'),
          outcome:
              Say('ロッカールームの空気が、自分に向くようになった。'
              '背負うものも、その日から増えた。', 'The dressing room turns to you now. So does the weight, from that day on.'),
          // **「責任は重い」と書いてあるのに、得るものしか無かった。**
          // 腕章は関係を厚くするが、重圧は自分で引き受ける。
          effect: LifeEffect(
            manager: 8,
            teammates: 10,
            morale: -4,
            ambition: 1,
            special: LifeSpecial.takeCaptain,
          ),
        ),
        LifeChoice(
          label: Say('自分より相応しい人がいると伝える', 'Say someone else deserves it more'),
          outcome: Say('監督は頷いた。プレーで引っ張れ、と言われた。', 'The manager nodded. Lead with your football, he said.'),
          effect: LifeEffect(teammates: 4, special: LifeSpecial.declineCaptain),
        ),
      ],
    ),
    // ---- 自分が選んだことが返ってくる ----
    LifeEvent(
      id: 'push-body',
      title: Say('身体が重い', 'Heavy legs'),
      body:
          Say('追い込んだ翌朝、階段を降りるのに手すりを掴んだ。'
          'まだやれる、とも思う。', 'The morning after a hard session you held the handrail going downstairs. You think you can still go.'),
      once: false,
      requirement: LifeRequirement(pushingHard: true),
      choices: [
        LifeChoice(
          label: Say('構わず追い込む', 'Push on anyway'),
          outcome: Say('振り切った。身体は正直に軋んだ。', 'You went through it. Your body creaked honestly.'),
          effect: LifeEffect(
            train: Detail.stamina,
            fatigue: 8,
            condition: -6,
            ambition: 1,
          ),
        ),
        LifeChoice(
          label: Say('一日だけ落とす', 'Ease off for one day'),
          outcome: Say('落とした日の翌日、身体が軽かった。', 'The day after you eased off, your body felt light.'),
          effect: LifeEffect(condition: 10, fatigue: -6),
        ),
        LifeChoice(
          label: Say('トレーナーに診てもらう', 'See the trainer'),
          outcome: Say('悪いところは無い、と言われた。それだけで少し楽になった。', 'Nothing wrong, he said. That alone helped.'),
          effect: LifeEffect(condition: 5, morale: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'push-notice',
      title: Say('見ている人がいる', 'Someone is watching'),
      body:
          Say('誰も居ないはずの時間に走っていたら、'
          'クラブの職員が黙って水を置いていった。', 'Running at an hour when nobody should be there, a club employee quietly left you a drink.'),
      once: false,
      requirement: LifeRequirement(pushingHard: true),
      choices: [
        LifeChoice(
          label: Say('礼を言って続ける', 'Thank them and carry on'),
          outcome: Say('見られていることが、少しだけ背中を押した。', 'Being seen pushed you on, just slightly.'),
          effect: LifeEffect(morale: 6, fatigue: 3),
        ),
        LifeChoice(
          label: Say('切り上げる', 'Call it a day'),
          outcome: Say('今日はここまで。明日も来る。', 'That is enough for today. You will be back tomorrow.'),
          effect: LifeEffect(condition: 6),
        ),
      ],
    ),
    LifeEvent(
      id: 'promise-weight',
      title: Say('言葉の重さ', 'The weight of words'),
      body:
          Say('記者に約束のことを蒸し返された。'
          '「あれ、本気ですか」と笑いを含んだ声で聞かれる。', 'A reporter brings your promise back up. Were you serious, he asks, half laughing.'),
      once: false,
      requirement: LifeRequirement(promised: true),
      choices: [
        LifeChoice(
          label: Say('もう一度言い切る', 'Say it again'),
          outcome: Say('逃げ道はもう無い。それでいい。', 'There is no way out now. That is fine.'),
          effect: LifeEffect(fame: 4, confidence: 1, morale: 4, manager: 2),
        ),
        LifeChoice(
          label: Say('笑ってかわす', 'Laugh it off'),
          outcome: Say('言葉を薄めた。少しだけ楽になった。', 'You watered it down. It felt a little easier.'),
          effect: LifeEffect(morale: 3, confidence: -1, teammates: 2),
        ),
        LifeChoice(
          label: Say('結果で見せると答える', 'Say you will show it on the pitch'),
          outcome: Say('余計なことは言わなかった。', 'You said nothing more than you had to.'),
          effect: LifeEffect(teammates: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'promise-doubt',
      title: Say('眠れない夜', 'Sleepless nights'),
      body:
          Say('口にした数字が、天井のあたりに浮かんでいる。'
          '取り消せないことだけは分かっている。', 'The number you said out loud is hanging near the ceiling. You know you cannot take it back.'),
      once: false,
      requirement: LifeRequirement(promised: true, lowCondition: true),
      choices: [
        LifeChoice(
          label: Say('映像を見返す', 'Watch it back'),
          outcome: Say('止められた場面を数えた。眠るのは遅くなった。', 'You counted the ones that were saved. You got to bed late.'),
          effect: LifeEffect(train: Detail.vision, condition: -4),
        ),
        LifeChoice(
          label: Say('寝る', 'Sleep'),
          outcome: Say('考えても点は入らない。', 'Thinking about it will not score.'),
          effect: LifeEffect(condition: 8, morale: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'tired-choice',
      title: Say('出たいと言うか', 'Say you want to play'),
      body: Say('身体は限界に近い。次の試合、監督は使うつもりでいる。', 'Your body is close to its limit. The manager intends to use you next match.'),
      once: false,
      requirement: LifeRequirement(lowCondition: true),
      choices: [
        LifeChoice(
          label: Say('出ると言う', 'Say you will play'),
          outcome: Say('無理を通した。監督は頷いた。', 'You forced it through. The manager nodded.'),
          effect: LifeEffect(
            manager: 5,
            teammates: 3,
            fatigue: 6,
            condition: -4,
          ),
        ),
        LifeChoice(
          label: Say('正直に伝える', 'Be honest'),
          outcome: Say('外された。身体は少し戻った。', 'You were left out. Your body recovered a little.'),
          effect: LifeEffect(manager: -4, condition: 12, fatigue: -6),
        ),
      ],
    ),
    // ---- 人との時間 ----
    LifeEvent(
      id: 'partner-dinner',
      title: Say('<partner>と飯を食う', 'A meal with <partner>'),
      body:
          Say('練習の帰り、<partner>が「行くか」と顎で示した。'
          '大した話はしない相手だが、居心地は悪くない。', 'On the way back from training, <partner> tilts his head: coming? Not a man for big conversations, but easy company.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.partner),
      choices: [
        LifeChoice(
          label: Say('付き合う', 'Join him'),
          outcome: Say('サッカーの話は半分もしなかった。', 'You talked about football less than half the time.'),
          effect: LifeEffect(morale: 8, teammates: 5, condition: -3),
        ),
        LifeChoice(
          label: Say('映像を見たいと断る', 'Say you want to watch footage'),
          outcome: Say('一人で画面に向かった。<partner>は何も言わなかった。', 'You sat alone in front of the screen. <partner> said nothing.'),
          effect: LifeEffect(train: Detail.vision, teammates: -2),
        ),
      ],
    ),
    LifeEvent(
      id: 'competitor-advice',
      title: Say('<competitor>の一言', 'A word from <competitor>'),
      body:
          Say('自分が外れた試合の後、<competitor>が'
          '「あそこ、俺なら逆を向く」と言ってきた。悪意は無いらしい。', 'After a match you missed, <competitor> says: there, I would have turned the other way. No malice in it.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.competitor),
      choices: [
        LifeChoice(
          label: Say('素直に聞く', 'Take it on board'),
          outcome: Say('確かに逆だった。悔しさは後から来た。', 'He was right about the other way. The sting came later.'),
          effect: LifeEffect(train: Detail.ballControl, temper: -1),
        ),
        LifeChoice(
          label: Say('言い返す', 'Answer back'),
          outcome: Say('譲らなかった。次で見せるしかない。', 'You held your ground. You will have to show it next time.'),
          effect: LifeEffect(confidence: 1, teammates: -3),
        ),
        LifeChoice(
          label: Say('黙って練習に戻る', 'Go back to training without a word'),
          outcome: Say('言葉より、足を動かした。', 'You moved your feet instead of your mouth.'),
          effect: LifeEffect(train: Detail.stamina, professionalism: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'mentor-limit',
      title: Say('<mentor>の身体', '<mentor> body'),
      body:
          Say('<mentor>がアイシングをしながら「もう戻らないところがある」と言った。'
          '笑っていたが、目は笑っていなかった。', 'Icing his knee, <mentor> says there are parts that do not come back. He was smiling. His eyes were not.'),
      requirement: LifeRequirement(needsPerson: PersonKind.mentor),
      choices: [
        LifeChoice(
          label: Say('自分の身体の使い方を聞く', 'Ask how he uses his body'),
          outcome: Say('壊れる前にやることがある、と教わった。', 'There are things to do before you break, he taught you.'),
          effect: LifeEffect(professionalism: 2, condition: 5),
        ),
        LifeChoice(
          label: Say('何も言わずに隣に座る', 'Sit down beside him without a word'),
          outcome: Say('しばらく黙っていた。それで十分だった。', 'You sat in silence for a while. It was enough.'),
          effect: LifeEffect(morale: 6, teammates: 4),
        ),
      ],
    ),
    LifeEvent(
      id: 'manager-clash',
      title: Say('<manager>と噛み合わない', 'At odds with <manager>'),
      body:
          Say('ミーティングで名指しされた。'
          '言っていることは分かる。ただ、自分のやり方とは違う。', 'Named in the meeting. You follow what he is saying. It is just not your way.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.manager),
      choices: [
        LifeChoice(
          label: Say('飲み込んで合わせる', 'Swallow it and comply'),
          outcome: Say('違和感は残ったが、使われるほうを取った。', 'The unease stayed, but you took being picked.'),
          effect: LifeEffect(manager: 7, confidence: -1),
        ),
        LifeChoice(
          label: Say('その場で反論する', 'Argue on the spot'),
          outcome: Say('空気が固まった。何人かは、こちらを見ていた。', 'The room froze. A few of them were looking at you.'),
          effect: LifeEffect(manager: -8, teammates: 5, temper: 1),
        ),
        LifeChoice(
          label: Say('後で二人で話す', 'Talk to him afterwards'),
          outcome: Say('納得はしていないが、話は通じた。', 'You are not convinced, but you got through to him.'),
          effect: LifeEffect(manager: 3),
        ),
      ],
    ),
    LifeEvent(
      id: 'agent-offer-talk',
      title: Say('<agent>からの電話', 'A call from <agent>'),
      body:
          Say('「動いている話がある」とだけ言われた。'
          '詳しくは言わない。今は言えない、ということらしい。', 'There is something moving, he said, and nothing more. He cannot say yet, apparently.'),
      once: false,
      requirement: LifeRequirement(needsPerson: PersonKind.agent, minAge: 21),
      choices: [
        LifeChoice(
          label: Say('任せると答える', 'Say you will leave it to him'),
          outcome: Say('考えることが一つ減った。', 'One less thing to think about.'),
          effect: LifeEffect(morale: 5, ambition: 1),
        ),
        LifeChoice(
          label: Say('今は聞きたくないと言う', 'Say you do not want to hear it now'),
          outcome: Say('目の前の試合に戻った。', 'You went back to the match in front of you.'),
          effect: LifeEffect(condition: 3),
        ),
      ],
    ),
    // ---- 生活 ----
    LifeEvent(
      id: 'sleep',
      title: Say('眠れていない', 'Not sleeping'),
      body:
          Say('寝つきが悪い日が続いている。'
          '朝の重さは、練習の重さとは違う種類のものだ。', 'Night after night you struggle to drop off. The morning heaviness is a different kind from training.'),
      once: false,
      requirement: LifeRequirement(lowCondition: true),
      choices: [
        LifeChoice(
          label: Say('専門家に相談する（-40万円）', 'Talk to a professional (JPY -400K)'),
          outcome: Say('寝る前の手順を変えただけで、驚くほど変わった。', 'Just changing the routine before bed made a surprising difference.'),
          effect: LifeEffect(money: -40, condition: 12, professionalism: 1),
        ),
        LifeChoice(
          label: Say('自分でどうにかする', 'Sort it out yourself'),
          outcome: Say('少しずつ戻ってきた。時間はかかった。', 'It came back bit by bit. It took time.'),
          effect: LifeEffect(condition: 5),
        ),
      ],
    ),
    LifeEvent(
      id: 'hometown',
      title: Say('地元に帰る', 'Going home'),
      body:
          Say('オフの数日、育った街に戻った。'
          '通っていたグラウンドは、記憶より狭かった。', 'A few days off in the town you grew up in. The pitch you used felt smaller than you remembered.'),
      once: false,
      requirement: LifeRequirement(minAge: 22),
      choices: [
        LifeChoice(
          label: Say('子どもたちに混ざる', 'Join in with the children'),
          outcome: Say('本気で相手をしたら、息が上がった。', 'You took them on properly and ended up out of breath.'),
          effect: LifeEffect(morale: 10, fame: 2, condition: -4),
        ),
        LifeChoice(
          label: Say('一人で歩く', 'Walk on your own'),
          outcome: Say('ここから始まったのだと、静かに思い出した。', 'This is where it started, you remembered quietly.'),
          effect: LifeEffect(morale: 6, confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'boots',
      title: Say('道具を見直す', 'Looking at your gear'),
      body:
          Say('同じモデルを何年も履いている。'
          '新しいものを試してみないか、と用具担当に言われた。', 'You have worn the same model for years. The kit man asks if you want to try something new.'),
      once: false,
      requirement: LifeRequirement(),
      choices: [
        LifeChoice(
          label: Say('試す（-20万円）', 'Try them (JPY -200K)'),
          outcome: Say('足の感覚が変わった。慣れるまで少しかかりそうだ。', 'Your feet feel different. It will take a while to settle.'),
          effect: LifeEffect(money: -20, train: Detail.agility),
        ),
        LifeChoice(
          label: Say('慣れたものを履く', 'Stick with what you know'),
          outcome: Say('迷いは無い。それも一つの強さだ。', 'No doubts. That is a strength too.'),
          effect: LifeEffect(confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'video-night',
      title: Say('相手の映像', 'Footage of the opposition'),
      body:
          Say('次の相手の映像が配られた。'
          '見なくても試合はできる。見れば、何か見つかるかもしれない。', 'Footage of your next opponents. You can play without watching. Watch, and you might find something.'),
      once: false,
      requirement: LifeRequirement(),
      choices: [
        LifeChoice(
          label: Say('遅くまで見る', 'Watch late'),
          outcome: Say('癖が一つ見つかった。眠いのは仕方がない。', 'You found one habit. Being tired is the price.'),
          effect: LifeEffect(train: Detail.vision, condition: -5, fatigue: 3),
        ),
        LifeChoice(
          label: Say('要点だけ確認する', 'Check the key points'),
          outcome: Say('必要なことは頭に入れた。', 'You took in what you needed.'),
          effect: LifeEffect(train: Detail.marking, condition: -1),
        ),
        LifeChoice(
          label: Say('見ない', 'Do not watch'),
          outcome: Say('自分のプレーに集中した。', 'You focused on your own game.'),
          effect: LifeEffect(condition: 4, confidence: 1),
        ),
      ],
    ),
    LifeEvent(
      id: 'veteran',
      title: Say('若手が寄ってくる', 'The young ones come to you'),
      body:
          Say('練習後、若い選手が質問に来るようになった。'
          '自分が同じことを聞いていたのは、そう昔でもない。', 'After training, young players have started coming with questions. It was not that long ago you were asking the same things.'),
      requirement: LifeRequirement(minAge: 31),
      choices: [
        LifeChoice(
          label: Say('時間を取って教える', 'Make time for them'),
          outcome: Say('自分の言葉で説明すると、分かっていなかったことに気づいた。', 'Explaining it in your own words showed you what you had not understood.'),
          effect: LifeEffect(teammates: 10, morale: 6, condition: -5),
        ),
        LifeChoice(
          label: Say('自分のことに集中する', 'Focus on yourself'),
          outcome: Say('現役でいる時間は、もう長くない。', 'Your time as a player is not long now.'),
          effect: LifeEffect(condition: 5, ambition: 1, teammates: -3),
        ),
      ],
    ),
  ];
}
