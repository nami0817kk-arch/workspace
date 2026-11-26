// ignore_for_file: constant_identifier_names
/// 社員の特性 70種類（1.1.0+33。企画書「社員の特性」2026-11-26）。
/// 1人 2〜4個。いちばん上の1つ（[Person.trait]）は今までの10種（[STRAITS]）から選び、残りは新しい60種から選ぶ。
/// 「天才肌」と「光るもの」はまれ。効き目は game_traits.dart。
library;

import '../l10n/l10n.dart';

/// 社員の特性の1つ（名前・良い面・悪い面・分類・出やすさ）
class StaffTrait {
  final String id, nJa, gJa, bJa, cat;

  /// 出やすさの重み（ふつう 1。まれなものは小さい）
  final double w;
  const StaffTrait(this.id, this.nJa, this.gJa, this.bJa, this.cat, [this.w = 1]);
  String get n => de(nJa);
  String get g => gJa.isEmpty ? '' : de(gJa);
  String get b => bJa.isEmpty ? '' : de(bJa);
  bool get rare => w < 1;
}

/// 特性の分類（id・名前）
const List<(String, String)> STRAIT_CATS = [
  ('old', '今までの特性'),
  ('work', '働き方'),
  ('rel', '人との関わり'),
  ('val', '価値観'),
  ('mind', '心の強さ'),
  ('quirk', '癖・弱み'),
  ('shine', '光るもの'),
];

/// まれな特性の重み（「天才肌」と「光るもの」）
const double rareW = .12;

const List<StaffTrait> STAFF_TRAITS = [
  // ===== 今までの特性（10） =====
  StaffTrait('genius', '天才肌', '事業を大きく伸ばすことがある', '伸びがばらつく・部下がついてこない', 'old', rareW),
  StaffTrait('charm', '人たらし', '事業の力が1割上がる・採用と交渉に強い', '値下げを嫌う', 'old'),
  StaffTrait('oneman', 'ワンマン', '率いる事業が2割5分強い', '抜けると事業が3割弱る', 'old'),
  StaffTrait('careful', '慎重', '大きな失敗をしない', '稼ぎを事業に回す割合が小さい', 'old'),
  StaffTrait('gambler', '博打打ち', '稼ぎの多くを事業に回す', '回したお金が空振りすることがある', 'old'),
  StaffTrait('frugal', '倹約家', '利益率が2%上がる', '事業の伸びが遅い', 'old'),
  StaffTrait('tech', '技術バカ', '開発が高い', '営業が低い', 'old'),
  StaffTrait('liar', '二枚舌', '給料が安い・株の攻防に強い', '不祥事の火種になる', 'old'),
  StaffTrait('stamina', '体力おばけ', '年をとっても衰えない', '周りの社員が疲れる', 'old'),
  StaffTrait('grit', '叩き上げ', '利益率が1%上がる・給料が安い', '財務が低い', 'old'),
  // ===== 働き方（12） =====
  StaffTrait('perfect', '完璧主義', '商品の質が上がり、不祥事が減る', '商品を作るのに時間がかかる', 'work'),
  StaffTrait('hasty', 'せっかち', '店や事業の立ち上げが早い', '失敗の確率が上がる', 'work'),
  StaffTrait('field', '現場好き', '現場の力が上がる', '管理職にすると不満で辞めやすい', 'work'),
  StaffTrait('gut', '数字より勘', '当たると新しい事業が大きく伸びる', '当たり外れが大きい', 'work'),
  StaffTrait('neat', '几帳面', '経費のむだ・帳簿の誤りが減る', '伸びはふつう', 'work'),
  StaffTrait('rough', '大ざっぱ', '手が速い', '経費が漏れる・小さな事故', 'work'),
  StaffTrait('quick', '仕事が速い', '任せた手が早く済む', '', 'work'),
  StaffTrait('night', '夜型', '開発の伸びが上がる', '現場の店では力が落ちる', 'work'),
  StaffTrait('plan', '段取り上手', '物流・工場の稼働率が上がる', '', 'work'),
  StaffTrait('deadline', '締め切り直前に強い', '上場の準備・買収の手続きが早い', '普段の伸びは遅め', 'work'),
  StaffTrait('novelty', '新しいもの好き', '時代のIT・技術の乗り換えが早い', '古い業種では力が落ちる', 'work'),
  StaffTrait('precedent', '前例主義', '安定した事業で失敗しない', '新しい事業・海外で力が落ちる', 'work'),
  // ===== 人との関わり（12） =====
  StaffTrait('mentor', '面倒見がいい', '下の人の能力が早く伸びる・辞めにくい', '', 'rel'),
  StaffTrait('lone', '一匹狼', '1人でやる仕事（研究・営業）が強い', '責任者にすると部下の忠誠が下がる', 'rel'),
  StaffTrait('mood', 'ムードメーカー', '同じ事業の人の士気が上がる', '辞めると士気が下がる', 'rel'),
  StaffTrait('faction', '派閥を作る', '派閥の人の忠誠が上がる', '派閥を作る人どうしで揉める・独立のときに人を連れて出る', 'rel'),
  StaffTrait('listen', '聞き上手', '部下の不満に早く気づく（辞める前の知らせが早い）', '', 'rel'),
  StaffTrait('tongue', '口下手', '研究・工場では関係ない', '営業・交渉で力が落ちる', 'rel'),
  StaffTrait('mediate', '仲裁役', '揉めごとの出来事を小さく収める', '', 'rel'),
  StaffTrait('shy', '人見知り', '', '新しい国・新しい取引先で力が落ちる', 'rel'),
  StaffTrait('wide', '顔が広い', '採用の候補が増える・取引先を見つけやすい', '', 'rel'),
  StaffTrait('fixer', '根回し上手', '当局の審査・役所の許可が通りやすい', '', 'rel'),
  StaffTrait('credit', '手柄を横取りする', '本人の評価・出世は早い', '部下の忠誠が下がる', 'rel'),
  StaffTrait('protect', '部下を守る', '部下の忠誠が上がる', '社長の叱責を受け流す', 'rel'),
  // ===== 価値観（10） =====
  StaffTrait('stable', '安定志向', '給料が安定していれば辞めない', '異動・海外への転勤を嫌う', 'val'),
  StaffTrait('climb', '出世欲', '昇進で大きく燃える', '待たされると不満。独立を言い出しやすい', 'val'),
  StaffTrait('devoted', '会社が好き', '給料が相場より低くても辞めない。引き抜きに強い', '', 'val'),
  StaffTrait('money', 'お金で動く', '昇給で燃える', '引き抜きに弱い', 'val'),
  StaffTrait('family', '家族第一', '', '残業・転勤を嫌う。子が生まれると休む', 'val'),
  StaffTrait('craft', '職人気質', '開発・工場で力が上がる', '管理職を嫌う', 'val'),
  StaffTrait('social', '社会のために働きたい', '環境・医療などの業種で力が上がる', '不祥事を起こすと辞める', 'val'),
  StaffTrait('honor', '名誉が欲しい', '業界団体の役職や取材で燃える', '会社が小さいと不満', 'val'),
  StaffTrait('local', '地元を離れたくない', '', '本拠の都市圏から動かすと辞める', 'val'),
  StaffTrait('abroad', '海外で働きたい', '海外の事業で力が上がる', '国内のままだと不満', 'val'),
  // ===== 心の強さ（8） =====
  StaffTrait('steel', '肝が据わっている', '不況・危機で力が落ちない', '', 'mind'),
  StaffTrait('fragile', '打たれ弱い', '', '叱ると大きく落ち込み、燃え尽きやすい', 'mind'),
  StaffTrait('compete', '負けず嫌い', '宿敵と張り合う場面で力が上がる', '', 'mind'),
  StaffTrait('optimist', '楽天家', '健康が落ちにくい', '危機に気づくのが遅い', 'mind'),
  StaffTrait('worrier', '心配性', '危機を早く知らせる', '健康が落ちやすい', 'mind'),
  StaffTrait('bounce', '切り替えが早い', '失敗のあとの落ち込みが短い', '', 'mind'),
  StaffTrait('grudge', '根に持つ', '', '叱ったり、昇進で外したりすると、ずっと忠誠が戻らない', 'mind'),
  StaffTrait('clutch', '修羅場で燃える', '会社が赤字・危機のときだけ力が大きく上がる', '', 'mind'),
  // ===== 癖・弱み（10） =====
  StaffTrait('leaky', '口が軽い', '', '買収・新商品の話が漏れ、宿敵に先を越される', 'quirk'),
  StaffTrait('drunk', '酒癖が悪い', '', '酒の席の不祥事（評判とブランドが下がる）', 'quirk'),
  StaffTrait('proud', 'プライドが高い', '', '叱ると辞める・年下の上司を嫌う', 'quirk'),
  StaffTrait('vain', '見栄っ張り', '営業ではやや強い', '経費が増える', 'quirk'),
  StaffTrait('late', '遅刻癖', '', '現場の力が少し落ちる', 'quirk'),
  StaffTrait('betting', '賭け事好き', '', '借金を作り、使い込みの不祥事の種になる', 'quirk'),
  StaffTrait('lax', '経費に甘い', '', '本社の経費が増える', 'quirk'),
  StaffTrait('gossip', 'うわさ好き', '', '社内のうわさで、ほかの人の忠誠が揺れる', 'quirk'),
  StaffTrait('moody', '気分屋', '', '月ごとの力が上下する', 'quirk'),
  StaffTrait('excuse', '言い訳が多い', '', '失敗が報告に上がるのが遅れる', 'quirk'),
  // ===== 光るもの（8。まれ） =====
  StaffTrait('charisma', 'カリスマ', '率いる事業の全員の士気・忠誠が大きく上がる', '', 'shine', rareW),
  StaffTrait('eye', '目利き', '採用の候補の正体が見える・買収先の帳簿の嘘が見える', '', 'shine', rareW),
  StaffTrait('haggle', '交渉の鬼', '買収の値段が下がる・取引先との条件が良くなる', '', 'shine', rareW),
  StaffTrait('idea', 'アイデアマン', '新商品の大当たりが増える', '', 'shine', rareW),
  StaffTrait('teacher', '教え上手', '研修の効きが倍になる', '', 'shine', rareW),
  StaffTrait('crisis', '危機に強い', '資金繰りの危機・災害の痛手が小さい', '', 'shine', rareW),
  StaffTrait('memory', '記憶力が抜群', '顧客を失いにくい（大口の客が離れにくい）', '', 'shine', rareW),
  StaffTrait('blend', 'どこでも溶け込む', 'どの国でも現地に慣れるのが早い', '', 'shine', rareW),
];

final Map<String, StaffTrait> stm = {for (final t in STAFF_TRAITS) t.id: t};

/// 一緒に持たない組み合わせ（逆の性格・重ねない光るもの）
const List<(String, String)> STRAIT_NG = [
  ('careful', 'hasty'),
  ('careful', 'gut'),
  ('neat', 'rough'),
  ('neat', 'lax'),
  ('frugal', 'vain'),
  ('frugal', 'lax'),
  ('optimist', 'worrier'),
  ('shy', 'blend'),
  ('shy', 'wide'),
  ('stable', 'abroad'),
  ('local', 'abroad'),
  ('stable', 'climb'),
  ('devoted', 'money'),
  ('genius', 'idea'),
  ('charm', 'charisma'),
  ('lone', 'faction'),
  ('lone', 'mood'),
  ('fragile', 'steel'),
  ('fragile', 'clutch'),
  ('novelty', 'precedent'),
  ('protect', 'credit'),
  ('bounce', 'grudge'),
  ('tongue', 'haggle'),
  ('tongue', 'wide'),
  ('quick', 'perfect'),
  ('stamina', 'family'),
];

bool straitNg(String a, String b) => STRAIT_NG.any((x) => (x.$1 == a && x.$2 == b) || (x.$1 == b && x.$2 == a));

/// 社長の特性（10種）と部下の特性の相性（社長・部下・毎月のやる気の動き・わけ）
const List<(String, String, double, String)> PRES_COMPAT = [
  ('oneman', 'proud', -.25, 'ワンマンの社長とプライドが高い人は揉めやすい'),
  ('oneman', 'climb', -.12, 'ワンマンの社長の下では、出世欲の強い人は上がつかえる'),
  ('charm', 'mood', .12, '人たらしの社長とムードメーカーは馬が合う'),
  ('careful', 'gambler', -.12, '慎重な社長は、博打打ちの部下を信用しない'),
  ('gambler', 'precedent', -.12, '博打打ちの社長と前例主義の人はかみ合わない'),
  ('frugal', 'money', -.18, '倹約家の社長とお金で動く人は合わない'),
  ('stamina', 'worrier', -.12, '休まない社長の下では、心配性の人が気をもむ'),
  ('genius', 'craft', .12, '天才肌の社長と職人気質の人は通じ合う'),
  ('tech', 'night', .1, '技術バカの社長と夜型の人は話が合う'),
  ('liar', 'social', -.18, '二枚舌の社長の下では、社会のために働きたい人が嫌気がさす'),
  ('noble', 'proud', .08, '名家の出の社長には、プライドが高い人も一目置く'),
];

/// 部下どうしの相性（a・b・わけ）。効き目は game_traits.dart
const List<(String, String, String)> STAFF_COMPAT = [
  ('faction', 'faction', '派閥を作る人が2人いると、派閥どうしで揉める'),
  ('mentor', 'new', '面倒見がいい人がいると、入って2年までの人がよく育ち、辞めにくい'),
  ('mood', 'fragile', 'ムードメーカーがいると、打たれ弱い人が元気になる'),
  ('charisma', 'faction', 'カリスマがいると、派閥の揉めごとが半分に減る'),
  ('leaky', 'liar', '口が軽い人と二枚舌の人がいると、話が漏れやすい'),
  ('protect', 'credit', '部下を守る人と手柄を横取りする人は、互いにやる気を下げる'),
  ('mediate', 'faction', '仲裁役がいると、派閥の揉めごとが小さく収まる'),
];
