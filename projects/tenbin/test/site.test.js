// 公開ページ（legal/・site/）の確かめ。App Store の URL 欄とアプリのリンクがここを指す。
// docs/public-identity.md: 名義はつるはし社・連絡先は info[at]dailyquarry.com を素の文字で・mailto を使わない・個人名を出さない
// docs/app-pitfalls.md 8番: robots.txt を実体で置く（無いと app-ads.txt が読まれないことがある）
var assert = require('assert'), fs = require('fs'), path = require('path');
var R = path.join(__dirname, '..');
['legal/privacy.html', 'legal/support.html', 'legal/terms.html', 'site/index.html', 'site/404.html'].forEach(function (f) {
  var s = fs.readFileSync(path.join(R, f), 'utf8');
  assert.ok(s.indexOf('もじつみ') >= 0, f + ' に名前が無い');
  assert.ok(s.indexOf('mailto:') < 0, f + ' で mailto を使っている');
  assert.ok(!/nami|0817|なみ/i.test(s.replace(/dailyquarry/g, '')), f + ' に個人名が出ている');
  if (f.indexOf('legal/') === 0) { assert.ok(s.indexOf('つるはし社') >= 0, f + ' に名義が無い'); assert.ok(s.indexOf('info[at]dailyquarry.com') >= 0, f + ' に連絡先が無い'); }
});
var robots = fs.readFileSync(path.join(R, 'site/robots.txt'), 'utf8');
assert.ok(/User-agent: Google-adstxt/.test(robots) && robots.indexOf('<') < 0, 'robots.txt が実体のテキストでない');
assert.ok(/^google\.com, pub-\d{16}, DIRECT, f08c47fec0942fa0\s*$/.test(fs.readFileSync(path.join(R, 'site/app-ads.txt'), 'utf8')), 'app-ads.txt の形が違う');
// アプリが開くページはすべて公開ページにある
var html = fs.readFileSync(path.join(R, 'prototype/index.html'), 'utf8');
(html.match(/SITE \+ '\/([a-z]+\.html)'/g) || []).forEach(function (m) { var f = m.match(/\/([a-z]+\.html)/)[1]; assert.ok(fs.existsSync(path.join(R, 'legal', f)), 'アプリが開く ' + f + ' が legal/ に無い'); });
assert.ok(/var SITE = 'https:\/\/mojitsumi\.pages\.dev'/.test(html), '公開ページの場所が tenbin-site.yml と違う');
console.log('site ok');
