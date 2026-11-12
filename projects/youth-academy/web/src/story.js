// 2段目その3（決定136〜138）：進路面談（★の子だけ）・節目の場面4つ・口調10通り。
// 出来事（forced）の仕組みに乗せる：進路面談は 'path'、節目の場面は 'scene'（入学式・夏合宿・大会の決勝前・卒業式）。
(function () {
  'use strict';
  const YA = (globalThis.YA = globalThis.YA || {});
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const sur = (p) => String(p.name).split(' ')[0];
  const clubShort = (w) => String(w.clubName || 'このクラブ').replace(/U-18$/, '').trim() || 'このクラブ';

  // ---------- 口調10通り（決定138）：性格の組み合わせで1つ決まる ----------
  YA.TONES = ['元気', 'クール', '丁寧', 'ぶっきらぼう', 'おっとり', '熱血', '弱気', '生意気', '無口', 'お調子者'];
  YA.toneOf = function (p) {
    const v = Object.values(p.pers || {});
    const has = (...n) => n.some((x) => v.indexOf(x) >= 0);
    if (has('お調子者')) return 'お調子者';
    if (has('寡黙')) return '無口';
    if (has('一匹狼')) return 'ぶっきらぼう';
    if (has('反骨心', '自信家')) return '生意気';
    if (has('闘争的', '野心家', '負けず嫌い')) return '熱血';
    if (has('繊細', 'プレッシャーに弱い', '人見知り')) return '弱気';
    if (has('マイペース', '楽天家')) return 'おっとり';
    if (has('完璧主義', '安定型', '慎重')) return 'クール';
    if (has('素直', '真面目', '勉強家')) return '丁寧';
    if (has('リーダー気質', '世話好き', '仲間思い', 'クラブ愛')) return '元気';
    return YA.TONES[YA.hash(String(p.id || p.name)) % YA.TONES.length];
  };
  // 場面 × 口調 × 3通り。{c}＝クラブ名
  const SAY = {
    greet: { // 入学式の挨拶
      元気: ['よろしくお願いしますっ！　誰よりも走ります！', '今日からお世話になります！　早く試合に出たいです！', 'よろしくお願いします！　{c}の一員になれてうれしいです！'],
      クール: ['……よろしくお願いします。やることは変わりません。', 'お世話になります。結果で示します。', 'よろしくお願いします。ここで上手くなりに来ました。'],
      丁寧: ['本日からお世話になります。ご指導のほど、よろしくお願いいたします。', '一日も早く、チームの力になれるよう努めます。', '{c}の名に恥じないよう、精一杯やります。'],
      ぶっきらぼう: ['ども。よろしく。', '……うす。', 'よろしくっす。まあ、やるんで。'],
      おっとり: ['よ、よろしくお願いします〜。緊張してるけど、がんばります。', 'えっと、がんばります。ゆっくり覚えます。', 'よろしくお願いします。みなさん優しそうで、よかったです。'],
      熱血: ['日本一になりに来ました！　よろしくお願いします！', '絶対にAに上がります！　見ててください！', 'ここで化けます！　全部やらせてください！'],
      弱気: ['あの……ついていけるか不安ですが、がんばります。', 'よ、よろしくお願いします。足を引っ張らないようにします。', 'うまくやれるか分かりませんが、よろしくお願いします。'],
      生意気: ['よろしく。すぐ上に行くんで、見ててください。', '正直、ここは通過点です。よろしく。', 'まあ、やれると思います。よろしくお願いします。'],
      無口: ['……よろしくお願いします。', '（深く頭を下げた）', '……はい。'],
      お調子者: ['どーもっす！　ムードメーカー、立候補していいっすか！', 'よろしくっす！　先輩、いろいろ教えてくださいね！', '入学式、めっちゃ緊張しました！　もう大丈夫っす！'],
    },
    thanks: { // 卒業式の挨拶
      元気: ['3年間、ありがとうございました！　最高でした！', '{c}で過ごせて、本当に楽しかったです！', '監督、ありがとうございました！　どこへ行っても走ります！'],
      クール: ['お世話になりました。ここで学んだことは、無駄にしません。', '……ありがとうございました。感謝しています。', '3年間、ありがとうございました。次の場所でも続けます。'],
      丁寧: ['3年間のご指導、心より感謝しております。', '監督のおかげで、ここまで来られました。ありがとうございました。', '{c}で学んだことを、誇りに思います。'],
      ぶっきらぼう: ['……世話になりました。', 'まあ、あざした。', '……いろいろ、あざした。'],
      おっとり: ['3年間、あっという間でした。ありがとうございました。', 'ここでよかったなあって、今は思います。', 'みんなと過ごせて、しあわせでした。'],
      熱血: ['この悔しさも全部、次で晴らします！　ありがとうございました！', '見ていてください！　絶対に上で会いましょう！', '3年間、ありがとうございました！　まだまだ上へ行きます！'],
      弱気: ['最後まで迷惑ばかりかけて、すみませんでした。ありがとうございました。', '自分にできたかは分かりませんが、ここで過ごせてよかったです。', 'これからも、がんばります。……ありがとうございました。'],
      生意気: ['まあ、感謝してますよ。一応。', '見ててください。いつか恩返しするんで。', '最初は生意気でしたよね、俺。……ありがとうございました。'],
      無口: ['……ありがとうございました。', '（黙って頭を下げた）', '……お世話になりました。'],
      お調子者: ['3年間ありがとうございました！　テレビで会いましょう！', '最後まで騒がしくてすみません！　でも楽しかったっす！', '泣かないって決めてたのに〜！　ありがとうございましたっ！'],
    },
    path: { // 進路面談で道が決まったあとの返事
      元気: ['はい！　そこで全力でやります！', '分かりました！　やってみます！', '決めました！　あとは突き進むだけです！'],
      クール: ['……分かりました。そのつもりで準備します。', '納得しました。やるべきことは見えています。', '決めたからには、結果を出します。'],
      丁寧: ['ありがとうございます。よく考えて、決めました。', 'ご相談してよかったです。その道で努力します。', '背中を押していただき、ありがとうございます。'],
      ぶっきらぼう: ['……それでいいっす。', 'まあ、やってみるっす。', '分かった。行く。'],
      おっとり: ['そっか、そうですね。そうしてみます。', 'ちょっと不安だけど、がんばってみます。', '話せてよかったです。ゆっくり進みます。'],
      熱血: ['やってやります！　絶対にものにします！', 'そこで一番になります！　見ててください！', 'その道、燃えてきました！'],
      弱気: ['……自分に、できるでしょうか。でも、やってみます。', '不安はあるけど、監督が言うなら信じます。', 'がんばります。ついていけるように。'],
      生意気: ['まあ、妥当ですね。そうします。', '言われなくても、そのつもりでしたけど。', '見ててください。後悔させないんで。'],
      無口: ['……はい。', '（小さくうなずいた）', '……分かりました。'],
      お調子者: ['おっ、いいっすね！　それでいきます！', 'マジっすか、やる気出てきました！', 'オッケーっす！　任せてください！'],
    },
  };
  YA.SAY = SAY;
  // 台詞を1つ選ぶ。直近に出したものは避ける
  YA.say = function (w, p, scene) {
    const list = (SAY[scene] && SAY[scene][YA.toneOf(p)]) || ['……'];
    w.sayHist = w.sayHist || [];
    const start = YA.hash(String(p.id || p.name) + scene + (w.year || 0)) % list.length;
    let pick = list[start];
    for (let i = 0; i < list.length; i++) {
      const c = list[(start + i) % list.length];
      if (w.sayHist.indexOf(c) < 0) { pick = c; break; }
    }
    w.sayHist.push(pick);
    if (w.sayHist.length > 16) w.sayHist.shift();
    return pick.replace(/\{c\}/g, clubShort(w)).replace(/\{n\}/g, sur(p));
  };

  // ---------- 進路面談（決定136）：★の子だけ。トップに上がらない子と、3年の秋に面談する ----------
  const PATH_LABEL = {
    abroad: '海外のクラブへ売り込む（通れば評判が上がる。外れたら大学へ）',
    pro: '他のプロのクラブへ売り込む（練習参加を取りつける。通るのは6割ほど）',
    univ: '大学に進み、遅咲きに賭ける（4年のうちに化けることもある）',
    corp: '社会人リーグで続けながら就職する',
    quit: 'サッカーはここまでにして、別の道へ進む',
  };
  const PATH_HINT = {
    abroad: '「この力なら、海外も狙えます」',
    pro: '「プロの練習参加を取れば、道はあります」',
    univ: '「いまプロは厳しいですが、大学で化ける可能性はあります」',
    corp: '「いまは、続けながら仕事を持つ道が堅実です」',
  };
  // 力に合う道を、おすすめ順に2〜3個
  YA.pathCands = function (p) {
    const o = YA.ovr(p);
    if (o >= 13.3) return ['abroad', 'pro', 'univ'];
    if (o >= 11.3) return ['pro', 'univ', 'corp'];
    if (o >= 9.8) return ['univ', 'corp', o >= 10.5 ? 'pro' : 'quit'];
    return ['corp', 'univ', 'quit'];
  };
  YA.pathOptions = function (p) {
    const c = YA.pathCands(p);
    return c.map((k, i) => ({
      k, rec: i === 0,
      label: (i === 0 ? '【コーチのおすすめ】' : '') + PATH_LABEL[k],
      kind: k === 'quit' ? 'wait' : k === 'corp' ? 'warm' : 'push',
      extra: (w, q) => {
        q._p2 = k;
        if (k === 'abroad' || k === 'pro') q._push = 'sell';
        else if (k === 'univ') q._push = 'univ';
        if (i === 0) YA.addTr(w, q, 2, '進路面談：見立てと合った');
        q._pathRec = i === 0;
      },
    }));
  };
  YA.EVENTS.push({ id: 'path', name: '進路面談', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT.path = '★の子との進路の面談です。コーチのおすすめに沿うと信頼が上がり、大学なら遅咲きで化けることもあります。選んだ道は卒業の進路に反映されます。';

  // ---------- 節目の場面4つ（決定137）：入学式・夏合宿・大会の決勝前・卒業式。選択肢は「進む」でもよい（飛ばせる）----------
  YA.EVENTS.push({ id: 'scene', name: '節目の場面', weight: 0, pick: () => null, text: () => '', opts: [] });
  YA.EVENT_ABOUT.scene = '1年の山場の場面です。ひとこと添えるとチームの気持ちが動きます。何も言わずに進んでも構いません。';
  const SCENE_NAME = { enter: '入学式', camp: '夏合宿の夜', cup: '大会の決勝前', grad: '卒業式' };
  const rate = (p) => YA.rate(YA.ovr(p));
  const A_TEAM = (w) => Object.values(w.players).filter((p) => p.team === 'A');
  const bump = (list, key, d) => { for (const p of list) p[key] = clamp((p[key] || 0) + d, 0, 100); };

  function sceneText(w, e) {
    const all = Object.values(w.players);
    if (e.sc === 'enter') {
      const news = all.filter((p) => p.grade === 1);
      const best = news.slice().sort((a, b) => YA.ovr(b) - YA.ovr(a))[0];
      const g = news.slice(0, 3).map((p) => `${p.name}「${YA.say(w, p, 'greet')}」`).join(' ／ ');
      return `入学式。新入生${news.length}人が並んだ。` + (best ? `スカウトが耳打ちした。「${best.name}（${best.pos}）は、今年いちばんの掘り出し物かもしれません」` : '') + ` ${g}`;
    }
    if (e.sc === 'camp') {
      const n = all.filter((p) => p.star).length;
      return `夏合宿の夜。昼の疲れで静まった宿舎の食堂に、全員が集まった。` + (n ? `★の子たちの目が変わってきた。（合宿のあいだ、★の子の覚醒の鍵が見えやすくなっている）` : '');
    }
    if (e.sc === 'cup') {
      const c = w.cup && w.cup[e.cup];
      const rows = c ? c.opps.map((o, i) => `${i === c.opps.length - 1 ? '決勝' : (i + 1) + '回戦'} ${o.name}${i < c.round ? ' ○' : ' ←これから'}`.replace('○', '○')).slice(0, c.opps.length) : [];
      return `${YA.CUP_NAME[e.cup]}、決勝の前。ここまで勝ち上がってきた。 ${rows.join(' ／ ')}。ロッカーでみんなが、こちらの言葉を待っている。`;
    }
    const grads = all.filter((p) => p.grade === 3).sort((a, b) => (b.star ? 1 : 0) - (a.star ? 1 : 0) || YA.ovr(b) - YA.ovr(a));
    const shown = grads.slice(0, 4).map((p) => `${p.name}${p.star ? '★' : ''}「${YA.say(w, p, 'thanks')}」`).join(' ／ ');
    return `卒業式。${grads.length}人がグラウンドに並び、順に挨拶をした。 ${shown}`;
  }
  const run = (line, fn) => ({ label: null, kind: null, run: (w, p, r) => { const s = fn ? fn(w) : ''; return { line, small: s || '' }; } });
  function sceneOpts(w, e) {
    const o = (label, line, fn) => Object.assign(run(line, fn), { label });
    if (e.sc === 'enter') return [
      o('「ようこそ。三年間、本気でやろう」と声をかける', '新入生の顔が引き締まった。', (ww) => { const l = Object.values(ww.players).filter((p) => p.grade === 1); bump(l, 'conf', 3); return `新入生の自信 +3`; }),
      o('「まず慣れることからだ」と肩の力を抜かせる', '新入生の肩から力が抜けた。', (ww) => { const l = Object.values(ww.players).filter((p) => p.grade === 1); bump(l, 'conf', 1); bump(l, 'fat', -5); return '新入生の自信 +1・疲れ −5'; }),
      o('何も言わず、見守る', '拍手の中、静かに式が終わった。'),
    ];
    if (e.sc === 'camp') return [
      o('★の子と、夜に一人ずつ話す', '一人ずつ、夜風の中で話した。', (ww) => { for (const p of Object.values(ww.players)) if (p.star) YA.hintUp(ww, p, 0.6, '合宿の夜の話'); return '★の子の鍵のヒントが進んだかもしれない'; }),
      o('全員で車座になって、この半年を話す', '笑い声が広がった。', (ww) => { bump(Object.values(ww.players), 'conf', 2); return '全員の自信 +2'; }),
      o('早く寝かせる', 'その夜は、全員がぐっすり眠った。', (ww) => { bump(Object.values(ww.players), 'fat', -8); return '全員の疲れ −8'; }),
    ];
    if (e.sc === 'cup') return [
      o('「ここまで来たら、楽しんでこい」と送り出す', '肩の力が抜けて、笑顔で出ていった。', (ww) => { bump(A_TEAM(ww), 'conf', 3); return 'Aの自信 +3'; }),
      o('「勝ちにいくぞ」と気持ちを引き締める', '全員が大きくうなずいた。', (ww) => { bump(A_TEAM(ww), 'conf', 2); return 'Aの自信 +2'; }),
      o('何も言わず、送り出す', '無言のまま、全員がピッチへ向かった。'),
    ];
    return [
      o('一人ひとりに声をかける', '一人ひとりと握手をして、送り出した。', (ww) => { let n = 0; for (const p of Object.values(ww.players)) if (p.grade === 3 && p.star) { YA.addTr(ww, p, 1, '卒業式の声かけ'); n++; } return n ? `★の卒業生 ${n}人の信頼 +1` : ''; }),
      o('みんなの前で、3年生に感謝を伝える', '拍手が、しばらく鳴りやまなかった。', (ww) => { YA.addRep(ww, 1); return '評判 +1'; }),
      o('見送る', '桜の下を、卒業生が歩いていった。'),
    ];
  }
  function prep(w, e) {
    if (e.id === 'scene') {
      const def = YA.EVENTS.find((x) => x.id === 'scene');
      def.name = SCENE_NAME[e.sc] || '節目の場面';
      def.opts = sceneOpts(w, e);
      def.text = () => sceneText(w, e);
    } else if (e.id === 'path') {
      const def = YA.EVENTS.find((x) => x.id === 'path');
      const p = w.players[e.pid];
      if (!p) return;
      def.opts = YA.pathOptions(p);
      def.text = (q) => `${q.num}番 ${q.name}★（高3・総合力${rate(q)}）が、卒業後の進路の面談に来た。コーチの見立て：${PATH_HINT[YA.pathCands(q)[0]] || ''}「どの道に進みたいか、監督の考えも聞かせてください」`;
    }
  }
  const view0 = YA.eventView;
  YA.eventView = function (w, e) {
    prep(w, e);
    return view0(w, e);
  };
  const res0 = YA.resolveEvent;
  YA.resolveEvent = function (w, e, idx) {
    prep(w, e);
    const out = res0(w, e, idx);
    if (e.id === 'path' && out) {
      const p = w.players[e.pid];
      if (p) out.line = `${p.name}「${YA.say(w, p, 'path')}」`;
    }
    return out;
  };

  // 選んだ道を卒業の形に反映する：社会人・やめるは卒業時に、大学の「遅咲き」は印を付ける
  const ae0 = YA.alumniEntry;
  YA.alumniEntry = function (w, p, note) {
    const a = ae0(w, p, note);
    if (p._p2 === 'corp' || p._p2 === 'quit') {
      a.status = 'amateur';
      a.club = p._p2 === 'quit' ? '一般企業' : '社会人';
      a.league = p._p2 === 'quit' ? '' : '社会人リーグ';
      a.note = (note || '') + (p._p2 === 'quit' ? '（面談で、サッカーをやめて別の道へ）' : '（面談で、社会人として続ける道へ）');
      if (p._p2 === 'quit') a.retired = true;
    } else if (p._p2 === 'abroad' && !a.abroad) a.note = (note || '') + '（海外は届かなかった）';
    if (p._p2) a.path2 = p._p2;
    if (p._p2 === 'univ' && p._pathRec && a.status === 'univ') a.late = true;
    return a;
  };
  // 遅咲き：大学の4年で余分に伸びる
  const at0 = YA.alumniTick;
  YA.alumniTick = function (w) {
    const before = new Map(w.alumni.map((a) => [a, a.status]));
    const res = at0.apply(this, arguments);
    const r = YA.rngOf(w.seed * 83 + w.year * 17);
    for (const a of w.alumni) {
      if (!a.late || a.retired || a.age == null) continue;
      if (a.age <= 22) a.ovr = Math.round((a.ovr + 0.2 + r() * 0.5) * 10) / 10;
      if (before.get(a) === 'univ' && a.status === 'pro') YA.noteTier(w, 1, `面談で大学を勧めた${a.name}が、遅咲きでプロ入りしました（${a.club}）`);
    }
    return res;
  };

  // ---------- 毎週：面談と場面を出す ----------
  function push(w, ev) { w.forced = (w.forced || []).concat([Object.assign({ pid: null, x: null, week: w.week, year: w.year }, ev)]); }
  function storyWeek(w) {
    const key = w.year * 100 + w.week;
    if (w.storyKey === key) return;
    w.storyKey = key;
    if (w.week === 1) push(w, { id: 'scene', sc: 'enter' });
    if (w.week === 22) {
      const cut = YA.topCutLine ? YA.topCutLine(w) : 999;
      for (const p of Object.values(w.players)) if (p.grade === 3 && p.star && rate(p) < cut) push(w, { id: 'path', pid: p.id });
    }
    if (w.week === 26 && w.campChoice && w.campChoice !== 'none') {
      for (const p of Object.values(w.players)) if (p.star) YA.hintUp(w, p, 0.4, '合宿');
      push(w, { id: 'scene', sc: 'camp' });
    }
    if (w.week === 12 || w.week === 30) {
      const k = w.week === 12 ? 'summer' : 'winter';
      const c = w.cup && w.cup[k];
      if (c && c.alive && c.round === c.opps.length - 1) push(w, { id: 'scene', sc: 'cup', cup: k });
    }
    // 進路面談を受けた子には、38週の一般の進路相談を出さない
    if (w.week === 38) w.forced = (w.forced || []).filter((e) => !(e.id === 'career' && w.players[e.pid] && w.players[e.pid]._p2));
    if (w.week === 40) push(w, { id: 'scene', sc: 'grad' });
  }
  const rw0 = YA.rivalWeek;
  YA.rivalWeek = function (w) {
    const r = rw0 ? rw0.apply(this, arguments) : undefined;
    storyWeek(w);
    return r;
  };

  // ---------- スカウトの見立て（決定117）と、入団で分かる当たり外れ（決定148） ----------
  // 腕の良いスカウトほど「大化けの気配」「遅咲きかも」などの一言が付く。外れもある。見に行った子（seen≥1）だけに付く
  const eyeOf = (w) => clamp((YA.staffAb(w, 'スカウト') + (w.coach ? w.coach.eye : 8)) / 2, 3, 18);
  const HUNCH = {
    big: '大化けの気配がある',
    late: '遅咲きかもしれない',
    ready: 'いまが完成形に近いかもしれない',
  };
  // 本当の姿（見えない）：伸びしろが大きく、いまが低ければ「遅咲き」、伸びしろが大きく力もあれば「大化け」、伸びしろが小さければ「完成形」
  const trueKind = (p) => {
    const st = YA.potStars(p), o = YA.ovr(p);
    if (st >= 4 && o >= 8.5) return 'big';
    if (st >= 4) return 'late';
    if (st <= 2) return 'ready';
    return null;
  };
  YA.candHunch = function (w, c) {
    if (!c || c.seen < 1) return null;
    const eye = eyeOf(w);
    let hs = 0;
    for (const ch of c.id + 'h') hs = (hs * 37 + ch.charCodeAt(0)) % 9973;
    const r = (hs % 1000) / 1000;
    const acc = clamp(0.55 + (eye - 8) * 0.05, 0.4, 0.92);
    const tk = trueKind(c.p);
    // 腕が良いほど、気配を感じ取る確率も上がる
    const sense = clamp(0.1 + (eye - 8) * 0.04 + c.seen * 0.05, 0.06, 0.55);
    if (tk && r < sense) {
      if ((hs * 7 % 1000) / 1000 < acc) return { kind: tk, text: HUNCH[tk], true: true };
      const other = ['big', 'late', 'ready'].filter((k) => k !== tk)[hs % 2];
      return { kind: other, text: HUNCH[other], true: false };
    }
    // 何も感じない子にも、まれに外れの見立てが付く（腕が悪いほど）
    if (!tk && r > 0.975 - (8 - eye) * 0.005) { const k = ['big', 'late'][hs % 2]; return { kind: k, text: HUNCH[k], true: false }; }
    return null;
  };
  // 見える幅のめやす（画面に出す言葉）
  YA.rangeWord = (c) => (c.seen >= 3 ? 'ほぼ確か' : c.seen === 2 ? 'だいたい分かる' : c.seen === 1 ? '幅がある' : 'ぼんやり');
  const cv0 = YA.candView;
  YA.candView = function (w, c) {
    const v = cv0(w, c);
    v.hunch = YA.candHunch(w, c);
    v.rangeWord = YA.rangeWord(c);
    return v;
  };
  // 入団した子について、見立てと本当の数字を比べて知らせる（当たり外れが見える）
  const intake0 = YA.intake;
  YA.intake = function (w) {
    const S = w.scouting;
    const pre = [];
    if (S) for (const c of S.cands.filter((x) => x.status === 'signed').slice(0, 12)) {
      const v = YA.candView(w, c);
      pre.push({ p: c.p, lo: YA.rate(v.ovr[0]), hi: YA.rate(v.ovr[1]), stars: v.stars, hunch: v.hunch, seen: c.seen });
    }
    const res = intake0.apply(this, arguments);
    let hit = 0, over = 0, under = 0;
    for (const e of pre) {
      const p = e.p;
      const now = YA.rate(YA.ovr(p));
      const st = YA.potStars(p);
      const pos = e.hi > e.lo ? (now - e.lo) / (e.hi - e.lo) : 0.5; // 見立ての幅の中のどこか
      const kind = pos > 0.66 ? 'over' : pos < 0.34 ? 'under' : 'hit';
      p.scoutNote = { lo: e.lo, hi: e.hi, now, kind, hunch: e.hunch ? { text: e.hunch.text, true: e.hunch.true } : null };
      if (kind === 'hit') hit++; else if (kind === 'over') over++; else under++;
      if (kind !== 'hit' || e.hunch) {
        const hn = e.hunch ? `「${e.hunch.text}」という見立ては${e.hunch.true ? '当たっていた' : '外れた'}（伸びしろ★${st}）。` : '';
        YA.noteTier(w, kind === 'hit' ? 3 : 2, `入団した${p.name}：見立ては総合力${e.lo}〜${e.hi}、本当は${now}（${kind === 'over' ? '幅の上のほう＝当たり' : kind === 'under' ? '幅の下のほう＝外れ' : '見立てどおり'}）。${hn}`);
      }
    }
    w.scoutScore = w.scoutScore || { hit: 0, over: 0, under: 0 };
    w.scoutScore.hit += hit; w.scoutScore.over += over; w.scoutScore.under += under;
    return res;
  };
  YA.EXTRA_SIM_IMPORTANT = (YA.EXTRA_SIM_IMPORTANT || []).concat(['path']);
})();
