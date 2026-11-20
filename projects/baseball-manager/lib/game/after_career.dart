/// 引退後のセカンドキャリア。プロを引退したあとの道を、5つから1つ選ぶ。
///
/// 選んだ道で、10年後くらいまでの物語が出る。**結果は乱数を使わず**、現役時代の成績・人気・資産と
/// 名前から決まる(同じ一生なら同じ。選び直しても、道ごとの結果は変わらない)。
enum AfterPath {
  manager('監督', '球団のコーチから監督を目指す。成績と優勝の数が物を言う。'),
  coach('コーチ', 'コーチとして次の世代を育てる。総合評価の高さが効く。'),
  commentator('解説者', '野球解説者として活躍する。人気とタイトルが効く。'),
  business('実業家', '資産をもとに事業を起こす。資産が効く。'),
  teacher('少年野球の指導者', '子どもたちに野球を教える。長く続けた経験と家族が効く。');

  const AfterPath(this.label, this.description);
  final String label;
  final String description;

  static AfterPath? parse(String? s) {
    for (final p in AfterPath.values) {
      if (p.name == s) return p;
    }
    return null;
  }
}

/// 結果の段階: 0=地道に歩む・1=成功・2=大成功(名監督・人気解説者・大実業家など)。
class SecondCareer {
  const SecondCareer(this.tier, this.lines);
  final int tier;
  final List<String> lines;

  String get tierLabel => switch (tier) { 2 => '大成功', 1 => '成功', _ => '地道な歩み' };
}

int _hash(String s, int salt) {
  var v = 17 + salt;
  for (final c in s.codeUnits) {
    v = (v * 131 + c) & 0x7fffffff;
  }
  return v;
}

/// 道 `path` で歩んだ、引退後の物語。
SecondCareer secondCareerOf(
  AfterPath path, {
  required String name,
  required int peak,
  required int titles,
  required int championships,
  required int popularity,
  required int money,
  required int proYears,
  required bool married,
  String? team,
}) {
  final t = team ?? '古巣';
  // 道ごとの得点(大きいほど成功)。
  final score = switch (path) {
    AfterPath.manager =>
      peak * 0.5 + championships * 4.0 + titles * 1.5 + popularity * 0.2,
    AfterPath.coach => peak * 0.9 + titles * 2.0 + proYears * 0.5,
    AfterPath.commentator => popularity * 0.9 + titles * 2.5 + peak * 0.2,
    AfterPath.business => money / 1500.0 + popularity * 0.2,
    AfterPath.teacher => proYears * 3.0 + (married ? 12.0 : 0) + peak * 0.3,
  };
  // 名前から決める小さなばらつき(同じ選手なら同じ)。
  final nudge = (_hash(name, path.index) % 7) - 3.0;
  final s = score + nudge;
  final (hi, lo) = switch (path) {
    AfterPath.manager => (88.0, 62.0),
    AfterPath.coach => (82.0, 60.0),
    AfterPath.commentator => (80.0, 52.0),
    AfterPath.business => (80.0, 28.0),
    AfterPath.teacher => (74.0, 48.0),
  };
  final tier = s >= hi ? 2 : (s >= lo ? 1 : 0);
  final v = _hash(name, 99 + path.index) % 3; // 文面のばらつき
  final lines = switch (path) {
    AfterPath.manager => switch (tier) {
        2 => [
            '$tのコーチを経て、監督に就任した。',
            '就任3年目にチームをリーグ優勝へ導き、「名将」と呼ばれるようになった。',
            '$nameの野球は、のちの世代の手本になった。',
          ],
        1 => [
            '$tのコーチを経て、監督に就任した。',
            '${[
              'Aクラスの常連に育て上げ',
              '若手を次々に一軍へ送り出し',
              '粘り強い野球でチームを立て直し'
            ][v]}、球団からの信頼を得た。',
          ],
        _ => [
            '$tの二軍コーチとして、地道に若手を見ている。',
            '監督への道は遠いが、現場を愛して指導を続けている。',
          ],
      },
    AfterPath.coach => switch (tier) {
        2 => [
            '$tのコーチとして、多くの選手を一流に育てた。',
            '教え子の中から、${proYears >= 10 ? 'タイトルを獲る' : '新人王に輝く'}選手が出た。',
            '「$nameの教え」は、球団の財産になった。',
          ],
        1 => [
            '$tのコーチとして、${['打撃', '守備', '投手'][v]}を担当している。',
            '選手たちから頼りにされる存在になった。',
          ],
        _ => [
            '$tで二軍のコーチをしている。',
            '派手さはないが、選手の話をじっくり聞く指導が評判だ。',
          ],
      },
    AfterPath.commentator => switch (tier) {
        2 => [
            '野球解説者として、テレビやラジオに引っ張りだこになった。',
            '現役時代の経験にもとづく解説は、「分かりやすい」と大評判。',
            '${['シーズンの名場面を語る番組', '少年野球を応援する番組', '球場からの生中継'][v]}を任されている。',
          ],
        1 => [
            '野球解説者として、週に数回の仕事をもらっている。',
            '現役時代の話を交えた解説が、ファンに親しまれている。',
          ],
        _ => [
            '解説の仕事は少ないが、講演会や野球教室でファンとふれあっている。',
          ],
      },
    AfterPath.business => switch (tier) {
        2 => [
            '現役時代の資産をもとに、スポーツ関連の事業を起こした。',
            '${[
              '全国に広がるスポーツジム',
              '子ども向けの野球スクール',
              'スポーツ用品のブランド'
            ][v]}が大成功し、実業家として名を成した。',
          ],
        1 => [
            '資産をもとに、小さなスポーツ用品店を開いた。',
            '地域に愛される店になり、経営は順調だ。',
          ],
        _ => [
            '事業を始めたが、うまくいかないこともある。',
            '野球で鍛えた粘り強さで、毎日の仕事に向き合っている。',
          ],
      },
    AfterPath.teacher => switch (tier) {
        2 => [
            '地元の少年野球チームの監督として、子どもたちを指導している。',
            '教え子の中から、プロ入りする選手が出た。',
            '${married ? '家族に支えられながら、' : ''}野球を教える喜びを、今も感じている。',
          ],
        1 => [
            '地元の少年野球チームで、子どもたちに野球を教えている。',
            '「$nameコーチ」と呼ばれ、子どもたちに慕われている。',
          ],
        _ => [
            '休みの日に、近所の子どもたちとキャッチボールをしている。',
            '野球の楽しさを伝える、ささやかな毎日を送っている。',
          ],
      },
  };
  return SecondCareer(tier, lines);
}
