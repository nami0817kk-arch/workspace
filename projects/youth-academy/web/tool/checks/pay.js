// 課金・広告・保存まわり（shop.js）のページ側の点検。2026-11-17 の点検役の報告（課金の分野）を直したもの。
'use strict';
module.exports = (YA, ok) => {
  const sent = [];
  const withBridge = (fn) => {
    globalThis.YouthApp = { postMessage: (m) => sent.push(JSON.parse(m)) };
    try { fn(); } finally { delete globalThis.YouthApp; }
  };
  const mem = {};
  const st = { get: (k, d) => (mem[k] != null ? mem[k] : d), set: (k, v) => { mem[k] = v; return true; } };
  const spec = (name) => ({ name, pos: 'CM', foot: 'R', stars: 3, face: null, pers: {} });

  // 2. オリジナル選手が3人そろっていたら、チケットを使う前に止まる
  {
    YA.entSet({ tickets: 5 });
    const w = YA.newWorld(301);
    w.originals = [spec('甲'), spec('乙'), spec('丙')];
    ok(YA.origFull(w) && /3人まで/.test(YA.origValid(w, spec('丁')) || ''), '課金: 3人そろっていたら入力の確かめで止まる（チケットを使う前）');
    ok(!YA.origCreate(w, spec('丁')).ok && w.originals.length === 3, '課金: 3人そろっていたら予定に入らない');
    YA.entSet(null);
  }

  // 12. 通し番号でチケットの使用の記録と突き合わせる（書き出しの復元で増やせない）
  {
    const ent = { used: 3, spent: [1] };
    const list = [{ name: 'a', serial: 1 }, { name: 'b', serial: 2 }, { name: 'c', serial: 2 }, { name: 'd', serial: 4 }, { name: 'e' }];
    const keep = YA.origFilter(list, ent, false).map((o) => o.name).join();
    ok(keep === 'b', '課金: 迎え済み・重複・使っていない番号・番号なしは復元で戻らない ' + keep);
    ok(YA.origFilter(list, ent, true).map((o) => o.name).join() === 'b,e', '課金: 前の版の予約（番号なし）は、ふだんの入団では残す');
    // 入団で迎えたら、その番号を Flutter に控えてもらう
    YA.entSet({ used: 2, spent: [] });
    const w = YA.newWorld(302);
    w.scouting = YA.newScouting();
    w.originals = [Object.assign(spec('通し 一郎'), { serial: 2 }), Object.assign(spec('通し 二郎'), { serial: 2 })];
    sent.length = 0;
    withBridge(() => YA.intake(w, YA.rngOf(3), new Set(Object.values(w.players).map((p) => p.name))));
    const names = Object.values(w.players).map((p) => p.name);
    ok(names.includes('通し 一郎') && !names.includes('通し 二郎'), '課金: 同じ番号の予約は1人しか迎えない');
    ok(sent.some((m) => m.cmd === 'ticketSpent' && m.serials.join() === '2') && YA.ent.spent.includes(2), '課金: 迎えた番号を Flutter へ控えに出す');
    ok(w.originals.length === 0, '課金: 迎えたら予定は空になる');
    YA.entSet(null);
  }

  // 4. 見終えた動画の特典：読み直しの後でも渡り、二度は渡らない。受け取ったら Flutter の控えを消す
  {
    const w = YA.newWorld(303);
    const p = Object.values(w.players)[0];
    p.fat = 50;
    sent.length = 0;
    let t1, t2;
    withBridge(() => {
      t1 = YA.claimReward(w, 123, { k: 'rest' }, st);
      t2 = YA.claimReward(w, 123, { k: 'rest' }, st);
    });
    ok(t1 && p.fat === 38 && t2 == null, '課金: 同じ動画の特典は一度だけ ' + p.fat);
    ok(sent.filter((m) => m.cmd === 'adClaimed' && m.tag === 123).length === 2, '課金: 受け取ったら（二度目でも）Flutter の控えを消す');
    ok(mem.adday && mem.adday.n === 1 && mem.adday.d === YA.localDay(), '課金: 1日の回数は端末の日付で1回だけ数える');
    ok(YA.claimReward(null, 124, { k: 'rest' }, st) == null, '課金: 世界が無いときは受け取らない（控えを残して次に渡す）');
    // 候補の見立て
    w.scouting = w.scouting || YA.newScouting();
    const c = { id: 'cx', p, kind: 'scout', seen: 1, status: 'open' };
    w.scouting.cands = [c];
    withBridge(() => YA.claimReward(w, 125, { k: 'boost', cid: 'cx' }, st));
    ok(c.boost === true, '課金: 候補の見立ての特典が、その候補に付く');
    // Flutter から読み直し後に届く控え（adUnclaimed）も同じ道
    const app = YA._ui ? YA._ui.app : null;
    if (!app) {
      const saved = YA._ui;
      YA._ui = { app: { w }, store: st, render: () => {} };
      const f0 = p.fat;
      withBridge(() => globalThis.YAnative.onMsg(JSON.stringify({ ev: 'adUnclaimed', list: [{ tag: 777, reward: { k: 'rest' } }] })));
      ok(p.fat === Math.max(0, f0 - 12) && w.adClaimed.includes(777), '課金: 読み直しの前に見終えた動画の特典が、挨拶のあとに渡る');
      YA._ui = saved;
    }
  }

  // 4. 動画の番号は読み直しの後も重ならない（前のページの控えと取り違えない）
  {
    const tags = [];
    withBridge(() => {
      sent.length = 0;
      YA.watchReward({ get: (k, d) => d, set: () => true }, { k: 'rest' }, () => {});
      YA.watchReward({ get: (k, d) => d, set: () => true }, { k: 'rest' }, () => {});
      for (const m of sent) if (m.cmd === 'ad') tags.push(m.tag);
    });
    ok(tags.length === 2 && tags[0] !== tags[1] && tags[0] > 1e12 && sent[0].reward.k === 'rest', '課金: 動画の番号は時刻から作り、特典の中身も Flutter に預ける');
  }

  // 9・13. 価格が取れていない商品・上限の商品は買えず、理由が付く
  {
    withBridge(() => {
      YA.shopPrices = {};
      YA.entSet(null);
      const ads = YA.SHOP.find((x) => x.id === 'youth_remove_ads');
      ok(/ストアに接続中/.test(YA.buyWhy(ads) || ''), '課金: 価格が取れていない商品は押せず「ストアに接続中」');
      YA.shopPrices = { youth_remove_ads: '¥610', youth_keen_eye: '¥800', youth_save_slot: '¥250', youth_ticket_1: '¥250', youth_ticket_3: '¥610' };
      ok(YA.buyWhy(ads) === null, '課金: 価格が取れたら押せる');
      YA.entSet({ slots: 4, tickets: 97 });
      ok(/5枠/.test(YA.buyWhy(YA.SHOP.find((x) => x.id === 'youth_save_slot')) || ''), '課金: セーブ枠が上限なら買えない');
      ok(YA.buyWhy(YA.SHOP.find((x) => x.id === 'youth_ticket_1')) === null && /99枚/.test(YA.buyWhy(YA.SHOP.find((x) => x.id === 'youth_ticket_3')) || ''), '課金: チケットが上限を超える買い方はできない');
      sent.length = 0;
      ok(YA.askPrices() === false, '課金: 価格がそろっていれば取り直さない');
      YA.shopPrices = {};
      ok(YA.askPrices() === true && sent.some((m) => m.cmd === 'prices') && YA.askPrices() === false, '課金: ショップを開いたら価格を取り直す（続けては頼まない）');
    });
    ok(!/円/.test(YA.SHOP.map((x) => YA.shopPrices[x.id] || '').join('')), '課金: 決め打ちの値段は出さない');
    YA.shopPrices = {};
    YA.entSet(null);
  }

  // 3. 消費型（枠・チケット）は、この端末だけ・復元では戻らないとはっきり書く
  ok(YA.SHOP.filter((x) => !x.once).every((x) => /この端末だけ/.test(x.note) && /購入の復元でも戻りません/.test(x.note)), '課金: 枠とチケットの説明に「この端末だけ・復元では戻らない」');

  // 10. 復元を打ち切ったときは「確認中」
  YA.onNative({ ev: 'restore', outcome: 'pending' });
  ok(/確認中です。届いたら反映されます/.test(YA.shopMsg), '課金: 復元を打ち切ったら「確認中です。届いたら反映されます」');
  YA.onNative({ ev: 'purchase', outcome: 'undelivered' });
  ok(/受け取りに失敗/.test(YA.shopMsg), '課金: 受け取りに失敗したら失敗の文言');
  YA.shopMsg = '';

  // 「1日3回」は端末の日付で数える
  ok(/^\d{4}-\d{2}-\d{2}$/.test(YA.localDay()) && YA.localDay() === `${new Date().getFullYear()}-${String(new Date().getMonth() + 1).padStart(2, '0')}-${String(new Date().getDate()).padStart(2, '0')}`, '課金: ご褒美の回数は端末の日付で数える');
};
