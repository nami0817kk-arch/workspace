import 'package:flutter/material.dart';

import '../models/player.dart';
import '../l10n/tr.dart';

/// ガイド内の1トピック(見出し + 説明文)。
class GuideTopic {
  final String title;
  final String description;

  const GuideTopic({required this.title, required this.description});
}

/// ガイドの1セクション。アプリ内のある画面・機能領域に対応し、その画面が
/// 何をする場所かという概要と、そこに登場する用語・仕組みのトピック群を持つ。
/// 用語集([glossaryEntries])が用語ごとのフラットな辞書であるのに対し、
/// こちらは「どの画面で何ができるか」という視点で情報をまとめ、初めて
/// その画面を触るときに読む導入ガイドとして使う。
class GuideSection {
  final IconData icon;
  final String title;
  final String overview;
  final List<GuideTopic> topics;

  const GuideSection({
    required this.icon,
    required this.title,
    required this.overview,
    required this.topics,
  });
}

/// 選手の性格(パーソナリティ)を説明するトピック一覧。[PlayerPersonality]側の
/// label/descriptionをそのまま使うことで、実際のゲームロジックの説明と
/// ガイドの記述が食い違わないようにしている。
List<GuideTopic> _personalityTopics() => [
      for (final p in PlayerPersonality.values)
        GuideTopic(title: p.label, description: p.description),
    ];

/// 選手のプレースタイル(ロール)を説明するトピック一覧。standard(標準)は
/// 「特定のロールを指定しない」という意味しか持たないため、ガイドでは
/// 個性のある残りの全種類のみを紹介する(一覧は実際のenumから生成する
/// ため、ロールが増減してもこのガイドは自動的に追随する)。
List<GuideTopic> _roleTopics() => [
      for (final r in PlayerRole.values)
        if (r != PlayerRole.standard)
          GuideTopic(title: r.label, description: r.description),
    ];

List<GuideTopic> _dutyTopics() => [
      for (final d in PlayerDuty.values)
        GuideTopic(title: d.label, description: d.description),
    ];

/// 選手特性を説明するトピック一覧。持たない選手も多い。
List<GuideTopic> _traitTopics() => [
      for (final t in PlayerTrait.values)
        GuideTopic(
          title: '${t.label}(${t.category.label})',
          description: t.description,
        ),
    ];

/// 選手の成長タイプを説明するトピック一覧。
List<GuideTopic> _growthTypeTopics() => [
      for (final g in PlayerGrowthType.values)
        GuideTopic(title: g.label, description: g.description),
    ];

// final ではなくゲッター。final だと最初のアクセス時にガイド全文が
// 組み立てられ、そのときの言語で固定されてしまう。
List<GuideSection> get guideSections => [
      GuideSection(
        icon: Icons.home,
        title: Tr.pick('ホーム画面', 'Home'),
        overview: Tr.pick(
            'クラブの現状をひと目で確認できるダッシュボード。次の試合・理事会目標・資金繰りなど、毎週まず最初に見るべき情報がまとまっている。',
            "The dashboard for where the club stands. The next match, the board's target, the state of the finances — everything worth checking first each week."),
        topics: [
          GuideTopic(
            title: Tr.pick('理事会の目標順位', "The board's target"),
            description: Tr.pick(
                'シーズン開始時に理事会から示される目標順位。これを下回る成績が続くと監督への信頼度が下がり、0になると解任される。ホーム画面の順位表示と見比べて、順位が目標に届いているか確認する。',
                'The finishing position the board asks for at the start of the season. Sitting below it for long costs you their confidence, and at zero you are sacked. Check it against the position shown on the home screen.'),
          ),
          GuideTopic(
            title: Tr.pick('通知バッジ', 'Notification badges'),
            description: Tr.pick(
                '各タブのアイコンに付くバッジは、その画面で確認すべき新しい出来事(移籍オファー・契約満了間近・負傷の回復など)がある合図。バッジが消えるまで一度は該当画面を開いて確認するとよい。',
                'A badge on a tab means something there needs your attention: a transfer offer, a contract running down, a player back from injury. Open the screen once and the badge clears.'),
          ),
          GuideTopic(
            title: Tr.pick('スーパーカップ', 'Super Cup'),
            description: Tr.pick(
                'リーグ優勝クラブとカップ優勝クラブが対戦する単発の一戦。開催条件を満たすとホーム画面に専用カードが表示される。',
                'A single match between the league champions and the cup winners. When it is on, a card for it appears on the home screen.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.work_outline,
        title: Tr.pick('オーナーの仕事', "The owner's job"),
        overview: Tr.pick(
            'あなたはクラブのオーナーです。試合や練習は監督とコーチ陣に任せ、お金・人・方針を決めます。サポーターと株主、2つの期待を両方保つのが仕事です。',
            'You own the club. The manager and coaches run matches and training; you decide money, people and direction. Your job is to keep two groups happy: the fans and the shareholders.'),
        topics: [
          GuideTopic(
            title: Tr.pick('2つの期待', 'Two expectations'),
            description: Tr.pick(
                'サポーターの期待は成績と人気で、株主の期待は収支で動きます。どちらかが尽きると、クラブを手放すことになります。',
                'Fan expectation follows results and popularity; shareholder expectation follows the books. If either runs out, you must sell the club.'),
          ),
          GuideTopic(
            title: Tr.pick('次の節へ', 'Next matchday'),
            description: Tr.pick(
                '試合には直接関わりません。押すと数秒のダイジェストで結果と、2つの期待の動きが出ます。先発や構えは監督が決めます。',
                'You do not touch the match itself. Press it to see a short digest with the result and how both expectations moved. The manager picks the team.'),
          ),
          GuideTopic(
            title: Tr.pick('監督からの報告・経営診断', "Manager's report and health check"),
            description: Tr.pick(
                '状況ページの先頭に、監督のひと言と順位・収支が出ます。経営診断は、2つの期待・人件費率・資金からA〜Eで評価します。',
                "The status page opens with the manager's note, the table position and the books. The health check grades you A to E from both expectations, the wage ratio and your funds."),
          ),
          GuideTopic(
            title: Tr.pick('今週の決断', "This week's decision"),
            description: Tr.pick(
                '補強の候補や売却のオファーなど、いま決めることを1件ずつ出します。',
                'One thing to decide at a time, such as signing candidates or an offer for a player.'),
          ),
          GuideTopic(
            title: Tr.pick('年の予算と効きの時間差', 'The budget and its delays'),
            description: Tr.pick(
                '補強・育成・施設・営業・配当に予算を配ります。補強はすぐ、営業は1年、育成は2〜3年、施設は3〜5年かけて効きます。',
                'Split the budget between signings, youth, facilities, marketing and dividends. Signings work at once, marketing in a year, youth in two or three, facilities in three to five.'),
          ),
          GuideTopic(
            title: Tr.pick('補強と売却', 'Signings and sales'),
            description: Tr.pick(
                '監督が挙げた候補を、買うか見送るかで決めます。売却のオファーには、監督の見立てが付きます。移籍には代理人手数料がかかり、値切ると売却条項が付きます。',
                "Approve or pass on the manager's candidates. Offers for your players come with the manager's view. Signings carry agent fees, and haggling can add a sell-on clause."),
          ),
          GuideTopic(
            title: Tr.pick('オーナー室', "Owner's office"),
            description: Tr.pick(
                'オーナーの仕事(1シーズンに1回ずつ打てる手)、試合日のイベント、提携クラブ、年間予定、ニュースや記録をまとめています。',
                "Moves you can make once a season, matchday events, a partner club, the club calendar, news and records."),
          ),
          GuideTopic(
            title: Tr.pick('事件と目標', 'Incidents and goals'),
            description: Tr.pick(
                '年に3回、事件の判断が求められます。どの答えも、サポーターか株主のどちらかを傷つけます。就任時に選んだ目標を果たすと、殿堂に残ります。',
                'Three times a season an incident needs your call; every answer hurts either the fans or the shareholders. Reach the goal you chose and it stays in your hall of fame.'),
          ),
          GuideTopic(
            title: Tr.pick('売却と買い直し', 'Selling up and starting again'),
            description: Tr.pick(
                '期待が尽きてクラブを手放しても、実績を残したまま別のクラブ(別の国も選べる)を買い直せます。',
                'If you lose the club you keep your record and can buy another, even in another country.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.groups,
        title: Tr.pick('スカッド・選手詳細画面', 'Squad and player pages'),
        overview: Tr.pick(
            '保有選手の一覧と、選手1人ごとの詳細なステータス・契約・個性を確認する画面。誰をスタメンに据えるか、誰を鍛えるか、誰を放出するかを判断する材料がここに集まっている。',
            "Your full squad, and each player's attributes, contract and character. Everything you need to decide who starts, who you develop and who you let go."),
        topics: [
          GuideTopic(
            title: Tr.pick('総合力・潜在能力', 'Overall and potential'),
            description: Tr.pick(
                '総合力は現在の実力を1つの数値にまとめたもの。潜在能力は将来到達しうる総合力の上限で、若い選手ほど潜在能力との差(伸びしろ)が大きい傾向にある。',
                'Overall is one number for how good he is now. Potential is the ceiling he could reach, and younger players tend to have more room between the two.'),
          ),
          GuideTopic(
            title: Tr.pick('性格(パーソナリティ)', 'Personality'),
            description: Tr.pick('選手の気質。不満度の変動しやすさや移籍希望の出やすさに影響する。以下の20種類がある。',
                'His temperament. It governs how easily he becomes unsettled and how readily he asks to leave. There are twenty in all.'),
          ),
          ..._personalityTopics(),
          GuideTopic(
            title: Tr.pick('デューティ(攻守の重心)', 'Duty'),
            description: Tr.pick('スタメン・戦術画面で選手ごとに設定する、攻撃/守備どちらに比重を置くかの指定。',
                'Set per player on the tactics screen: whether he leans towards attacking or defending.'),
          ),
          ..._dutyTopics(),
          GuideTopic(
            title: Tr.pick('ロール(プレースタイル)', 'Role'),
            description: Tr.pick(
                'どの能力値を活かしたプレーを得意とするかという設定。ロールが重視する能力値が高い選手に割り当てるとボーナスが、低い選手に割り当てるとペナルティが付くため、選手の得意な能力に合わせて選ぶ。',
                'What kind of player he is asked to be. Give a role to someone strong in the attributes it values and he gains; give it to someone weak in them and he suffers. Pick it to match his strengths.'),
          ),
          ..._roleTopics(),
          GuideTopic(
            title: Tr.pick('特性', 'Traits'),
            description: Tr.pick(
                '性格(パーソナリティ)とは別に、試合の相手や当日の調子によってパフォーマンスが変わる選手固有の個性。持たない選手も多く、能力値が近い選手同士でも試合結果に差が生まれる要因になる。3つに分類される。\n・技術: 特定の能力値と結びついた、技術・フィジカル面の持ち味。\n・性格: 対戦相手や状況への向き合い方など、メンタル面の資質。\n・才能: 天候・年齢・調子の波など、生まれ持った資質。\n特性は加入した時点で決まっていて、あとから身に付くことはない。欲しい特性は、持っている選手を獲るか、ユースから上げて手に入れる。',
                'Separate from personality: quirks that change how a player performs depending on the opponent and how the day is going. Plenty of players have none, and they are a reason two players with similar attributes can produce different results. They come in three kinds.\n• Technical: a strength tied to specific technical or physical attributes.\n• Personality: mental qualities, such as how he approaches an opponent or a situation.\n• Natural: innate things like weather, age and streakiness.\nA trait is settled when the player joins and does not change later. To get one you want, sign a player who has it or bring one up from the academy.'),
          ),
          ..._traitTopics(),
          GuideTopic(
            title: Tr.pick('成長タイプ', 'Growth type'),
            description: Tr.pick(
                '年齢による伸びやすさ・衰え始める時期の傾向。標準タイプの選手は選手詳細画面では表示されず、以下の2種類が該当する場合のみ表示される。',
                'How his development runs with age, and when the decline starts. Standard is not shown on his page; only the two below appear.'),
          ),
          ..._growthTypeTopics(),
          GuideTopic(
            title: Tr.pick('才能開花(ブレイクスルー)', 'Breakthroughs'),
            description: Tr.pick(
                '週次トレーニングの際、まれに複数の能力値が一気に伸びる特別な瞬間が起きることがある。発生した週はトレーニング結果ダイアログと選手詳細画面に「★ 才能開花」と表示される。闘志(determination)が高い選手や、成長タイプの伸び盛りの年齢に該当する選手ほど起きやすい。',
                "Now and then a weekly session produces a moment where several attributes jump at once. In that week the training report and the player's page both show a breakthrough. It happens more often to players with high determination, and to those at the age their growth type favours."),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.swap_horiz,
        title: Tr.pick('移籍市場画面', 'Transfer screen'),
        overview: Tr.pick(
            '他クラブの選手を獲得したり、自クラブの選手を放出したりする画面。交渉の駆け引きやローン移籍など、実際の移籍市場に近い要素を扱う。',
            'Where you sign players and move them on, with haggling, loans and the rest of what a real market involves.'),
        topics: [
          GuideTopic(
            title: Tr.pick('想定移籍金', 'Estimated fee'),
            description: Tr.pick('年齢・現在の総合力・伸びしろから概算した市場価値。交渉時のオファー額の目安になる。',
                'A rough valuation from his age, current overall and room to grow. The yardstick for what a bid should look like.'),
          ),
          GuideTopic(
            title: Tr.pick('リリース条項', 'Release clauses'),
            description: Tr.pick('設定されている場合、他クラブがこの金額を提示すると交渉なしで自動的に移籍が成立する。',
                'Where one is set, any club offering that amount takes him with no negotiation at all.'),
          ),
          GuideTopic(
            title: Tr.pick('ローン(期限付き移籍)', 'Loans'),
            description: Tr.pick(
                '一定期間だけ選手を貸し出す/借り受ける制度。ローン中の週俸は貸出先が負担し、期間満了で自動的に元クラブへ復帰する。買取オプション付きなら期間中に完全移籍へ切り替えられる。',
                'Sending a player elsewhere, or taking one in, for a fixed spell. The receiving club pays his wages, and he returns automatically when it ends. With an option to buy, it can be made permanent at any point.'),
          ),
          GuideTopic(
            title: Tr.pick('移籍リスト登録', 'Transfer listing'),
            description: Tr.pick('登録すると他クラブからの獲得オファーが届きやすくなる。放出したい選手に活用できる。',
                'Listing a player makes offers from other clubs arrive more often. Useful for anyone you want off the books.'),
          ),
          GuideTopic(
            title: Tr.pick('移籍ウィンドウ', 'Transfer window'),
            description: Tr.pick('移籍市場が開いている期間。ウィンドウが閉じている間は新規の移籍交渉ができない。',
                'The period the market is open. While it is shut you cannot open new negotiations.'),
          ),
          GuideTopic(
            title: Tr.pick('市場の入れ替わり(持続的な移籍市場)', 'How the market turns over'),
            description: Tr.pick(
                '移籍市場の顔ぶれは毎週数人だけが入れ替わる。狙っていた選手は翌週以降も追えるが、いつまでも市場に残っているとは限らない。',
                'Only a handful of names change each week. A target will usually still be there next week, though not forever.'),
          ),
          GuideTopic(
            title: Tr.pick('値切り交渉', 'Haggling'),
            description: Tr.pick(
                '想定移籍金より安い提示額で獲得を試みる交渉。提示額の割合が高いほど成立しやすく、55%以下では必ず決裂する。決裂した選手とはその週は再交渉できない。',
                "Bidding below a player's valuation. The closer to the asking price, the likelier it is accepted; at 55% or under it always fails, and once talks break down you cannot go back to him that week."),
          ),
          GuideTopic(
            title: Tr.pick('放出選手の行き先', 'Where sold players go'),
            description: Tr.pick(
                '放出した選手は消えるのではなく、リーグ内の他クラブへ実際に移籍して対戦相手として再会することがある。',
                'A player you sell does not vanish. He joins another club in the league, and you may well face him.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.emoji_people,
        title: Tr.pick('ユース・スカウト画面', 'Youth and scouting screen'),
        overview: Tr.pick(
            '将来性のある若手選手を獲得するための画面。スカウトによる個別発掘と、シーズンごとのユースインテークの両方を扱う。',
            'Where you bring young players in, both by scouting them individually and through the yearly academy intake.'),
        topics: [
          GuideTopic(
            title: Tr.pick('スカウト候補', 'Scouted prospects'),
            description: Tr.pick(
                'スカウトに費用を払って探してもらう若手選手の候補。スタッフの「スカウト」レベルが高いほど、一度に提示される候補の人数が増える。',
                "Young players your scouts find, for a fee. The higher your scout's level, the more names come back at once."),
          ),
          GuideTopic(
            title: Tr.pick('ユースインテーク', 'Youth intake'),
            description: Tr.pick(
                'シーズンの節目に自クラブの下部組織から一括で入団してくる若手選手たち。まとめて確認し、昇格させたい選手を選抜する。',
                'The group that comes up from your own academy at a set point in the season. Look them over and choose who you take on.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.account_balance,
        title: Tr.pick('クラブ経営(ファイナンス)画面', 'Finances screen'),
        overview: Tr.pick(
            'クラブの資金繰りを管理する画面。収入(観客動員・スポンサー)と支出(週俸・ローン返済)を見ながら、融資や投資の判断を行う。',
            'Where you manage the money. Weigh what comes in from the gate and sponsors against wages and loan repayments, and decide whether to borrow or invest.'),
        topics: [
          GuideTopic(
            title: Tr.pick('銀行ローン', 'Bank loans'),
            description: Tr.pick('資金が不足した際に借り入れられる融資。借りた分は利息付きで分割返済していく必要がある。',
                'Money you can borrow when funds run short, repaid in instalments with interest.'),
          ),
          GuideTopic(
            title: Tr.pick('定期預金・資金運用', 'Fixed deposits'),
            description: Tr.pick(
                '余剰資金を一定期間預けて増やす仕組み。すぐには引き出せない代わりに、置いておくだけの資金より効率よく増やせる。',
                'Putting spare money away for a fixed spell. You cannot touch it until it matures, but it grows faster than money sitting idle.'),
          ),
          GuideTopic(
            title: Tr.pick('スポンサー契約', 'Sponsorship'),
            description: Tr.pick(
                '年単位で結ぶ契約で、契約期間中は毎週安定した収入が得られる。契約満了が近づくと更新や新規オファーの検討が必要になる。',
                'A deal measured in years that pays steadily every week. As it runs down you need to think about renewing or taking a new offer.'),
          ),
          GuideTopic(
            title: Tr.pick('財政破綻ペナルティ', 'Running out of money'),
            description: Tr.pick('資金がマイナスの状態が長期間続くと、理事会からの信頼度低下などのペナルティが課される。',
                "Stay in the red long enough and there are consequences, starting with the board's confidence in you."),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.apartment,
        title: Tr.pick('施設・スタッフ画面', 'Facilities and staff screen'),
        overview: Tr.pick(
            'クラブの設備とスタッフを強化する画面。ここへの投資は選手の成長・怪我のしにくさ・収入に長期的な効果をもたらす。',
            'Where you upgrade the club itself. What you spend here pays back over time in player development, fewer injuries and more income.'),
        topics: [
          GuideTopic(
              title: Tr.pick('トレーニング施設', 'Training facilities'),
              description: Tr.pick('レベルが高いほど選手の成長速度にボーナスが付く。',
                  'Higher levels speed up how quickly players improve.')),
          GuideTopic(
              title: Tr.pick('スタジアム', 'Stadium'),
              description: Tr.pick('レベルが高いほど収容人数が増え、観客動員による収入が伸びる。',
                  'Higher levels mean more seats, and more money through the gate.')),
          GuideTopic(
            title: Tr.pick('ユース施設', 'Youth facilities'),
            description: Tr.pick('レベルが高いほどユースインテークで入ってくる選手の質(潜在能力)が上がりやすくなる。',
                'Higher levels raise the quality — the potential — of the players your academy produces.'),
          ),
          GuideTopic(
            title: Tr.pick('商業施設', 'Commercial facilities'),
            description: Tr.pick('レベルに応じて観客収入とスポンサー収入の両方をまとめて底上げする。',
                'Lifts both gate receipts and sponsorship income together, by level.'),
          ),
          GuideTopic(
            title: Tr.pick('スタッフ(スカウト等)', 'Staff'),
            description: Tr.pick('スタッフのレベルはそれぞれの担当領域(スカウトなら候補選手の発掘力など)に影響する。',
                'Each member of staff affects their own area — your scout, for instance, decides what your scouting turns up.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.emoji_events,
        title: Tr.pick('日程・カップ戦・カレンダー画面', 'Fixtures, cups and calendar'),
        overview: Tr.pick('リーグ戦の日程と順位表、国内・大陸カップ戦の進行、そして週ごとの予定を確認する画面群。',
            'The league fixtures and table, how the cups are progressing, and what each week holds.'),
        topics: [
          GuideTopic(
            title: Tr.pick('順位表と昇格・降格', 'The table, promotion and relegation'),
            description: Tr.pick(
                '自クラブの所属ディビジョン以外の順位表も閲覧できる。上位陣は自動昇格または昇格プレーオフ進出、下位陣は降格の対象になる。',
                'You can look at the table for any division, not just your own. The top go up automatically or into the play-offs; the bottom go down.'),
          ),
          GuideTopic(
            title: Tr.pick('昇格プレーオフ', 'Promotion play-offs'),
            description: Tr.pick(
                '自動昇格枠を逃した中位クラブ同士で行われる、上位ディビジョンへの最後の昇格枠を懸けたノックアウト方式のトーナメント。',
                'A knockout between the clubs that just missed automatic promotion, for the last place in the division above.'),
          ),
          GuideTopic(
            title: Tr.pick('国内カップ・大陸カップ', 'Domestic and continental cups'),
            description: Tr.pick(
                '国内カップは同ディビジョン内外を問わないノックアウト方式。大陸カップは上位成績クラブのみが参加し、グループステージの後にノックアウトで優勝を争う。自クラブの試合はライブ観戦でもクイック消化でも進められる。',
                'The domestic cup is a straight knockout, open across divisions. The continental cup takes only the clubs that finished high enough, with a group stage before the knockout rounds. Your own ties can be watched live or simmed.'),
          ),
          GuideTopic(
            title: Tr.pick('勝ち上がり賞金', 'Progression prize money'),
            description: Tr.pick(
                'カップ戦は1勝(1タイ勝ち抜け)ごとに賞金が入り、ラウンドが深いほど高額になる。優勝時はさらに大きな優勝ボーナスが加わるため、カップ戦を勝ち進むこと自体が重要な収入源になる。',
                'Every cup tie you win pays, and the deeper the round the more it is worth. Winning the thing adds a much larger bonus on top, which makes a cup run a serious source of income in itself.'),
          ),
          GuideTopic(
            title: Tr.pick('カレンダー', 'Calendar'),
            description: Tr.pick(
                'リーグ戦・カップ戦の実際の日付と、週の重点トレーニング日を一覧できる。試合が詰まる週の見通しを立てるのに使う。',
                'The actual dates of league and cup matches, plus your main training day each week. Use it to see a congested run coming.'),
          ),
        ],
      ),
      GuideSection(
        icon: Icons.workspace_premium,
        title:
            Tr.pick('シーズン成績・実績・監督キャリア画面', 'Records, achievements and career'),
        overview: Tr.pick(
            '過去の記録を振り返るための画面群。うまくいった/いかなかったシーズンを見返し、次のシーズンの方針決めに活かす。',
            'Where you look back. Review the seasons that went well and the ones that did not, and decide how to approach the next one.'),
        topics: [
          GuideTopic(
            title: Tr.pick('シーズン成績アーカイブ', 'Season archive'),
            description: Tr.pick('シーズンごとの最終順位・勝敗・昇降格・カップ優勝歴をまとめて振り返れる。',
                'Final positions, records, promotions and relegations, and cups won, season by season.'),
          ),
          GuideTopic(
            title: Tr.pick('実績(アチーブメント)', 'Achievements'),
            description: Tr.pick('タイトル獲得や通算記録など、特定の条件を満たすと解除されるやり込み要素。',
                'Unlocked by meeting particular conditions — winning things, reaching career milestones and so on.'),
          ),
          GuideTopic(
            title: Tr.pick(
                '表彰・ベストイレブン・殿堂', 'Awards, team of the season and hall of fame'),
            description: Tr.pick(
                'シーズン終了時には得点王・MVP・ゴールデングラブ(無失点王)などの個人タイトルとシーズンベストイレブンが選出される。長く活躍した選手は引退・退団後に殿堂入りとして記録に残る。',
                'At the end of each season the top scorer, player of the season and Golden Glove are decided, along with the team of the season. Players who gave you long service are remembered in the hall of fame once they retire or leave.'),
          ),
          GuideTopic(
            title:
                Tr.pick('監督への信頼度・監督としての評価', 'Board confidence and reputation'),
            description: Tr.pick(
                '信頼度は理事会からの評価で、目標順位を下回る成績が続くと下がり0で解任される。評価は世間からの監督評価で、解任・移籍後も引き継がれ、他クラブからの就任オファーの受けやすさに影響する。',
                'Confidence is what your board thinks: results below their target push it down, and at zero you are sacked. Reputation is what the wider game thinks, and unlike confidence it follows you through sackings and moves, shaping the offers you receive.'),
          ),
        ],
      ),
    ];
