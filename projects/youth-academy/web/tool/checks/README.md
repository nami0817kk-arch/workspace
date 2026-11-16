# 分野ごとの点検

`tool/world.js` が、このフォルダの `*.js` を名前順に読みます。1つのファイルは

```js
module.exports = (YA, ok) => {
  ok(条件, '何を確かめたか');
};
```

の形にします。`YA` は world.js が src をすべて読み込んだあとのもの。
