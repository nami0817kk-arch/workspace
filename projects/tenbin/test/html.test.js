// 画面（prototype/index.html）の静的な確かめ: 読み込むファイルが揃っている・名前が「もじつみ」・外向きの文字の決まり
// （docs/public-identity.md: 個人名を出さない・mailto: を使わない）
var assert = require('assert'), fs = require('fs'), path = require('path');
var dir = path.join(__dirname, '../prototype'), html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');
var refs = []; html.replace(/<(?:script|link)[^>]+(?:src|href)="([^"]+)"/g, function (m, u) { refs.push(u); });
refs.filter(function (u) { return !/^https?:/.test(u); }).forEach(function (u) { assert.ok(fs.existsSync(path.join(dir, u)), '読み込むファイルが無い: ' + u); });
fs.readFileSync(path.join(dir, 'fonts/kana.css'), 'utf8').replace(/url\(([^)]+)\)/g, function (m, u) { assert.ok(fs.existsSync(path.join(dir, 'fonts', u.replace(/['"]/g, ''))), 'フォントが無い: ' + u); });
assert.ok(/<title>もじつみ<\/title>/.test(html), 'title が もじつみ でない');
assert.ok(html.indexOf('ひらがなてんびん') < 0, '古い仮の名前が残っている');
assert.ok(html.indexOf('mailto:') < 0, 'mailto: は使わない（docs/public-identity.md）');
assert.ok(html.indexOf('つるはし社') >= 0, '名義（つるはし社）がクレジットに無い');
// getElementById で探す名前が、HTML か 作る画面の文字列のどこかにある
var ids = {}; html.replace(/getElementById\('([^']+)'\)/g, function (m, id) { ids[id] = 1; });
Object.keys(ids).forEach(function (id) { assert.ok(html.indexOf('id="' + id + '"') >= 0, 'id が無い: ' + id); });
console.log('html ok');
