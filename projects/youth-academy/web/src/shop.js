// 3段目「仕上げ」（決定124・125・130・131・94）：課金4つ・広告・セーブ枠・オリジナル選手。
// 課金と広告の本物は Flutter 側（app/lib/monetization）が持つ。ここは「橋」と「特典の中身」と「画面」だけ。
// 権利（広告を消す・見抜く目・セーブ枠・チケット）は Flutter が端末に保存し、届いたら ent として渡してくる（書き込むのは Flutter だけ）。
// ブラウザで開いたとき（Flutter の外）は購入も広告も出ず、権利は空のまま。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------- 権利 ----------
  // used＝これまでに使ったチケットの枚数（オリジナル選手の通し番号）、spent＝新入生として迎え終えた通し番号
  YA.ENT0 = { noAds: false, eye: false, slots: 0, tickets: 0, used: 0, spent: [] };
  YA.TICKET_MAX = 99;
  YA.ent = Object.assign({}, YA.ENT0);
  YA.entSet = function (e) {
    const x = Object.assign({}, YA.ENT0, e && typeof e === 'object' ? e : {});
    YA.ent = { noAds: !!x.noAds, eye: !!x.eye, slots: clamp(x.slots | 0, 0, 4), tickets: clamp(x.tickets | 0, 0, YA.TICKET_MAX), used: Math.max(0, x.used | 0), spent: Array.isArray(x.spent) ? x.spent.filter((n) => typeof n === 'number') : [] };
    try { if (YA.eyeReveal && YA._ui && YA._ui.app) YA.eyeReveal(YA._ui.app.w); } catch (err) { /* 画面なし */ }
    return YA.ent;
  };
  // セーブ枠：最初は1枠。買うたびに+1（最大5）
  YA.SLOT_MAX = 5;
  Object.defineProperty(YA, 'SLOT_COUNT', { configurable: true, get: () => 1 + clamp(YA.ent.slots | 0, 0, YA.SLOT_MAX - 1), set: () => {} });

  // ---------- 商品（値段は決定124。ストアでは App Store Connect の価格が正で、画面にはストアの表示価格を出す） ----------
  YA.SHOP = [
    { id: 'youth_remove_ads', key: 'noAds', name: '広告を消す', price: 610, once: true, note: '全画面の広告が出なくなります（ご褒美の動画は残ります）。買い切り。' },
    { id: 'youth_keen_eye', key: 'eye', name: '見抜く目', price: 800, once: true, note: '選手の将来の総合力が数字で見えます（星ではなく「将来 148」）。スカウトの候補も、総合力・将来・特性・性格がはっきり見え、本当に向いたポジションも分かります。買い切り。' },
    // 枠とチケットは消費型（App Store Connect の商品は変えられない）。端末にだけ残り、入れ直すと戻らないことをはっきり書く
    { id: 'youth_save_slot', key: 'slot', name: 'セーブ枠の追加', price: 250, once: false, note: '1枠ふえます（最大5枠）。枠ごとに別のクラブで遊べます。この端末だけで使えます。アプリを入れ直したり機種変更したりすると戻りません（購入の復元でも戻りません）。' },
    { id: 'youth_ticket_1', key: 'ticket', name: 'オリジナル選手チケット（1枚）', price: 250, once: false, add: 1, note: '名前・ポジション・性格に加え、能力29個を1つずつ数字で・将来の総合力（200まで）・特性3つ・覚醒の形まで決めた選手を、来年度の新入生に迎えます。この端末だけで使えます。入れ直すと戻りません（購入の復元でも戻りません）。' },
    { id: 'youth_ticket_3', key: 'ticket3', name: 'オリジナル選手チケット（3枚まとめ）', price: 610, once: false, add: 3, note: '3枚ぶん。1枚ずつ買うより安くなります。この端末だけで使えます。入れ直すと戻りません（購入の復元でも戻りません）。' },
  ];
  YA.shopPrices = {}; // ストアの表示価格 { productId: '¥610' }。取れていない商品は値段を出さず、買えない（決め打ちの値段は出さない）

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
  YA.PURCHASE_MSG = { purchased: '購入できました', pending: '保護者の承認待ちです。承認されると届きます', canceled: '購入を取りやめました', unavailable: 'いまはストアに繋がりません', failed: '購入に失敗しました', undelivered: '支払いは済みましたが、受け取りに失敗しました。次にアプリを開いたときにもう一度受け取ります', busy: 'ほかの購入を手続き中です。終わってからもう一度', limit: 'これ以上は増やせません（上限です）' };
  YA.RESTORE_MSG = { purchased: '購入を復元しました', unavailable: '復元できる買い切りの購入が見つかりませんでした', pending: '確認中です。届いたら反映されます', undelivered: '受け取りに失敗しました。次にアプリを開いたときにもう一度受け取ります', failed: '復元できませんでした' };
  YA.onNative = function (ev) {
    if (!ev || typeof ev !== 'object') return;
    if (ev.ev === 'ent') { YA.entSet(ev.v); if (YA.bgm) YA.bgm.unlock(); }
    else if (ev.ev === 'prices') YA.shopPrices = Object.assign({}, YA.shopPrices, ev.map || {});
    else if (ev.ev === 'purchase') YA.shopMsg = ev.outcome === 'purchased' && YA.purchasedNext && YA.purchasedNext(ev.id || YA.lastBuy) ? YA.purchasedNext(ev.id || YA.lastBuy) : YA.PURCHASE_MSG[ev.outcome] || '';
    else if (ev.ev === 'restore') YA.shopMsg = YA.RESTORE_MSG[ev.outcome] || YA.RESTORE_MSG.failed;
    else if (ev.ev === 'adDone') adDone(ev);
    else if (ev.ev === 'adUnclaimed') { for (const x of ev.list || []) if (x) adDone({ tag: x.tag, result: 'earned', reward: x.reward }); }
    else if (ev.ev === 'saveFail') { if (YA.saveFailed) YA.saveFailed(); return; }
    if (YA._ui && YA._ui.render) { try { YA._ui.render(); } catch (e) { /* 画面なし */ } }
  };
  globalThis.YAnative = { onMsg: (s) => { try { YA.onNative(typeof s === 'string' ? JSON.parse(s) : s); } catch (e) { /* 壊れた通知は捨てる */ } } };
  YA.shopStart = function () {
    if (!YA.native.has()) return;
    YA.native.post({ cmd: 'hello', ids: YA.SHOP.map((x) => x.id) });
  };
  YA.buy = (id) => { YA.lastBuy = id; return YA.native.post({ cmd: 'buy', id }); };
  // ショップを開いたら、取れていない価格を取り直す（続けて何度も頼まない）
  let pricesAsked = 0;
  YA.askPrices = function () {
    if (!YA.native.has() || YA.SHOP.every((x) => YA.shopPrices[x.id]) || Date.now() - pricesAsked < 5000) return false;
    pricesAsked = Date.now();
    return YA.native.post({ cmd: 'prices' });
  };
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
      if (YA.monthIdx(w.week) !== m0 && YA.interstitialDue(w, 'month')) adDue();
      w.sharpEye = !!YA.ent.eye; // 見抜く目（伸びしろの幅が狭まる）
      YA.eyeReveal(w);
      return r;
    };
  }
  const am0 = YA.applyMatch;
  if (am0) {
    YA.applyMatch = function (w) {
      const r = am0.apply(this, arguments);
      if (YA.interstitialDue(w, 'match')) adDue();
      return r;
    };
  }
  // 出す番になったら、Flutter に読み込みを頼む（起動時からは読まない。出すのは画面の区切りの flushAd）
  function adDue() {
    if (!YA.adPending) YA.native.post({ cmd: 'adPrep' });
    YA.adPending = true;
  }
  YA.flushAd = function () {
    if (!YA.adPending) return false;
    YA.adPending = false;
    return YA.native.post({ cmd: 'ad', kind: 'interstitial', tag: 0 });
  };
  // ご褒美の動画
  const adWait = {};
  let adTag = 0;
  // 端末の日付で数える（UTC で数えると、日本では朝9時に日が替わっていた）
  const today = () => { const d = new Date(); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
  YA.localDay = today;
  YA.rewardLeft = function (store) {
    const d = store.get('adday', null);
    return d && d.d === today() ? Math.max(0, YA.AD.rewardPerDay - d.n) : YA.AD.rewardPerDay;
  };
  YA.REWARDS = [
    { k: 'rest', name: '疲れを抜く', note: 'いまいる全員の疲れが少し抜けます', run: (w) => { for (const p of Object.values(w.players)) p.fat = Math.max(0, (p.fat || 0) - 12); return '全員の疲れ −12'; } },
    { k: 'eye', name: 'スカウトの見立てを詳しく', note: '選んだ候補の幅が狭まり、見立てが付きやすくなります（候補の画面から）', run: null },
  ];
  // 特典の中身（reward）を渡す。rest＝全員の疲れ、boost＝候補 cid の見立てを詳しく。渡せたら結果の文、渡す相手が居なければ null
  YA.applyReward = function (w, reward) {
    if (!w || !reward) return null;
    if (reward.k === 'rest') return YA.REWARDS[0].run(w);
    if (reward.k === 'boost') {
      const c = ((w.scouting && w.scouting.cands) || []).find((x) => x.id === reward.cid);
      if (c) c.boost = true;
      return c ? '候補の見立てが詳しくなりました' : '';
    }
    return '';
  };
  // 見終えた動画の受け取り。読み直しの前に見終えた分（adUnclaimed）も同じ道を通る。
  // 同じ動画を二度渡さないよう、受け取った印を世界（w.adClaimed）に残してから Flutter の控えを消す
  function adDone(ev) {
    const f = adWait[ev.tag];
    delete adWait[ev.tag];
    let text = null;
    if (ev.result === 'earned') {
      const ui = YA._ui;
      text = YA.claimReward(ui && ui.app ? ui.app.w : null, ev.tag, ev.reward, ui && ui.store);
      if (!f && text) { try { YA.toast('見終えた動画の特典を受け取りました：' + text); } catch (e) { /* 画面なし */ } }
    }
    if (f) f(ev.result, text);
  }
  YA.claimReward = function (w, tag, reward, store) {
    if (!w) return null; // 世界が無い（新しく始める画面）。控えは残し、次に開いたときに渡す
    w.adClaimed = w.adClaimed || [];
    if (w.adClaimed.indexOf(tag) >= 0) { YA.native.post({ cmd: 'adClaimed', tag }); return null; }
    const text = YA.applyReward(w, reward);
    if (text == null) return null;
    w.adClaimed = w.adClaimed.concat([tag]).slice(-20);
    if (store) { const d = store.get('adday', null); store.set('adday', { d: today(), n: (d && d.d === today() ? d.n : 0) + 1 }); }
    if (YA.saveWorld) YA.saveWorld(true);
    YA.native.post({ cmd: 'adClaimed', tag });
    return text;
  };
  // 動画を見て、見終えたら特典を渡す（結果は Flutter から adDone で届く）。done(結果, 特典の文)
  YA.watchReward = function (store, reward, done) {
    if (!YA.native.has()) return done('unavailable');
    if (YA.rewardLeft(store) <= 0) return done('limit');
    // 読み直しのあとも重ならない番号（前のページの控えと取り違えない）
    const tag = Date.now() * 10 + (adTag++ % 10);
    adWait[tag] = done;
    YA.native.post({ cmd: 'ad', kind: 'rewarded', tag, reward });
  };
  YA.rewardMsg = (res) => ({ earned: '見終えました。特典が入ります', limit: '今日の分は終わりました（1日3回まで）', unavailable: 'いま見られる動画がありません。あとでもう一度', closedEarly: '途中で閉じたので、特典は入りません', showFailed: '動画を表示できませんでした' }[res] || '');

  // ---------- 見抜く目（2026-11-19「能力見るのは数値レベルで見る」）：伸びしろ・候補を数字で見せる ----------
  // 将来の総合力の見込み（幅の真ん中。futureRange と同じ物差し）
  YA.futurePoint = function (p) {
    const n = (p.pos === 'GK' ? YA.AB_GK : YA.AB_FIELD).length;
    const room = Math.max(0, p.pot - YA.abSum(p)) / n;
    return Math.max(YA.rating(p), Math.min(200, YA.rate(Math.min(20, YA.ovr(p) + room * 0.75))));
  };
  const lvNm = (v) => YA.levelOf(v).replace(/（.*）/, '');
  const fr0 = YA.futureRange;
  if (fr0) {
    YA.futureRange = function (w, p) {
      if (!YA.ent.eye) return fr0.apply(this, arguments);
      const v = YA.futurePoint(p);
      return { lo: v, hi: v, exact: true, text: `将来 ${v}（${lvNm(v)}）` };
    };
  }
  const fw0 = YA.futureWords;
  if (fw0) YA.futureWords = function (w, p) { return YA.ent.eye ? `${YA.futurePoint(p)}（${lvNm(YA.futurePoint(p))}）` : fw0.apply(this, arguments); };
  const cs0 = YA.coachStars;
  if (cs0) YA.coachStars = function (w, p) { return YA.ent.eye ? clamp(YA.potStars(p), 1, 5) : cs0.apply(this, arguments); };
  // 本当に向いているポジションも見える
  YA.eyeReveal = function (w) {
    if (!YA.ent.eye || !w || !w.players) return;
    for (const p of Object.values(w.players)) if (p.best && !p.bestKnown) p.bestKnown = true;
  };
  // 候補：総合力・伸びしろ・特性・性格を数字のまま（動画で詳しく は「もう少し見た」扱い）
  const cv0 = YA.candView;
  if (cv0) {
    YA.candView = function (w, c) {
      const add = c && c.boost ? 2 : 0;
      let v;
      if (!add) v = cv0.apply(this, arguments);
      else { c.seen += add; try { v = cv0.apply(this, arguments); } finally { c.seen -= add; } }
      if (YA.ent.eye && c && c.p) {
        const p = c.p;
        const o = Math.round(YA.ovr(p) * 10) / 10;
        const st = YA.potStars(p);
        v.ovr = [o, o];
        v.stars = [st, st];
        v.future = YA.futurePoint(p);
        v.traits = p.traits;
        v.pers = p.pers;
        v.exact = true;
        v.rangeWord = '見抜く目で数字が見えています';
      }
      return v;
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
  // 名前・顔・ポジション・利き足・性格・能力（1つずつ数字で）・将来の総合力（〜200）・特性3つまで・覚醒の形を決める。
  // 次の年度の新入生として入る（2026-11-19「選手作成、数値レベルで設定できる・個々の能力も覚醒スキルも設定可能」「伸び代は200」）
  YA.ORIG_POS = ['GK', 'CB', 'LB', 'RB', 'LWB', 'RWB', 'DM', 'CM', 'LM', 'RM', 'AM', 'LW', 'RW', 'SS', 'ST'];
  YA.ORIG_POT = { 1: 10, 2: 11.5, 3: 13, 4: 15, 5: 17.6 }; // 伸びしろの星 → 能力の平均の上限
  YA.ORIG_MAX = 3;
  YA.ORIG_FUT = [100, 200]; // 将来の総合力の幅
  YA.ORIG_TRAITS = 3;
  YA.origAbList = (pos) => (pos === 'GK' ? YA.AB_GK.concat(YA.AB_MENTAL, YA.AB_PHYS) : YA.AB_FIELD);
  YA.origTraitList = (pos) => (pos === 'GK' ? YA.TRAIT_GROUPS.GK.concat(YA.TRAIT_GROUPS['駆け引きと声']) : YA.TRAITS.filter((t) => YA.TRAIT_GROUPS.GK.indexOf(t) < 0));
  YA.origForms = (pos) => YA.AWAKE_FORMS.filter((f) => f.pos.indexOf(pos) >= 0);
  // 決めた能力でのいまの総合力（登録ポジションの物差し）
  YA.origRating = function (pos, ab) {
    const full = {};
    for (const n of YA.AB_FIELD.concat(YA.AB_GK)) full[n] = ab[n] || 1;
    return YA.rate(YA.ovr({ main: pos, pos: YA.GROUP[pos], ab: full }));
  };
  YA.origFull = (w) => (w.originals || []).length >= YA.ORIG_MAX;
  YA.origValid = function (w, spec) {
    // 上限はチケットを使う前に見る（3人そろっているのにチケットだけ減らない）
    if (YA.origFull(w)) return '来年度に迎えられるオリジナル選手は3人までです';
    const name = String(spec.name || '').trim();
    if (!name || name.length > 12) return '名前は1〜12文字で決めてください';
    if (Object.values(w.players).some((p) => p.name === name) || (w.originals || []).some((o) => o.name === name)) return '同じ名前の子がいます';
    if (YA.ORIG_POS.indexOf(spec.pos) < 0) return 'ポジションを選んでください';
    if (spec.fut != null) {
      if (!(spec.fut >= YA.ORIG_FUT[0] && spec.fut <= YA.ORIG_FUT[1])) return `将来の総合力は${YA.ORIG_FUT[0]}〜${YA.ORIG_FUT[1]}で決めてください`;
    } else if (!(spec.stars >= 1 && spec.stars <= 5)) return '伸びしろを決めてください';
    if (spec.ab) {
      for (const n of YA.origAbList(spec.pos)) { const v = spec.ab[n]; if (!(v >= 1 && v <= 20)) return `能力「${n}」は1〜20で決めてください`; }
      if (spec.fut != null && spec.fut < YA.origRating(spec.pos, spec.ab)) return '将来の総合力が、いまの総合力より低くなっています';
    }
    if (spec.traits) {
      const ok = YA.origTraitList(spec.pos);
      if (spec.traits.length > YA.ORIG_TRAITS) return `特性は${YA.ORIG_TRAITS}つまでです`;
      if (spec.traits.some((t) => ok.indexOf(t) < 0)) return 'このポジションでは選べない特性があります';
    }
    if (spec.form && !YA.origForms(spec.pos).some((f) => f.k === spec.form)) return 'このポジションでは選べない覚醒の形です';
    return null;
  };
  YA.origCreate = function (w, spec) {
    const err = YA.origValid(w, spec);
    if (err) return { ok: false, msg: err };
    if (YA.ent.tickets < 1) return { ok: false, msg: 'チケットがありません' };
    const o = { name: String(spec.name).trim(), pos: spec.pos, foot: spec.foot === 'L' ? 'L' : 'R', stars: spec.stars | 0, face: spec.face == null ? null : spec.face | 0, pers: Object.assign({}, spec.pers || {}) };
    if (spec.fut != null) o.fut = Math.round(spec.fut);
    if (spec.ab) { o.ab = {}; for (const n of YA.origAbList(spec.pos)) o.ab[n] = Math.round(spec.ab[n]); }
    if (spec.traits) o.traits = spec.traits.slice();
    if (spec.form) o.form = spec.form;
    if (spec.serial != null) o.serial = spec.serial | 0; // 使ったチケットの通し番号（Flutter の権利と突き合わせる）
    w.originals = (w.originals || []).concat([o]);
    return { ok: true, tickets: YA.ent.tickets };
  };
  // 予約したオリジナル選手のうち、本当にチケットを使っていて、まだ迎えていない子だけを残す。
  // 書き出したセーブを復元して、同じチケットで二度迎える（増やす）のを防ぐ。legacy が true なら、
  // 通し番号を持たない前の版の予約も残す（書き出しからの復元では残さない）
  YA.origFilter = function (list, ent, legacy) {
    const e = ent || YA.ent;
    const seen = new Set();
    return (list || []).filter((o) => {
      if (!o) return false;
      if (o.serial == null) return !!legacy;
      const ok = o.serial >= 1 && o.serial <= (e.used | 0) && (e.spent || []).indexOf(o.serial) < 0 && !seen.has(o.serial);
      seen.add(o.serial);
      return ok;
    });
  };
  const intake0 = YA.intake;
  if (intake0) {
    YA.intake = function (w, rng, used) {
      const list = YA.origFilter(w.originals, YA.ent, true);
      const serials = list.filter((o) => o.serial != null).map((o) => o.serial);
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
          if (o.ab) for (const k of Object.keys(o.ab)) if (p.ab[k] != null || YA.origAbList(o.pos).indexOf(k) >= 0) p.ab[k] = clamp(o.ab[k] | 0, 1, 20);
          if (o.ab) p.sumIn = YA.abSum(p); // 3年間の伸びの起点は決めた能力から
          if (o.traits) p.traits = o.traits.slice(0, YA.ORIG_TRAITS);
          if (o.form) p.formPick = o.form;
          const n = (p.pos === 'GK' ? YA.AB_GK : YA.AB_FIELD).length;
          if (o.fut != null) {
            // 将来の総合力から行き着く高さ（futurePoint と同じ物差しを逆にたどる）
            const need = Math.max(0, (YA.unrate(Math.min(200, o.fut)) - YA.ovr(p)) / 0.75);
            p.pot = Math.round(YA.abSum(p) + need * n + 1);
          } else p.pot = Math.max(YA.abSum(p) + 25, Math.round(YA.ORIG_POT[o.stars] * n));
          p._orig = true; // 画面では見分けを付けない（決定125）。印は内部だけ
          adds.push({ id: p.id, p, kind: 'int', prof: null, foreign: false, seen: 3, status: 'signed', rival: false, persSeen: true, amb: 5, where: null });
        }
        w.scouting.cands = adds.concat(w.scouting.cands || []);
      }
      w.originals = [];
      // 迎え終えた通し番号を Flutter に控えてもらう（同じチケットで二度迎えない）
      if (serials.length) {
        YA.ent.spent = (YA.ent.spent || []).concat(serials);
        YA.native.post({ cmd: 'ticketSpent', serials });
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
  // 値段はストアの表示価格だけ（取れていなければ出さない。決め打ちの「610円」で別の値段を見せない）
  const priceOf = (it) => YA.shopPrices[it.id] || '';
  // 買えない理由（無ければ null）。上限に達した消費型は、買ってもお金だけ取られるので押せなくする
  YA.buyWhy = function (it) {
    if (!YA.native.has()) return '買い物はアプリでだけできます';
    if (it.key === 'slot' && YA.ent.slots >= YA.SLOT_MAX - 1) return 'セーブ枠は5枠までです（いまが上限）';
    if (it.add && YA.ent.tickets + it.add > YA.TICKET_MAX) return `チケットは${YA.TICKET_MAX}枚までしか持てません`;
    if (!YA.shopPrices[it.id]) return 'ストアに接続中です。少し待ってから開き直してください';
    return null;
  };
  function stateOf(it) {
    if (it.key === 'noAds') return YA.ent.noAds ? '購入済み' : null;
    if (it.key === 'eye') return YA.ent.eye ? '購入済み' : null;
    if (it.key === 'slot') return YA.ent.slots >= YA.SLOT_MAX - 1 ? '上限（5枠）' : `いま${YA.SLOT_COUNT}枠`;
    return `チケット ${YA.ent.tickets}枚`;
  }
  // 持っている（使える）商品か。使う場所へのボタンを出す
  function owned(it) {
    if (it.key === 'noAds') return false;
    if (it.key === 'eye') return !!YA.ent.eye;
    if (it.key === 'slot') return YA.ent.slots > 0;
    return YA.ent.tickets > 0;
  }
  YA.shopBlock = function (body) {
    YA.askPrices();
    body.append(h('div', { class: 'h', style: 'margin-top:10px' }, 'ショップ'), h('div', { class: 'note' }, YA.native.has() ? '買い切りは、機種変更や入れ直しのあとに「購入を復元」で戻せます。' : 'ショップはアプリ版（iPhone）で使えます。'));
    if (YA.shopHowEl) body.append(YA.shopHowEl());
    for (const it of YA.SHOP) {
      const st = stateOf(it);
      const done = it.once && st === '購入済み';
      body.append(h('div', { class: 'card', style: 'padding:6px 9px;margin:4px 0;display:flex;align-items:center;gap:6px' },
        h('div', { class: 'grow' }, h('b', {}, it.name), h('div', { class: 'note' }, it.note), YA.shopItemGuideEl ? YA.shopItemGuideEl(it) : null, st ? h('div', { class: 'note', style: 'color:var(--ink)' }, st) : null),
        owned(it) && YA.shopGoEl ? YA.shopGoEl(it) : null,
        done ? null : (() => { const why = YA.buyWhy(it); return h('button', { class: 'btn sm pri', 'data-pid': it.id, disabled: !!why, why: why || '', onclick: () => { YA.shopMsg = ''; YA.buy(it.id); } }, priceOf(it) || (YA.native.has() ? 'ストアに接続中' : '買う')); })()));
    }
    body.append(h('div', { class: 'row', style: 'gap:6px;margin-top:4px' }, h('button', { class: 'btn sm', disabled: !YA.native.has(), why: '購入の復元はアプリでだけできます', onclick: () => { YA.shopMsg = '確認しています…'; YA.restorePurchases(); rerender(); } }, '購入を復元'), h('span', { class: 'note' }, YA.shopMsg || '')));
    YA.origButton(body);
  };
  YA.origModal = () => origModal();
  YA.origButton = function (body) {
    const w = U().app.w;
    if (!w) return;
    const n = (w.originals || []).length;
    const why = YA.origFull(w) ? `来年度に迎えられるのは${YA.ORIG_MAX}人までです（もう${n}人決まっています）` : YA.ent.tickets < 1 ? 'オリジナル選手のチケットがありません' : !YA.native.has() ? 'オリジナル選手はアプリでだけ作れます' : null;
    body.append(h('div', { class: 'row origrow', style: 'gap:6px;margin-top:6px' }, h('button', { class: 'btn sm', disabled: !!why, why: why || '', onclick: () => origModal() }, 'オリジナル選手を作る'), h('span', { class: 'note' }, `チケット${YA.ent.tickets}枚／来年度に迎える予定 ${n}人（${YA.ORIG_MAX}人まで）`)));
    if (n) body.append(h('div', { class: 'note' }, (w.originals || []).map((o) => `${o.name}（${YA.POS_LABEL ? YA.POS_LABEL[o.pos] || o.pos : o.pos}・${o.fut != null ? '将来' + o.fut : '伸びしろ' + '★'.repeat(o.stars)}${o.ab ? '・いま' + YA.origRating(o.pos, o.ab) : ''}）`).join('、')));
  };
  function origModal() {
    const w = U().app.w;
    const ab = {};
    for (const n of YA.AB_FIELD.concat(YA.AB_GK)) ab[n] = 9;
    const st = { name: '', pos: 'CM', foot: 'R', stars: 3, fut: 150, ab, traits: [], form: null, face: null, pers: {}, msg: '' };
    const PERS = YA.PERS_W || {};
    const lv = (v) => YA.levelOf(v).replace(/（.*）/, '');
    YA._v.modal((close) => {
      const box = h('div', { class: 'sheet-in origmk', style: 'flex:none;align-self:center;margin:auto;width:min(720px,98%);max-height:96%;padding:10px 12px;gap:6px;overflow:auto' });
      const draw = () => {
        const FN = (YA.IMG && YA.IMG.faces && YA.IMG.faces.length) || 0;
        const abList = YA.origAbList(st.pos);
        const okTr = YA.origTraitList(st.pos);
        st.traits = st.traits.filter((t) => okTr.indexOf(t) >= 0);
        const forms = YA.origForms(st.pos);
        if (st.form && !forms.some((f) => f.k === st.form)) st.form = null;
        // いまの総合力と将来は、動かしたらその場で変える（全体は描き直さない。描き直すと指が離れる）
        const nowEl = h('b', {});
        const futEl = h('b', {});
        const warnEl = h('span', { class: 'note', style: 'color:#c0392b' });
        const sync = () => {
          const r = YA.origRating(st.pos, st.ab);
          nowEl.textContent = `${r}（${lv(r)}）`;
          futEl.textContent = `${st.fut}（${lv(st.fut)}）`;
          warnEl.textContent = st.fut < r ? '将来がいまより低くなっています' : '';
        };
        const futIn = h('input', { type: 'range', min: YA.ORIG_FUT[0], max: YA.ORIG_FUT[1], step: 1, value: st.fut, 'data-fut': '1', style: 'flex:1;min-width:140px', oninput: (e) => { st.fut = +e.target.value; sync(); } });
        const abRow = (n) => {
          const val = h('b', { style: 'width:20px;text-align:right;flex:none' }, String(st.ab[n]));
          return h('label', { class: 'orab', style: 'display:flex;align-items:center;gap:4px;min-width:0' },
            h('span', { style: 'width:86px;flex:none;font-size:11.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis' }, n),
            h('input', { type: 'range', min: 1, max: 20, step: 1, value: st.ab[n], 'data-ab': n, style: 'flex:1;min-width:60px', oninput: (e) => { st.ab[n] = +e.target.value; val.textContent = e.target.value; sync(); } }),
            val);
        };
        const setAll = (fn) => { for (const n of abList) st.ab[n] = fn(n); draw(); };
        const keyAbs = (YA.POS_ABS15 && YA.POS_ABS15[st.pos]) || [];
        const fsel = forms.find((f) => f.k === st.form);
        box.replaceChildren(
          h('div', { class: 'row' }, h('div', { class: 'h grow' }, 'オリジナル選手を作る'), h('button', { class: 'btn sm', onclick: close }, '閉じる')),
          h('div', { class: 'note' }, '来年度の新入生として入ります。能力・将来の総合力・特性・覚醒の形を自分で決められます。高校の3年間で伸びる量には上限があるので、将来に届くのは卒業してからのこともあります。'),
          h('div', { class: 'row', style: 'gap:6px' }, h('span', {}, '名前'), h('input', { type: 'text', value: st.name, maxlength: 12, style: 'flex:1;padding:5px;border:1px solid var(--line);border-radius:6px', oninput: (e) => { st.name = e.target.value; } })),
          h('div', { class: 'row', style: 'flex-wrap:wrap;gap:4px' }, h('span', { class: 'sub', style: 'width:60px' }, 'ポジション'), ...YA.ORIG_POS.map((p) => h('button', { class: 'btn sm' + (st.pos === p ? ' on' : ''), onclick: () => { st.pos = p; draw(); } }, (YA.POS_LABEL && YA.POS_LABEL[p]) || p))),
          h('div', { class: 'row', style: 'gap:4px' }, h('span', { class: 'sub', style: 'width:60px' }, '利き足'), ...[['R', '右'], ['L', '左']].map(([k, n]) => h('button', { class: 'btn sm' + (st.foot === k ? ' on' : ''), onclick: () => { st.foot = k; draw(); } }, n))),
          FN ?h('div', { class: 'row', style: 'gap:4px;flex-wrap:wrap' }, h('span', { class: 'sub', style: 'width:60px' }, '顔'), h('button', { class: 'btn sm' + (st.face == null ? ' on' : ''), onclick: () => { st.face = null; draw(); } }, 'おまかせ'), ...Array.from({ length: Math.min(FN, 8) }, (_, i) => h('button', { class: 'btn sm' + (st.face === i ? ' on' : ''), onclick: () => { st.face = i; draw(); } }, YA.faceEl ? YA.faceEl(w, { id: 'x' + i, name: '', pos: YA.GROUP[st.pos], face: i }, 30) || String(i + 1) : String(i + 1)))) : null,
          // 能力
          h('div', { class: 'row', style: 'margin-top:4px;gap:6px;flex-wrap:wrap' }, h('div', { class: 'h' }, `能力（1〜20・${abList.length}個）`), h('span', { class: 'sub' }, 'いまの総合力'), nowEl,
            h('button', { class: 'btn sm', onclick: () => setAll(() => 9) }, '高1並みにそろえる'),
            h('button', { class: 'btn sm', onclick: () => setAll((n) => (keyAbs.indexOf(n) >= 0 ? 13 : 8)) }, 'ポジションに合わせる'),
            h('button', { class: 'btn sm', onclick: () => setAll(() => 20) }, '全部20')),
          h('div', { class: 'orgrid', style: 'display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:2px 12px' }, ...abList.map(abRow)),
          // 将来
          h('div', { class: 'row', style: 'margin-top:4px;gap:6px;flex-wrap:wrap' }, h('div', { class: 'h' }, '将来の総合力'), futEl, futIn, warnEl),
          h('div', { class: 'note' }, '100＝プロ入りの目安・125＝J1でやれる・155＝日本代表・185＝バロンドール級・200＝歴史上No.1'),
          // 特性
          h('div', { class: 'row', style: 'margin-top:4px;gap:6px' }, h('div', { class: 'h' }, `特性（${YA.ORIG_TRAITS}つまで）`), h('span', { class: 'sub' }, `選んだ ${st.traits.length}`)),
          ...Object.keys(YA.TRAIT_GROUPS).map((g) => {
            const ts = YA.TRAIT_GROUPS[g].filter((t) => okTr.indexOf(t) >= 0);
            if (!ts.length) return null;
            return h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap' }, h('span', { class: 'sub', style: 'width:96px;font-size:11.5px' }, g), ...ts.map((t) => {
              const on = st.traits.indexOf(t) >= 0;
              const full = !on && st.traits.length >= YA.ORIG_TRAITS;
              return h('button', { class: 'btn sm' + (on ? ' on' : ''), 'data-tr': t, disabled: full, why: `特性は${YA.ORIG_TRAITS}つまでです。ほかを外してから選んでください`, style: 'padding:2px 6px;min-height:26px;font-size:11px', onclick: () => { st.traits = on ? st.traits.filter((x) => x !== t) : st.traits.concat([t]); draw(); } }, t);
            }));
          }),
          // 覚醒の形
          h('div', { class: 'h', style: 'margin-top:4px' }, '覚醒の形（★を付けて鍵がそろうと、この形で目覚めます）'),
          h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap' }, h('button', { class: 'btn sm' + (!st.form ? ' on' : ''), onclick: () => { st.form = null; draw(); } }, 'おまかせ'), ...forms.map((f) => h('button', { class: 'btn sm' + (st.form === f.k ? ' on' : ''), 'data-form': f.k, onclick: () => { st.form = f.k; draw(); } }, f.trait))),
          h('div', { class: 'note' }, fsel ? `${fsel.name}：特性「${fsel.trait}」（${fsel.as.join('・')}）。目覚めると${fsel.abs.join('・')}がまとめて上がります。` : 'おまかせなら、育ち方と接し方で形が決まります。'),
          h('div', { class: 'h', style: 'margin-top:4px' }, '性格（選ばなければ「ふつう」）'),
          ...Object.keys(PERS).map((g) => h('div', { class: 'row', style: 'gap:3px;flex-wrap:wrap' }, h('span', { class: 'sub', style: 'width:96px;font-size:11.5px' }, g), ...Object.keys(PERS[g]).map((t) => h('button', { class: 'btn sm' + ((st.pers[g] || 'ふつう') === t ? ' on' : ''), style: 'padding:2px 6px;min-height:26px;font-size:11px', onclick: () => { st.pers[g] = t; draw(); } }, t)))),
          h('div', { class: 'row', style: 'gap:6px;margin-top:6px' }, h('button', { class: 'btn pri', onclick: () => {
            // 上限・入力・チケットを、チケットを使う前に全部確かめる
            const r = YA.origValid(w, st) || (YA.ent.tickets < 1 ? 'チケットがありません' : null) || (YA.native.has() ? null : 'アプリ版でのみ作れます');
            if (r) { st.msg = r; draw(); return; }
            // 予定に入れて保存してから、チケットを1枚使う（権利の書き込みは Flutter だけ）。
            // 通し番号は Flutter が数える「使った枚数」の次。書き出しの復元で同じチケットを二度使えないように突き合わせる
            const serial = (YA.ent.used | 0) + 1;
            const res = YA.origCreate(w, Object.assign({}, st, { serial }));
            if (!res.ok) { st.msg = res.msg; draw(); return; }
            YA.saveWorld(true);
            YA.ent.tickets = Math.max(0, YA.ent.tickets - 1);
            YA.ent.used = serial;
            YA.native.post({ cmd: 'useTicket' });
            close();
            rerender();
          } }, 'この子を迎える（チケット1枚）'), h('span', { class: 'note', style: 'color:#c0392b' }, st.msg)));
        sync();
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
    card.append(msg, h('button', { class: 'btn sm', disabled: !YA.native.has() || left <= 0, why: !YA.native.has() ? '動画はアプリでだけ見られます' : '今日はもう見られません（1日の回数を使い切りました）', style: 'margin-top:3px', onclick: () => {
      // 特典は受け取りの道（YA.claimReward）で渡す。読み直しの後でも同じ道で渡る
      YA.watchReward(st, { k: 'rest' }, (res, text) => {
        const t = YA.rewardMsg(res) + (res === 'earned' && text ? '：' + text : '');
        rerender();
        try { YA.toast(t); } catch (e) { /* 画面なし */ }
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
    return h('button', { class: 'btn sm', disabled: !YA.native.has() || YA.rewardLeft(st) <= 0, why: !YA.native.has() ? '動画はアプリでだけ見られます' : '今日はもう見られません（1日3回まで）', style: 'margin-top:3px', onclick: () => {
      YA.watchReward(st, { k: 'boost', cid: c.id }, (res) => { if (res !== 'earned') { try { YA.toast(YA.rewardMsg(res)); } catch (e) { /* 画面なし */ } } (rerenderFn || rerender)(); });
    } }, '動画で詳しく見る');
  };
})();
