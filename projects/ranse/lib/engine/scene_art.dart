import 'game.dart';

/// 岐路の場面に添える絵（Gemini で作ったドット絵、assets/images/scene_<名>.jpg）。
/// 画面に依存しないよう、ここでは絵の名前だけを決める（パスは UI 側の `sceneArtPath`）。
const kSceneArts = <String>[
  'battle', // 合戦
  'camp', // 陣中の夜（足軽）
  'child', // 寺の手習い（子ども）
  'council', // 城の評定（城主以上）
  'engawa', // 縁側（縁・家族・晩年）
  'farm', // 村と田
  'market', // 城下の市（商い）
  'ninja', // 月夜の忍び（野の道）
  'oku', // 奥の間（女性）
  'tea', // 茶室（嗜み）
  'temple', // 山寺（仏門）
  'winter', // 冬の村（飢え・病・災い）
];

bool _any(String s, List<String> words) => words.any(s.contains);

/// [id] は場面の id（`SceneDef.id`）、[title] は岐路の題。どの絵を添えるかを返す。
/// 「今年の重点」（場面でない問い）には絵を添えない（null）。
String? sceneArtFor(Game g, String? id, String title) {
  if (id == null) return null;
  final i = id;
  final t = title;
  // 災い・飢え・病は、どの道でも冬の村。
  if (_any(t, ['凶作', '飢', '疫病', '熱病', '大水', '地震', '火事', '不作', '病'])) {
    return 'winter';
  }
  // 合戦。
  if (i.startsWith('bt_') ||
      i == 'battle' ||
      i == 'first_battle' ||
      _any(t, ['合戦', '初陣', '出陣', '夜襲', '籠城', '戦い', '一騎打ち', '陣触れ'])) {
    return 'battle';
  }
  if (g.isChild) return 'child';
  if (i.startsWith('a_') || i.startsWith('al_')) return 'camp';
  if (i.startsWith('sh_') || _any(t, ['忍', '刺客', '野盗', '追手', '獲物', '山狩り'])) {
    return 'ninja';
  }
  if (i.startsWith('tm_') || _any(t, ['寺', '僧', '経', '住持', '比叡山', '本山', '仏'])) {
    return 'temple';
  }
  if (_any(t, ['茶', '連歌', '名物', '香', '琴'])) return 'tea';
  if (i.startsWith('tf_m_') || _any(t, ['商', '市', '座', '店', '銭', '矢銭', '南蛮'])) {
    return 'market';
  }
  if (i.startsWith('tf_f_') ||
      i.startsWith('v_') ||
      _any(t, ['田', '村', '一揆', '堰', '水争い', '検地', '年貢'])) {
    return 'farm';
  }
  if (i.startsWith('bd_') ||
      i.startsWith('fa_') ||
      i.startsWith('oa_') ||
      _any(t, ['縁側', '幼なじみ', '連れ合い', '孫', '隠居', '辞世', '旧友'])) {
    return 'engawa';
  }
  if (i.startsWith('w_') ||
      i.startsWith('wl_') ||
      _any(t, ['奥', '輿入れ', '縁談'])) {
    return 'oku';
  }
  if (i.startsWith('l_') ||
      _any(t, [
        '評定',
        '家督',
        '謀反',
        '同盟',
        '重臣',
        '下剋上',
        '仕官',
        '奉公',
        '徴募',
        '草履取り',
      ])) {
    return 'council';
  }
  // 決め手がなければ、その人の暮らしで選ぶ。
  final l = g.l;
  if (g.hasFlag('priesthood')) return 'temple';
  if (g.hasFlag('way_outlaw') || g.hasFlag('nukenin')) return 'ninja';
  if (g.hasFlag('way_merchant')) return 'market';
  if (l.rank >= 5) return 'council';
  if (l.female && l.rank >= 1) return 'oku';
  if (l.rank >= 1) return 'camp';
  return 'farm';
}
