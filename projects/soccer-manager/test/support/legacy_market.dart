import 'package:soccer_manager/logic/transfer_market.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

/// 獲得の仕組み(買う・値切る・分割・ローン)だけを確かめるテストのために、
/// 作り物の市場に選手を置く。ゲームはもう市場を作らない(相手は他の
/// クラブの選手)が、獲得の関数は先に市場を見るので、置けば同じ選手で
/// 何度でも確かめられる。
List<Player> legacyMarket(GameState game) {
  if (game.transferMarket.isEmpty) {
    game.transferMarket =
        TransferMarket.generate(home: game.currentLeagueTheme);
  }
  return game.transferMarket;
}
