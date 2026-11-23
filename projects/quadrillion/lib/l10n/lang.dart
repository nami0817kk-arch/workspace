/// 今の言語（'ja' か 'en'）。仕組み（lib/game）も画面も、文を組み立てるときにここを見る。
/// 画面側（GameController）が端末の言語か設定から決めて書き換える。Flutter に依存しない。
library;

class L {
  static String lang = 'ja';
  static bool get en => lang == 'en';
}
