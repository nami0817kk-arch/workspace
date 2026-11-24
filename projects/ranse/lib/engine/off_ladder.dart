import 'childhood.dart';
import 'craft_life.dart';
import 'game.dart';

/// 段の外の暮らしの段（2026-11-25、ユーザーが決めた作り込みの項目24）。
///
/// 武家と奥の女性には十段の位（`kRanksM` / `kRanksF`）があるが、商人・僧・忍び・流れ者・村の暮らしは
/// 立ち位置のカードに「身分の段の外」と一行出るだけだった。ここでは**新しい出世の仕組みを作らず**、
/// これまでの岐路が立てた旗（`goyo`・`abbot`・`sh_n_heir`・`shoya`・`sp_shop_1`・`tf_`・`cr_` ほか）と歳から、
/// その暮らしの梯子のどの段にいるかを決める。旗は消えないものだけを見るので、同じ暮らしのあいだ段は下がらない。
///
/// 段を上がる道が薄かった村（組頭）と浜（網元）にだけ、上がるきっかけの岐路を二つ足した（[buildOffLadderScenes]）。

/// 段の外の暮らしの梯子。[steps] は下から順の段の名、[hints] は i 段目から次の段へ上がる道しるべ（匂わせ）。
class OffLadderDef {
  const OffLadderDef(this.title, this.steps, this.hints, this.top);
  final String title;
  final List<String> steps;
  final List<String> hints;

  /// いちばん上の段にいる人に出す一言。
  final String top;
}

/// 暮らしの種類 → 梯子。並びは位の解説に出す順。
const kOffLadders = <String, OffLadderDef>{
  'merchant': OffLadderDef(
    '商いの段',
    ['振り売り', '店持ち', '大店', '御用商人'],
    [
      '商いに精を出す年には、町の顔役から店を構える誘いが来る。町人の家の者は、歳を重ねれば家の店を継ぐ',
      '蓄えを使って店を広げる、売りに出た大店を買い取る、育てた小僧に暖簾を分ける',
      '蓄えの厚い店には、武家の勘定方が御用の話を持ち込むことがある',
    ],
    '武家の御用を務める商人。店の格は、主家の浮き沈みと共にある',
  ),
  'priest': OffLadderDef(
    '仏門の段',
    ['小僧', '僧', '住持', '高僧'],
    [
      '二十を越えるか、寺の務めを一つ果たせば一人前の僧',
      '名が上がると、本山や老いた師から寺を任される話が来る',
      '論義の座や辻の宗論で名を上げる、使僧の務めを果たす、山の行を貫く',
    ],
    '高僧と呼ばれる身。説く言葉が、遠い国まで届く',
  ),
  'nun': OffLadderDef(
    '仏門の段（尼）',
    ['見習いの尼', '尼', '庵主', '名の聞こえた尼'],
    [
      '二十を越えるか、寺の務めを一つ果たせば一人前の尼',
      '名が上がると、寺を任される話や老いた師の跡目の話が来る',
      '講で説いて名を上げる、山の行を貫く',
    ],
    '名の聞こえた尼。教えを乞う者が門を叩く',
  ),
  'ninja': OffLadderDef(
    '忍びの段',
    ['下忍', '中忍', '上忍', '里の頭'],
    [
      '頭の仕事を引き受けて里の信を得る。術を身につけるのもよい',
      '里の働きが知れ渡ると、雇い主を選ぶ立場になる',
      '老いた頭が床につけば、里の跡目の話になる。信を得ていれば継ぎやすい',
    ],
    '里を束ねる頭。掟を守らせる側にいる',
  ),
  'bandit': OffLadderDef(
    '山の一味の段',
    ['手下', '一味の古株', '一味の頭'],
    [
      '年を重ねるか、用心棒や陣借りで腕を見せれば古株',
      '頭が倒れたとき、名乗りを上げれば頭になれる',
    ],
    '一味の頭。手下の命も背負っている',
  ),
  'wanderer': OffLadderDef(
    '流れ者の段',
    ['流れ者', '渡り者', '名の通った渡り者'],
    [
      '年を重ねるか、用心棒・賭場の見張り・一座の護衛など、腕や目で食う口を得る',
      '陣借りで手柄を立てる、野盗から村を守り抜くと名が通る',
    ],
    '名の通った渡り者。どこの宿場でも顔が利く',
  ),
  'craft': OffLadderDef(
    '職人の段',
    ['弟子', '職人', '親方', '名工'],
    [
      '親方の仕込みに耐え、年季が明ければ一人前の職人',
      '腕比べで親方の跡を取るか、自分の仕事場を開き弟子を取れば親方',
      '大名の御用を果たすか、品に名を刻むほど腕が知られれば名工',
    ],
    '名指しで品を求められる名工',
  ),
  'kawara': OffLadderDef(
    '河原の段',
    ['河原の者', '庭者・芸の者', '名のある者'],
    [
      '庭作りの人足、河原の一座、皮の仕事など、腕を見せる場に出る',
      '任された庭を仕上げる、勧進の舞台で名を上げる',
    ],
    '名のある者。卑しまれる生まれでも、腕は人を黙らせる',
  ),
  'sea': OffLadderDef(
    '浜の段',
    ['網子', '漁師', '船持ち', '網元'],
    [
      '年を重ねるか、仲間と網を合わせて自分の漁を始める',
      '借りを背負ってでも船を持てば、沖の漁場に出られる',
      '船を持って年を重ねると、浜の者に網元にと推されることがある',
    ],
    '浜を預かる網元。不漁の年も網子を食わせる',
  ),
  'mountain': OffLadderDef(
    '山の段',
    ['山の若い衆', '一人前の山の者', '山の衆の年寄'],
    [
      '年を重ねるか、自分で山の品を里へ売るようになれば一人前',
      '山の掟を預かる揉め事を裁くか、老いれば年寄に数えられる',
    ],
    '山の衆の年寄。掟は、この人の口から出る',
  ),
  'farm': OffLadderDef(
    '村の段',
    ['小百姓', '本百姓', '組頭', '庄屋・名主'],
    [
      '田を買い足す、牛を飼う、家を継ぐ歳になれば本百姓',
      '惣の沙汰人を引き受ける、減免の願いで総代に立つ。寄合で組頭に推されることも',
      '村の縁が厚いと、年寄たちに庄屋に推される。年貢を請け負う村請も',
    ],
    '村をまとめる庄屋。武家と村の板挟みにもなる',
  ),
};

/// いまの段の外の暮らし。[kind] は [kOffLadders] の鍵、[step] は 0 から。
class OffLadder {
  const OffLadder(this.kind, this.step);
  final String kind;
  final int step;
  OffLadderDef get def => kOffLadders[kind]!;
  String get name => def.steps[step];
  bool get atTop => step >= def.steps.length - 1;

  /// 次の段の名（いちばん上なら null）。
  String? get nextName => atTop ? null : def.steps[step + 1];

  /// 次の段へ上がる道しるべ（いちばん上なら、その段の一言）。
  String get guide => atTop ? def.top : def.hints[step];
}

bool _anyFlag(Game g, List<String> fs) => fs.any(g.hasFlag);
bool _anyPrefix(Game g, List<String> ps) =>
    g.l.flags.any((f) => ps.any(f.startsWith));

/// 腕や目で食う口を得た旗（野の道）。
const _roughFlags = [
  'sh_yojin_kept',
  'sh_yojin_greedy',
  'sh_yojin_fought',
  'sh_yojin_saved',
  'sh_yojin_deal',
  'sh_jingari_won',
  'sh_saw_cheat',
  'sh_forged_pass',
  'sh_ochi_spared',
  'sh_joined_troupe',
  'sh_henso_master',
];

/// どの暮らしの梯子にいるか（段は決めない）。武家・奥の位に就いた人、子ども、隠居、抜け忍、
/// 村・浜・山の女性（奉公で奥の位へ上がる道がある）は null（いままでどおり）。
String? offLadderKind(Game g) {
  final l = g.l;
  if (g.isChild || l.rank != 0) return null;
  if (g.hasFlag('priesthood')) return l.female ? 'nun' : 'priest';
  if (g.hasFlag('retired')) return null;
  if (g.hasFlag('way_merchant')) return 'merchant';
  if (g.hasFlag('nukenin')) return null;
  if (g.hasFlag('way_outlaw')) {
    return g.hasFlag('wanderer') ? 'wanderer' : 'bandit';
  }
  if (l.cls.id == 'ninja') return 'ninja';
  if (l.ronin) return null;
  if (g.hasFlag('cr_craft') ||
      g.hasFlag('craftsman') ||
      g.hasFlag('rg_seki_deshi')) {
    return 'craft';
  }
  if (l.cls.id == 'merchant') return 'merchant';
  if (l.cls.id == 'beggar') return 'kawara';
  if (l.female) return null;
  if (l.cls.id == 'fisher') return crMountainFolk(g) ? 'mountain' : 'sea';
  if (l.cls.id == 'farmer') return 'farm';
  return null;
}

/// 段の外の暮らしの、いまの段。当てはまらなければ null。乱数は使わない。
OffLadder? offLadder(Game g) {
  final kind = offLadderKind(g);
  if (kind == null) return null;
  return OffLadder(kind, offLadderStep(g, kind));
}

/// [kind] の梯子での段（0 から）。旗と歳だけで決める。
int offLadderStep(Game g, String kind) {
  final age = g.age;
  switch (kind) {
    case 'merchant':
      if (g.hasFlag('goyo')) return 3;
      if (_anyFlag(g, ['sp_shop_1', 'sp_shop_2', 'tf_norenwake', 'off_oodana'])) {
        return 2;
      }
      if (_anyFlag(g, ['way_merchant', 'tf_rakuichi_held'])) return 1;
      // 町人の家の者は、歳を重ねると家の店を継ぐ。
      if (g.l.cls.id == 'merchant' && age >= 30) return 1;
      return 0;
    case 'priest':
    case 'nun':
      final abbot = g.hasFlag('abbot');
      if (abbot &&
          _anyFlag(g, [
            'tm_rongi_praised',
            'tm_ko_praised',
            'tm_shuron_win',
            'tm_shiso_peace',
            'tm_retreat_peak',
          ])) {
        return 3;
      }
      if (abbot) return 2;
      if (age >= 20 || _anyPrefix(g, ['tm_'])) return 1;
      return 0;
    case 'ninja':
      if (g.hasFlag('sh_n_heir')) return 3;
      if (_anyFlag(g, [
        'sh_n_elder',
        'sh_lord_near',
        'sh_lord_far',
        'sh_lord_none',
        'sh_found_traitor',
        'sh_iga_led',
      ])) {
        return 2;
      }
      if (_anyFlag(g, [
        'sh_trust',
        'sh_ezu',
        'sh_henso_master',
        'sh_herb_med',
        'sh_herb_poison',
        'sh_saved_comrade',
      ])) {
        return 1;
      }
      return 0;
    case 'bandit':
      if (g.hasFlag('sh_band_head')) return 2;
      if (age >= 30 || _anyFlag(g, _roughFlags)) return 1;
      return 0;
    case 'wanderer':
      if (_anyFlag(g, [
        'sh_jingari_won',
        'sh_yojin_fought',
        'sh_ochi_repaid',
        'sh_band_head',
      ])) {
        return 2;
      }
      if (age >= 30 || _anyFlag(g, _roughFlags)) return 1;
      return 0;
    case 'craft':
      if (_anyFlag(g, ['cr_goyo_done', 'cr_mei_cut', 'cr_mei_sign'])) return 3;
      if (_anyFlag(g, [
        'craftsman',
        'cr_kurabe_won',
        'cr_deshi_strict',
        'cr_deshi_open',
        'cr_deshi_sent',
      ])) {
        return 2;
      }
      if (age >= 28 ||
          _anyFlag(g, [
            'cr_kurabe_yielded',
            'cr_nusumi_won',
            'cr_nusumi_ahead',
            'cr_mei_none',
            'cr_goyo_honest',
          ])) {
        return 1;
      }
      return 0;
    case 'kawara':
      if (_anyFlag(g, ['cr_niwa_master', 'cr_gei_named'])) return 2;
      if (_anyFlag(g, [
        'cr_niwa_worked',
        'cr_niwa_eye',
        'cr_gei_in',
        'cr_gei_kata',
        'cr_kawa_done',
        'cr_kawa_price',
      ])) {
        return 1;
      }
      return 0;
    case 'sea':
      if (_anyFlag(g, ['off_amimoto', 'shoya'])) return 3;
      if (_anyFlag(g, ['cr_fune_own', 'cr_fune_kumi'])) return 2;
      if (age >= 25 ||
          _anyFlag(g, ['cr_ami_kumi', 'cr_ami_alone', 'cr_ami_deal']) ||
          _anyPrefix(g, ['cr_kujira_', 'cr_enden_', 'cr_suigun_'])) {
        return 1;
      }
      return 0;
    case 'mountain':
      if (age >= 50 ||
          _anyFlag(g, ['cr_okite_kept', 'cr_okite_mercy', 'cr_okite_new', 'shoya'])) {
        return 2;
      }
      if (age >= 25 ||
          g.hasFlag('cr_kuma_slain') ||
          _anyPrefix(g, ['cr_sato_', 'cr_sumi_', 'cr_ochudo_'])) {
        return 1;
      }
      return 0;
    case 'farm':
      if (_anyFlag(g, ['shoya', 'tf_murauke'])) return 3;
      if (_anyFlag(g, ['tf_so_role', 'tf_genmen_won', 'off_kumigashira'])) {
        return 2;
      }
      if (age >= 30 || _anyFlag(g, ['sp_field_1', 'sp_genin', 'ox'])) return 1;
      return 0;
  }
  return 0;
}

// ======================================================================
// 段を上がるきっかけの岐路（村の組頭・浜の網元）。どれも一生に一度。
// ======================================================================

/// この作りで足した岐路の id（テストが使う）。
const kOffLadderSceneIds = ['ol_kumigashira', 'ol_amimoto', 'ol_oodana'];

/// 足した岐路 → それが出る暮らしと段（テストが使う）。
const kOffLadderSceneAt = <String, (String, int)>{
  'ol_kumigashira': ('farm', 1),
  'ol_amimoto': ('sea', 2),
  'ol_oodana': ('merchant', 1),
};

bool _at(Game g, String kind, int step) {
  if (!g.active) return false;
  final o = offLadder(g);
  return o != null && o.kind == kind && o.step == step;
}

List<SceneDef> buildOffLadderScenes() => [
  SceneDef(
    'ol_kumigashira',
    30,
    65,
    (g) => 2 + g.l.net / 20,
    (g) => _at(g, 'farm', 1),
    (g, next) {
      final l = g.l;
      g.ask('組頭の役', '村の寄合で、近くの家々をまとめる組頭を立て直すことになった。年寄たちが、あなたの名を挙げた。', [
        Choice.h('引き受ける', '村の顔になる。寄合と年貢の取りまとめに追われる', () {
          g.setFlag('off_kumigashira');
          l.fame += 3;
          l.net += 2;
          g.mark('寄合に推され、村の組頭を引き受けた');
          return '寄合の席が、年寄たちの隣に移った。';
        }),
        if (l.sei >= 60)
          Choice.h('引き受け、寄合の決め事を帳面に残す', '帳面の才が生きる。言った言わないの揉め事が減る', () {
            g.setFlag('off_kumigashira');
            l.fame += 5;
            l.net += 3;
            g.mark('寄合に推され、村の組頭を引き受けた');
            return '寄合のたびに、決めたことを帳面に書きつけた。年寄たちも、やがてその帳面を頼るようになった。';
          }, via: '政'),
        Choice.h('年寄に譲る', '気楽な百姓のままでいられる', () {
          g.j(1);
          return '自分にはまだ早いと、頭を下げて譲った。';
        }),
      ], after: next);
    },
  ),
  SceneDef(
    'ol_amimoto',
    35,
    70,
    (g) => 3 + g.l.net / 20,
    (g) => _at(g, 'sea', 2),
    (g, next) {
      final l = g.l;
      g.ask('網元の跡', '浜の網元が老いて、大網と網子たちを誰かに任せたいと言い出した。浜の者たちは、船を持つあなたの名を挙げている。', [
        Choice.h('網元を継ぐ', '浜を背負う。不漁の年も網子を食わせねばならない', () {
          g.setFlag('off_amimoto');
          l.fame += 5;
          l.net += 3;
          g.mark('老いた網元に代わり、浜の大網を預かった');
          return '網元の家の神棚に、あなたの名で灯明が上がった。';
        }),
        if (l.mi >= 60)
          Choice.h('網子たちと分け前を決め直して継ぐ', '人を惹きつける者の手だ。網子は懐く。網元の取り分は細る', () {
            g.setFlag('off_amimoto');
            l.fame += 4;
            l.net += 6;
            g.j(3);
            g.mark('老いた網元に代わり、浜の大網を預かった');
            return '網子を一人ずつ呼んで話を聞き、分け前を決め直した。翌朝の網引きには、いつもより声が出ていた。';
          }, via: '魅'),
        Choice.h('自分の船だけで漁を続ける', '身軽なままでいられる。浜の顔にはならない', () {
          return '網元の話は、若い者に回った。あなたは今朝も、自分の船で沖へ出た。';
        }),
      ], after: next);
    },
  ),
  SceneDef(
    'ol_oodana',
    28,
    65,
    (g) => 2.5 + g.l.gold / 80,
    (g) => _at(g, 'merchant', 1) && g.l.gold >= 40,
    (g, next) {
      final l = g.l;
      g.ask('売りに出た大店', '通りの角の大きな店が、跡継ぎのないまま売りに出た。蔵も暖簾も、得意先もそのまま譲るという。', [
        Choice.h('買い取って大店の主になる', '店の格が上がる。蓄えの大半が要る', () {
          l.gold = (l.gold * .4).floor();
          l.fame += 4;
          l.net += 2;
          g.setFlag('off_oodana');
          g.mark('角の大店を買い取り、暖簾を掛け替えた');
          return '角の店の暖簾を、自分の屋号に掛け替えた。蔵の鍵束が、ずしりと重かった。';
        }),
        if (l.sei >= 60)
          Choice.h('帳面を調べ上げ、値を掛け合って買う', '帳面の才が生きる。売り手の親類には恨まれる', () {
            l.gold = (l.gold * .6).floor();
            l.fame += 4;
            g.setFlag('off_oodana');
            g.mark('角の大店を買い取り、暖簾を掛け替えた');
            return '貸し倒れの掛けを一つずつ洗い出し、値を下げさせた。安く手に入れた店に、売り手の親類は最後まで頭を下げなかった。';
          }, via: '政'),
        Choice.h('今の店を守る', '蓄えは減らない。店は今のまま', () {
          return '角の店は、よその町の商人の手に渡った。';
        }),
      ], after: next);
    },
  ),
];
