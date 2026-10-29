// 試合の試作で使うデータ（能力・特性・性格・役割・チーム）。見せ方には依存しない。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});

  // 能力（決定40）。フィールド29・GK8。1〜20
  YA.AB_TECH = ['ファーストタッチ', 'パス', 'ドリブル', 'フィニッシュ', 'ロングシュート', 'クロス', 'ヘディング', 'タックル', 'マーク', 'テクニック', 'プレースキック', 'PK', '逆足の精度'];
  YA.AB_MENTAL = ['予測', '判断', '視野', 'ポジショニング', 'オフザボール', 'チームワーク', '運動量', '集中', '冷静さ'];
  YA.AB_PHYS = ['加速', 'スピード', '敏しょう性', 'バランス', 'ジャンプ', 'スタミナ', '強さ'];
  YA.AB_GK = ['ハンドリング', '反応', '1対1', '飛び出し', '空中戦', 'エリアの支配', 'コーチング', '配球'];
  YA.AB_FIELD = YA.AB_TECH.concat(YA.AB_MENTAL, YA.AB_PHYS);

  // 特性（決定41）42個。グループ別
  YA.TRAIT_GROUPS = {
    攻撃: ['裏への抜け出し', 'カットイン', '縦への突破', 'ワンツー', 'スルーパス', 'アーリークロス', '巻いて流し込むシュート', 'ループシュート', '弾丸ミドル', 'ポストプレー', 'ひらめき', '背負ってからのターン', 'ニアへの飛び込み', 'こぼれ球への嗅覚', 'ヘディングシュート', '下がって受ける', 'ボールを運ぶ', 'サイドチェンジ', 'オーバーラップ', 'タメを作る'],
    守備: ['前線からの守備', '読みのインターセプト', 'スライディング', '1対1の粘り', '空中戦の競り', 'カバーリング', 'ボール奪取', 'ラインコントロール', 'シュートブロック', '即時奪回'],
    セットプレー: ['ロングスロー', '直接FK', '曲がるCK'],
    駆け引きと声: ['ファウルをもらう', '声で味方を動かす', '試合を落ち着かせる'],
    GK: ['前に出るGK', 'PKストップ', 'パンチング', '速い配球', '足元のうまいGK', 'クロスへの強さ'],
  };
  YA.TRAITS = [].concat(...Object.values(YA.TRAIT_GROUPS));

  // 性格（決定42）。8グループから1つずつ。先頭が「ふつう」
  YA.PERS_GROUPS = {
    気持ちの強さ: ['ふつう', '負けず嫌い', '粘り強い', '楽天家', '繊細', '完璧主義'],
    感情の波: ['ふつう', '気分屋', '安定型', '短気'],
    大舞台: ['ふつう', '大舞台に強い', '目立ちたがり', 'プレッシャーに弱い', '慎重'],
    人との関わり: ['ふつう', 'リーダー気質', '世話好き', '仲間思い', 'お調子者', '一匹狼', '人見知り', '寡黙'],
    教えの受け止め方: ['ふつう', '素直', '頑固', 'マイペース', '構ってほしい', '反骨心'],
    練習への向き合い: ['ふつう', '真面目', '勉強家', '練習嫌い'],
    目指すもの: ['ふつう', '野心家', 'クラブ愛', '家族思い', '寂しがり'],
    プレーの気質: ['ふつう', '闘争的', '勇敢', '献身的', 'ずる賢い', '自信家'],
  };

  // 試合に出る性格の効き（画面の説明にも使う）
  YA.PERS_NOTE = {
    大舞台に強い: '終盤の競った場面で力が上がる',
    プレッシャーに弱い: '終盤の競った場面で力が落ちる',
    負けず嫌い: 'リードされていると力が上がる',
    粘り強い: '疲れても落ちにくい',
    繊細: '自信が低いと力が落ち、叱られるのが苦手',
    短気: 'ファウルと警告が増える',
    気分屋: '試合ごとに調子が大きく振れる',
    勇敢: 'ドリブルと1対1に踏み込む',
    闘争的: '競り合いと奪い合いに強い',
    自信家: '自信が高いとシュートが決まりやすい',
    ずる賢い: 'ファウルをもらいやすい',
    献身的: '守備に走り、味方を助ける',
    リーダー気質: 'いるだけで周りの力が少し上がる',
    頑固: '指示を聞き流すことがある',
    素直: '指示をそのまま実行する',
    マイペース: '指示を聞き流すことがある',
    反骨心: '叱られると奮起する',
    構ってほしい: '褒められると伸びる',
    目立ちたがり: '見せ場でシュートを選ぶ',
    慎重: '大事な場面で無理をしない',
  };

  // ---------- ポジション15個（決定81）と、ポジションごとの役割（決定37・81）----------
  YA.POS15 = ['GK', 'CB', 'LB', 'RB', 'LWB', 'RWB', 'DM', 'CM', 'LM', 'RM', 'AM', 'LW', 'RW', 'SS', 'ST'];
  YA.POS_LABEL = { GK: 'GK', CB: 'CB', LB: '左SB', RB: '右SB', LWB: '左WB', RWB: '右WB', DM: 'DM', CM: 'CM', LM: '左MF', RM: '右MF', AM: 'AM', LW: '左WG', RW: '右WG', SS: 'SS', ST: 'ST' };
  YA.POS_NAME = { GK: 'ゴールキーパー', CB: 'センターバック', LB: '左サイドバック', RB: '右サイドバック', LWB: '左ウイングバック', RWB: '右ウイングバック', DM: '守備的MF', CM: 'センターMF', LM: '左サイドMF', RM: '右サイドMF', AM: '攻撃的MF', LW: '左ウイング', RW: '右ウイング', SS: 'セカンドストライカー', ST: 'ストライカー' };
  // 試合の中身（場面の選び方）は4つの大きな括りで動く。ポジション名は細かく、中身は括りで共通
  YA.GROUP = { GK: 'GK', CB: 'DF', LB: 'DF', RB: 'DF', LWB: 'DF', RWB: 'DF', DM: 'MF', CM: 'MF', LM: 'MF', RM: 'MF', AM: 'MF', LW: 'FW', RW: 'FW', SS: 'FW', ST: 'FW' };
  YA.SIDE = { LB: 'L', LWB: 'L', LM: 'L', LW: 'L', RB: 'R', RWB: 'R', RM: 'R', RW: 'R' };
  YA.POS_ABS15 = {
    GK: YA.AB_GK,
    CB: ['タックル', 'マーク', 'ポジショニング', '予測', 'ヘディング', '強さ'],
    LB: ['タックル', 'マーク', 'スタミナ', 'スピード', 'クロス', '運動量'],
    RB: ['タックル', 'マーク', 'スタミナ', 'スピード', 'クロス', '運動量'],
    LWB: ['スタミナ', 'クロス', 'スピード', '運動量', 'ドリブル', 'タックル'],
    RWB: ['スタミナ', 'クロス', 'スピード', '運動量', 'ドリブル', 'タックル'],
    DM: ['タックル', 'ポジショニング', '予測', 'パス', '運動量', '判断'],
    CM: ['パス', '視野', '運動量', '判断', 'ファーストタッチ', 'タックル'],
    LM: ['クロス', 'スピード', '運動量', 'ドリブル', 'スタミナ', 'パス'],
    RM: ['クロス', 'スピード', '運動量', 'ドリブル', 'スタミナ', 'パス'],
    AM: ['パス', '視野', 'テクニック', 'ドリブル', '判断', 'オフザボール'],
    LW: ['ドリブル', 'スピード', '加速', 'クロス', 'テクニック', 'フィニッシュ'],
    RW: ['ドリブル', 'スピード', '加速', 'クロス', 'テクニック', 'フィニッシュ'],
    SS: ['オフザボール', 'テクニック', 'ファーストタッチ', 'フィニッシュ', 'パス', '加速'],
    ST: ['フィニッシュ', 'ヘディング', 'オフザボール', '強さ', 'ファーストタッチ', '加速'],
  };
  // 布陣ボードに置いた場所からポジション名が決まる
  YA.pos15OfPoint = function (x, y) {
    const wide = x < 0.25 || x > 0.75;
    const side = x < 0.5 ? 'L' : 'R';
    if (y < 0.27) return wide ? side + 'B' : 'CB';
    if (wide) return y < 0.5 ? side + 'WB' : y < 0.72 ? side + 'M' : side + 'W';
    if (y < 0.46) return 'DM';
    if (y < 0.66) return 'CM';
    if (y < 0.76) return 'AM';
    if (y < 0.84) return 'SS';
    return 'ST';
  };
  YA.pos15OfSlot = (s, i) => (i === 0 || s.y < 0.08 ? 'GK' : YA.pos15OfPoint(s.x, s.y));

  // ---------- 役割と任務（FMの「役割＋任務」の形。名前は借りるが、効き方はこのゲーム用の表）----------
  // 任務：後ろに残る／バランス／攻めに出る。役割ごとに選べる任務が決まっている
  //   boostMul = 自分のチームの場面の出やすさにかかる倍率、denyMul = 相手の場面を減らす効きの倍率、
  //   actor = その役割の選手が場面の主役に選ばれやすい倍率、press = 奪う・守る場面での倍率、depth = 立つ位置の深さ（ピッチ縦の割合）、fat = 疲れの溜まり方
  YA.DUTY = {
    def: { label: '守備', short: '守', note: '後ろに残って守りを優先する。攻めの場面には絡みにくい', boostMul: 0.5, denyMul: 1.45, actor: 0.75, press: 1.2, depth: -0.05, fat: 0.92 },
    sup: { label: 'サポート', short: 'サ', note: '攻守のバランスを取る', boostMul: 1, denyMul: 1, actor: 1, press: 1, depth: 0, fat: 1 },
    att: { label: '攻撃', short: '攻', note: '高い位置まで出て攻めに絡む。守りへの戻りは遅れる', boostMul: 1.5, denyMul: 0.55, actor: 1.25, press: 0.85, depth: 0.06, fat: 1.1 },
    stop: { label: 'ストッパー', short: 'ス', note: '前に出て潰しにいく。裏を取られやすい', boostMul: 0.8, denyMul: 1.2, actor: 0.9, press: 1.3, depth: 0.03, fat: 1.05 },
    cover: { label: 'カバー', short: 'カ', note: '一歩引いて読んで拾う。裏のスペースを消す', boostMul: 0.7, denyMul: 1.3, actor: 0.85, press: 1.1, depth: -0.04, fat: 0.95 },
  };
  const DU = { D: ['def'], S: ['sup'], A: ['att'], DS: ['def', 'sup'], SA: ['sup', 'att'], DSA: ['def', 'sup', 'att'], CB3: ['def', 'stop', 'cover'] };

  // 役割の表。1行 = 1つの役割。表に1行足せば役割が増える（ROLES15 の並びに名前を足すと選べる）
  //   abs = 効く能力の重み、traits = 合う特性、tags = 場面の主役への選ばれやすさ、
  //   boost = 自分のチームで出やすくなる場面の型、deny = 相手の場面を減らす効き
  YA.ROLE_DEF = {};
  const ROLE = (name, duties, note, absW, traits, tags, boost, deny) => {
    YA.ROLE_DEF[name] = { note, duties: DU[duties], absW, abs: Object.keys(absW), traits, tags, boost: boost || {}, deny: deny || {} };
  };
  // GK
  ROLE('ゴールキーパー', 'D', '守りに専念して、シュートを止める', { 反応: 3, ハンドリング: 3, '1対1': 2, エリアの支配: 1 }, ['PKストップ', 'クロスへの強さ', 'パンチング'], ['gk'], {}, { cross: 0.1, longshot: 0.1 });
  ROLE('スイーパーキーパー', 'DSA', '最終ラインの裏までカバーし、足元でつなぐ', { 飛び出し: 3, '1対1': 2, 配球: 2, 反応: 2 }, ['前に出るGK', '足元のうまいGK', '速い配球'], ['gk', 'pass'], { counter: 0.12 }, { through: 0.14, counter: 0.06 });
  // CB
  ROLE('センターディフェンダー', 'CB3', '競り合いと対人で守る基本の形', { ヘディング: 3, タックル: 3, ポジショニング: 2, 強さ: 2, マーク: 2 }, ['空中戦の競り', 'シュートブロック', '1対1の粘り'], ['stop'], { ck: 0.1 }, { cross: 0.08, dribble: 0.05 });
  ROLE('ボールプレイングDF', 'CB3', '後ろからつないで、持ち上がる', { パス: 3, ファーストタッチ: 2, ポジショニング: 2, 冷静さ: 2 }, ['ボールを運ぶ', 'サイドチェンジ', 'スルーパス'], ['pass', 'carry'], { through: 0.15, counter: 0.08 }, { through: 0.04 });
  ROLE('ノーナンセンスCB', 'CB3', '余計なことはせず、とにかく跳ね返す', { ヘディング: 3, 強さ: 3, タックル: 2, 集中: 2 }, ['空中戦の競り', 'スライディング', 'シュートブロック'], ['stop'], {}, { cross: 0.12, through: 0.04 });
  ROLE('ワイドCB', 'DSA', '広く開いて、サイドの守りと攻め上がりを担う', { スピード: 2, スタミナ: 2, タックル: 2, 運動量: 2 }, ['オーバーラップ', 'カバーリング', '縦への突破'], ['wide', 'cover'], { cross: 0.12, dribble: 0.05 }, { counter: 0.08 });
  ROLE('リベロ', 'SA', '最終ラインから持ち上がり、攻撃にも加わる', { パス: 3, ドリブル: 2, 判断: 2, 冷静さ: 2, 視野: 2 }, ['ボールを運ぶ', 'スルーパス', 'カバーリング'], ['pass', 'carry', 'cover'], { through: 0.18, dribble: 0.1, longshot: 0.08 });
  // SB
  ROLE('フルバック', 'DSA', '外側を上下して、サイドを任される基本の形', { スタミナ: 3, タックル: 2, クロス: 2, マーク: 2, スピード: 2 }, ['オーバーラップ', '1対1の粘り', 'アーリークロス'], ['wide', 'cross'], { cross: 0.22 }, { counter: 0.05 });
  ROLE('インバーテッドフルバック', 'D', '内側に絞って中央を固め、最終ラインを厚くする', { ポジショニング: 3, パス: 2, 判断: 2, タックル: 2 }, ['カバーリング', 'ボールを運ぶ', '読みのインターセプト'], ['stay', 'cover', 'pass'], { through: 0.06 }, { counter: 0.1, through: 0.06 });
  // WB
  ROLE('ウイングバック', 'DSA', '上下動を繰り返し、サイドを一人で受け持つ', { スタミナ: 3, クロス: 3, スピード: 2, 運動量: 3, ドリブル: 1 }, ['オーバーラップ', 'アーリークロス', '縦への突破'], ['wide', 'cross'], { cross: 0.3, dribble: 0.08 });
  ROLE('インバーテッドウイングバック', 'DSA', '内側に入ってつなぎ、中盤の数を増やす', { パス: 3, 判断: 2, 運動量: 2, ファーストタッチ: 2 }, ['ボールを運ぶ', 'ワンツー', 'スルーパス'], ['pass', 'carry'], { onetwo: 0.2, through: 0.12 });
  ROLE('プレイメイキングウイングバック', 'SA', '高い位置から、崩しの起点になる', { パス: 3, クロス: 2, 視野: 3, テクニック: 2 }, ['スルーパス', 'アーリークロス', 'ひらめき'], ['pass', 'cross', 'wide'], { through: 0.18, cross: 0.2, onetwo: 0.1 });
  // DM
  ROLE('アンカーマン', 'D', '中央に腰を据えて、相手の攻めを止める', { ポジショニング: 3, タックル: 3, 予測: 3, 集中: 2 }, ['カバーリング', 'ボール奪取', 'ラインコントロール'], ['stay', 'cover'], {}, { through: 0.12, longshot: 0.1, counter: 0.08 });
  ROLE('ディフェンシブMF', 'DS', '守備を優先し、機を見て前に出る', { タックル: 3, 運動量: 3, ポジショニング: 2, 判断: 2 }, ['ボール奪取', '読みのインターセプト', '即時奪回'], ['press', 'stay'], { steal: 0.1 }, { counter: 0.08, through: 0.05 });
  ROLE('ボール奪取MF', 'DS', 'ボールを追いかけて奪い取る', { タックル: 3, 運動量: 3, 強さ: 2, 予測: 2 }, ['ボール奪取', 'スライディング', '即時奪回', '前線からの守備'], ['press'], { steal: 0.22 }, { counter: 0.06 });
  ROLE('ハーフバック', 'D', 'DFの前に落ちて、最終ラインの一員になる', { ポジショニング: 3, 判断: 2, タックル: 2, マーク: 2 }, ['カバーリング', 'ラインコントロール'], ['cover', 'stay'], {}, { through: 0.1, cross: 0.05 });
  ROLE('ディープライイングプレイメーカー', 'DS', '低い位置から配球する', { パス: 3, 視野: 3, ファーストタッチ: 2, 冷静さ: 2 }, ['スルーパス', 'サイドチェンジ', 'ひらめき'], ['pass'], { through: 0.22, counter: 0.08 });
  ROLE('レジスタ', 'S', '低い位置から攻撃のリズムを作る司令塔', { パス: 3, 視野: 3, テクニック: 2, 判断: 2 }, ['スルーパス', 'サイドチェンジ', 'ひらめき', '直接FK'], ['pass'], { through: 0.28, counter: 0.1, fk: 0.05 });
  ROLE('セグンドボランチ', 'SA', '守備的な位置から、攻撃にも飛び出す', { 運動量: 3, スタミナ: 2, タックル: 2, オフザボール: 2, ロングシュート: 1 }, ['ボールを運ぶ', 'こぼれ球への嗅覚', '弾丸ミドル'], ['carry', 'press', 'finish'], { longshot: 0.16, dribble: 0.08, steal: 0.08 });
  // CM
  ROLE('セントラルMF', 'DSA', '攻守のバランスを取る基本の形', { パス: 2, 運動量: 3, 判断: 2, タックル: 2, 視野: 2 }, ['ボールを運ぶ', 'ワンツー', 'ボール奪取'], ['pass', 'carry'], { onetwo: 0.1, through: 0.06 });
  ROLE('ボックス・トゥ・ボックスMF', 'S', '攻守に走り回り、両方のゴール前に顔を出す', { 運動量: 3, スタミナ: 3, タックル: 2, ドリブル: 2, フィニッシュ: 1 }, ['オーバーラップ', 'ボールを運ぶ', 'こぼれ球への嗅覚'], ['carry', 'finish', 'press'], { dribble: 0.12, longshot: 0.12, counter: 0.1, steal: 0.08 });
  ROLE('アドバンスドプレイメーカー', 'SA', '前向きの位置で、決定的なパスを狙う', { パス: 3, 視野: 3, テクニック: 3, オフザボール: 1 }, ['スルーパス', 'ひらめき', 'ワンツー'], ['pass', 'run'], { through: 0.28, onetwo: 0.12 });
  ROLE('メッツァラ', 'SA', '中と外の間を動いて、攻撃の厚みを作る', { ドリブル: 2, 運動量: 3, パス: 2, オフザボール: 2, 判断: 2 }, ['ボールを運ぶ', 'ワンツー', '裏への抜け出し'], ['carry', 'run'], { dribble: 0.14, onetwo: 0.16, through: 0.1 });
  ROLE('カリレロ', 'S', '味方の守備の穴を埋めて、ボールをつなぐ', { 運動量: 3, ポジショニング: 2, パス: 2, タックル: 2 }, ['カバーリング', 'ボール奪取', '読みのインターセプト'], ['stay', 'press'], { steal: 0.1 }, { counter: 0.07, cross: 0.04 });
  ROLE('ローミングプレイメーカー', 'S', 'ピッチ中を動き回って組み立てる', { パス: 3, 運動量: 3, ドリブル: 2, 視野: 2, ファーストタッチ: 2 }, ['ボールを運ぶ', 'サイドチェンジ', 'ワンツー'], ['pass', 'carry'], { onetwo: 0.18, dribble: 0.1, through: 0.1 });
  // 左MF・右MF／左WG・右WG
  ROLE('ウイング', 'SA', 'サイドで幅を取り、縦に仕掛ける', { ドリブル: 3, スピード: 3, クロス: 2, 加速: 2 }, ['縦への突破', 'アーリークロス', 'ボールを運ぶ'], ['wide', 'dribble', 'cross'], { dribble: 0.28, cross: 0.22 });
  ROLE('ワイドMF', 'DS', 'サイドで守備と攻撃を両方こなす', { 運動量: 3, スタミナ: 3, クロス: 2, タックル: 2 }, ['オーバーラップ', '1対1の粘り', 'アーリークロス'], ['wide', 'cross'], { cross: 0.15 }, { counter: 0.05 });
  ROLE('ディフェンシブウインガー', 'DS', '守備を優先して、サイドを閉める', { マーク: 3, 運動量: 3, タックル: 2, ポジショニング: 2 }, ['カバーリング', '1対1の粘り', '前線からの守備'], ['stay', 'wide'], { steal: 0.08 }, { cross: 0.08, counter: 0.08 });
  ROLE('ワイドプレイメーカー', 'SA', 'サイドから組み立てる', { パス: 3, 視野: 3, クロス: 2, テクニック: 2 }, ['スルーパス', 'アーリークロス', 'サイドチェンジ'], ['pass', 'wide', 'cross'], { through: 0.16, cross: 0.2, onetwo: 0.1 });
  ROLE('インサイドフォワード', 'SA', '外から中へ切れ込んで決める', { ドリブル: 3, フィニッシュ: 3, スピード: 2, テクニック: 2, オフザボール: 1 }, ['カットイン', '巻いて流し込むシュート', 'ループシュート'], ['dribble', 'finish', 'cutin'], { dribble: 0.3, longshot: 0.14 });
  ROLE('インサイドウイング', 'SA', '中へ入って味方とつなぎ、仕上げる', { パス: 3, ドリブル: 2, 視野: 2, テクニック: 2 }, ['カットイン', 'ワンツー', 'スルーパス'], ['dribble', 'pass', 'cutin'], { dribble: 0.2, onetwo: 0.2, through: 0.14 });
  ROLE('ラウムドイター', 'A', '空いたスペースに入り込んで得点を狙う', { オフザボール: 3, 予測: 3, フィニッシュ: 2, 集中: 2 }, ['裏への抜け出し', 'ニアへの飛び込み', 'こぼれ球への嗅覚'], ['run', 'finish'], { through: 0.2, cross: 0.15, counter: 0.08 });
  // AM
  ROLE('アタッキングMF', 'SA', '前線と中盤をつなぎ、仕掛ける', { ドリブル: 2, パス: 3, テクニック: 2, オフザボール: 2, フィニッシュ: 1 }, ['ひらめき', 'ワンツー', 'ボールを運ぶ'], ['pass', 'dribble'], { through: 0.15, dribble: 0.15, onetwo: 0.12, longshot: 0.08 });
  ROLE('エンガンチェ', 'S', '動かずに味方を操る、古典的な司令塔', { パス: 3, 視野: 3, テクニック: 3, ファーストタッチ: 2 }, ['スルーパス', 'ひらめき', '直接FK', '曲がるCK'], ['pass'], { through: 0.3, onetwo: 0.1, fk: 0.12, ck: 0.08 });
  ROLE('シャドーストライカー', 'A', 'FWの背後から飛び込む', { オフザボール: 3, フィニッシュ: 3, 加速: 2, 判断: 1 }, ['裏への抜け出し', 'ニアへの飛び込み', 'こぼれ球への嗅覚'], ['run', 'finish'], { through: 0.24, cross: 0.12, counter: 0.1 });
  ROLE('トレクァルティスタ', 'A', '自由な位置から決定的な仕事をする', { テクニック: 3, ドリブル: 3, パス: 2, フィニッシュ: 2, 視野: 2 }, ['ひらめき', 'カットイン', 'スルーパス'], ['dribble', 'pass', 'finish'], { dribble: 0.2, through: 0.16, longshot: 0.12 });
  ROLE('フリーロール', 'SA', '決まった持ち場を持たず、動き回る', { テクニック: 3, 判断: 3, ドリブル: 2, パス: 2 }, ['ひらめき', 'ワンツー', 'ボールを運ぶ'], ['carry', 'pass', 'dribble'], { dribble: 0.15, onetwo: 0.15, longshot: 0.1 });
  // SS・ST
  ROLE('ディープライイングフォワード', 'SA', '下がって受けて、前を向いて仕掛ける', { ファーストタッチ: 3, パス: 2, テクニック: 3, ドリブル: 2 }, ['下がって受ける', 'ワンツー', '背負ってからのターン'], ['post', 'pass', 'dribble'], { onetwo: 0.28, dribble: 0.1, through: 0.08 });
  ROLE('フォルスナイン', 'S', '最前線から降りて、相手DFを引き出す', { パス: 3, 視野: 3, ファーストタッチ: 3, テクニック: 2 }, ['下がって受ける', 'スルーパス', 'ひらめき'], ['post', 'pass'], { onetwo: 0.3, through: 0.14 });
  ROLE('アドバンスドフォワード', 'A', '常に最終ラインの裏を狙う', { オフザボール: 3, 加速: 3, スピード: 2, フィニッシュ: 3 }, ['裏への抜け出し', 'ループシュート', '縦への突破'], ['run', 'finish'], { through: 0.35, counter: 0.15 });
  ROLE('コンプリートフォワード', 'SA', 'ポスト・突破・仕上げを全部こなす', { フィニッシュ: 2, ファーストタッチ: 2, ドリブル: 2, 強さ: 2, パス: 2 }, ['タメを作る', '裏への抜け出し', 'ヘディングシュート'], ['finish', 'post', 'run'], { through: 0.1, cross: 0.1, onetwo: 0.1, dribble: 0.06 });
  ROLE('ポーチャー', 'A', 'ゴール前で、得点だけに集中する', { フィニッシュ: 3, オフザボール: 3, 予測: 2, 集中: 2 }, ['ニアへの飛び込み', 'こぼれ球への嗅覚', 'ヘディングシュート'], ['finish'], { cross: 0.22, ck: 0.1 });
  ROLE('プレッシングフォワード', 'DSA', '最前線から追いかけて、奪い返す', { 運動量: 3, スタミナ: 2, タックル: 2, 予測: 2 }, ['前線からの守備', '即時奪回', 'ボール奪取'], ['press', 'finish'], { steal: 0.32 });
  ROLE('ターゲットフォワード', 'SA', '高さと強さで収める', { 強さ: 3, ヘディング: 3, ファーストタッチ: 2, ジャンプ: 2 }, ['ポストプレー', 'ヘディングシュート', '背負ってからのターン'], ['post', 'finish'], { cross: 0.3, onetwo: 0.15, longthrow: 0.1, ck: 0.06 });

  // ポジションごとに選べる役割（先頭が既定）
  YA.ROLES15 = {
    GK: ['ゴールキーパー', 'スイーパーキーパー'],
    CB: ['センターディフェンダー', 'ボールプレイングDF', 'ノーナンセンスCB', 'ワイドCB', 'リベロ'],
    LB: ['フルバック', 'インバーテッドフルバック'], RB: ['フルバック', 'インバーテッドフルバック'],
    LWB: ['ウイングバック', 'インバーテッドウイングバック', 'プレイメイキングウイングバック'], RWB: ['ウイングバック', 'インバーテッドウイングバック', 'プレイメイキングウイングバック'],
    DM: ['アンカーマン', 'ディフェンシブMF', 'ボール奪取MF', 'ハーフバック', 'ディープライイングプレイメーカー', 'レジスタ', 'セグンドボランチ'],
    CM: ['セントラルMF', 'ボックス・トゥ・ボックスMF', 'ボール奪取MF', 'ディープライイングプレイメーカー', 'アドバンスドプレイメーカー', 'メッツァラ', 'カリレロ', 'ローミングプレイメーカー'],
    LM: ['ウイング', 'ワイドMF', 'ディフェンシブウインガー', 'ワイドプレイメーカー'], RM: ['ウイング', 'ワイドMF', 'ディフェンシブウインガー', 'ワイドプレイメーカー'],
    AM: ['アタッキングMF', 'アドバンスドプレイメーカー', 'エンガンチェ', 'シャドーストライカー', 'トレクァルティスタ', 'フリーロール'],
    LW: ['ウイング', 'インサイドフォワード', 'インサイドウイング', 'ラウムドイター', 'ワイドプレイメーカー'], RW: ['ウイング', 'インサイドフォワード', 'インサイドウイング', 'ラウムドイター', 'ワイドプレイメーカー'],
    SS: ['ディープライイングフォワード', 'フォルスナイン', 'シャドーストライカー', 'トレクァルティスタ'],
    ST: ['アドバンスドフォワード', 'コンプリートフォワード', 'ディープライイングフォワード', 'フォルスナイン', 'ポーチャー', 'プレッシングフォワード', 'ターゲットフォワード'],
  };
  // 既定の任務：サポートが選べればサポート、なければ先頭
  YA.defaultDuty = (role) => {
    const d = YA.ROLE_DEF[role] && YA.ROLE_DEF[role].duties;
    return d ? (d.indexOf('sup') >= 0 ? 'sup' : d[0]) : 'sup';
  };
  YA.defaultRole = (pos15) => YA.ROLES15[pos15][0];
  YA.rolesAt = (s, i) => YA.ROLES15[YA.pos15OfSlot(s, i)];
  // スロットの役割・任務を、そのポジションで使えるものに直す（足りなければ既定を入れる）
  YA.fixSlotRole = function (s, i) {
    const rs = YA.rolesAt(s, i);
    if (rs.indexOf(s.role) < 0) {
      s.role = rs[0];
      s.duty = null;
    }
    const ds = YA.ROLE_DEF[s.role].duties;
    if (!s.duty || ds.indexOf(s.duty) < 0) s.duty = YA.defaultDuty(s.role);
  };
  YA.setRole = function (s, i, role) {
    if (YA.rolesAt(s, i).indexOf(role) < 0) return;
    s.role = role;
    s.duty = null;
    YA.fixSlotRole(s, i);
  };
  YA.ROLE_TRAITS = {};
  YA.ROLE_ABS = {};

  // ---------- 選手のポジション適性（1〜20）。本人も知らない「本当に向いているポジション」----------
  YA.hash = function (str) {
    let hv = 7;
    for (let k = 0; k < str.length; k++) hv = (hv * 31 + str.charCodeAt(k)) % 100003;
    return hv;
  };
  const clampN = (v, a, b) => Math.max(a, Math.min(b, v));
  YA.aptOf = function (p, pos15) {
    const isGK = p.pos === 'GK' || p.main === 'GK';
    if (isGK !== (pos15 === 'GK')) return 1;
    const keys = YA.POS_ABS15[pos15];
    let v = keys.reduce((s, n) => s + (p.ab[n] || 1), 0) / keys.length;
    if (pos15 === 'CB' || pos15 === 'ST') v += (p.height - 178) * 0.12;
    if (pos15 === 'LW' || pos15 === 'RW' || pos15 === 'LWB' || pos15 === 'RWB') v += ((p.ab['スピード'] || 8) - 10) * 0.1;
    // 利き足と左右の相性
    const side = YA.SIDE[pos15];
    if (side && p.foot && p.foot !== 'B' && (p.foot === 'L') !== (side === 'L') && pos15.indexOf('W') < 0) v -= (12 - (p.ab['逆足の精度'] || 8)) * 0.05;
    const bias = ((YA.hash(p.id + pos15) % 100) / 100 - 0.5) * 1.6;
    return Math.round(clampN(v + bias, 1, 20) * 10) / 10;
  };
  YA.refreshApt = function (p) {
    p.apt = p.apt || {};
    let best = null;
    let bv = -1;
    for (const pos of YA.POS15) {
      p.apt[pos] = YA.aptOf(p, pos);
      if (p.apt[pos] > bv) { bv = p.apt[pos]; best = pos; }
    }
    p.best = best;
  };
  // 選手に、適性・登録ポジション・利き足を持たせる
  YA.initPos = function (p, rng, main) {
    p.foot = p.foot || (rng() < 0.72 ? 'R' : rng() < 0.78 ? 'L' : 'B');
    p.fam = p.fam || {};
    const isGK = p.pos === 'GK';
    p.main = isGK ? 'GK' : main || null;
    YA.refreshApt(p);
    if (!p.main) {
      // 登録は本当の適性とは限らない（3割は隣のポジションで登録されている）
      p.main = p.best;
      if (!isGK && rng() < 0.3) {
        const near = { CB: ['DM', 'LB'], LB: ['LWB', 'CB'], RB: ['RWB', 'CB'], LWB: ['LB', 'LM'], RWB: ['RB', 'RM'], DM: ['CM', 'CB'], CM: ['DM', 'AM'], LM: ['LW', 'CM'], RM: ['RW', 'CM'], AM: ['CM', 'SS'], LW: ['LM', 'AM'], RW: ['RM', 'AM'], SS: ['AM', 'ST'], ST: ['SS', 'LW'] }[p.best];
        if (near) p.main = near[rng.int(0, near.length - 1)];
      }
    }
    p.pos = YA.GROUP[p.main];
    p.fam[p.main] = 14;
  };
  // 置いた場所での力の落ち方（0〜）。向いていない場所・逆足だと落ち、慣れると和らぐ。向いている場所に置くと少し上がる
  YA.slotPenalty = function (p, pos15) {
    if (!p.apt) return 0;
    if ((p.pos === 'GK') !== (pos15 === 'GK')) return 0.3;
    let pen = clampN(((p.apt[p.main] || 10) - (p.apt[pos15] || 10)) * 0.02, -0.05, 0.25);
    const fam = (p.fam && p.fam[pos15]) || 0;
    if (pen > 0) pen *= clampN(1 - fam / 14, 0.3, 1);
    const side = YA.SIDE[pos15];
    if (side && ['LB', 'RB', 'LWB', 'RWB', 'LM', 'RM'].indexOf(pos15) >= 0 && p.foot !== 'B' && (p.foot === 'L') !== (side === 'L')) pen += clampN((12 - (p.ab['逆足の精度'] || 8)) * 0.01, 0, 0.1);
    return Math.round(pen * 1000) / 1000;
  };

  // 布陣の定番（x:左0〜右1、y:自陣ゴール0〜相手ゴール1）。自由に動かせる土台
  const f = (a) => a.map(([x, y]) => ({ x, y }));
  YA.FORMATIONS = {
    '4-3-3': f([[0.5, 0.03], [0.85, 0.2], [0.62, 0.17], [0.38, 0.17], [0.15, 0.2], [0.5, 0.4], [0.7, 0.54], [0.3, 0.54], [0.84, 0.82], [0.16, 0.82], [0.5, 0.9]]),
    '4-4-2': f([[0.5, 0.03], [0.85, 0.2], [0.62, 0.17], [0.38, 0.17], [0.15, 0.2], [0.85, 0.55], [0.62, 0.52], [0.38, 0.52], [0.15, 0.55], [0.62, 0.9], [0.38, 0.8]]),
    '4-2-3-1': f([[0.5, 0.03], [0.85, 0.2], [0.62, 0.17], [0.38, 0.17], [0.15, 0.2], [0.62, 0.4], [0.38, 0.4], [0.84, 0.78], [0.5, 0.7], [0.16, 0.78], [0.5, 0.9]]),
    '3-5-2': f([[0.5, 0.03], [0.72, 0.17], [0.5, 0.15], [0.28, 0.17], [0.92, 0.48], [0.68, 0.54], [0.5, 0.4], [0.32, 0.54], [0.08, 0.48], [0.62, 0.9], [0.38, 0.8]]),
    '5-3-2': f([[0.5, 0.03], [0.93, 0.3], [0.72, 0.17], [0.5, 0.15], [0.28, 0.17], [0.07, 0.3], [0.7, 0.54], [0.5, 0.4], [0.3, 0.54], [0.62, 0.9], [0.38, 0.8]]),
    '3-4-3': f([[0.5, 0.03], [0.72, 0.17], [0.5, 0.15], [0.28, 0.17], [0.92, 0.48], [0.62, 0.54], [0.38, 0.54], [0.08, 0.48], [0.84, 0.82], [0.16, 0.82], [0.5, 0.9]]),
  };

  // 戦い方の型（決定38）と、つまみ
  YA.TACTICS = {
    ポゼッション: { tempo: 0.25, width: 0.5, line: 0.65, press: 0.5, intensity: 0.4 },
    カウンター: { tempo: 0.85, width: 0.4, line: 0.25, press: 0.2, intensity: 0.5 },
    ハイプレス: { tempo: 0.65, width: 0.5, line: 0.85, press: 0.9, intensity: 0.8 },
    サイド攻撃: { tempo: 0.55, width: 0.9, line: 0.55, press: 0.5, intensity: 0.5 },
    縦に速い: { tempo: 0.9, width: 0.45, line: 0.5, press: 0.5, intensity: 0.6 },
    堅守: { tempo: 0.5, width: 0.35, line: 0.2, press: 0.15, intensity: 0.5 },
  };
  YA.KNOBS = [
    ['tempo', '攻め方', '持つ', '速く縦へ'],
    ['width', '幅', '中央', 'サイド'],
    ['line', 'ラインの高さ', '低い', '高い'],
    ['press', '奪い方', '構える', '前から'],
    ['intensity', '当たりの強さ', '弱', '強'],
  ];

  // ----- チーム作り -----
  const SUR = ['佐藤', '鈴木', '高橋', '田中', '伊藤', '渡辺', '山本', '中村', '小林', '加藤', '吉田', '山田', '佐々木', '山口', '松本', '井上', '木村', '林', '斎藤', '清水', '山崎', '森', '池田', '橋本', '阿部', '石川', '山下', '中島', '石井', '小川', '前田', '岡田', '長谷川', '藤田', '後藤', '近藤', '村上', '遠藤', '青木', '坂本', '斉藤', '福田', '太田', '西村', '藤井', '金子', '三浦', '岡本', '松田', '中川'];
  const GIV = ['蓮', '大翔', '陽翔', '湊', '蒼', '樹', '悠真', '朝陽', '律', '颯太', '龍之介', '海斗', '凛', '奏', '隼人', '拓海', '翔', '航', '陸', '光', '諒', '慎', '健太', '直樹', '康介', '優斗', '駿', '瑛太', '晴', '誠'];

  function rngOf(seed) {
    let s = seed >>> 0;
    const f = () => {
      s = (s + 0x6d2b79f5) >>> 0;
      let t = s;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
    f.int = (a, b) => a + Math.floor(f() * (b - a + 1));
    f.pick = (a) => a[Math.floor(f() * a.length)];
    f.chance = (p) => f() < p;
    f.weighted = (items, wf) => {
      let tot = 0;
      const ws = items.map((x) => {
        const w = Math.max(0, wf(x));
        tot += w;
        return w;
      });
      if (tot <= 0) return items[Math.floor(f() * items.length)];
      let r = f() * tot;
      for (let i = 0; i < items.length; i++) {
        r -= ws[i];
        if (r <= 0) return items[i];
      }
      return items[items.length - 1];
    };
    return f;
  }
  YA.rngOf = rngOf;

  function persOf(over) {
    const o = {};
    for (const g of Object.keys(YA.PERS_GROUPS)) o[g] = 'ふつう';
    const alias = { 気持ち: '気持ちの強さ', 波: '感情の波', 関わり: '人との関わり', 教え: '教えの受け止め方', 練習: '練習への向き合い', 目指す: '目指すもの', 気質: 'プレーの気質' };
    for (const [k, v] of Object.entries(over || {})) o[alias[k] || k] = v;
    return o;
  }

  // 能力の土台。lvl を中心に少しばらつかせ、boost で得意を上げる
  function mkPlayer(rng, d) {
    const ab = {};
    const isGK = d.pos === 'GK';
    const boost = d.boost || {};
    for (const n of YA.AB_FIELD) ab[n] = Math.max(1, Math.min(20, Math.round(d.lvl - (isGK ? 4 : 0) + (rng() - 0.5) * 3 + (boost[n] || 0))));
    for (const n of YA.AB_GK) ab[n] = Math.max(1, Math.min(20, Math.round((isGK ? d.lvl : 3) + (rng() - 0.5) * 3 + (isGK ? boost[n] || 0 : 0))));
    const p = {
      id: d.id,
      num: d.num,
      name: d.name,
      pos: d.pos,
      ab,
      traits: d.traits || [],
      pers: persOf(d.pers),
      height: d.height || 175,
      form: d.form != null ? d.form : 0,
      conf: d.conf != null ? d.conf : 55,
      stam: 100,
      yellow: 0,
      st: { goals: 0, assists: 0, shots: 0, rating: 6.0, minutes: 0, saves: 0 },
    };
    YA.initPos(p, rng, d.main || null);
    return p;
  }
  YA.mkPlayer = mkPlayer;

  const B = (o) => o;
  // あなたのクラブ。特性や性格が場面に出るよう、役者を分けて作る
  const OURS = [
    { num: 1, name: '渡辺 蓮', pos: 'GK', lvl: 12, boost: { 反応: 3, '1対1': 2, 飛び出し: 2 }, traits: ['前に出るGK', '速い配球'], pers: { 感情の波: '安定型', 練習への向き合い: '真面目' } },
    { num: 2, name: '小林 大地', pos: 'DF', lvl: 11, boost: { スタミナ: 3, クロス: 2, 運動量: 3 }, traits: ['オーバーラップ', '1対1の粘り'], pers: { プレーの気質: '献身的', 練習への向き合い: '真面目' } },
    { num: 3, name: '森田 海斗', pos: 'DF', lvl: 11, boost: { クロス: 4, スピード: 2, 加速: 2 }, traits: ['アーリークロス', '縦への突破'], pers: { 人との関わり: 'お調子者', 教えの受け止め方: '素直' } },
    { num: 4, name: '石原 剛', pos: 'DF', lvl: 12, boost: { ヘディング: 4, ジャンプ: 3, 強さ: 3, スピード: -2 }, traits: ['空中戦の競り', 'ラインコントロール', 'シュートブロック'], pers: { 人との関わり: 'リーダー気質', 気持ちの強さ: '粘り強い' }, height: 187 },
    { num: 5, name: '長谷川 駿', pos: 'DF', lvl: 11, boost: { 予測: 3, ポジショニング: 3, 判断: 2 }, traits: ['カバーリング', '読みのインターセプト'], pers: { 大舞台: '慎重', 人との関わり: '寡黙' } },
    { num: 6, name: '岡田 悠真', pos: 'MF', lvl: 11, boost: { タックル: 4, 強さ: 3, 運動量: 3, 視野: -2 }, traits: ['ボール奪取', '即時奪回', '前線からの守備'], pers: { プレーの気質: '闘争的', 感情の波: '短気' } },
    { num: 8, name: '村上 湊', pos: 'MF', lvl: 11, boost: { ドリブル: 3, 運動量: 3, パス: 2 }, traits: ['ボールを運ぶ', 'ワンツー', 'サイドチェンジ'], pers: { 人との関わり: '仲間思い', 気持ちの強さ: '粘り強い' } },
    { num: 10, name: '神谷 陽翔', pos: 'MF', lvl: 12, boost: { パス: 4, 視野: 5, テクニック: 3, プレースキック: 3, スタミナ: -3 }, traits: ['スルーパス', 'ひらめき', '直接FK'], pers: { 大舞台: '大舞台に強い', プレーの気質: '自信家', 感情の波: '気分屋' } },
    { num: 7, name: '工藤 迅', pos: 'FW', lvl: 11, boost: { スピード: 4, 加速: 3, ドリブル: 3, フィニッシュ: -1 }, traits: ['縦への突破', 'ニアへの飛び込み', 'ファウルをもらう'], pers: { プレーの気質: '勇敢', 人との関わり: 'お調子者' } },
    { num: 11, name: '高梨 奏', pos: 'FW', lvl: 11, boost: { ドリブル: 3, テクニック: 3, フィニッシュ: 3, 逆足の精度: 3 }, traits: ['カットイン', '巻いて流し込むシュート'], pers: { 気持ちの強さ: '繊細', 大舞台: 'プレッシャーに弱い' } },
    { num: 9, name: '鷹村 隼人', pos: 'FW', lvl: 12, boost: { オフザボール: 5, 加速: 3, フィニッシュ: 3, 冷静さ: 1, ヘディング: 1 }, traits: ['裏への抜け出し', 'こぼれ球への嗅覚', 'ヘディングシュート'], pers: { 気持ちの強さ: '負けず嫌い', 目指すもの: '野心家', 教えの受け止め方: '頑固' }, height: 181 },
    // ベンチ9人（交代で試合を変えられる顔ぶれ）
    { num: 12, name: '佐野 悠', pos: 'GK', lvl: 11, boost: { 反応: 1, ハンドリング: 3 }, traits: ['PKストップ', 'クロスへの強さ'], pers: { 大舞台: '大舞台に強い' } },
    { num: 13, name: '内田 圭', pos: 'DF', lvl: 10, boost: { 強さ: 3, ヘディング: 3, ジャンプ: 2 }, traits: ['ロングスロー', '空中戦の競り'], pers: { 感情の波: '安定型' }, height: 184 },
    { num: 14, name: '清水 瑛', pos: 'MF', lvl: 10, boost: { ロングシュート: 5, 強さ: 2 }, traits: ['弾丸ミドル', '声で味方を動かす'], pers: { 人との関わり: 'リーダー気質', プレーの気質: '勇敢' } },
    { num: 15, name: '吉岡 澪', pos: 'MF', lvl: 10, boost: { プレースキック: 5, パス: 3, クロス: 3 }, traits: ['曲がるCK', 'スルーパス'], pers: { 教えの受け止め方: '構ってほしい' } },
    { num: 16, name: '白石 烈', pos: 'FW', lvl: 10, boost: { 強さ: 4, ファーストタッチ: 3, バランス: 3, スピード: -2 }, traits: ['ポストプレー', 'タメを作る', '背負ってからのターン'], pers: { 感情の波: '安定型', 人との関わり: '寡黙' }, height: 183 },
    { num: 17, name: '速水 翼', pos: 'FW', lvl: 10, boost: { スピード: 5, 加速: 4, 冷静さ: -1 }, traits: ['裏への抜け出し', 'ループシュート'], pers: { 練習への向き合い: '練習嫌い', 教えの受け止め方: '反骨心' } },
    { num: 18, name: '松本 竜', pos: 'DF', lvl: 10, boost: { タックル: 3, 敏しょう性: 2 }, traits: ['スライディング', '1対1の粘り'], pers: { プレーの気質: '闘争的' } },
    { num: 19, name: '大野 純', pos: 'MF', lvl: 10, boost: { 判断: 3, 冷静さ: 4, チームワーク: 3 }, traits: ['試合を落ち着かせる', '下がって受ける'], pers: { 感情の波: '安定型', 練習への向き合い: '勉強家' } },
    { num: 20, name: '田島 豪', pos: 'FW', lvl: 10, boost: { ヘディング: 4, ジャンプ: 3, フィニッシュ: 2 }, traits: ['ヘディングシュート', 'ニアへの飛び込み'], pers: { 気持ちの強さ: '楽天家' }, height: 186 },
  ];

  YA.OPPONENTS = [
    { id: 'kouhoku', name: '港北学院高校', short: '港北学院', color: '#c0392b', lvl: 12.3, formation: '4-4-2', tactic: 'ハイプレス', desc: '強豪の高校。体が強く、前から奪いにくる', style: 'power' },
    { id: 'bluewing', name: 'ブルーウィング東京ユース', short: 'ブルーウィング', color: '#2c3e50', lvl: 12.4, formation: '4-3-3', tactic: 'ポゼッション', desc: 'プロのユース。つないで崩す技術派', style: 'tech' },
    { id: 'hokuryo', name: '北陵高校', short: '北陵', color: '#7f8c8d', lvl: 11.5, formation: '5-3-2', tactic: '堅守', desc: '堅守速攻の高校。一発の裏抜けに注意', style: 'defend' },
  ];

  const STYLE_TRAITS = {
    power: { DF: ['空中戦の競り', 'スライディング', 'シュートブロック', '1対1の粘り'], MF: ['ボール奪取', '前線からの守備', '即時奪回', 'ボールを運ぶ'], FW: ['ポストプレー', 'ヘディングシュート', '背負ってからのターン', 'こぼれ球への嗅覚'], GK: ['パンチング', 'クロスへの強さ'] },
    tech: { DF: ['カバーリング', 'ボールを運ぶ', '読みのインターセプト', 'ラインコントロール'], MF: ['スルーパス', 'ワンツー', 'ひらめき', 'サイドチェンジ', 'タメを作る'], FW: ['カットイン', '巻いて流し込むシュート', 'ループシュート', '裏への抜け出し'], GK: ['足元のうまいGK', '速い配球'] },
    defend: { DF: ['ラインコントロール', 'カバーリング', 'スライディング', 'シュートブロック', '1対1の粘り'], MF: ['ボール奪取', '読みのインターセプト', 'ボールを運ぶ'], FW: ['裏への抜け出し', 'ニアへの飛び込み', '縦への突破'], GK: ['PKストップ', '前に出るGK'] },
  };
  const PERS_POOL = [
    { 気持ち: '負けず嫌い' }, { 気持ち: '粘り強い' }, { 大舞台: '大舞台に強い' }, { 大舞台: 'プレッシャーに弱い' }, { 波: '短気' }, { 波: '気分屋' }, { 気質: '勇敢' }, { 気質: '闘争的' }, { 気質: 'ずる賢い' }, {}, {}, {}, { 教え: '頑固' }, { 気質: '自信家' }, { 関わり: 'リーダー気質' },
  ];
  const NUMS_START = [1, 2, 3, 4, 5, 6, 8, 10, 7, 11, 9];

  YA.makeOpponent = function (opp, seed) {
    const rng = rngOf(seed);
    const fm = YA.FORMATIONS[opp.formation];
    const slot15 = fm.map((s, i) => YA.pos15OfSlot(s, i));
    const usedName = new Set();
    const nameOf = () => {
      for (;;) {
        const n = rng.pick(SUR) + ' ' + rng.pick(GIV);
        if (!usedName.has(n)) {
          usedName.add(n);
          return n;
        }
      }
    };
    const players = {};
    const mk = (pos15, num, lvl) => {
      const grp = YA.GROUP[pos15];
      const pool = STYLE_TRAITS[opp.style][grp];
      const tr = [];
      const nt = grp === 'GK' ? 1 : 1 + rng.int(0, 2);
      while (tr.length < nt) {
        const t = rng.pick(pool);
        if (!tr.includes(t)) tr.push(t);
      }
      const boost = {};
      if (opp.style === 'power') Object.assign(boost, { 強さ: 2, ジャンプ: 1, スタミナ: 2, テクニック: -1 });
      if (opp.style === 'tech') Object.assign(boost, { パス: 2, テクニック: 2, 視野: 1, 強さ: -2 });
      if (opp.style === 'defend') Object.assign(boost, { ポジショニング: 2, マーク: 2, 集中: 2, ドリブル: -1 });
      for (const n of YA.POS_ABS15[pos15]) boost[n] = (boost[n] || 0) + (grp === 'GK' ? 0 : 1.5);
      const p = mkPlayer(rng, { id: opp.id + '_' + num, num, name: nameOf(), pos: grp, main: pos15, lvl, boost, traits: tr, pers: rng.pick(PERS_POOL), height: 170 + rng.int(0, 16) });
      p.form = rng.int(-1, 1);
      players[p.id] = p;
      return p;
    };
    const lineup = fm.map((s, i) => {
      const p = mk(slot15[i], NUMS_START[i] != null ? NUMS_START[i] : 20 + i, opp.lvl + (rng() - 0.5) * 1.2);
      const sl = { pid: p.id, x: s.x, y: s.y, role: YA.defaultRole(slot15[i]) };
      YA.fixSlotRole(sl, i);
      return sl;
    });
    const benchPos = ['GK', 'CB', 'LB', 'RB', 'DM', 'CM', 'AM', 'LW', 'ST'];
    const bench = [];
    for (let k = 0; k < 9; k++) {
      const p = mk(benchPos[k], 12 + k, opp.lvl - 1 + (rng() - 0.5));
      bench.push(p.id);
    }
    return { id: opp.id, name: opp.name, short: opp.short, color: opp.color, isUser: false, players, lineup, bench, tactic: Object.assign({ type: opp.tactic }, YA.TACTICS[opp.tactic]), instr: {}, subsUsed: 0, windowsUsed: 0, formation: opp.formation };
  };

  YA.makeOurs = function (seed) {
    const rng = rngOf(seed || 7);
    const players = {};
    const list = OURS.map((d) => {
      const p = mkPlayer(rng, Object.assign({ id: 'me_' + d.num }, d));
      players[p.id] = p;
      return p;
    });
    const fm = YA.FORMATIONS['4-3-3'];
    // 4-3-3 の並びに、スタメンを当てはめる（GK・右SB・CB・CB・左SB・アンカー・右IH・左IH・右W・左W・CF）
    const order = [1, 2, 4, 5, 3, 6, 8, 10, 7, 11, 9];
    const lineup = order.map((n, i) => {
      const pid = 'me_' + n;
      const p15 = YA.pos15OfSlot(fm[i], i);
      const pl = players[pid];
      if (pl.pos !== 'GK') { pl.main = p15; pl.pos = YA.GROUP[p15]; pl.fam[p15] = 14; }
      const sl = { pid, x: fm[i].x, y: fm[i].y, role: YA.defaultRole(p15) };
      YA.fixSlotRole(sl, i);
      return sl;
    });
    // 役割の初期値（特性の合う役割を初めから当てておく）
    const init = { me_2: ['フルバック', 'att'], me_3: ['フルバック', 'att'], me_4: ['センターディフェンダー', 'stop'], me_5: ['センターディフェンダー', 'cover'], me_10: ['アドバンスドプレイメーカー', 'sup'], me_8: ['メッツァラ', 'att'], me_6: ['ボール奪取MF', 'def'], me_9: ['アドバンスドフォワード', 'att'], me_1: ['スイーパーキーパー', 'sup'], me_7: ['ウイング', 'att'], me_11: ['インサイドフォワード', 'sup'] };
    lineup.forEach((sl, i) => {
      const it = init[sl.pid];
      if (it && YA.rolesAt(sl, i).indexOf(it[0]) >= 0) { sl.role = it[0]; sl.duty = it[1]; YA.fixSlotRole(sl, i); }
    });
    return { id: 'me', name: 'レガーレ湘南U-18', short: 'レガーレ', color: '#1f6feb', isUser: true, players, lineup, bench: [12, 13, 14, 15, 16, 17, 18, 19, 20].map((n) => 'me_' + n), tactic: Object.assign({ type: 'ポゼッション' }, YA.TACTICS['ポゼッション']), instr: {}, subsUsed: 0, windowsUsed: 0, formation: '4-3-3', _list: list };
  };

  YA.posOfSlot = (s, idx) => YA.GROUP[YA.pos15OfSlot(s, idx)];
})();
