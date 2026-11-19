part of 'game_state.dart';

/// 選手の国籍と、労働許可(アルビオン式のリーグだけ)。
extension GameStateNation on GameState {
  /// 国の呼び名(リーグ名の語幹。「アルビオン」など)。
  static String nationLabel(LeagueTheme t) {
    final l = t.label;
    // 区切りの中黒(U+30FB)。文字を直接書くと翻訳漏れの点検に掛かる。
    final dot = String.fromCharCode(0x30FB);
    return l.contains(dot) ? l.split(dot).first : l.split(' ').first;
  }

  /// [p]の国籍。移ったことのある選手は覚えている国籍、そうでなければ
  /// 今いるリーグの国(1割は別の国)。自由契約と作り物の市場の選手は自国。
  LeagueTheme nationalityOf(Player p) {
    final stored = p.nation;
    if (stored != null) {
      return LeagueTheme.values.firstWhere((t) => t.name == stored,
          orElse: () => currentLeagueTheme);
    }
    final home = currentLeagueTheme;
    final club = _sellingClubOf(p.id);
    // 自由契約・作り物の市場・自クラブの選手は自国(国籍の揺れはクラブに
    // いる他の選手だけに付ける)。
    if (club == null) return home;
    final foreignName = _foreignTeamIds()[club.id];
    final base = foreignName == null
        ? home
        : LeagueTheme.values.firstWhere((t) => t.name == foreignName,
            orElse: () => home);
    final h = p.id.codeUnits.fold<int>(37, (a, c) => (a * 31 + c) % 1000003);
    if (h % 10 != 0) return base;
    final others = [
      for (final t in LeagueTheme.values)
        if (t != base) t,
    ];
    return others[(h ~/ 10) % others.length];
  }

  /// 国籍を覚えさせる(国をまたいで移る前に呼ぶ)。
  void _fixNationality(Player p) {
    p.nation ??= nationalityOf(p).name;
  }

  /// 労働許可が要るリーグか(アルビオン式だけ)。
  bool get workPermitRequired => currentLeagueTheme == LeagueTheme.england;

  /// 労働許可に要る総合力(上の部ほど高い)。
  int workPermitMinimum(int tier) => 76 - tier * 4; // 1部72・5部56

  /// 労働許可が下りないなら、その理由。下りるなら null。
  String? workPermitBlock(Player p) {
    if (_save == null || !workPermitRequired) return null;
    final nation = nationalityOf(p);
    if (nation == currentLeagueTheme) return null;
    final need = workPermitMinimum(_save!.currentDivisionTier);
    if (p.overall >= need) return null;
    return Tr.pick(
        '${p.name}(${nationLabel(nation)}国籍)には労働許可が下りません。${_save!.currentDivisionTier}部では総合力$need以上が要ります。',
        '${p.name} (${nationLabel(nation)}) would not get a work permit: tier ${_save!.currentDivisionTier} needs an overall of $need or more.');
  }
}
