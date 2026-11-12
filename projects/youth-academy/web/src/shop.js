// 3段目「仕上げ」（決定124・125・130・131・94）：課金4つ・広告・セーブ枠・オリジナル選手。
// 課金と広告の本物は Flutter 側（app/lib/monetization）が持つ。ここは「橋」と「特典の中身」と「画面」だけ。
// 権利（広告を消す・見抜く目・セーブ枠・チケット）は Flutter が端末に保存し、届いたら ent として渡してくる（書き込むのは Flutter だけ）。
// ブラウザで開いたとき（Flutter の外）は購入も広告も出ず、権利は空のまま。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 権利 ----------
  YA.ENT0 = { noAds: false, eye: false, slots: 0, tickets: 0 };
  YA.ent = Object.assign({}, YA.ENT0);
  YA.entSet = function (e) {
    const x = Object.assign({}, YA.ENT0, e && typeof e === 'object' ? e : {});
    YA.ent = { noAds: !!x.noAds, eye: !!x.eye, slots: clamp(x.slots | 0, 0, 4), tickets: clamp(x.tickets | 0, 0, 99) };
    return YA.ent;
  };
  // セーブ枠：最初は1枠。買うたびに+1（最大5）
  YA.SLOT_MAX = 5;
  Object.defineProperty(YA, 'SLOT_COUNT', { configurable: true, get: () => 1 + clamp(YA.ent.slots | 0, 0, YA.SLOT_MAX - 1), set: () => {} });

  // ---------- 商品（値段は決定124。ストアでは App Store Connect の価格が正で、画面にはストアの表示価格を出す） ----------
  YA.SHOP = [
    { id: 'youth_remove_ads', key: 'noAds', name: '広告を消す', price: 610, once: true, note: '全画面の広告が出なくなります（ご褒美の動画は残ります）。買い切り。' },
    { id: 'youth_keen_eye', key: 'eye', name: '見抜く目', price: 800, once: true, note: '伸びしろの幅が狭まり、候補の性格と向いたポジションが早く分かります。買い切り。' },
    { id: 'youth_save_slot', key: 'slot', name: 'セーブ枠の追加', price: 250, once: false, note: '1枠ふえます（最大5枠）。枠ごとに別のクラブで遊べます。' },
    { id: 'youth_ticket_1', key: 'ticket', name: 'オリジナル選手チケット（1枚）', price: 250, once: false, note: '名前・顔・ポジション・性格・伸びしろを決めた選手を、来年度の新入生に迎えます。' },
    { id: 'youth_ticket_3', key: 'ticket3', name: 'オリジナル選手チケット（3枚まとめ）', price: 610, once: false, note: '3枚ぶん。1枚ずつ買うより安くなります。' },
  ];
  YA.shopPrices = {}; // ストアの表示価格 { productId: '¥610' }

  // ---------- Flutter との橋 ----------
  // 送る：YouthApp.postMessage(JSON)。受ける：Flutter が YAnative.onMsg(JSON) を呼ぶ
  YA.native = {
    has: () => !!(globalThis.YouthApp && typeof globalThis.YouthApp.postMessage === 'function'),
    post(o) {
      try { if (this.has()) { globalThis.YouthApp.postMessage(JSON.stringify(o)); return true; } } catch (e) { /* 橋が無い */ }
      return false;
    },
  };
  YA.shopMsg = ''; // 画面に出す直近の結果
  YA.onNative = function (ev) {
    if (!ev || typeof ev !== 'object') return;
    if (ev.ev === 'ent') { YA.entSet(ev.v); if (YA.bgm) YA.bgm.unlock(); }
    else if (ev.ev === 'prices') YA.shopPrices = Object.assign({}, ev.map || {});
    else if (ev.ev === 'purchase') YA.shopMsg = { purchased: '購入できました', pending: '保護者の承認待ちです。承認されると届きます', canceled: '購入を取りやめました', unavailable: 'いまはストアに繋がりません', failed: '購入に失敗しました' }[ev.outcome] || '';
    else if (ev.ev === 'restore') YA.shopMsg = ev.outcome === 'purchased' ? '購入を復元しました' : ev.outcome === 'unavailable' ? '復元できる購入が見つかりませんでした' : '復元できませんでした';
    else if (ev.ev === 'adDone') { const f = adWait[ev.tag]; delete adWait[ev.tag]; if (f) f(ev.result); }
    if (YA._ui && YA._ui.render) { try { YA._ui.render(); } catch (e) { /* 画面なし */ } }
  };
  globalThis.YAnative = { onMsg: (s) => { try { YA.onNative(typeof s === 'string' ? JSON.parse(s) : s); } catch (e) { /* 壊れた通知は捨てる */ } } };
  YA.shopStart = function () {
    if (!YA.native.has()) return;
    YA.native.post({ cmd: 'hello', ids: YA.SHOP.map((x) => x.id) });
  };
  YA.buy = (id) => YA.native.post({ cmd: 'buy', id });
  YA.restorePurchases = () => YA.native.post({ cmd: 'restore' });

  // ---------- 広告（決定130） ----------
  // 全画面：試合のあと3試合に1回と、月の区切りに1回。最初の4週は出さない。「広告を消す」で消える。
  // ご褒美の動画：選んだときだけ。1日3回まで。「広告を消す」を買っても残る。
  YA.AD = { everyMatches: 3, rewardPerDay: 3, graceWeeks: 4 };
  YA.interstitialDue = function (w, why) {
    if (!w || YA.ent.noAds) return false;
    if (w.year === 1 && w.week <= YA.AD.graceWeeks) return false;
    if (why === 'match') { w.adMatches = (w.adMatches || 0) + 1; return w.adMatches % YA.AD.everyMatches === 0; }
    return why === 'month';
  };
  YA.adPending = false;
  const wk0 = YA.endWeek;
  if (wk0) {
    YA.endWeek = function (w) {
      const m0 = YA.monthIdx(w.week);
      const r = wk0.apply(this, arguments);
      // 月の区切り（週が進んで月が替わった）
      if (YA.monthIdx(w.week) !== m0 && YA.interstitialDue(w, 'month')) YA.adPending = true;
      w.sharpEye = !!YA.ent.eye; // 見抜く目（伸びしろの幅が狭まる）
      return r;
    };
  }
  const am0 = YA.applyMatch;
  if (am0) {
    YA.applyMatch = function (w) {
      const r = am0.apply(this, arguments);
      if (YA.interstitialDue(w, 'match')) YA.adPending = true;
      return r;
    };
  }
  YA.flushAd = function () {
    if (!YA.adPending) return false;
    YA.adPending = false;
    return YA.native.post({ cmd: 'ad', kind: 'interstitial', tag: 0 });
  };
  // ご褒美の動画
  const adWait = {};
  let adTag = 0;
  const today = () => new Date().toISOString().slice(0, 10);
  YA.rewardLeft = function (store) {
    const d = store.get('adday', null);
    return d && d.d === today() ? Math.max(0, YA.AD.rewardPerDay - d.n) : YA.AD.rewardPerDay;
  };
  YA.REWARDS = [
    { k: 'rest', name: '疲れを抜く', note: 'いまいる全員の疲れが少し抜けます', run: (w) => { for (const p of Object.values(w.players)) p.fat = Math.max(0, (p.fat || 0) - 12); return '全員の疲れ −12'; } },
    { k: 'eye', name: 'スカウトの見立てを詳しく', note: '選んだ候補の幅が狭まり、見立てが付きやすくなります（候補の画面から）', run: null },
  ];
  // 動画を見て、見終えたら特典を渡す（結果は Flutter から adDone で届く）
  YA.watchReward = function (store, done) {
    if (!YA.native.has()) return done('unavailable');
    if (YA.rewardLeft(store) <= 0) return done('limit');
    const tag = ++adTag;
    adWait[tag] = (res) => {
      if (res === 'earned') { const d = store.get('adday', null); store.set('adday', { d: today(), n: (d && d.d === today() ? d.n : 0) + 1 }); }
      done(res);
    };
    YA.native.post({ cmd: 'ad', kind: 'rewarded', tag });
  };
  YA.rewardMsg = (res) => ({ earned: '見終えました。特典が入ります', limit: '今日の分は終わりました（1日3回まで）', unavailable: 'いま見られる動画がありません。あとでもう一度', closedEarly: '途中で閉じたので、特典は入りません', showFailed: '動画を表示できませんでした' }[res] || '');

  // 見抜く目・動画で詳しく：候補を「もう少し見た」ことにして見え方を進める
  const cv0 = YA.candView;
  if (cv0) {
    YA.candView = function (w, c) {
      const add = (c && YA.ent.eye ? 1 : 0) + (c && c.boost ? 2 : 0);
      if (!add) return cv0.apply(this, arguments);
      c.seen += add;
      try { return cv0.apply(this, arguments); } finally { c.seen -= add; }
    };
  }
  const ch0 = YA.candHunch;
  if (ch0) {
    YA.candHunch = function (w, c) {
      if (!c || !c.boost) return ch0.apply(this, arguments);
      c.seen += 2;
      try { return ch0.apply(this, arguments); } finally { c.seen -= 2; }
    };
  }

  // ---------- オリジナル選手（決定94・125） ----------
  // 名前・顔・ポジション・利き足・性格・伸びしろを決める。入団時の能力は高1並み。次の年度の新入生として入る。
  YA.ORIG_POS = ['GK', 'CB', 'LB', 'RB', 'LWB', 'RWB', 'DM', 'CM', 'LM', 'RM', 'AM', 'LW', 'RW', 'SS', 'ST'];
  YA.ORIG_POT = { 1: 10, 2: 11.5, 3: 13, 4: 15, 5: 17.6 }; // 伸びしろの星 → 能力の平均の上限
  YA.origValid = function (w, spec) {
    const name = String(spec.name || '').trim();
    if (!name || name.length > 12) return '名前は1〜12文字で決めてください';
    if (Object.values(w.players).some((p) => p.name === name) || (w.originals || []).some((o) => o.name === name)) return '同じ名前の子がいます';
    if (YA.ORIG_POS.indexOf(spec.pos) < 0) return 'ポジションを選んでください';
    if (!(spec.stars >= 1 && spec.stars <= 5)) return '伸びしろを決めてください';
    return null;
  };
  YA.origCreate = function (w, spec) {
    const err = YA.origValid(w, spec);
    if (err) return { ok: false, msg: err };
    if (YA.ent.tickets < 1) return { ok: false, msg: 'チケットがありません' };
    if ((w.originals || []).length >= 3) return { ok: false, msg: '来年度に迎えられるオリジナル選手は3人までです' };
    w.originals = (w.originals || []).concat([{ name: String(spec.name).trim(), pos: spec.pos, foot: spec.foot === 'L' ? 'L' : 'R', stars: spec.stars | 0, face: spec.face == null ? null : spec.face | 0, pers: Object.assign({}, spec.pers || {}) }]);
    return { ok: true, tickets: YA.ent.tickets };
  };
  const intake0 = YA.intake;
  if (intake0) {
    YA.intake = function (w, rng, used) {
      const list = w.originals || [];
      if (list.length) {
        w.scouting = w.scouting || YA.newScouting();
        const names = new Set(used);
        const adds = [];
        for (const o of list) {
          const p = YA.genPlayer(rng, 'orig' + (++w.nextId), 1, o.pos, 0, names);
          p.name = o.name;
          names.add(o.name);
          p.main = o.pos;
          p.pos = YA.GROUP[o.pos];
          p.foot = o.foot;
          for (const g of Object.keys(o.pers || {})) if (o.pers[g]) p.pers[g] = o.pers[g];
          if (o.face != null) p.face = o.face;
          const n = (p.pos === 'GK' ? YA.AB_GK : YA.AB_FIELD).length;
          p.pot = Math.max(YA.abSum(p) + 25, Math.round(YA.ORIG_POT[o.stars] * n));
          p._orig = true; // 画面では見分けを付けない（決定125）。印は内部だけ
          adds.push({ id: p.id, p, kind: 'int', prof: null, foreign: false, seen: 3, status: 'signed', rival: false, persSeen: true, amb: 5, where: null });
        }
        w.scouting.cands = adds.concat(w.scouting.cands || []);
        w.originals = [];
      }
      const res = intake0.apply(this, arguments);
      for (const p of Object.values(w.players)) if (p._orig && p.hist && p.hist[0] && /undefined|内部昇格/.test(p.hist[0].t) && p.grade === 1) p.hist[0].t = '入団';
      return res;
    };
  }

  // ---------- 画面（設定の「ショップ」と、ホームのご褒美の動画） ----------
  const U = () => YA._ui;
  const h = (...a) => U().h(...a);
  const rerender = () => U().render();
  const priceOf = (it) => YA.shopPrices[it.id] || `${it.price}円`;
  function stateOf(it) {
    if (it.key === 'noAds') return YA.ent.noAds ? '購入済み' : null;
    if (it.key === 'eye') return YA.ent.eye ? '購入済み' : null;
    if (it.key === 'slot') return YA.ent.slots >= YA.SLOT_MAX - 1 ? '上限（5枠）' : `いま${YA.SLOT_COUNT}枠`;
    return `チケット ${YA.ent.tickets}枚`;
  }
  YA.shopBlock = function (body) {
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, 'ショップ'), h('div', { class: 'note' }, YA.native.has() ? '買い切りは、機種変更や入れ直しのあとに「購入を復元」で戻せます。' : 'ショップはアプリ版（iPhone）で使えます。'));
    for (const it of YA.SHOP) {
      const st = stateOf(it);
      const done = it.once && st === '購入済み';
      body.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;display:flex;align-items:center;gap:6px' },
        h('div', { class: 'grow' }, h('b', {}, it.name), h('div', { class: 'note' }, it.note), st ? h('div', { class: 'note', style: 'color:var(--ink)' }, st) : null),
        done || (it.key === 'slot' && YA.ent.slots >= YA.SLOT_MAX - 1) ? null : h('button', { class: 'btn sm pri', disabled: !YA.native.has(), onclick: () => { YA.shopMsg = ''; YA.buy(it.id); } }, priceOf(it))));
    }
    body.append(h('div', { class: 'row', style: 'gap:6px;margin-top:4px' }, h('button', { class: 'btn sm', disabled: !YA.native.has(), onclick: () => { YA.shopMsg = ''; YA.restorePurchases(); } }, '購入を復元'), h('span', { class: 'note' }, YA.shopMsg || '')));
    YA.origButton(body);
  };
  YA.origButton = function (body) {
    const w = U().app.w;
    if (!w) return;
    const n = (w.originals || []).length;
    body.append(h('div', { class: 'row', style: 'gap:6px;margin-top:6px' }, h('button', { class: 'btn sm', disabled: YA.ent.tickets < 1, onclick: () => origModal() }, 'オリジナル選手を作る'), h('span', { class: 'note' }, `チケット${YA.ent.tickets}枚／来年度に迎える予定 ${n}人`)));
    if (n) body.append(h('div', { class: 'note' }, (w.originals || []).map((o) => `${o.name}（${YA.POS_LABEL ? YA.POS_LABEL[o.pos] || o.pos : o.pos}・伸びしろ${'★'.repeat(o.stars)}）`).join('、')));
  };
  function origModal() {
    const w = U().app.w;
    const st = { name: '', pos: 'CM', foot: 'R', stars: 3, face: null, pers: {}, msg: '' };
    const PERS = YA.PERS_W || {};
    YA._v.modal((close) => {
      const box = h('div', { class: 'sheet-in', style: 'flex:none;align-self:center;margin:auto;width:min(560px,96%);max-height:94%;padding:10px 12px;gap:6px;overflow:auto' });
      const draw = () => {
        const FN = (YA.IMG && YA.IMG.faces && YA.IMG.faces.length) || 0;
        box.replaceChildren(
          h('div', { class: 'row' }, h('div', { class: 'h grow' }, 'オリジナル選手を作る'), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
          h('div', { class: 'note' }, '来年度の新入生として入ります。能力は高1並みで、伸びしろを決めても育てないと届きません。'),
          h('div', { class: 'row', style: 'gap:6px' }, h('span', {}, '名前'), h('input', { type: 'text', value: st.name, maxlength: 12, style: 'flex:1;padding:5px;border:1px solid var(--line);border-radius:6px', oninput: (e) => { st.name = e.target.value; } })),
          h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' }, h('span', { class: 'sub', style: 'width:60px' }, 'ポジション'), ...YA.ORIG_POS.map((p) => h('button', { class: 'btn sm' + (st.pos === p ? ' on' : ''), onclick: () => { st.pos = p; draw(); } }, (YA.POS_LABEL && YA.POS_LABEL[p]) || p))),
          h('div', { class: 'row', style: 'gap:4px' }, h('span', { class: 'sub', style: 'width:60px' }, '利き足'), ...[['R', '右'], ['L', '左']].map(([k, n]) => h('button', { class: 'btn sm' + (st.foot === k ? ' on' : ''), onclick: () => { st.foot = k; draw(); } }, n))),
          h('div', { class: 'row', style: 'gap:4px' }, h('span', { class: 'sub', style: 'width:60px' }, '伸びしろ'), ...[1, 2, 3, 4, 5].map((n) => h('button', { class: 'btn sm' + (st.stars === n ? ' on' : ''), onclick: () => { st.stars = n; draw(); } }, '★'.repeat(n)))),
          FN ? h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap' }, h('span', { class: 'sub', style: 'width:60px' }, '顔'), h('button', { class: 'btn sm' + (st.face == null ? ' on' : ''), onclick: () => { st.face = null; draw(); } }, 'おまかせ'), ...Array.from({ length: Math.min(FN, 8) }, (_, i) => h('button', { class: 'btn sm' + (st.face === i ? ' on' : ''), onclick: () => { st.face = i; draw(); } }, YA.faceEl ? YA.faceEl(w, { id: 'x' + i, name: '', pos: YA.GROUP[st.pos], face: i }, 30) || String(i + 1) : String(i + 1)))) : null,
          h('div', { class: 'h', style: 'margin-top:4px' }, '性格（選ばなければ「ふつう」）'),
          ...Object.keys(PERS).map((g) => h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap' }, h('span', { class: 'sub', style: 'width:96px;font-size:10.5px' }, g), ...Object.keys(PERS[g]).map((t) => h('button', { class: 'btn sm' + ((st.pers[g] || 'ふつう') === t ? ' on' : ''), style: 'padding:2px 6px;min-height:26px;font-size:11px', onclick: () => { st.pers[g] = t; draw(); } }, t)))),
          h('div', { class: 'row', style: 'gap:6px;margin-top:6px' }, h('button', { class: 'btn pri', onclick: () => {
            const r = YA.origValid(w, st) || (YA.ent.tickets < 1 ? 'チケットがありません' : null);
            if (r) { st.msg = r; draw(); return; }
            // チケットを1枚使う（権利の書き込みは Flutter だけ。先に届けてから予定に入れる）
            if (YA.native.has()) { YA.native.post({ cmd: 'useTicket' }); YA.ent.tickets = Math.max(0, YA.ent.tickets - 1); } else { st.msg = 'アプリ版でのみ作れます'; draw(); return; }
            const res = YA.origCreate(w, Object.assign({}, st, { _ok: 1 }));
            if (!res.ok) { st.msg = res.msg; draw(); return; }
            YA.saveWorld(true);
            close();
            rerender();
          } }, 'この子を迎える（チケット1枚）'), h('span', { class: 'note', style: 'color:#c0392b' }, st.msg)));
      };
      draw();
      return box;
    });
  }
  // ご褒美の動画（ホームの右列に足す）
  YA.rewardCard = function (w) {
    const st = U().store;
    const left = YA.rewardLeft(st);
    const card = h('div', { class: 'card', style: 'padding:6px 9px;margin-top:6px' }, h('div', { class: 'h' }, 'ご褒美の動画'));
    const msg = h('div', { class: 'note' }, YA.native.has() ? `今日あと${left}回。見終えると、全員の疲れが少し抜けます。` : 'アプリ版（iPhone）で使えます。');
    card.append(msg, h('button', { class: 'btn sm', disabled: !YA.native.has() || left <= 0, style: 'margin-top:3px', onclick: () => {
      YA.watchReward(st, (res) => {
        let t = YA.rewardMsg(res);
        if (res === 'earned') { t += '：' + YA.REWARDS[0].run(w); YA.saveWorld(); }
        msg.textContent = t;
        rerender();
      });
    } }, '動画を見る'));
    return card;
  };
  YA.views = YA.views || {};
  const homeBase = YA.views.home;
  if (homeBase && !homeBase._shop) {
    const home3 = function (main) {
      homeBase(main);
      const right = main.querySelector('.card.pbody[style*="210px"]');
      if (right && U().app.w) right.append(YA.rewardCard(U().app.w));
    };
    home3._shop = true;
    YA.views.home = home3;
  }
  // 候補の画面：動画で見立てを詳しく
  YA.boostButton = function (w, c, rerenderFn) {
    if (c.boost || c.status !== 'open' || c.seen < 1) return null;
    const st = U().store;
    return h('button', { class: 'btn sm', disabled: !YA.native.has() || YA.rewardLeft(st) <= 0, style: 'margin-top:3px', onclick: () => {
      YA.watchReward(st, (res) => { if (res === 'earned') { c.boost = true; YA.saveWorld(); } (rerenderFn || rerender)(); });
    } }, '動画で詳しく見る');
  };
})();
