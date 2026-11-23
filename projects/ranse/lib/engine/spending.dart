import 'childhood.dart';
import 'data.dart';
import 'game.dart';
import 'history_lines.dart';
import 'rng.dart';

/// 銭と功の使い道（2026-11-24、ユーザー「稼いだお金でできることも増やそう。功とかも」）。
///
/// - **入り口**: 大人の「今年の重点」に「蓄えを使う」（銭）と「功を願い出る」（功）を足す
///   （`adultFocusOptions` が、暮らしと嗜み・晩年・仏門・女性の重点のうしろに足す）。
///   銭は身分の段（[spTier]）ごとの目安（[kSpendGoldMin]）を越え、功は次の昇進に要る分を
///   [kMeritSpare] 以上越えたときだけ出る。使った年から [kSpendGap] 年は出ない。
///   並べられる使い道が3つに満たなければ出さない。当てはまるかは乱数を使わずに決める（テストも使う）。
/// - 選ぶとその年に岐路（`sp_spend` / `sp_boon`）が出て、身分・暮らし・持ち物でまだ持っていないもの・
///   その年の状況に合う使い道を3〜5つと「見送る」を並べる。値は出さず、蓄えに比べての重さを匂わせる。
///   使い道を決めたあとは、ふつうの年と同じく岐路を引く（`Game.usualYearScene`。ほかの岐路を押しのけない）。
/// - **銭の使い道 21**（[kSpendGoldIds]）と**功の使い道 11**（[kSpendMeritIds]）。功を使っても、
///   次の昇進に要る功を割り込まないものだけを並べる（昇進の仕組みはそのまま通す）。
/// - 持ち物は旗で持ち、合戦（`Game.battle` の倍率 [spendingRisk]・[spendingGain]）と、
///   毎年の暮らし（[spendingYear]。田・知行・店・下人・屋敷・茶器）に効き続ける。
/// - 買ったもの・賜ったものに続く岐路 8（[kSpendEchoIds]。一生に一度ずつ）。
///
/// id・旗は `sp_`。数字は選択肢に出さない。新しい `die()` は無い。

// ======================================================================
// 補助
// ======================================================================

int _c(int v) => clampInt(v, 0, 99);
int _c100(int v) => clampInt(v, 0, 100);
void _heal(Game g, int n) =>
    g.l.hp = g.l.hp + n > g.l.maxhp ? g.l.maxhp : g.l.hp + n;

/// いまの暮らしの場（`pastimes.dart` と同じ分け方）。
enum _Ctx { retired, merchant, outlaw, monk, lord, retainer, none }

_Ctx _ctx(Game g) {
  final l = g.l;
  if (g.hasFlag('retired')) return _Ctx.retired;
  if (g.hasFlag('way_merchant') && l.rank == 0) return _Ctx.merchant;
  if (g.hasFlag('way_outlaw') && l.rank == 0) return _Ctx.outlaw;
  if (g.hasFlag('priesthood')) return _Ctx.monk;
  if (l.rank >= 8) return _Ctx.lord;
  if (l.rank >= 1) return _Ctx.retainer;
  return _Ctx.none;
}

/// 主家に仕えている（主家が生きている）。
bool _serving(Game g) =>
    _ctx(g) == _Ctx.retainer &&
    g.l.lord != null &&
    (g.fa[g.l.lord]?.alive ?? false);

/// 戦える武家（主家に仕える身か一国の主）。
bool _warrior(Game g) =>
    g.canFight && (_serving(g) || _ctx(g) == _Ctx.lord);

/// 身分の段。0 貧しい（身分なし・野・仏門）／1 足軽・組頭・商人／2 馬廻・侍大将／3 城主より上・大名。
int spTier(Game g) {
  final l = g.l;
  return switch (_ctx(g)) {
    _Ctx.none || _Ctx.outlaw || _Ctx.monk => 0,
    _Ctx.merchant => 1,
    _Ctx.lord => 3,
    _Ctx.retainer => l.rank >= 5 ? 3 : (l.rank >= 3 ? 2 : 1),
    _Ctx.retired => l.maxRank >= 5 ? 3 : (l.maxRank >= 3 ? 2 : 1),
  };
}

/// 「蓄えを使う」が出る銭の目安（段ごと）。
const kSpendGoldMin = [25, 60, 150, 400];

/// 「功を願い出る」が出るのに、次の昇進に要る功より多く要る分。
const kMeritSpare = 25;

/// 使った年から、次に入り口が出るまでの年。
const kSpendGap = 2;

/// 旗 `<key>@<年>` の最新の年。
int? _atYear(Game g, String key) {
  final p = '$key@';
  int? y;
  for (final f in g.l.flags) {
    if (!f.startsWith(p)) continue;
    final v = int.tryParse(f.substring(p.length));
    if (v != null && (y == null || v > y)) y = v;
  }
  return y;
}

void _stamp(Game g, String key) {
  g.l.flags.removeWhere((f) => f.startsWith('$key@'));
  g.setFlag('$key@${g.year}');
}

/// [key] の年から何年たったか（無ければ大きな数）。
int spSince(Game g, String key) {
  final y = _atYear(g, key);
  return y == null ? 999 : g.year - y;
}

/// 段のある持ち物（田・店・知行）の段。
const _fieldLv = ['sp_field_1', 'sp_field_2', 'sp_field_3'];
const _shopLv = ['sp_shop_1', 'sp_shop_2'];
const _chigyoLv = ['sp_chigyo_1', 'sp_chigyo_2', 'sp_chigyo_3'];
int _lv(Game g, List<String> lv) => lv.where(g.hasFlag).length;
void _lvUp(Game g, List<String> lv) {
  final n = _lv(g, lv);
  if (n < lv.length) g.setFlag(lv[n]);
}

/// 次の昇進に要る功（宿老はもう上がないので宿老の目安）。
int _needMerit(Game g) {
  final r = g.l.rank;
  return kPromo[r < 7 ? r + 1 : 7]!.merit;
}

/// 次の昇進に要る功を越えている分。
int spMeritSpare(Game g) => g.l.merit - _needMerit(g);

String _house(Game g) => g.l.lord == null ? '主' : houseName(g, g.l.lord);

/// 値の重さの匂わせ（数字は出さない）。
String _costWord(int price, int have) {
  final r = have <= 0 ? 1.0 : price / have;
  if (r >= .6) return '蓄えの大半が要る';
  if (r >= .3) return '少し値が張る';
  return '蓄えからすれば軽い';
}

String _meritWord(int cost, int spare) =>
    cost >= spare * .6 ? '積んだ功の多くを差し出す' : '功を少し差し出す';

// ======================================================================
// 使い道の表
// ======================================================================

class _Use {
  const _Use(
    this.id,
    this.ok,
    this.cost,
    this.label,
    this.hint,
    this.apply, {
    this.w,
  });
  final String id;

  /// 身分・暮らし・持ち物・その年の状況に合うか（銭・功の足りる足りないは見ない。乱数を使わない）。
  final bool Function(Game g) ok;

  /// 値（銭）か、差し出す功。null ならその段では並ばない。
  final int? Function(Game g) cost;
  final String Function(Game g) label;

  /// 効き目の匂わせ（値の重さの言葉はうしろに足す）。
  final String Function(Game g) hint;

  /// 払ったあとに効かせる。見聞録の文を返す。
  final String Function(Game g) apply;

  /// 並びに選ばれやすさ（その年の状況に合うものは重く）。
  final double Function(Game g)? w;
}

int? Function(Game) _tp(List<int?> byTier) => (g) => byTier[spTier(g)];
String Function(Game) _s(String s) => (_) => s;

final _goldUses = <_Use>[
  // ------------------------------------------------------------ 持ち物
  _Use(
    'sp_horse',
    (g) =>
        !g.hasFlag('sp_horse') &&
        (_warrior(g) && g.l.rank >= 3 || _ctx(g) == _Ctx.merchant),
    _tp([null, 40, 90, 160]),
    (g) => _ctx(g) == _Ctx.merchant
        ? '荷駄の馬を買う'
        : (spTier(g) >= 3 ? '名馬を求める' : '馬を買う'),
    (g) => _ctx(g) == _Ctx.merchant
        ? '仕入れの旅が楽になり、儲けが増える'
        : '戦場を駆けられ、手柄の目が増える',
    (g) {
      g.setFlag('sp_horse');
      _stamp(g, 'sp_horse');
      if (spTier(g) >= 3 && _ctx(g) != _Ctx.merchant) {
        g.setFlag('sp_horse_fine');
        g.l.fame += 3;
        g.mark('名馬を手に入れた');
        return '脚の太い栗毛の名馬を手に入れた。厩の前に人だかりができた。';
      }
      g.j(3);
      return _ctx(g) == _Ctx.merchant
          ? '荷を負える丈夫な馬を一頭買った。'
          : 'よく走る若駒を買い、毎朝自ら手綱を取った。';
    },
  ),
  _Use(
    'sp_armor',
    (g) =>
        !g.hasFlag('sp_armor') &&
        g.canFight &&
        (_warrior(g) ||
            _ctx(g) == _Ctx.outlaw ||
            (_ctx(g) == _Ctx.none && !g.l.female && g.l.ronin)),
    _tp([30, 35, 90, 180]),
    (g) => spTier(g) >= 2 ? '名のある具足師に具足を誂えさせる' : '具足を買い揃える',
    _s('矢玉から身を守り、戦場で生き残りやすくなる'),
    (g) {
      g.setFlag('sp_armor');
      _stamp(g, 'sp_armor');
      if (spTier(g) >= 2) {
        g.setFlag('sp_armor_fine');
        g.mark('具足師に具足を誂えさせた');
        return '具足師が身の丈を測り、ひと冬かけて黒糸縅の具足を仕上げた。';
      }
      return '古手屋で胴と籠手を買い揃え、紐を自分の手で締め直した。';
    },
  ),
  _Use(
    'sp_sword',
    (g) =>
        !g.hasFlag('sp_sword') &&
        !g.l.female &&
        (_warrior(g) && spTier(g) >= 2 ||
            _ctx(g) == _Ctx.merchant ||
            _ctx(g) == _Ctx.retired && g.l.maxRank >= 3),
    _tp([null, 120, 120, 200]),
    _s('名のある刀を求める'),
    _s('腰の物に箔が付き、人の見る目が変わる。戦場でも頼れる'),
    (g) {
      g.setFlag('sp_sword');
      _stamp(g, 'sp_sword');
      g.l.fame += 4;
      g.l.mi = _c(g.l.mi + 1);
      g.mark('名のある刀を求めた');
      return '銘のある刀を求めた。抜けば、刃文が水のように揺れた。';
    },
  ),
  _Use(
    'sp_gun',
    (g) =>
        !g.l.gun &&
        g.year >= 1555 &&
        g.canFight &&
        (_warrior(g) || _ctx(g) == _Ctx.outlaw),
    _tp([45, 50, 60, 80]),
    _s('鉄砲を買い求める'),
    _s('遠くから敵を撃てる。玉薬にも銭がかかる'),
    (g) {
      g.l.gun = true;
      g.setFlag('sp_gun');
      _stamp(g, 'sp_gun');
      return '堺の鍛冶の鉄砲を一挺買い、河原で撃ち方を覚えた。';
    },
  ),
  _Use(
    'sp_chaki',
    (g) =>
        !g.hasFlag('sp_chaki') &&
        !g.hasFlag('sp_chaki_given') &&
        !g.hasFlag('ps_meibutsu') &&
        switch (_ctx(g)) {
          _Ctx.merchant || _Ctx.lord => true,
          _Ctx.retainer => !g.l.female && g.l.rank >= 3,
          _Ctx.retired => g.l.maxRank >= 3,
          _ => (g.l.focus['ps_tea'] ?? 0) > 0,
        },
    _tp([60, 70, 120, 250]),
    _s('名のある茶器を買い求める'),
    _s('茶の席で一目置かれる。欲しがる者も出る'),
    (g) {
      g.setFlag('sp_chaki');
      _stamp(g, 'sp_chaki');
      g.l.net += 3;
      g.l.fame += 3;
      g.mark('名のある茶入を買い求めた');
      return '小ぶりな茶入を求めた。肩の張りが見事だと、茶人が膝を打った。';
    },
  ),
  _Use(
    'sp_nanban',
    (g) =>
        !g.hasFlag('sp_nanban') &&
        g.year >= 1550 &&
        switch (_ctx(g)) {
          _Ctx.merchant || _Ctx.lord || _Ctx.retired => true,
          _Ctx.retainer => g.l.rank >= 3,
          _ => false,
        },
    _tp([null, 60, 100, 200]),
    _s('南蛮渡りの遠眼鏡を求める'),
    _s('珍しい品で人の目を集める。見せてくれと言う者が増える'),
    (g) {
      g.setFlag('sp_nanban');
      _stamp(g, 'sp_nanban');
      g.l.chi = _c(g.l.chi + 1);
      g.l.fame += 3;
      return '筒をのぞくと、遠い山の木の葉まで見えた。家の者が代わる代わるのぞいた。';
    },
  ),

  // ------------------------------------------------------------ 暮らし
  _Use(
    'sp_house',
    (g) =>
        !g.hasFlag('sp_house') &&
        _ctx(g) != _Ctx.monk &&
        _ctx(g) != _Ctx.outlaw &&
        !(g.l.female && _ctx(g) == _Ctx.retainer && !g.l.married),
    _tp([20, 50, 140, 350]),
    (g) => switch (spTier(g)) {
      0 || 1 => '家を建て直す',
      2 => '屋敷を構える',
      _ => _ctx(g) == _Ctx.lord ? '館を造り直す' : '屋敷を普請する',
    },
    (g) => spTier(g) >= 2
        ? '人を招ける屋敷ができる。暮らしに張りが出る'
        : '雨漏りのしない家で、暮らしが落ち着く',
    (g) {
      g.setFlag('sp_house');
      _stamp(g, 'sp_house');
      g.j(8);
      g.l.net += spTier(g) >= 2 ? 4 : 1;
      final sp = g.l.people['伴侶'];
      if (sp != null && g.l.married) sp.bond = _c100(sp.bond + 5);
      if (spTier(g) >= 2) {
        g.mark('屋敷を構えた');
        return '庭に松を植えた屋敷が建った。棟上げの日には、近所の者まで餅を拾いに来た。';
      }
      return '柱を替え、屋根を葺き直した。新しい木の匂いのする家で、よく眠れた。';
    },
  ),
  _Use(
    'sp_field',
    (g) =>
        _lv(g, _fieldLv) < _fieldLv.length &&
        (_ctx(g) == _Ctx.none && g.l.cls.id == 'farmer' ||
            _ctx(g) == _Ctx.merchant ||
            _ctx(g) == _Ctx.retired),
    (g) {
      final base = [20, 45, 90, 150][spTier(g)];
      return base + base * _lv(g, _fieldLv) ~/ 2;
    },
    (g) => _ctx(g) == _Ctx.none ? '隣の田を買い足す' : '田を買い、小作に出す',
    _s('毎年の実入りが増える。元を取るには年がかかる'),
    (g) {
      _lvUp(g, _fieldLv);
      _stamp(g, 'sp_field');
      g.j(3);
      if (_lv(g, _fieldLv) == 1) g.mark('田を買い足した');
      return _ctx(g) == _Ctx.none
          ? '隣の家が手放した田を買った。畦に立つと、胸のあたりが温かかった。'
          : '村の田を買い、小作に任せた。秋には米が届く。';
    },
  ),
  _Use(
    'sp_roto',
    (g) => !g.hasFlag('sp_roto') && _serving(g) && g.canFight && g.l.rank >= 2,
    _tp([null, 40, 100, 220]),
    _s('郎党を召し抱える'),
    _s('手勢が増え、戦場で脇を固める者ができる。扶持もかかる'),
    (g) {
      g.setFlag('sp_roto');
      _stamp(g, 'sp_roto');
      g.l.troops += [0, 5, 10, 20][spTier(g)];
      return '腕の立つ者を幾人か郎党に迎えた。屋敷の土間が急に狭くなった。';
    },
  ),
  _Use(
    'sp_genin',
    (g) =>
        !g.hasFlag('sp_genin') &&
        (_ctx(g) == _Ctx.merchant ||
            _ctx(g) == _Ctx.none &&
                const ['farmer', 'fisher', 'merchant'].contains(g.l.cls.id)),
    _tp([20, 40, null, null]),
    (g) => _ctx(g) == _Ctx.merchant ? '店に下人を置く' : '下人を置く',
    _s('働き手が増えて、体が楽になる。食わせる口も増える'),
    (g) {
      g.setFlag('sp_genin');
      _stamp(g, 'sp_genin');
      _heal(g, 10);
      return '身寄りのない若者を下人に置いた。朝の水汲みが、いつのまにか済んでいた。';
    },
  ),
  _Use(
    'sp_shop',
    (g) =>
        _lv(g, _shopLv) < _shopLv.length &&
        (_ctx(g) == _Ctx.merchant ||
            _ctx(g) == _Ctx.none && g.l.cls.id == 'merchant'),
    (g) => 80 * (_lv(g, _shopLv) + 1),
    (g) => _lv(g, _shopLv) == 0 ? '店を広げる' : '蔵を建て増す',
    _s('商いが大きくなり、毎年の儲けが増える。売れ残れば重荷になる'),
    (g) {
      _lvUp(g, _shopLv);
      _stamp(g, 'sp_shop');
      if (_lv(g, _shopLv) == 1) {
        g.mark('店を広げた');
        return '隣の店を買い取って間口を広げた。暖簾が二枚になった。';
      }
      return '裏に土蔵を建て増した。白壁が、通りからも見えた。';
    },
  ),

  // ------------------------------------------------------------ 人と家に
  _Use(
    'sp_tutor',
    (g) =>
        !g.hasFlag('sp_tutor') &&
        g.l.hasKidAged(g.year, 6, 15) &&
        _ctx(g) != _Ctx.outlaw &&
        _ctx(g) != _Ctx.monk,
    _tp([15, 30, 60, 120]),
    (g) => spTier(g) >= 2 ? '子に武芸と学問の師を付ける' : '子を学ばせる師を頼む',
    _s('子が伸びる。子との絆も深まる'),
    (g) {
      g.setFlag('sp_tutor');
      _stamp(g, 'sp_tutor');
      g.j(4);
      final k = g.l.people['子'] ?? g.l.people['娘'];
      if (k != null) k.bond = _c100(k.bond + 8);
      return spTier(g) >= 2
          ? '名の知れた師を招いた。子は朝は槍、昼は書に向かった。'
          : '寺の和尚に頼み込み、子に字と算用を教えてもらうことにした。';
    },
    w: (g) => 1.5,
  ),
  _Use(
    'sp_dowry',
    (g) =>
        !g.hasFlag('sp_dowry') &&
        g.l.kidsAtLeast(g.year, 14) >= 1 &&
        _ctx(g) != _Ctx.outlaw &&
        _ctx(g) != _Ctx.monk,
    _tp([15, 40, 100, 250]),
    _s('子の縁組の支度を調える'),
    _s('恥ずかしくない支度で送り出せる。家の顔が立つ'),
    (g) {
      g.setFlag('sp_dowry');
      _stamp(g, 'sp_dowry');
      g.l.net += 3;
      g.j(6);
      if (spTier(g) >= 2) g.l.fame += 2;
      if (_serving(g)) g.l.fav = _c100(g.l.fav + 3);
      return '長持に晴れ着と道具を詰めた。行列を見送る家の者は、皆うつむいて目を拭った。';
    },
    w: (g) => 2,
  ),
  _Use(
    'sp_medicine',
    (g) => g.l.hp < g.l.maxhp * .6,
    _tp([8, 20, 40, 80]),
    (g) => spTier(g) >= 2 ? '名医を呼ぶ' : '薬師に薬を求める',
    _s('体が持ち直す。効くかどうかは分からない'),
    (g) {
      g.setFlag('sp_medicine');
      _stamp(g, 'sp_medicine');
      _heal(g, 30 + spTier(g) * 10);
      g.j(2);
      return spTier(g) >= 2
          ? '都から下ってきた医者が脈を取り、苦い煎じ薬を置いていった。'
          : '薬師の煎じ薬を朝夕飲んだ。少しずつ床から起きられるようになった。';
    },
    w: (g) => 3,
  ),
  _Use(
    'sp_kuyo',
    (g) => !g.hasFlag('sp_kuyo') && g.age >= 35,
    _tp([8, 20, 50, 120]),
    _s('先祖と親の供養を営む'),
    _s('心が落ち着く。親類の顔もそろう'),
    (g) {
      g.setFlag('sp_kuyo');
      _stamp(g, 'sp_kuyo');
      g.j(6);
      g.l.net += 1;
      g.l.fame += 1;
      return '僧を招いて経をあげてもらった。久しく会わなかった親類も顔を見せた。';
    },
  ),

  // ------------------------------------------------------------ 上へ
  _Use(
    'sp_gift',
    (g) => _serving(g),
    _tp([null, 30, 80, 250]),
    (g) => g.l.female ? '奥方さまに品を献上する' : '主君に品を献上する',
    _s('覚えがよくなる。見返りは約束されない'),
    (g) {
      g.setFlag('sp_gift');
      _stamp(g, 'sp_gift');
      g.l.fav = _c100(g.l.fav + g.rng.range(6, 10));
      return g.l.female
          ? '京の紅と白粉を献上した。奥方さまは、目を細めて受け取った。'
          : '${_house(g)}家の主君に、鷹の羽と酒を献上した。主君は機嫌よく盃を干した。';
    },
  ),
  _Use(
    'sp_temple',
    (g) => _ctx(g) != _Ctx.outlaw,
    _tp([10, 25, 60, 200]),
    (g) => _ctx(g) == _Ctx.monk ? '寺の堂を繕う' : '寺社に寄進する',
    (g) => _ctx(g) == _Ctx.monk ? '寺の者が喜ぶ。名も少し上がる' : '名が上がり、心も晴れる',
    (g) {
      g.setFlag('sp_temple');
      _stamp(g, 'sp_temple');
      g.l.fame += 2 + spTier(g);
      g.j(3);
      if (g.rng.chance(.3)) g.l.un = _c(g.l.un + 1);
      return _ctx(g) == _Ctx.monk
          ? '傾いた堂の柱を継ぎ、屋根を葺き直した。村の者が手を合わせに来た。'
          : '寄進の札に名が書かれ、山門の脇に掲げられた。';
    },
  ),
  _Use(
    'sp_kani',
    (g) =>
        !g.hasFlag('sp_kani') &&
        !g.hasFlag('kanni') &&
        g.year <= 1600 &&
        (_ctx(g) == _Ctx.lord || _serving(g) && g.l.rank >= 5),
    _tp([null, null, null, 300]),
    _s('公家に献金して官位を願う'),
    _s('名に箔が付く。妬む者も出る'),
    (g) {
      g.setFlag('sp_kani');
      _stamp(g, 'sp_kani');
      g.l.fame += 15;
      g.j(4);
      g.mark('公家に献金し、守の名乗りを許された');
      return '都の公家に銭を送ると、ほどなく守の名乗りを許す文が届いた。';
    },
  ),
  _Use(
    'sp_bribe',
    (g) =>
        !g.hasFlag('sp_bribe') &&
        (_serving(g) && g.l.rank <= 6 ||
            _ctx(g) == _Ctx.merchant ||
            _ctx(g) == _Ctx.none && g.l.cls.id == 'farmer'),
    _tp([10, 30, 80, 150]),
    (g) => switch (_ctx(g)) {
      _Ctx.retainer => '奉行に袖の下を贈る',
      _Ctx.merchant => '役人に袖の下を贈る',
      _ => '代官に袖の下を贈る',
    },
    (g) => switch (_ctx(g)) {
      _Ctx.retainer => '話が通りやすくなる。露見すれば面目を失う',
      _Ctx.merchant => '御用の口が回ってくる。露見すれば商いが傾く',
      _ => '年貢の取り立てが緩む。露見すれば村に居づらくなる',
    },
    (g) {
      g.setFlag('sp_bribe');
      _stamp(g, 'sp_bribe');
      switch (_ctx(g)) {
        case _Ctx.retainer:
          g.l.fav = _c100(g.l.fav + 8);
          return '奉行の屋敷に菓子箱を届けた。箱の底には、銭が敷いてあった。';
        case _Ctx.merchant:
          g.l.gold += g.rng.range(20, 50);
          return '役人に銭を握らせると、城の御用の口が一つ回ってきた。';
        default:
          g.l.gold += g.rng.range(8, 16);
          return '代官の手代に銭を包んだ。その秋の取り立ては、目こぼしが多かった。';
      }
    },
  ),
  _Use(
    'sp_alms',
    (g) => _ctx(g) != _Ctx.outlaw,
    _tp([10, 20, 50, 120]),
    _s('飢えた者に粥を施す'),
    _s('人の恩は巡る。蔵は軽くなる'),
    (g) {
      g.setFlag('sp_alms');
      _stamp(g, 'sp_alms');
      g.l.net += 2;
      g.l.fame += 1;
      g.j(4);
      if (g.rng.chance(.25)) g.l.un = _c(g.l.un + 1);
      return '門の前に大釜を据えて粥を炊いた。列は夕方まで途切れなかった。';
    },
  ),
  _Use(
    'sp_robe',
    (g) => !g.hasFlag('sp_robe') && g.l.female && _ctx(g) != _Ctx.monk,
    _tp([10, 25, 60, 150]),
    _s('晴れ着と櫛を誂える'),
    _s('装いが映え、人の目が変わる。贅沢と言う者もいる'),
    (g) {
      g.setFlag('sp_robe');
      _stamp(g, 'sp_robe');
      g.l.mi = _c(g.l.mi + 2);
      g.j(6);
      if (_serving(g)) g.l.fav = _c100(g.l.fav + 2);
      return '辻が花の小袖と、蒔絵の櫛を誂えた。鏡の前で、しばらく動けなかった。';
    },
  ),
];

// ------------------------------------------------------------ 功の使い道（主家に仕える身）

const _meritCost = <String, int>{
  'sp_m_chigyo': 20,
  'sp_m_suikyo': 20,
  'sp_m_kanjo': 15,
  'sp_m_henki': 40,
  'sp_m_family': 25,
  'sp_m_roto': 20,
  'sp_m_pardon': 20,
  'sp_m_horse': 15,
  'sp_m_sword': 20,
  'sp_m_tea': 30,
  'sp_m_robe': 15,
};

int? Function(Game) _mc(String id) => (g) => _meritCost[id];

final _meritUses = <_Use>[
  _Use(
    'sp_m_chigyo',
    (g) => _lv(g, _chigyoLv) < _chigyoLv.length,
    _mc('sp_m_chigyo'),
    (g) => g.l.female ? '化粧料として田を願う' : '恩賞に知行を願う',
    _s('毎年の実入りが増える。欲深と見る者もいる'),
    (g) {
      _lvUp(g, _chigyoLv);
      _stamp(g, 'sp_m_chigyo');
      g.l.fav = _c100(g.l.fav - 1);
      if (_lv(g, _chigyoLv) == 1) g.mark('恩賞に知行を賜った');
      return g.l.female
          ? '化粧料として、村ひとつの年貢の一部を賜った。'
          : '${_house(g)}家から、川沿いの村の田を知行として賜った。';
    },
  ),
  _Use(
    'sp_m_suikyo',
    (g) => g.l.rank < 7,
    _mc('sp_m_suikyo'),
    (g) => g.l.female ? '奥での引き立てを願う' : '重臣に推挙を頼む',
    _s('覚えがよくなり、次の位が近づく。借りもできる'),
    (g) {
      g.setFlag('sp_m_suikyo');
      _stamp(g, 'sp_m_suikyo');
      g.l.fav = _c100(g.l.fav + 10 + g.rng.range(0, 4));
      return g.l.female
          ? '老女に願い出ると、奥方さまの前で名を挙げてくれた。'
          : '重臣の一人が、評定の席であなたの働きを主君に言上してくれた。';
    },
  ),
  _Use(
    'sp_m_kanjo',
    (g) =>
        !g.hasFlag('sp_m_kanjo') &&
        !g.l.female &&
        g.canFight &&
        g.hasFlag('first_battle'),
    _mc('sp_m_kanjo'),
    _s('戦の働きに感状を願う'),
    _s('武功が書き付けで残り、名が上がる'),
    (g) {
      g.setFlag('sp_m_kanjo');
      _stamp(g, 'sp_m_kanjo');
      g.l.fame += 6;
      g.l.fav = _c100(g.l.fav + 2);
      return '主君の花押の入った感状を賜った。桐の箱に納め、床の間に置いた。';
    },
  ),
  _Use(
    'sp_m_henki',
    (g) => !g.hasFlag('sp_m_henki') && !g.l.female && g.l.rank >= 3,
    _mc('sp_m_henki'),
    _s('主君に名の一字を願う'),
    _s('主君の名を戴き、家中で重んじられる。背負うものも重くなる'),
    (g) {
      g.setFlag('sp_m_henki');
      _stamp(g, 'sp_m_henki');
      g.l.fame += 10;
      g.l.fav = _c100(g.l.fav + 4);
      g.mark('主君から名の一字を賜った');
      return '主君の名の一字を賜り、名乗りを改めた。家中の者の呼び方が変わった。';
    },
  ),
  _Use(
    'sp_m_family',
    (g) =>
        !g.hasFlag('sp_m_family') &&
        (g.l.kidsAtLeast(g.year, 15) >= 1 || g.l.married),
    _mc('sp_m_family'),
    _s('身内の取り立てを願う'),
    _s('身内が家中に職を得る。家が安らぐ'),
    (g) {
      g.setFlag('sp_m_family');
      _stamp(g, 'sp_m_family');
      g.j(8);
      g.l.net += 2;
      final sp = g.l.people['伴侶'];
      if (sp != null && g.l.married) sp.bond = _c100(sp.bond + 5);
      return g.l.kidsAtLeast(g.year, 15) >= 1
          ? '子が${_house(g)}家の小姓に取り立てられた。初めて出仕する朝、門まで見送った。'
          : '連れ合いの弟が、${_house(g)}家の台所方に職を得た。';
    },
  ),
  _Use(
    'sp_m_roto',
    (g) =>
        !g.hasFlag('sp_m_roto') && g.canFight && g.l.troops >= 5,
    _mc('sp_m_roto'),
    _s('郎党の取り立てを願う'),
    _s('手勢が増え、配下の者の励みになる'),
    (g) {
      g.setFlag('sp_m_roto');
      _stamp(g, 'sp_m_roto');
      g.l.troops += 3 + g.l.rank * 2;
      g.l.fav = _c100(g.l.fav + 2);
      return '配下の者に扶持が付いた。皆、前にも増して槍を磨くようになった。';
    },
  ),
  _Use(
    'sp_m_pardon',
    (g) => g.l.fav < 35,
    _mc('sp_m_pardon'),
    _s('先の不始末の赦しを請う'),
    _s('主君の機嫌が直る。積んだ働きと引き換えになる'),
    (g) {
      g.setFlag('sp_m_pardon');
      _stamp(g, 'sp_m_pardon');
      g.l.fav = _c100(g.l.fav + 15);
      return '頭を下げ、これまでの働きに免じて赦しを請うた。主君は黙ってうなずいた。';
    },
    w: (g) => 2.5,
  ),
  _Use(
    'sp_m_horse',
    (g) => !g.hasFlag('sp_horse') && g.canFight && g.l.rank >= 3,
    _mc('sp_m_horse'),
    _s('主君の厩の馬を拝領する'),
    _s('戦場を駆けられ、手柄の目が増える'),
    (g) {
      g.setFlag('sp_horse');
      g.setFlag('sp_horse_gift');
      _stamp(g, 'sp_horse');
      _stamp(g, 'sp_m_horse');
      return '主君の厩から、葦毛の馬を一頭賜った。';
    },
  ),
  _Use(
    'sp_m_sword',
    (g) => !g.hasFlag('sp_sword') && !g.l.female && g.l.rank >= 3,
    _mc('sp_m_sword'),
    _s('主君の刀を拝領する'),
    _s('拝領の刀は家の誉れになる'),
    (g) {
      g.setFlag('sp_sword');
      g.setFlag('sp_sword_gift');
      _stamp(g, 'sp_sword');
      _stamp(g, 'sp_m_sword');
      g.l.fame += 3;
      return '主君の差料を一振り賜った。抜かずに、拝んでから納めた。';
    },
  ),
  _Use(
    'sp_m_tea',
    (g) => !g.hasFlag('sp_m_tea') && !g.l.female && g.l.rank >= 4,
    _mc('sp_m_tea'),
    _s('茶の湯の許しを願う'),
    _s('茶会を開ける身になり、人が集まる'),
    (g) {
      g.setFlag('sp_m_tea');
      _stamp(g, 'sp_m_tea');
      g.l.fame += 6;
      g.l.net += 3;
      return '茶会を開くことを許された。最初の席には、同輩が競って来た。';
    },
  ),
  _Use(
    'sp_m_robe',
    (g) => !g.hasFlag('sp_m_robe') && g.l.female,
    _mc('sp_m_robe'),
    _s('奥方さまの小袖を拝領する'),
    _s('奥で重んじられ、心も弾む'),
    (g) {
      g.setFlag('sp_m_robe');
      _stamp(g, 'sp_m_robe');
      g.l.fame += 2;
      g.j(5);
      g.l.fav = _c100(g.l.fav + 2);
      return '奥方さまの着古しの小袖を賜った。袖を通すと、香の匂いがした。';
    },
  ),
];

/// 銭の使い道の id。
final kSpendGoldIds = [for (final u in _goldUses) u.id];

/// 功の使い道の id。
final kSpendMeritIds = [for (final u in _meritUses) u.id];

// ======================================================================
// 入り口
// ======================================================================

/// いま並べられる銭の使い道（身分・持ち物・状況に合い、銭で買えるもの。乱数を使わない）。
List<String> spendGoldIds(Game g) {
  final have = g.l.gold;
  return [
    for (final u in _goldUses)
      if (u.ok(g) && (u.cost(g) ?? 1 << 30) <= have) u.id,
  ];
}

/// 功を願い出られる身（主家に仕える、隠居でない身）。
bool _meritCtx(Game g) =>
    _serving(g) && g.l.rank >= 1 && g.l.rank <= 7 && g.active;

/// いま並べられる功の使い道（次の昇進に要る功を割り込まないもの。乱数を使わない）。
List<String> spendMeritIds(Game g) {
  if (!_meritCtx(g)) return const [];
  final spare = spMeritSpare(g);
  return [
    for (final u in _meritUses)
      if (u.ok(g) && (u.cost(g) ?? 1 << 30) <= spare) u.id,
  ];
}

/// 「蓄えを使う」が出るか。
bool spendGoldReady(Game g) =>
    g.l.gold >= kSpendGoldMin[spTier(g)] &&
    spSince(g, 'sp_gold') >= kSpendGap &&
    spendGoldIds(g).length >= 3;

/// 「功を願い出る」が出るか。
bool spendMeritReady(Game g) =>
    _meritCtx(g) &&
    spMeritSpare(g) >= kMeritSpare &&
    spSince(g, 'sp_merit') >= kSpendGap &&
    spendMeritIds(g).length >= 3;

/// 入り口を出すか（足す前と比べるテスト用の切り替え。ゲームではいつも真）。
bool spendingEnabled = true;

/// 使い道の名（テストが、並んだ選択肢と持ち物を突き合わせるのに使う）。
String spendLabel(Game g, String id) =>
    [..._goldUses, ..._meritUses].firstWhere((u) => u.id == id).label(g);

/// 大人の「今年の重点」に足す、銭と功の使い道の入り口。
List<FocusDef> spendingFocusOptions(Game g) => [
  if (spendingEnabled && spendGoldReady(g))
    FocusDef(
      'sp_gold',
      '蓄えを使う',
      '貯めた銭の使い道を考える。蔵は軽くなる',
      (g) {},
      forced: 'sp_spend',
    ),
  if (spendingEnabled && spendMeritReady(g))
    FocusDef(
      'sp_merit',
      g.l.female ? '働きに見合う恩賞を願い出る' : '功を願い出る',
      '積んだ功に見合う恩賞を願う。功は減る',
      (g) {},
      forced: 'sp_boon',
    ),
];

/// 並べる使い道を、重みをつけて [n] まで選ぶ（並びの順は表のまま）。
List<_Use> _sample(Game g, List<_Use> cand, int n) {
  if (cand.length <= n) return cand;
  final pool = [...cand];
  final keep = <_Use>{};
  while (keep.length < n) {
    final u = g.rng.wpick(pool, (e) => e.w?.call(g) ?? 1);
    keep.add(u);
    pool.remove(u);
  }
  return [
    for (final u in cand)
      if (keep.contains(u)) u,
  ];
}

// ======================================================================
// 合戦と毎年の暮らしに効く
// ======================================================================

/// 合戦の討死の危うさに掛ける倍率（具足・馬・郎党）。持ち物がなければ 1。
double spendingRisk(Game g) {
  var r = 1.0;
  if (g.hasFlag('sp_armor')) r *= g.hasFlag('sp_armor_fine') ? .7 : .78;
  if (g.hasFlag('sp_horse')) r *= .95;
  if (g.hasFlag('sp_roto')) r *= .95;
  return r;
}

/// 合戦の手柄に掛ける倍率（馬・刀）。持ち物がなければ 1。
double spendingGain(Game g) {
  var m = 1.0;
  if (g.hasFlag('sp_horse')) m *= g.hasFlag('sp_horse_fine') ? 1.15 : 1.1;
  if (g.hasFlag('sp_sword')) m *= 1.08;
  return m;
}

/// 毎年の暮らしに効く持ち物（大人の年の終わりに一度）。
void spendingYear(Game g) {
  final l = g.l;
  final ctx = _ctx(g);
  final field = _lv(g, _fieldLv);
  if (field > 0) l.gold += field * (ctx == _Ctx.none ? 3 : 4);
  final chigyo = _lv(g, _chigyoLv);
  if (chigyo > 0 && l.rank >= 1 && l.rank < 8) {
    l.gold += chigyo * (3 + l.rank * 2);
  }
  if (ctx == _Ctx.merchant || ctx == _Ctx.none && l.cls.id == 'merchant') {
    final shop = _lv(g, _shopLv);
    if (shop > 0) l.gold += shop * 6 + l.sei ~/ 20;
    if (g.hasFlag('sp_chaki')) l.gold += 3;
    if (g.hasFlag('sp_horse')) l.gold += 2;
  }
  if (g.hasFlag('sp_genin')) {
    _heal(g, 3);
    l.gold += 1;
  }
  if (g.hasFlag('sp_house') && l.joy < 70) g.j(1);
  if (g.hasFlag('sp_chaki') && g.rng.chance(.15)) l.net += 1;
}

/// 人物のタブに出す持ち物（名・一言）。鉄砲は画面が別に出す。
List<(String, String)> spendingBelongings(Game g) {
  final out = <(String, String)>[];
  if (g.hasFlag('sp_horse')) {
    out.add(
      g.hasFlag('sp_horse_fine')
          ? ('名馬', '脚の太い栗毛。合戦で手柄を立てやすい')
          : (g.hasFlag('sp_horse_gift') ? ('拝領の馬', '主君の厩の葦毛。合戦で手柄を立てやすい') : ('馬', '合戦や旅で頼れる')),
    );
  }
  if (g.hasFlag('sp_armor')) {
    out.add(
      g.hasFlag('sp_armor_fine')
          ? ('誂えの具足', '身の丈に合わせた具足。討死しにくい')
          : ('具足', '戦場で身を守る'),
    );
  }
  if (g.hasFlag('sp_sword')) {
    out.add(
      g.hasFlag('sp_sword_gift') ? ('拝領の刀', '家の誉れ') : ('名のある刀', '腰の物に箔が付く'),
    );
  }
  if (g.hasFlag('sp_chaki')) out.add(('名のある茶入', '茶の席で一目置かれる'));
  if (g.hasFlag('sp_nanban')) out.add(('遠眼鏡', '南蛮渡りの珍しい品'));
  if (g.hasFlag('sp_house')) out.add(('建てた家', '暮らしが落ち着く'));
  if (_lv(g, _fieldLv) > 0) out.add(('買い足した田', '毎年の実入りになる'));
  if (_lv(g, _chigyoLv) > 0) out.add(('知行', '恩賞の田。毎年の実入りになる'));
  if (_lv(g, _shopLv) > 0) out.add(('広げた店', '毎年の儲けが増える'));
  if (g.hasFlag('sp_kani')) out.add(('官位', '守の名乗り'));
  return out;
}

// ======================================================================
// 岐路
// ======================================================================

/// 買ったもの・賜ったものに続く岐路の id。
const kSpendEchoIds = [
  'sp_e_horse',
  'sp_e_chaki',
  'sp_e_kani',
  'sp_e_bribe',
  'sp_e_armor',
  'sp_e_nanban',
  'sp_e_house',
  'sp_e_henki',
];

/// 続きの岐路が出てよい人と、前の段からの間（年）。
const kSpendEchoGap = <String, (String, int)>{
  'sp_e_horse': ('sp_horse', 2),
  'sp_e_chaki': ('sp_chaki', 2),
  'sp_e_kani': ('sp_kani', 1),
  'sp_e_bribe': ('sp_bribe', 2),
  'sp_e_armor': ('sp_armor', 1),
  'sp_e_nanban': ('sp_nanban', 2),
  'sp_e_house': ('sp_house', 2),
  'sp_e_henki': ('sp_m_henki', 2),
};

bool _echoReady(Game g, String id) {
  final (flag, gap) = kSpendEchoGap[id]!;
  return g.hasFlag(flag) && spSince(g, flag) >= gap;
}

SceneDef _echo(
  String id,
  bool Function(Game g) who,
  void Function(Game g, void Function() next) run,
) => SceneDef(
  id,
  16,
  90,
  (g) => 6,
  (g) => _echoReady(g, id) && who(g),
  run,
);

List<SceneDef> buildSpendingScenes() => [
  // ------------------------------------------------------------ 蓄えを使う
  SceneDef(
    'sp_spend',
    15,
    100,
    (g) => 1,
    (g) => spendGoldIds(g).isNotEmpty,
    (g, next) {
      _stamp(g, 'sp_gold');
      final have = g.l.gold;
      final cand = [
        for (final u in _goldUses)
          if (u.ok(g) && (u.cost(g) ?? 1 << 30) <= have) u,
      ];
      final shown = _sample(g, cand, g.rng.range(3, 5));
      final head = switch (spTier(g)) {
        0 => '壺の底に貯めてきた銭を、膝の上で数えた。',
        1 => '銭箱の重みが、思いのほか増えていた。',
        2 => '蔵の銭が、ひと財産と呼べるほどになった。',
        _ => '勘定方が、蔵の銭が溢れそうだと言ってきた。',
      };
      g.ask('蓄えの使い道', '$head何に使う？', [
        for (final u in shown)
          Choice.h(u.label(g), '${u.hint(g)}。${_costWord(u.cost(g)!, have)}', () {
            final price = u.cost(g)!;
            g.l.gold -= price;
            return u.apply(g);
          }),
        Choice.h('今年は使わずにおく', '蓄えはそのまま残る', () {
          return '銭箱の蓋を閉め、そのまましまっておいた。';
        }),
      ], after: () => _thenUsual(g, next));
    },
    repeat: true,
    onlyForced: true,
  ),

  // ------------------------------------------------------------ 功を願い出る
  SceneDef(
    'sp_boon',
    15,
    100,
    (g) => 1,
    (g) => spendMeritIds(g).isNotEmpty,
    (g, next) {
      _stamp(g, 'sp_merit');
      final spare = spMeritSpare(g);
      final cand = [
        for (final u in _meritUses)
          if (u.ok(g) && (u.cost(g) ?? 1 << 30) <= spare) u,
      ];
      final shown = _sample(g, cand, g.rng.range(3, 5));
      final text = g.l.female
          ? '奥での働きが積もり、老女から「望みがあれば申してみよ」と言われた。'
          : '${_house(g)}家の主君から「これまでの働きに報いたい。望みを申せ」と言われた。';
      g.ask('恩賞の願い', '$text何を願う？', [
        for (final u in shown)
          Choice.h(u.label(g), '${u.hint(g)}。${_meritWord(u.cost(g)!, spare)}', () {
            g.l.merit -= u.cost(g)!;
            return u.apply(g);
          }),
        Choice.h('何も願わずに下がる', '功はそのまま残る。欲のない者と見られる', () {
          g.l.fav = _c100(g.l.fav + 1);
          return '「働きは務めのうち」と答え、何も願わずに下がった。';
        }),
      ], after: () => _thenUsual(g, next));
    },
    repeat: true,
    onlyForced: true,
  ),

  // ------------------------------------------------------------ 名馬が盗まれる
  _echo('sp_e_horse', (g) => g.active, (g, next) {
    final fine = g.hasFlag('sp_horse_fine');
    g.ask('馬盗人', '夜明け前、厩が空になっていた。${fine ? '自慢の名馬' : '馬'}が盗まれたらしい。泥に蹄の跡が残っている。', [
      if (g.canFight)
        Choice.h('跡を追う', '取り戻せるかもしれない。盗人は刃物を持っている', () {
          if (g.rng.chance(.45 + g.l.bu / 300)) {
            g.setFlag('sp_horse_back');
            g.l.fame += 2;
            return '峠の手前で盗人に追いついた。盗人は馬を捨てて藪に逃げ込んだ。';
          }
          g.l.hp -= g.rng.range(5, 12);
          _loseHorse(g);
          return '盗人ともみ合い、腕を切られた。馬は戻らなかった。';
        }),
      Choice.h('馬喰に頼んで探させる', '銭はかかる。顔の広い馬喰なら見つけ出す', () {
        if (g.l.gold >= 10) g.l.gold -= 10;
        if (g.rng.chance(.55 + g.l.net / 200)) {
          g.setFlag('sp_horse_back');
          return '十日ほどして、隣国の馬市に出ていたのを馬喰が見つけて連れ戻した。';
        }
        _loseHorse(g);
        return '馬喰は方々を探したが、馬の行方は知れなかった。';
      }),
      Choice.h('諦める', '何も起きない。厩が寂しくなる', () {
        _loseHorse(g);
        g.j(-4);
        return '空になった厩に、飼い葉だけが残った。';
      }),
    ], after: next);
  }),

  // ------------------------------------------------------------ 茶器を所望される
  _echo('sp_e_chaki', (g) => g.active, (g, next) {
    // 大名には隣国の大名、仕える身には主君、ほかの人には町を治める奉行が所望する。
    final lord = g.l.rank >= 8;
    final serving = _serving(g);
    final who = lord
        ? '隣国の大名'
        : (serving ? '${_house(g)}家の主君' : '町を治める奉行');
    g.ask('茶入の所望', '$whoが、あなたの茶入を見たいと言ってきた。使いの口ぶりでは、見るだけでは済みそうにない。', [
      Choice.h('差し出す', '惜しいが、覚えはめでたくなる', () {
        g.l.flags.remove('sp_chaki');
        g.setFlag('sp_chaki_given');
        if (lord) {
          g.l.fame += 3;
          final f = g.fa[g.l.lord];
          if (f != null) f.power += 1;
          return '茶入を贈ると、隣国の大名から丁重な礼状と和を結ぶ文が届いた。';
        }
        g.j(-3);
        if (serving) {
          g.l.fav = _c100(g.l.fav + 12);
          return '茶入を差し出した。主君は掌で転がし、満足げにうなずいた。';
        }
        g.l.gold += g.rng.range(20, 40);
        g.l.net += 2;
        return '茶入を差し出した。奉行は礼にと、城の御用の口を回してくれた。';
      }),
      Choice.h('丁重に断る', '茶入は手元に残る。相手の機嫌は損ねる', () {
        g.setFlag('sp_chaki_kept');
        if (lord) {
          g.l.fame += 1;
          return '「家の宝ゆえ」と断った。隣国の使いは、黙って帰っていった。';
        }
        if (serving) {
          g.l.fav = _c100(g.l.fav - 10);
          return '「先祖の形見ゆえ」と断った。主君はしばらく口をきいてくれなかった。';
        }
        g.l.gold = (g.l.gold * .9).floor();
        return '「家の宝ゆえ」と断った。その年は、なにかと運上の取り立てが厳しかった。';
      }),
      Choice.h('写しを作らせて差し出す', '知恵がいる。見抜かれれば面目を失う', () {
        if (g.rng.chance(.35 + g.l.chi / 250)) {
          g.setFlag('sp_chaki_kept');
          if (serving) g.l.fav = _c100(g.l.fav + 5);
          return '焼き物師に写しを作らせて贈った。相手は気づかず、喜んで受け取った。';
        }
        g.l.flags.remove('sp_chaki');
        g.setFlag('sp_chaki_given');
        if (serving) g.l.fav = _c100(g.l.fav - 12);
        g.l.fame -= 3;
        return '写しは茶人に見抜かれた。本物も差し出すことになり、面目も失った。';
      }),
    ], after: next);
  }),

  // ------------------------------------------------------------ 官位を妬まれる
  _echo('sp_e_kani', (g) => g.active, (g, next) {
    final lord = g.l.rank >= 8;
    final text = lord
        ? '隣国から「銭で買った守の名乗り」と嘲る落首が届いた。家中にも、それを口ずさむ者がいるという。'
        : '同輩のあいだで「銭で守を買った」という陰口が立っている。主君の耳にも入ったらしい。';
    g.ask('妬み', text, [
      Choice.h('名乗りにふさわしい働きで黙らせる', '時がかかる。働きが続けば陰口は止む', () {
        g.setFlag('sp_kani_proved');
        if (lord) {
          final f = g.fa[g.l.lord];
          if (f != null) f.power += 1;
        } else {
          g.l.merit += g.rng.range(3, 6);
        }
        g.l.hp -= 4;
        return '朝から晩まで務めに励んだ。年が改まる頃には、陰口は聞こえなくなった。';
      }),
      Choice.h(lord ? '家中に酒と肴を振る舞う' : '同輩に酒と肴を振る舞う', '銭はかかる。口はふさがる', () {
        g.l.gold = g.l.gold >= 20 ? g.l.gold - 20 : 0;
        g.l.net += 2;
        return '酒宴を開いた。酔いが回ると、陰口を言っていた者が真っ先に肩を組んできた。';
      }),
      Choice.h('取り合わない', '何も変わらない。陰口は残る', () {
        if (!lord) g.l.fav = _c100(g.l.fav - 4);
        g.j(-3);
        return '聞こえないふりをした。陰口は、しばらく消えなかった。';
      }),
    ], after: next);
  }),

  // ------------------------------------------------------------ 袖の下の露見
  _echo('sp_e_bribe', (g) => g.active, (g, next) {
    final m = _ctx(g);
    final who = switch (m) {
      _Ctx.retainer => '袖の下を受け取っていた奉行が、別の件で詮議を受けている。',
      _Ctx.merchant => '銭を握らせた役人が罷免され、帳面が調べられている。',
      _ => '目こぼしをしていた代官の手代が捕らえられた。',
    };
    g.ask('袖の下', '$whoあなたの名が出るのも時間の問題だ。', [
      Choice.h('自ら申し出る', '面目は失う。隠すよりは軽く済む', () {
        g.setFlag('sp_bribe_confessed');
        g.l.fame -= 3;
        if (m == _Ctx.retainer) g.l.fav = _c100(g.l.fav - 8);
        if (m != _Ctx.retainer) g.l.gold = (g.l.gold * .8).floor();
        return '自ら出向いて頭を下げた。叱りは受けたが、それ以上の咎めはなかった。';
      }),
      Choice.h('知らぬ存ぜぬで通す', '名が出なければ済む。出れば重く咎められる', () {
        if (g.rng.chance(.55 + g.l.un / 300)) {
          return '詮議は奉行ひとりの罪で幕が引かれた。胸をなでおろした。';
        }
        g.setFlag('sp_bribe_caught');
        g.l.fame -= 8;
        if (m == _Ctx.retainer) {
          g.l.fav = _c100(g.l.fav - 25);
        } else {
          g.l.gold = (g.l.gold * .5).floor();
        }
        g.j(-8);
        return '帳面にあなたの名が残っていた。厳しく咎められ、面目を失った。';
      }),
      Choice.h('口止めの銭を重ねる', '銭はかかる。口は一つ閉じるが、弱みも一つ増える', () {
        g.l.gold = (g.l.gold * .7).floor();
        if (g.rng.chance(.7)) {
          return '銭を包んで回った。あなたの名は、どこにも出なかった。';
        }
        g.setFlag('sp_bribe_caught');
        g.l.fame -= 6;
        if (m == _Ctx.retainer) g.l.fav = _c100(g.l.fav - 20);
        return '口止めの銭まで露見した。二重の恥をかいた。';
      }),
    ], after: next);
  }),

  // ------------------------------------------------------------ 具足に救われる
  _echo(
    'sp_e_armor',
    (g) => g.active && g.canFight && g.l.rank >= 1 && g.hasFlag('first_battle'),
    (g, next) {
      g.ask('具足', '先の戦の傷を手入れしていると、具足の胸板に矢の跡が深く残っていた。あと少しで、胸まで通っていた。', [
        Choice.h('具足師に礼を届ける', '人の縁が深まる。次の戦にも心強い', () {
          g.setFlag('sp_armor_saved');
          g.l.gold = g.l.gold >= 5 ? g.l.gold - 5 : 0;
          g.l.net += 2;
          return '具足師に酒を届けた。具足師は矢の跡を撫で、黙って縅を締め直してくれた。';
        }),
        Choice.h('矢を抜いて守りにする', '心が落ち着く。験を担ぐ者には頼もしい', () {
          g.setFlag('sp_armor_saved');
          g.j(4);
          g.l.un = _c(g.l.un + 1);
          return '鏃を抜き、小さな袋に入れて守りにした。';
        }),
        Choice.h('傷は気にせず次の戦に備える', '何も変わらない。肝が据わる', () {
          g.l.bu = _c(g.l.bu + 1);
          return '胸板を叩いて、そのまま次の戦の支度にかかった。';
        }),
      ], after: next);
    },
  ),

  // ------------------------------------------------------------ 南蛮の品を見せてくれ
  _echo('sp_e_nanban', (g) => g.active, (g, next) {
    final lord = g.l.rank >= 8;
    final who = lord ? '堺の豪商' : (g.l.rank >= 1 ? '${_house(g)}家の主君' : '町の年寄');
    g.ask('遠眼鏡', '$whoが、南蛮渡りの遠眼鏡の噂を聞きつけて、ぜひ見せてほしいと訪ねてきた。', [
      Choice.h('見せて、のぞかせる', '人の輪が広がる。欲しがられるかもしれない', () {
        g.l.net += 3;
        if (g.rng.chance(.4)) {
          g.l.flags.remove('sp_nanban');
          g.setFlag('sp_nanban_given');
          if (g.l.rank >= 1 && g.l.rank < 8) g.l.fav = _c100(g.l.fav + 8);
          g.l.fame += 2;
          return 'のぞいた相手は手放そうとせず、結局そのまま譲ることになった。';
        }
        return '代わる代わる筒をのぞき、遠い城の旗まで見えると皆で大笑いした。';
      }),
      Choice.h('高値で譲る', '銭が戻る。珍しい品は手元を離れる', () {
        g.l.flags.remove('sp_nanban');
        g.setFlag('sp_nanban_sold');
        g.l.gold += g.rng.range(80, 140);
        return '買った値の倍近くで譲った。';
      }),
      Choice.h('壊れていると言って断る', '何も変わらない。噂はいずれ知れる', () {
        if (g.rng.chance(.3)) {
          g.l.fame -= 2;
          return '嘘はすぐに知れ、けちな者だと噂された。';
        }
        return '残念がる相手を見送り、遠眼鏡を箱にしまい直した。';
      }),
    ], after: next);
  }),

  // ------------------------------------------------------------ 建てた家の客
  _echo('sp_e_house', (g) => g.active, (g, next) {
    final os = g.l.people['幼なじみ']?.name;
    final who = os != null ? '幼なじみの$os' : '昔の知り合い';
    g.ask('客', '$whoが、建てたばかりの家を訪ねてきた。暮らしに行き詰まり、しばらく置いてほしいという。', [
      Choice.h('離れに住まわせる', '人の情は返ってくる。食い扶持は増える', () {
        g.setFlag('sp_house_shelter');
        g.l.gold = g.l.gold >= 10 ? g.l.gold - 10 : 0;
        g.l.net += 3;
        final p = g.l.people['幼なじみ'];
        if (p != null) p.bond = _c100(p.bond + 10);
        g.j(3);
        return '離れを片づけて住まわせた。ひと冬が過ぎる頃、$whoは働き口を見つけて出ていった。';
      }),
      Choice.h('銭を持たせて送り出す', '角は立たない。縁は薄くなる', () {
        g.l.gold = g.l.gold >= 6 ? g.l.gold - 6 : 0;
        return '旅の銭を包んで持たせた。$whoは何度も頭を下げて去った。';
      }),
      Choice.h('断る', '何も変わらない。後味は悪い', () {
        g.j(-4);
        final p = g.l.people['幼なじみ'];
        if (p != null) p.bond = _c100(p.bond - 10);
        return '門の前で断った。$whoの背中が、やけに小さく見えた。';
      }),
    ], after: next);
  }),

  // ------------------------------------------------------------ 偏諱の重み
  _echo(
    'sp_e_henki',
    (g) =>
        g.active &&
        g.l.rank >= 1 &&
        g.l.rank < 8 &&
        g.l.lord != null &&
        (g.fa[g.l.lord]?.alive ?? false),
    (g, next) {
      g.ask('名の一字', '主君の一字を戴いた者として、家中の若い者の揉め事を裁くよう命じられた。片方は重臣の子、もう片方は足軽の子だ。', [
        Choice.h('理のあるほうに付く', '名に恥じない。重臣には睨まれる', () {
          g.setFlag('sp_henki_fair');
          g.l.fame += 3;
          g.l.fav = _c100(g.l.fav + 3);
          return '足軽の子に理があると裁いた。主君は「名を与えた甲斐があった」と言った。';
        }),
        Choice.h('重臣の子の顔を立てる', '家中は丸く収まる。名に傷がつく', () {
          g.l.net += 2;
          g.l.fame -= 2;
          return '重臣の子の顔を立てて収めた。足軽の子は、黙って頭を下げた。';
        }),
        Choice.h('両方を叱って痛み分けにする', '角は立たない。誰も満足しない', () {
          g.l.fav = _c100(g.l.fav + 1);
          return '二人を並べて叱りつけ、喧嘩両成敗とした。';
        }),
      ], after: next);
    },
  ),
];

/// 使い道を決めたあとは、ふつうの年と同じく岐路を引く（使い道の岐路が、その年のほかの岐路を押しのけない）。
void _thenUsual(Game g, void Function() next) =>
    g.l.dead != null ? next() : g.usualYearScene();

void _loseHorse(Game g) {
  g.l.flags
    ..remove('sp_horse')
    ..remove('sp_horse_fine')
    ..remove('sp_horse_gift');
  g.setFlag('sp_horse_lost');
}
