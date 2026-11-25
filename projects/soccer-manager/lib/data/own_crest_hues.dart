// 生成物。手で直さない(tool/art/build_own_crests.py が作る)。

/// 自クラブ用のエンブレム画像(assets/crests/own_NN.webp)の2色の色相。
/// 番号 i の色は [i * 2](地)と [i * 2 + 1](差し色)。-1 は白・黒・灰。
const List<int> kOwnCrestHues = [
  225, 200, // 00 sunrise-waves
  350, 45, // 01 phoenix
  150, -1, // 02 mountain-pine
  -1, 30, // 03 fox
  220, 55, // 04 lightning
  275, 45, // 05 crown
  180, 10, // 06 koi
  -1, 0, // 07 crane
  30, 225, // 08 tiger
  200, 225, // 09 swallow
  350, -1, // 10 kabuto
  55, -1, // 11 hawk
  120, 45, // 12 oak-leaf
  225, 45, // 13 anchor-star
  0, -1, // 14 horse
  230, -1, // 15 wolf-moon
  245, 340, // 16 sakura
  70, 45, // 17 castle-tower
  190, -1, // 18 dolphin
  45, 25, // 19 lion
  315, 45, // 20 dragon
  130, 55, // 21 stag
  -1, 0, // 22 flame
  -1, 225, // 23 compass
  215, 30, // 24 eagle
];

const int kOwnCrestCount = 25;
