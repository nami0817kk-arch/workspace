// アプリのアイコン（1024×1024・透明なし）を描く。Gemini の絵が届くまでの仮のアイコン。
//   node tool/make_icon.js   → app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-1024.png
let pw;
try { pw = require('playwright'); } catch (e) { pw = require('/opt/node22/lib/node_modules/playwright'); }
const path = require('path');
const OUT = path.join(__dirname, '..', 'app', 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', 'Icon-1024.png');
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <radialGradient id="bg" cx="50%" cy="38%" r="75%"><stop offset="0" stop-color="#7a4f26"/><stop offset=".55" stop-color="#3b2614"/><stop offset="1" stop-color="#1c120a"/></radialGradient>
    <linearGradient id="head" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".45" stop-color="#d9e1ea"/><stop offset="1" stop-color="#8f9aa8"/></linearGradient>
    <linearGradient id="wood" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#8a5326"/><stop offset=".5" stop-color="#c0803f"/><stop offset="1" stop-color="#7a4520"/></linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#ffe9a0" stop-opacity=".95"/><stop offset="1" stop-color="#ffd166" stop-opacity="0"/></radialGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <!-- 地層 -->
  <path d="M0 800 Q256 770 512 790 T1024 780 V1024 H0Z" fill="#5a3a1e"/>
  <path d="M0 880 Q300 860 600 880 T1024 870 V1024 H0Z" fill="#43291a"/>
  <path d="M0 950 Q300 935 640 950 T1024 945 V1024 H0Z" fill="#2c1b10"/>
  <!-- 金の鉱石の光 -->
  <circle cx="742" cy="760" r="170" fill="url(#glow)"/>
  <path d="M672 790 L705 720 L770 700 L818 742 L805 800 L730 820Z" fill="#ffd166" stroke="#8a5a00" stroke-width="10"/>
  <path d="M705 735 l25 -18" stroke="#fff6c4" stroke-width="14" stroke-linecap="round"/>
  <!-- つるはし（柄と頭） -->
  <g transform="rotate(-28 512 520)">
    <rect x="482" y="300" width="60" height="560" rx="22" fill="url(#wood)" stroke="#2b1a0c" stroke-width="12"/>
    <path d="M150 380 Q512 120 874 380 L846 432 Q512 230 178 432Z" fill="url(#head)" stroke="#20160e" stroke-width="16" stroke-linejoin="round"/>
    <rect x="462" y="300" width="100" height="92" rx="14" fill="#5b6470" stroke="#20160e" stroke-width="12"/>
  </g>
  <!-- きらめき -->
  <path d="M300 230 l14 40 40 14 -40 14 -14 40 -14 -40 -40 -14 40 -14Z" fill="#fff6c4" opacity=".9"/>
  <path d="M820 300 l9 26 26 9 -26 9 -9 26 -9 -26 -26 -9 26 -9Z" fill="#fff6c4" opacity=".8"/>
</svg>`;
(async () => {
  const b = await pw.chromium.launch();
  const p = await b.newPage({ viewport: { width: 1024, height: 1024 } });
  await p.setContent(`<html><body style="margin:0">${svg}</body></html>`);
  await p.screenshot({ path: OUT, omitBackground: false, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  await b.close();
  console.log('icon →', OUT);
})();
