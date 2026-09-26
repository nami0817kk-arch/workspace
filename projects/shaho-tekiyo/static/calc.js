// 計算機の計算部分。画面の組み立て（templates/calculator.html）とは分けてある。
// **正は Python 側（src/eligibility.py・src/premium.py）で、ここはその写し。**
// tests/test_calc_js.py が node でこのファイルを動かし、Python と同じ答えになることを確かめている。
// どちらかを直したら、もう片方も同じように直すこと。
(function (root) {
  "use strict";

  var UNIT = 100000; // 料率は 1/100000 単位の整数（10.28% → 10280）

  function regimeFor(schedule, asOfIso) {
    if (asOfIso < schedule[0].effective_from) return null;
    var applicable = schedule[0];
    for (var i = 0; i < schedule.length; i++) {
      if (schedule[i].effective_from <= asOfIso) applicable = schedule[i];
      else break;
    }
    return applicable;
  }

  function evaluate(schedule, hoursRequirement, asOfIso, weeklyHours, monthlyWageYen, isStudent, employerSize) {
    var regime = regimeFor(schedule, asOfIso);
    if (!regime) return null;
    var hoursOk = weeklyHours >= hoursRequirement;
    var wageOk = regime.wage_requirement_yen === null || monthlyWageYen >= regime.wage_requirement_yen;
    var notStudentOk = !isStudent;
    var employerSizeOk = regime.company_size_threshold === null || employerSize >= regime.company_size_threshold;
    return {
      regime: regime,
      hoursOk: hoursOk,
      wageOk: wageOk,
      notStudentOk: notStudentOk,
      employerSizeOk: employerSizeOk,
      eligible: hoursOk && wageOk && notStudentOk && employerSizeOk
    };
  }

  function tableFor(tables, asOfIso) {
    for (var i = 0; i < tables.length; i++) {
      if (tables[i].valid_from <= asOfIso && asOfIso <= tables[i].valid_until) return tables[i];
    }
    return null; // 収録していない時点は計算しない（premium.RatesOutOfRange と同じ）
  }

  function standardMonthly(grades, pay) {
    var applicable = grades[0];
    for (var i = 0; i < grades.length; i++) {
      if (pay >= grades[i][2]) applicable = grades[i];
      else break;
    }
    return applicable[1];
  }

  // 標準報酬月額 × 料率 ÷ 2 を、天引きの端数処理（50銭以下切り捨て・超えたら切り上げ）にかける。
  // 整数だけで計算する（浮動小数だと 0.5 ちょうどの判定がずれる）。
  function employeeShare(standard, units) {
    var num = standard * units;
    var den = 2 * UNIT;
    var whole = Math.floor(num / den);
    var rem = num - whole * den;
    return whole + (2 * rem > den ? 1 : 0);
  }

  function estimate(tables, asOfIso, prefecture, monthlyPay, age40to64) {
    var table = tableFor(tables, asOfIso);
    if (!table) return null;
    var rates = table.prefectures[prefecture];
    if (!rates) return null;
    var healthStd = standardMonthly(table.health_grades, monthlyPay);
    var pensionStd = standardMonthly(table.pension_grades, monthlyPay);
    var health = employeeShare(healthStd, rates.health + (age40to64 ? rates.care : 0));
    var kodomo = employeeShare(healthStd, rates.kodomo);
    var pension = employeeShare(pensionStd, rates.pension);
    return {
      table: table,
      healthStandard: healthStd,
      pensionStandard: pensionStd,
      health: health,
      kodomo: kodomo,
      pension: pension,
      total: health + kodomo + pension,
      takeHome: monthlyPay - (health + kodomo + pension)
    };
  }

  // ---- extras.py の写し（雇用保険料・国民年金保険料・将来の年金・都道府県名） ----
  function periodFor(entries, asOfIso) {
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].valid_from <= asOfIso && asOfIso <= entries[i].valid_until) return entries[i];
    }
    return null;
  }

  // 50銭以下切り捨て・超えたら切り上げ（premium.payroll_round と同じ）。num/den を整数で。
  function payrollRound(num, den) {
    var whole = Math.floor(num / den);
    var rem = num - whole * den;
    return whole + (2 * rem > den ? 1 : 0);
  }

  function employmentYen(extras, asOfIso, grossPay) {
    var e = periodFor(extras.employment, asOfIso);
    return e ? payrollRound(grossPay * e.worker_per_mille, 1000) : null;
  }

  function kokuminNenkinYen(extras, asOfIso) {
    var e = periodFor(extras.kokumin_nenkin, asOfIso);
    return e ? e.monthly_yen : null;
  }

  function pensionIncreasePerYear(extras, pensionStandard) {
    return Math.floor(pensionStandard * extras.pension_accrual.per_mille_x1000 * 12 / 1000000);
  }

  function sicknessDailyYen(healthStandard) {
    var perDay = Math.floor((healthStandard + 150) / 300) * 10;
    return Math.floor((4 * perDay + 3) / 6);
  }

  function band(rows, amount) {
    for (var i = 0; i < rows.length; i++) {
      if (amount >= rows[i][0] && (rows[i][1] === null || amount <= rows[i][1])) return rows[i];
    }
    return null;
  }

  // 所得税（月額表・甲欄の電算機計算の特例、令和8年分）。extras.income_tax_yen と同じ。
  function incomeTaxYen(extras, asOfIso, afterSocial, dependents) {
    var w = periodFor(extras.withholding, asOfIso);
    if (!w) return null;
    var a = Math.max(afterSocial, 0);
    var e = band(w.employment_deduction, a);
    var kyuyo = Math.ceil(a * e[2] / 100000) + e[3];
    var basic = band(w.basic_deduction, a)[2];
    var b = a - kyuyo - w.dependent_deduction * (dependents || 0) - basic;
    if (b <= 0) return 0;
    var r = band(w.rates, b);
    var num = b * r[2] - r[3] * 100000;
    if (num <= 0) return 0;
    return Math.floor((num + 500000) / 1000000) * 10;
  }

  // ---- kabe.py の写し（週20時間の壁） ----
  function kabePay(hourly, hoursX10) {
    return Math.floor((hourly * hoursX10 * 52 * 2 + 120) / 240);
  }

  function netCovered(tables, extras, asOfIso, pay, prefecture, age) {
    var p = estimate(tables, asOfIso, prefecture, pay, age);
    if (!p) return null;
    var koyo = employmentYen(extras, asOfIso, pay);
    if (koyo === null) return null;
    var tax = incomeTaxYen(extras, asOfIso, pay - p.total - koyo, 0);
    if (tax === null) return null;
    return pay - p.total - koyo - tax;
  }

  function kabeAnalyze(tables, extras, asOfIso, hourly, prefecture, age) {
    var pay19 = kabePay(hourly, 190);
    var tax19 = incomeTaxYen(extras, asOfIso, pay19, 0);
    var pay20 = kabePay(hourly, 200);
    var net20 = netCovered(tables, extras, asOfIso, pay20, prefecture, age);
    if (tax19 === null || net20 === null) return null;
    var net19 = pay19 - tax19;
    var be = null;
    for (var h = 200; h <= 400; h += 5) {
      var pay = kabePay(hourly, h);
      var net = netCovered(tables, extras, asOfIso, pay, prefecture, age);
      if (net !== null && net >= net19) { be = { hoursX10: h, pay: pay, net: net }; break; }
    }
    return { pay19: pay19, net19: net19, pay20: pay20, net20: net20, loss: net19 - net20, breakeven: be };
  }

  // 週の時間ごとの手取り（図に使う）。hoursX10 の並びを受け取る。190 は加入なしで計算する。
  function kabeRows(tables, extras, asOfIso, hourly, prefecture, age, hoursList) {
    return hoursList.map(function (h) {
      var pay = kabePay(hourly, h);
      var net;
      if (h < 200) {
        var tax = incomeTaxYen(extras, asOfIso, pay, 0);
        net = tax === null ? null : pay - tax;
      } else {
        net = netCovered(tables, extras, asOfIso, pay, prefecture, age);
      }
      return { hoursX10: h, pay: pay, net: net };
    });
  }

  function prefFull(short) {
    if (short === '北海道') return short;
    if (short === '東京') return '東京都';
    if (short === '京都' || short === '大阪') return short + '府';
    return short + '県';
  }

  var api = {
    regimeFor: regimeFor, evaluate: evaluate, tableFor: tableFor, estimate: estimate,
    employmentYen: employmentYen, kokuminNenkinYen: kokuminNenkinYen,
    pensionIncreasePerYear: pensionIncreasePerYear, sicknessDailyYen: sicknessDailyYen, incomeTaxYen: incomeTaxYen, kabeAnalyze: kabeAnalyze, kabeRows: kabeRows, prefFull: prefFull
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.ShahoCalc = api;
})(this);
