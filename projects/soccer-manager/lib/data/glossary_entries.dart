import '../models/attributes.dart';
import '../l10n/tr.dart';

/// 用語集のカテゴリ。用語集画面でのグルーピング・絞り込みに用いる。
enum GlossaryCategory {
  attribute,
  composite,
  condition,
  contractTransfer,
  tactics,
  liveMatch,
  club,
}

extension GlossaryCategoryInfo on GlossaryCategory {
  String get label => switch (this) {
        GlossaryCategory.attribute => Tr.pick('選手能力値', 'Player attributes'),
        GlossaryCategory.composite => Tr.pick('複合指標', 'Composite ratings'),
        GlossaryCategory.condition =>
          Tr.pick('コンディション・メンタル', 'Condition & mentality'),
        GlossaryCategory.contractTransfer =>
          Tr.pick('契約・移籍', 'Contracts & transfers'),
        GlossaryCategory.tactics => Tr.pick('戦術', 'Tactics'),
        // 名前は旧来のまま。ライブ観戦は無くなり(試合は一括で計算する)、
        // 残るのは試合の進め方の項目だけなので、見出しは「試合」にした。
        GlossaryCategory.liveMatch => Tr.pick('試合', 'Matches'),
        GlossaryCategory.club => Tr.pick('クラブ経営', 'Club finances'),
      };
}

/// 用語集の1項目。[term]は画面上の見出し、[description]は意味・仕様の説明文。
class GlossaryEntry {
  final String term;
  final GlossaryCategory category;
  final String description;

  const GlossaryEntry({
    required this.term,
    required this.category,
    required this.description,
  });
}

// const にできないのは、説明文が表示時の言語で決まるため。
Map<String, String> get _attributeDescriptions => {
      AttributeKeys.corners: Tr.pick(
          'コーナーキックの精度。蹴る選手の値が高いほどチャンスの質が上がる。',
          'Accuracy from corners. The higher this is on the man taking them, the better the chances that come from them.'),
      AttributeKeys.crossing: Tr.pick('サイドからのクロスの正確さ。攻撃力の複合値(技術)に反映される。',
          'Accuracy of crosses from wide. Feeds into the attack and technical ratings.'),
      AttributeKeys.dribbling: Tr.pick('ボールを持って相手を抜く能力。攻撃力の複合値に反映される。',
          'The ability to beat a man with the ball. Feeds into the attack rating.'),
      AttributeKeys.finishing: Tr.pick('シュートの決定力。攻撃力の複合値で最も重みが大きい項目。',
          'How reliably he finishes. The heaviest single item in the attack rating.'),
      AttributeKeys.firstTouch: Tr.pick('ボールを受けた際の落ち着き。技術の複合値に反映される。',
          'How cleanly he takes the ball. Feeds into the technical rating.'),
      AttributeKeys.freeKick: Tr.pick(
          '直接フリーキックの精度。蹴る選手の値が高いほどチャンスの質が上がる。',
          'Accuracy from direct free kicks. The higher this is on the man taking them, the better the chances.'),
      AttributeKeys.heading: Tr.pick(
          '空中戦での競り合い・ヘディングシュートの精度。', 'Winning headers, and finishing them.'),
      AttributeKeys.longShots: Tr.pick('中距離・遠距離からのシュート精度。攻撃力の複合値に反映される。',
          'Accuracy shooting from range. Feeds into the attack rating.'),
      AttributeKeys.longThrows: Tr.pick(
          'ロングスローインの飛距離・精度。', 'The distance and accuracy of his long throws.'),
      AttributeKeys.marking: Tr.pick('相手選手を捕まえる能力。守備力の複合値で最も重みが大きい項目。',
          'How well he sticks to an opponent. The heaviest single item in the defence rating.'),
      AttributeKeys.passing: Tr.pick('パスの正確さ。技術の複合値で最も重みが大きい項目。',
          'Accuracy of his passing. The heaviest single item in the technical rating.'),
      AttributeKeys.penalties: Tr.pick('PKの成功率。蹴る選手の値が高いほど成功率が上がる。',
          'His success rate from the spot. The higher this is on the man taking it, the better the odds.'),
      AttributeKeys.tackling: Tr.pick('相手からボールを奪う能力。守備力の複合値に反映される。',
          'Winning the ball back. Feeds into the defence rating.'),
      AttributeKeys.technique: Tr.pick('ボールコントロール全般の巧みさ。技術の複合値に反映される。',
          'General skill on the ball. Feeds into the technical rating.'),
      AttributeKeys.aggression: Tr.pick(
          '球際やプレスでの積極性。高いほど守備力にプラスだが、警告・退場のリスクも増える。',
          'How hard he goes into challenges. Helps the defence, but raises the risk of cards.'),
      AttributeKeys.anticipation: Tr.pick('状況を先読みする力。守備力の複合値に反映される。',
          'Reading the play before it happens. Feeds into the defence rating.'),
      AttributeKeys.bravery: Tr.pick(
          '危険な状況でも臆さずプレーする度胸。', 'Playing without flinching where it hurts.'),
      AttributeKeys.composure: Tr.pick('プレッシャー下での冷静さ。高いほど攻撃力にプラスで、警告のリスクを抑える。',
          'Keeping his head under pressure. Helps the attack and reduces the risk of cards.'),
      AttributeKeys.concentration: Tr.pick(
          '試合を通して集中力を維持する能力。', 'Holding his concentration for the full match.'),
      AttributeKeys.decisions: Tr.pick('状況判断の的確さ。技術の複合値に反映される。',
          'Picking the right option. Feeds into the technical rating.'),
      AttributeKeys.determination: Tr.pick(
          '逆境でも諦めない闘志。潜在能力に到達するための成長のしやすさに影響する。',
          'Refusing to give in. Affects how readily he grows towards his potential.'),
      AttributeKeys.flair:
          Tr.pick('独創的なプレーを生み出すひらめき。', 'The spark to do something unexpected.'),
      AttributeKeys.leadership: Tr.pick('チームを鼓舞する統率力。値が高い選手ほどチームリーダーになりやすい。',
          'How he lifts those around him. The higher it is, the likelier he is to be one of the team leaders.'),
      AttributeKeys.offTheBall: Tr.pick('ボールを持たない時の動き出し。攻撃力の複合値に反映される。',
          'His movement without the ball. Feeds into the attack rating.'),
      AttributeKeys.positioning: Tr.pick('守備時の立ち位置の的確さ。守備力の複合値に反映される。',
          'Where he stands when defending. Feeds into the defence rating.'),
      AttributeKeys.teamwork:
          Tr.pick('味方と連携してプレーする意識。', 'How well he plays for the team.'),
      AttributeKeys.vision: Tr.pick('味方の動きを見通すパスセンス。技術の複合値に反映される。',
          'Seeing the pass before others do. Feeds into the technical rating.'),
      AttributeKeys.workRate: Tr.pick('運動量・献身性。スタミナの複合値に反映される。',
          'How much ground he covers, and how willingly. Feeds into the stamina rating.'),
      AttributeKeys.acceleration: Tr.pick('瞬間的な加速力。スタミナの複合値に反映される。',
          'How quickly he gets up to speed. Feeds into the stamina rating.'),
      AttributeKeys.agility: Tr.pick('身のこなしの俊敏さ。', 'How nimbly he moves.'),
      AttributeKeys.balance:
          Tr.pick('接触時にバランスを崩さない安定感。', 'Staying on his feet through contact.'),
      AttributeKeys.jumpingReach: Tr.pick('ジャンプの高さ・到達点。空中戦の強さに関わる。',
          'How high he gets. Central to winning the ball in the air.'),
      AttributeKeys.naturalFitness: Tr.pick(
          '生まれ持った体力の強さ。高いほど怪我をしにくく、トレーニングでの成長効率にも影響する。',
          'His natural constitution. Higher means fewer injuries, and better returns from training.'),
      AttributeKeys.pace: Tr.pick('走る速さ。攻撃力の複合値に反映される。',
          'How fast he runs. Feeds into the attack rating.'),
      AttributeKeys.stamina: Tr.pick('試合を通して運動量を維持する持久力。スタミナの複合値で最も重みが大きい項目。',
          'Keeping his work rate up for 90 minutes. The heaviest single item in the stamina rating.'),
      AttributeKeys.strength: Tr.pick('フィジカルの強さ。守備力・スタミナ両方の複合値に反映される。',
          'Sheer physical strength. Feeds into both the defence and stamina ratings.'),
      AttributeKeys.aerialReach: Tr.pick(
          'GKが飛び出して高いボールに対応する能力。', 'How well the keeper comes for high balls.'),
      AttributeKeys.commandOfArea: Tr.pick(
          'GKがペナルティエリア内を統率する能力。', 'How well the keeper commands his box.'),
      AttributeKeys.handling: Tr.pick(
          'GKがボールを確実にキャッチ・キープする能力。', 'How safely the keeper holds the ball.'),
      AttributeKeys.kicking: Tr.pick('GKのゴールキックやパントキックの精度。',
          "The keeper's accuracy with goal kicks and punts."),
      AttributeKeys.oneOnOnes: Tr.pick(
          'GKが1対1の場面でシュートを防ぐ能力。', 'How the keeper handles a one-on-one.'),
      AttributeKeys.reflexes:
          Tr.pick('GKの反射的な反応の速さ。', "The keeper's reaction speed."),
    };

// final ではなくゲッターにしている。final にすると最初のアクセス時に
// リストが組み立てられ、そのときの言語で文言が固定されてしまい、設定で
// 日本語/英語を切り替えても用語集だけ変わらなくなる。
List<GlossaryEntry> get glossaryEntries => [
      for (final key in AttributeKeys.all)
        GlossaryEntry(
          term: AttributeKeys.labelOf(key),
          category: GlossaryCategory.attribute,
          description: _attributeDescriptions[key] ?? '',
        ),
      GlossaryEntry(
        term: Tr.pick('総合力', 'Overall'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            '選手全体の実力を1つの数値にまとめたもの。攻撃力・守備力・技術・スタミナなど能力値全体の平均から算出される。',
            'One number for how good he is overall, averaged across attack, defence, technical and stamina.'),
      ),
      GlossaryEntry(
        term: Tr.pick('潜在能力', 'Potential'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            '選手が将来到達しうる総合力の上限。若い選手ほど現在の総合力との差(伸びしろ)が大きくなりやすく、ユース画面では「伸びしろ」でも並び替えできる。',
            'The ceiling on his overall. Younger players tend to have more room between the two, and the youth screen lets you sort by that gap.'),
      ),
      GlossaryEntry(
        term: Tr.pick('攻撃力', 'Attack'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            'フィニッシュ・ロングシュート・ドリブル・オフザボール・冷静さ・スピードの加重平均。試合シミュレーションのチーム攻撃力計算のベースになる。',
            "A weighted average of finishing, long shots, dribbling, movement off the ball, composure and pace. The basis of your side's attacking strength in the match simulation."),
      ),
      GlossaryEntry(
        term: Tr.pick('守備力', 'Defence'),
        category: GlossaryCategory.composite,
        description: Tr.pick(
            'タックル・マーキング・ポジショニング・予測・強さ・積極性の加重平均。試合シミュレーションのチーム守備力計算のベースになる。',
            "A weighted average of tackling, marking, positioning, anticipation, strength and aggression. The basis of your side's defensive strength in the match simulation."),
      ),
      GlossaryEntry(
        term: Tr.pick('技術', 'Technical'),
        category: GlossaryCategory.composite,
        description: Tr.pick('パス・ファーストタッチ・視野・テクニック・クロス・判断力の加重平均。ボールを扱う巧みさの目安。',
            'A weighted average of passing, first touch, vision, technique, crossing and decisions. A measure of how well he handles the ball.'),
      ),
      GlossaryEntry(
        term: Tr.pick('スタミナ(複合値)', 'Stamina (composite)'),
        category: GlossaryCategory.composite,
        description: Tr.pick('スタミナ・基礎体力・労働量・強さ・加速力の加重平均。運動量が求められるポジションほど重要になる。',
            'A weighted average of stamina, natural fitness, work rate, strength and acceleration. It matters more the more ground a position demands.'),
      ),
      GlossaryEntry(
        term: Tr.pick('疲労', 'Fatigue'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '試合出場で蓄積し、休養やトレーニング施設で回復する。高いほど試合でのコンディション(パフォーマンス)が下がる。',
            'Builds up through matches, and comes down with rest and good facilities. The higher it is, the worse his condition on the day.'),
      ),
      GlossaryEntry(
        term: Tr.pick('士気(モラール)', 'Morale'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'チームの勢い・選手の意気込みを表す値。高いほど試合でのコンディションが上がる。試合の結果で上下する。',
            'How the side and the player feel about things. Higher means a better condition on the day. Results move it up and down.'),
      ),
      GlossaryEntry(
        term: Tr.pick('マッチシャープネス', 'Match sharpness'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '直近の試合勘・実戦感覚。出場を重ねるほど上がり、ベンチ・怪我・出場停止が続くと緩やかに下がる。負傷から復帰した直後は大きく下がるため、復帰後しばらくは本来のコンディションを出しにくい。',
            'How match-ready he is. It rises with minutes and drifts down through spells on the bench, injured or suspended. It drops sharply on return from injury, so he will not be himself for a while.'),
      ),
      GlossaryEntry(
        term: Tr.pick('コンディション', 'Condition'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '試合中の実際のパフォーマンス補正。疲労・士気・マッチシャープネスの3要素から算出され、これらが高いほど攻撃力・守備力への影響が良くなる。',
            'The modifier applied to his performance on the day. Worked out from fatigue, morale and match sharpness; the better those are, the more he contributes.'),
      ),
      GlossaryEntry(
        term: Tr.pick('不満度', 'Happiness'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手のクラブへの満足度(0-100)。低いほど移籍を希望しやすくなる。出場機会・年俸・チーム成績・性格によって変動し、性格ごとの閾値を下回ると移籍希望のフラグが立つ。',
            'How content he is at the club (0-100). The lower it is, the more likely he asks to leave. Minutes, wages, results and his personality all move it, and each personality has its own threshold for requesting a move.'),
      ),
      GlossaryEntry(
        term: Tr.pick('性格', 'Personality'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手の気質(全20種類)。不満度の変動しやすさ・移籍希望の出やすさのほか、賃金要求の強さにも影響する。各性格の詳しい説明はガイドの「スカッド・選手詳細画面」を参照。',
            "His temperament, one of twenty. It governs how easily he becomes unsettled, how readily he asks for a move, and how hard he pushes on wages. The guide's squad section describes each one."),
      ),
      GlossaryEntry(
        term: Tr.pick('デューティ', 'Duty'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手の戦術上の役割の重心(守備的/バランス/攻撃的)。ポジションとロールから選手ごとに決まっていて、変えることはできない。攻撃的な選手ほど攻撃力に、守備的な選手ほど守備力にボーナスが付く代わりに、もう一方が手薄になる。',
            'Where his role sits between defend, support and attack. It comes with the player, from his position and role, and cannot be changed. An attacking duty adds attacking output at the cost of defensive cover, and a defensive one the other way round.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ロール(プレースタイル)', 'Role'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'どの能力値を活かしたプレーを得意とするか(プレーメイカー・ポーチャーなど)。選手の能力値から選手ごとに決まっていて、変えることはできない。特に得意な能力が無い選手には付かない。ロールが重視する能力値が高いほど試合でボーナスが付く。',
            'What kind of player he is (playmaker, poacher and so on). It comes with the player, from his attributes, and cannot be changed; players with no standout strength have none. The stronger he is in the attributes it values, the more it adds in matches.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ポジション適性・慣れ', 'Position familiarity'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '本職(主ポジション)以外で起用した際の習熟度(0-100)。出場を重ねるほど上昇し、本来のポジションとのギャップによる攻撃力・守備力ペナルティを徐々に軽減する。',
            'How settled he is in a position that is not his own (0-100). It climbs with minutes there, and gradually eats away at the penalty for playing out of position.'),
      ),
      GlossaryEntry(
        term: Tr.pick('年俸', 'Salary'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '選手に1年で支払う給料。市場価値に応じて決まり(価値が高いほど高い)、毎節その年の節の数で割って支払う。契約更新の交渉で上がり、性格ごとの賃金感応度によって要求額が変わる。',
            'What he is paid a year. It follows his market value and is paid out over the matchdays. Contract talks raise it, and how hard he pushes depends on his personality.'),
      ),
      GlossaryEntry(
        term: Tr.pick('契約残り年数', 'Years remaining'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '現在の契約が満了するまでの年数。シーズン終了時に1年ずつ減り、残り0年のままシーズンを終えると自由契約として退団してしまうため、事前の契約更新が必要になる。',
            'How long his deal has left. It drops by a year each season, and if it reaches zero he leaves on a free, so renew before then.'),
      ),
      GlossaryEntry(
        term: Tr.pick('想定移籍金', 'Estimated fee'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('年齢・現在の総合力・伸びしろから概算した市場価値(万円)。移籍交渉時のオファー額の目安になる。',
            'A rough valuation from his age, current overall and room to grow. It is the yardstick for what a bid should look like.'),
      ),
      GlossaryEntry(
        term: Tr.pick('リリース条項', 'Release clause'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('設定されている場合、他クラブがこの金額(万円)を提示すると交渉なしで自動的に移籍が成立する。',
            'Where one is set, any club offering that amount takes him with no negotiation at all.'),
      ),
      GlossaryEntry(
        term: Tr.pick('出場手当', 'Appearance fee'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('契約更新時に決定される手当(万円)。リーグ戦・カップ戦・大陸大会に先発するたびに支払われ、途中出場なら半額。',
            'Agreed when you renew, and paid every time he starts a league, cup or continental match. Half if he comes off the bench.'),
      ),
      GlossaryEntry(
        term: Tr.pick('サインボーナス', 'Signing bonus'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick('契約更新時に一時金として支払う金額。性格ごとの賃金感応度に応じて要求されやすさが変わる。',
            'A lump sum paid on renewal. How often it is demanded depends on his personality.'),
      ),
      GlossaryEntry(
        term: Tr.pick('出場停止', 'Suspension'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '警告(イエローカード)の累積が一定枚数に達する、または退場(レッドカード)を受けると、その後の一定試合数は出場できなくなる。',
            'Collect enough yellows, or a red, and he sits out a set number of matches.'),
      ),
      GlossaryEntry(
        term: Tr.pick('移籍リスト登録', 'Transfer listing'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '登録すると他クラブからの獲得オファーが届きやすくなる(登録なしより高い確率で発生)。放出したい選手に活用できる。',
            'Listing a player makes offers from other clubs arrive more often. Useful for anyone you want off the books.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ローン(期限付き移籍)', 'Loan'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '一定期間だけ他クラブへ選手を貸し出す/借り受ける制度。ローン中の選手の年俸は貸出先が負担し、期間満了で自動的に元クラブへ復帰する。買取オプション付きなら期間中に完全移籍へ切り替えられる。',
            'Sending a player elsewhere, or taking one in, for a fixed spell. The receiving club pays his wages, and he returns automatically when it ends. With an option to buy, it can be made permanent at any point.'),
      ),
      GlossaryEntry(
        term: Tr.pick('代表召集', 'International duty'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '一定期間、代表チームの活動のため自クラブの試合に出場できなくなる。召集期間が明ければ通常通りチームに復帰する。',
            'He is away with his country for a spell and unavailable to you. He rejoins normally once it is over.'),
      ),
      GlossaryEntry(
        term: Tr.pick('サポーターの期待', 'Supporter expectation'),
        category: GlossaryCategory.club,
        // 実際の動きに合わせる(2026-11-23)。以前は「目標順位を下回る成績が
        // 続くと下がる」とだけあり、何で上下するのか分からなかった。
        // 2026-11-23 に作り直した動きに合わせる。
        description: Tr.pick(
            'サポーターの期待(0-100)。試合の結果は月末にまとめて-6〜+6(目標の順位との差と、その月の勝点の取り方)。ダービー(±4)・カップ・季の折り返しの理事会レビュー(目標との差に比例、最大-10)・季末(同じく比例、最大-10)はその場で動く。オーナーの手でも動く: チケットは毎月 安い+2・普通0・高い-2、広報・ファンの手は月に1回+3〜6、地域活動は続けている間 毎月+1、主力級の獲得+3、人気の選手の売却-3〜-6、スタジアムの増築の完成+5。毎月の内訳はホームと受信箱に出る。10を割ると最後通告が出て、3か月のうちに10以上へ戻せなければクラブを手放す。季を越えれば最低40から始まる。',
            'What the supporters expect (0-100). Results are summed up at the end of each month, -6 to +6 (your place against the target, and the points you took that month). Derbies (±4), cups, the halfway board review (in proportion to the gap from the target, at most -10) and the season-end verdict (likewise) move it on the spot. Your own moves count too: tickets each month (cheap +2, standard 0, expensive -2), one PR or fan move a month (+3 to +6), community work +1 every month while it runs, signing a first-team star +3, selling a fans\' favourite -3 to -6, and a finished stadium expansion +5. The monthly breakdown appears on the home screen and in the inbox. Below 10 the supporters issue a final warning: get back to 10 within three months, or you have to sell the club. A new season starts from at least 40.'),
      ),
      GlossaryEntry(
        term: Tr.pick('オーナーの評判', 'Reputation'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '世間からのオーナーとしての評価(0-100)。サポーターの期待と異なり、クラブを手放しても別のクラブへ移っても引き継がれ、スポンサーや人の集まりやすさに影響する。',
            'How the wider game rates you as an owner (0-100). Unlike supporter expectation it follows you when you sell and move to another club, and shapes how sponsors and people respond to you.'),
      ),
      GlossaryEntry(
        term: Tr.pick('理事会の目標順位', 'Board target'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'シーズン開始時に理事会から示される目標順位(1が最高位)。季の途中のレビューと季末に、これと比べてサポーターの期待が上下する。',
            'The finishing position the board asks for at the start of the season. Supporter expectation moves against it at the mid-season review and at the end of the season.'),
      ),
      GlossaryEntry(
        term: Tr.pick('生え抜き', 'Academy graduate'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '自クラブのユースから昇格させた選手に付く印。買ってきた選手と、何年もかけて育てた選手を名簿の上で見分けるためのもの。一度付いたら外れない。',
            'The mark on a player you brought through your own academy, so the ones you bought and the ones you raised can be told apart at a glance. Once earned it never comes off.'),
      ),
      GlossaryEntry(
        term: Tr.pick('シーズンの振り返り', 'Season review'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'シーズンが終わった直後にホームへ出るまとめ。順位・勝敗・得失点・獲得タイトル・得点王と、その年の総括が並ぶ。閉じるとそのシーズンについては二度と出ない。過去の年はシーズン成績の画面でいつでも見返せる。',
            'The summary that appears on the home screen when a season ends: where you finished, your record, the goals, any trophies, the top scorer and a verdict on the year. Close it and it will not come back; past seasons stay in the season history screen.'),
      ),
      GlossaryEntry(
        term: Tr.pick('次にやること', 'What to do next'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '状況ページの監督の報告の下に出る提案。始めたばかりのクラブなら空いたスタッフ・スポンサー・オーナーの目標を、ほかに季の切り替えでの資金不足・サポーターの期待の下落・移籍の締切・監督からの補強の候補・届いた売却のオファー・資金のマイナス・ユースの流出候補・主力の契約切れ間近を見て、いま手を付けるべきことを1件だけ出す。損が確定しているものが先に来る。',
            "The prompt under the manager's report on the status page. For a new club it looks at empty staff posts, a missing sponsor and an unset owner goal; after that it watches for a cash shortfall at the season changeover, falling supporter expectation, the transfer deadline, signing candidates from the manager, offers for your players, a negative balance, a prospect about to walk and a key contract running down, and names the single thing worth doing now. Whatever is already costing you comes first."),
      ),
      GlossaryEntry(
        term: Tr.pick('スタッフの得意分野', 'Staff specialty'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'ユースコーチが持つ専門(攻撃・守備・GK・フィジカル・万能)。能力値は「どれだけ上手いか」しか表さないため、得意分野が「何を伸ばせるか」を決める。有望株の伸びる能力に直接効き、担当が違う分野(GK専門とフィールドプレーヤーなど)には効かない。ほかの役職では効かないので、札はユースコーチにだけ出る。候補の半数は万能。',
            "What a youth coach is specialised in: attacking, defending, goalkeeping, physical or all-round. His attributes say how good he is; the specialty says what he can improve. It steers which attributes your prospects gain, and does nothing outside its remit: a goalkeeping coach adds nothing to an outfield player. It has no effect in other roles, so only youth coaches show one. About half the candidates are all-round."),
      ),
      GlossaryEntry(
        term: Tr.pick('ユースリーグ', 'Youth league'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '自クラブのユースと近隣7クラブのユースで戦う年間リーグ(14節)。毎週の練習試合がこの順位表に積み上がる。全節を終えると順位と得点王がニュースに出る。相手の強さはシーズン開始時に自クラブのユースの水準から決まり、年度ごとに引き直される。',
            'A 14-round league between your academy and seven neighbouring ones. The weekly youth match feeds this table, and when the rounds are done the finishing position and top scorer make the news. Opponent strength is set from your own academy at the start of each season, and redrawn every year.'),
      ),
      GlossaryEntry(
        term: Tr.pick('プロ契約(昇格)', 'First professional contract'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            'ユースから一軍へ上げるときに結ぶ契約。背番号が付き、市場価値に見合う年俸と契約金(一括)が発生する。契約金が払えない、または給与予算の枠が無いと昇格できない。昇格直後は一軍の強度に慣れておらず実戦感覚が低い状態から始まるため、出番を作れる時期に上げるかどうかの判断になる。',
            "The contract you sign when a prospect steps up. He takes a squad number, a wage in line with his market value and a one-off signing bonus. Without the bonus or the wage room, the promotion does not happen. He starts short of match sharpness until he adjusts, so the timing matters as much as the decision."),
      ),
      GlossaryEntry(
        term: Tr.pick('有望株の流出', 'Losing a prospect'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '19歳を過ぎた有望株は出場機会を求め、そのままにしておくとユースを去る。20歳を過ぎるとその確率は上がる。伸びしろの大きい選手は他クラブに引き抜かれ、伸び悩んだ選手は自分から去る。いずれも育成補償金が入る。ユース施設を上げる、一軍に昇格させる、のどちらかで引き止められる。',
            'Past 19, a prospect wants first-team football and will leave the academy if nothing changes; past 20 it happens more often. The ones with room to grow get poached, the ones who stalled walk away. Either way you receive a development fee. A better academy or a promotion to the first team will keep him.'),
      ),
      GlossaryEntry(
        term: Tr.pick('全体練習', 'General training'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '週の練習。毎週自動で行われ、ポジションに応じて攻守をバランス良く伸ばす。伸び方はトレーニング施設の水準と、雇っているコーチの水準で大きくなる。',
            'The weekly session. It runs itself every week and develops attack and defence evenly by position. How much players gain grows with your training facilities and with the level of the coaches you hire.'),
      ),
      GlossaryEntry(
        term: Tr.pick('マンマーク', 'Man-marking'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '相手に飛び抜けた選手がいると、監督が守備の強い選手を自動でその選手に付ける。マーカーが出場している間、相手のキープレイヤーの攻撃力への貢献を抑えられる。',
            'When the opponent has a player well above the rest, the manager puts your best defender on him automatically. While the marker is on the pitch, their man contributes less going forward.'),
      ),
      GlossaryEntry(
        term: Tr.pick('守備セットプレー担当', 'Defensive set piece duty'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '相手のコーナーキック・フリーキックを守る担当選手。監督が毎節、先発の中からヘディングとジャンプ力のいちばん高い選手を選ぶ。高いほど、相手のセットプレー由来のチャンスの質を下げられる。',
            'Who takes charge of defending their corners and free kicks. Each matchday the manager gives it to the starter with the best heading and jumping reach. The better those are, the less dangerous their set pieces become.'),
      ),
      GlossaryEntry(
        term: Tr.pick('負傷の種類', 'Types of injury'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '打撲(1-2週)・肉離れ(2-5週)・靭帯損傷(4-10週)の3種類があり、療養期間が異なる。基礎体力(naturalFitness)が高いほど負傷しにくく、同じ種類の負傷を繰り返すと再発しやすくなる。',
            'Three kinds, each with its own lay-off: a bruise (1-2 weeks), a torn muscle (2-5) and ligament damage (4-10). Better natural fitness means fewer injuries, and repeating the same one makes it more likely again.'),
      ),
      GlossaryEntry(
        term: Tr.pick('決定機', 'Big chance'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            '試合の中で、得点か失点かが懸かる場面。判断は監督と選手に任され、決まるかどうかは関わる選手の能力値の勝負(シューター対GKなど)で決まる。試合の記録には両チームの決定機の数が並ぶ。',
            'The moments in a match where a goal is on. The manager and players make the call, and whether it goes in comes down to the attributes of the players involved, shooter against keeper for instance. The match stats show how many each side had.'),
      ),
      GlossaryEntry(
        term: Tr.pick('メンタリティ', 'Mentality'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            'チーム全体の姿勢。超守備的〜超攻撃的の5段階で、攻撃的なほど攻撃力が上がる代わりに守備のリスクが増える(その逆も同様)。監督が毎節、相手との力関係と自分の考え方から決める。監督の水準が低いと変えずに前のまま戦う。',
            'How the side approaches the match, across five steps from very defensive to very attacking. The more positive it is, the more attacking threat and the more defensive risk, and the reverse. The manager sets it every matchday from the balance of strength and his own outlook; a manager of low standing leaves it as it was.'),
      ),
      GlossaryEntry(
        term: Tr.pick('スカッド・ステータス', 'Squad status'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '選手に約束する出場機会の立場(キープレイヤー/主力/ローテーション/育成枠)。獲得や契約更新の交渉で約束する。上の立場ほどベンチに置いたときの不満が大きく、求める給与も高くなる。',
            'What you promise a player about his minutes: key player, first team, rotation or prospect. You agree it in the talks when you sign or renew him. The higher the billing, the more he resents the bench and the more he asks for in wages.'),
      ),
      GlossaryEntry(
        term: Tr.pick('観客動員', 'Attendance'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '試合に足を運んだ人数。スタジアムの収容人数に動員率を掛けたもので、動員率は順位・サポーターの期待・チケット価格で上下する。下部ディビジョンほど低い。試合日の収入はここから決まるため、勝てないと資金も細る。',
            'How many came to the match: your stadium capacity times a turnout rate that moves with your league position, supporter expectation and your ticket prices, and which is lower the further down the pyramid you are. Matchday income follows from it, so a bad run thins the bank balance too.'),
      ),
      GlossaryEntry(
        term: Tr.pick('給与予算', 'Wage budget'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '理事会が設定する給与の総額の上限。シーズン開始時にディビジョンと現在の人件費から決まり、年の予算の補強の配分とクラブの方針でも広がり・狭まる。上限を超える新規獲得はブロックされる。クラブ経営画面で使用状況を確認できる。',
            'The ceiling the board puts on your total wages. It is set at the start of the season from your division and current bill, and it widens or narrows with the signings share of your budget and with your club policy. Any signing that would break it is blocked. The finances screen shows where you stand.'),
      ),
      GlossaryEntry(
        term: Tr.pick('チームリーダー', 'Team leaders'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'リーダーシップ・実力・年齢から決まるロッカールームの中心選手(上位3人)。リーダー陣が不機嫌だとチーム全体の士気が下がり、上機嫌だと上がる。リーダーを放出するとチームに動揺が走る。',
            "The three players the dressing room looks to, decided by leadership, ability and age. When they are unhappy the whole squad's morale sags; when they are content it lifts. Selling one unsettles everybody."),
      ),
      GlossaryEntry(
        term: Tr.pick('カップ目標', 'Cup target'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '理事会が期待する国内カップの到達ラウンド。リーグ内の戦力が高いクラブほど深いラウンドまで期待され、勝ち進めばサポーターの期待が上がり、敗退すると少し下がる。',
            'How far the board expects you to go in the domestic cup. Stronger clubs are expected deeper; cup runs lift supporter expectation, and going out lowers it a little.'),
      ),
      GlossaryEntry(
        term: Tr.pick('選手検索', 'Player search'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '移籍の画面の「探す」タブの「選手を探す」。自国の全部と、他の4か国の1部のクラブの選手を、ポジション・年齢の上限で絞り、総合力・伸びしろ・安さ・若さの順に並べられる。総合力と伸びしろはスカウトの見立ての幅で出る。気になる選手は星で注目に入れ、申し込みは同じ画面から行う。',
            "Find players, under the Search tab on the transfer screen. It covers every club at home and the top flights of the other four countries; filter by position and an age limit, and sort by overall, potential, price or age. Overall and potential are your scouts' estimated ranges. Star a player to watch him, and bid for him from the same screen."),
      ),
      GlossaryEntry(
        term: Tr.pick('武者修行(ローン育成)', 'Development loans'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            'ローン放出中の選手は貸出先で毎週実戦に出て成長する(24歳未満は特に効果が大きい)。自クラブの施設・スタッフのボーナスは効かないが、実戦感覚を保ちながら能力が伸びるため、出番のない若手の育成手段になる。復帰時には放出中の成長がニュースで報告される。',
            'A player out on loan plays every week and improves for it, especially under 24. He does not get your facilities or staff, but he stays sharp and grows, which makes it the answer for a young player with no route into your side. His progress is reported when he comes back.'),
      ),
      GlossaryEntry(
        term: Tr.pick('成長推移', 'Progress over time'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '選手の総合力を節送りごとに記録した週次の推移。選手詳細画面に折れ線グラフで表示され、伸びている選手・停滞している選手が一目で分かる。自クラブの選手とユース昇格候補が対象で、概ね1シーズン分を保持する。',
            "A weekly record of a player's overall, matchday by matchday. His page draws it as a line, so you can see at a glance who is climbing and who has stalled. Kept for your own players and academy prospects, roughly a season's worth."),
      ),
      GlossaryEntry(
        term: Tr.pick('紅白戦', 'Practice match'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '週次トレーニングの一環として自動で行われるスカッド内の練習試合。スタメン外の選手が実戦感覚(マッチシャープネス)を保ち、実戦経験による成長の機会も得る(そのぶん少し疲労は残る)。負傷・代表招集・ローン放出中の選手は参加できない。',
            'An in-house match played automatically as part of the weekly session. Players outside the XI keep their match sharpness and get some growth from the minutes, at the cost of a little fatigue. Anyone injured, away with their country or out on loan sits it out.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ユース練習試合', 'Youth matches'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            '昇格候補たちが毎週こなす近隣クラブのユースとの練習試合。全員に出場数・得点・評点が記録され、活躍(高評点)した候補は能力がさらに伸びる。戦績はユース画面で確認でき、昇格させるタイミングの判断材料になる。大活躍は受信箱にも届く。',
            "Your prospects play a nearby club's academy each week. Appearances, goals and ratings are recorded for all of them, and those who play well improve faster. The youth screen shows the record, which helps you judge when to promote someone. A standout performance reaches your inbox."),
      ),
      GlossaryEntry(
        term: Tr.pick('監督の契約', "The manager's contract"),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'あなたが雇っている監督の任期。シーズンが変わるたびに残りが1年ずつ減り、残り1年になると知らせが届く。切れると監督は去るので、新しい監督を雇う。残りはスタッフの画面で確かめられる。オーナーのあなたは理事会と契約していないので、任期で辞めさせられることはない。',
            'How long the manager you hired is signed for. It loses a year each season, you are told when he enters his last year, and when it runs out he leaves and you hire someone new. The staff screen shows what is left. As the owner you have no contract with a board, so no term can end your time at the club.'),
      ),
      GlossaryEntry(
        term: Tr.pick('監督が決める戦い方', 'How the manager sets up'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '試合の戦い方は、雇っている監督が考え方に沿って毎節決める。オーナーは選べないので、どんな戦い方をさせたいかは監督を選ぶことで決まる。決めるのは、プレッシング(寄せの強さ。強いほど守りが固くなるが疲れやすい)、ラインの高さ(高いほど攻めに厚いが裏を取られやすい)、攻撃の幅(広いほど攻めに厚いが中央が薄くなる)、テンポ(速いほど攻めに厚いが疲れやすい)、戦術スタイル(選手に合う型ほど効く)、リードした終盤に逃げ切るかどうか、キャプテン(統率力・年齢・経験で選び、季の初めと監督が替わったときに選び直す)、セットプレーの担当(PK・直接FK・CK・守備。毎節、先発の中からそれぞれ得意な選手)。攻撃的な監督は高いライン・強いプレス・速いテンポで攻め続け、堅守の監督は低いラインで守って奪ったら速く出て、リードした終盤は逃げ切る。水準の高い監督ほど、相手の強さや戦術に合わせてラインと型を変える。監督の考え方と戦い方は、スタッフの画面(雇う前の候補にも)に出る。',
            'Your manager decides how the side plays every week, following his own philosophy. You cannot pick it yourself, so the way you want to play is decided by who you hire. He sets the pressing (harder makes you tighter but tires the side), the defensive line (higher adds to the attack but leaves space behind), the width (wider adds to the attack but thins the middle), the tempo (quicker adds to the attack but tires the side), the tactical style (it works best when it suits the players), whether to shut up shop when ahead late on, the captain (chosen for leadership, age and experience, and picked again at the start of each season and when the manager changes), and the set-piece duties (penalties, direct free kicks, corners and defending them, given each matchday to the starters best at each). An attacking manager plays a high line, presses hard and goes quickly, and keeps going when ahead; a defensive one sits deep, breaks quickly when he wins the ball and sees games out. The better the manager, the more he adjusts the line and style to the opponent. The staff screen shows the philosophy and approach of every manager, candidates included.'),
      ),
      GlossaryEntry(
        term: Tr.pick('ウォッチリスト', 'Watchlist'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '気になる選手に星印をつけて追いかけるリスト。移籍の画面の「候補」の監督の補強案や「探す」で星を押すと入り、「候補」の「注目」で一覧できる。注目している選手は、どの地域でもスカウトの見え方が毎週少しずつ上がる。注目している選手が得点すると受信箱に届く。',
            'Star a player to keep an eye on him. Tap the star in the manager\'s signing picks or in Search on the transfer screen, and Watchlist under Shortlist shows them all. Your scouts get a little clearer on a watched player every week, wherever he plays, and when one of them scores it reaches your inbox.'),
      ),
      GlossaryEntry(
        term: Tr.pick('試合中の交代', 'Substitutions'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            '試合中の選手交代は監督が行う。1試合5人まで、ハーフタイム以外では3回まで(同じ場面で続けて替えるのは1回、ハーフタイムの交代は回数に数えない)。退場した選手の代わりは入れられない。',
            'The manager makes the changes during a match: five at most, in no more than three stoppages outside half-time (changes at the same stoppage count once; half-time changes do not count). A sent-off player cannot be replaced.'),
      ),
      GlossaryEntry(
        term: Tr.pick('モメンタム(試合の流れ)', 'Momentum'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            '試合の流れ。ゴールなどで勢いづいた側に傾き、傾いている間はその側の決定機がわずかに決まりやすくなる。',
            'Which way a match is flowing. It swings towards whoever has just had a moment, and while it leans their way their chances go in a little more often.'),
      ),
      GlossaryEntry(
        term: Tr.pick('クイック消化', 'Simming a match'),
        category: GlossaryCategory.liveMatch,
        description: Tr.pick(
            '試合の進め方。オーナーは試合の中に手を出さず、監督に任せて結果だけを確定させる。どの大会の試合も進むボタンがその日に止まって行い、同じ短いまとめ(結果・2つの期待の動き・賞金)を出す。疲労・負傷・警告の累積・出場記録などの試合後の効果は、どの大会でも同じように付く。',
            'How every match is played: the manager takes charge and the result is settled without you stepping in. Every competition is played from the advance button on the day, and ends in the same short digest (result, both expectations, prize money). Fatigue, injuries, cards and appearances follow in every competition.'),
      ),
      GlossaryEntry(
        term: Tr.pick('値切り交渉', 'Haggling'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '移籍市場の選手を想定移籍金より安い提示額で獲得しようとする交渉。提示額の割合が高いほど成立しやすく、55%以下では必ず決裂する。決裂した選手とはその週は再交渉できない。',
            "Bidding below a player's valuation. The closer to the asking price, the likelier it is accepted; at 55% or under it always fails. Once talks break down you cannot go back to him that week."),
      ),
      GlossaryEntry(
        term: Tr.pick('移籍市場の入れ替わり', 'How the market turns over'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '移籍市場の顔ぶれは毎週数人だけが入れ替わる持続的な仕組み。狙っていた選手を翌週以降も追える一方、いつまでも市場に残っているとは限らない。',
            'Only a handful of names change each week. A target you have your eye on will usually still be there next week, though not forever.'),
      ),
      GlossaryEntry(
        term: Tr.pick('勝ち上がり賞金', 'Progression prize money'),
        category: GlossaryCategory.club,
        description: Tr.pick(
            'カップ戦で1勝(1タイ勝ち抜け)するごとに得られる賞金。ラウンドが深いほど高額で、優勝時はさらに優勝ボーナスが加わる。',
            'Paid every time you win a cup tie. The deeper the round, the more it is worth, and winning the thing adds a further bonus on top.'),
      ),
      GlossaryEntry(
        term: Tr.pick('天候', 'Weather'),
        category: GlossaryCategory.tactics,
        description: Tr.pick(
            '試合当日の空模様(晴れ/雨/強風/猛暑/雪)。悪天候ほど攻撃力・チャンス数が下がり、雨は守備側がやや優位、猛暑は疲労が溜まりやすいなど試合展開が変わる。雨男・雪国育ちなど特定の天候で輝く選手特性もある。',
            'What the day brings: clear, rain, wind, a heatwave or snow. The worse it is, the less attacking threat and the fewer chances. Rain slightly favours defending, heat tires players faster, and some traits make a player shine in particular conditions.'),
      ),
      GlossaryEntry(
        term: Tr.pick('記者会見', 'Press conference'),
        category: GlossaryCategory.condition,
        description: Tr.pick(
            '他のクラブが自クラブの選手に関心と報じられると開かれる、移籍の噂に答える会見。「売らないと明言する」と本人は落ち着くが、その季のうちに売るとサポーターの期待が下がる。「条件しだいと話す」と本人は浮き足立つが、そのクラブから話が来る。「コメントしない」と本人は少し落ち着かなくなる。数節答えないと「コメントしない」になる。',
            'Held when another club is reported to want one of your players, to answer the transfer rumour. Saying he is not for sale settles him, but selling him that season lowers supporter expectation. Saying the price is right unsettles him, but brings an offer from that club. No comment leaves him a little restless. Leave it unanswered for a few matchdays and the club gives no comment.'),
      ),
      GlossaryEntry(
        term: Tr.pick('契約解除の違約金', 'Release compensation'),
        category: GlossaryCategory.contractTransfer,
        description: Tr.pick(
            '契約が残っている選手と合意して契約を解除するときに払う額。残りの年俸の半分〜全額で、残りが長く年俸が高いほど高い。他のクラブへ売る(放出する)ときは契約を買い手が引き継ぐので掛からない。',
            'What you pay to tear up, by mutual consent, a contract that still has time to run: half to all of the wages left, so long, expensive deals cost the most. Selling him to another club costs nothing of the sort, because the buyer takes the contract on.'),
      ),
    ];
