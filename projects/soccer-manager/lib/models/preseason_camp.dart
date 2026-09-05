import '../l10n/tr.dart';

/// シーズン前のキャンプ方針。
///
/// 開幕前の数週間をどう使うか。これまでは何もせずシーズンが始まっていた。
/// どれを選んでも良いことばかり、にはしない。伸ばすものと引き換えに
/// 何かを削る形にして、その年のチーム作りの方向を決める判断にする。
enum PreseasonCamp {
  /// キャンプを張らない。費用も掛からず、選手は休養して開幕を迎える。
  none,

  /// フィジカル重視。持久力と実戦感覚が仕上がるが、疲れを残して開幕する。
  fitness,

  /// 戦術の作り込み。布陣の習熟が大きく進むが、身体は仕上がらない。
  tactical,

  /// 若手中心の遠征。若い選手が伸びるが、主力の仕上がりは犠牲になる。
  youth,
}

extension PreseasonCampInfo on PreseasonCamp {
  String get label => switch (this) {
        PreseasonCamp.none => Tr.pick('キャンプを張らない', 'No camp'),
        PreseasonCamp.fitness => Tr.pick('フィジカル重視', 'Fitness camp'),
        PreseasonCamp.tactical => Tr.pick('戦術の作り込み', 'Tactical camp'),
        PreseasonCamp.youth => Tr.pick('若手中心の遠征', 'Youth tour'),
      };

  String get description => switch (this) {
        PreseasonCamp.none => Tr.pick('費用は掛からず、選手は休養して開幕を迎える。',
            'Nothing spent. The players come in rested.'),
        PreseasonCamp.fitness => Tr.pick('実戦感覚が大きく戻るが、疲れを残して開幕する。',
            'They come in sharp, but carrying some tiredness.'),
        PreseasonCamp.tactical => Tr.pick('布陣の習熟が大きく進むが、身体は仕上がらない。',
            'The shape beds in, but they are not physically ready.'),
        PreseasonCamp.youth => Tr.pick('23歳以下が伸びるが、主力の仕上がりは犠牲になる。',
            'The under-23s come on. The senior men do not.'),
      };

  /// 費用(万円)。
  int get cost => switch (this) {
        PreseasonCamp.none => 0,
        PreseasonCamp.fitness => 300,
        PreseasonCamp.tactical => 300,
        PreseasonCamp.youth => 200,
      };

  /// 全選手の実戦感覚への加算。
  int get sharpnessGain => switch (this) {
        PreseasonCamp.none => 0,
        PreseasonCamp.fitness => 25,
        PreseasonCamp.tactical => 8,
        PreseasonCamp.youth => 5,
      };

  /// 開幕時に残る疲労。
  int get fatigueCost => switch (this) {
        PreseasonCamp.none => 0,
        PreseasonCamp.fitness => 18,
        PreseasonCamp.tactical => 6,
        PreseasonCamp.youth => 8,
      };

  /// 布陣の習熟度への加算。
  int get familiarityGain => switch (this) {
        PreseasonCamp.none => 0,
        PreseasonCamp.fitness => 0,
        PreseasonCamp.tactical => 20,
        PreseasonCamp.youth => 0,
      };

  /// 23歳以下の選手が受け取る成長の機会(確率)。
  double get youthGrowthChance => switch (this) {
        PreseasonCamp.youth => 0.5,
        _ => 0.0,
      };
}
