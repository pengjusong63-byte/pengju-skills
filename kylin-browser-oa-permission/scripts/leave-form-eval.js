// ============================================================
// OA 请假表单填充脚本 (Ultra-Batch)
// 通过 agent-browser eval 在 iframe 内执行
// 
// 使用方式:
//   CLI 会在执行前注入 const 声明（eval-file KEY=VALUE 语法），
//   因此本文件只需定义函数体，变量由 CLI 注入。
//   未注入时有默认值兜底。
// ============================================================

(async () => {
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const iframe = document.querySelector("iframe");
  if (!iframe) return { error: "no_iframe" };
  const doc = iframe.contentDocument || iframe.contentWindow.document;
  const win = iframe.contentWindow;

  // 以下变量由 CLI 通过 eval-file KEY=VALUE 注入（外层 const 声明）
  // 通过 globalThis 读取避免 Temporal Dead Zone（与内部 const 同名导致 typeof 抛 ReferenceError）
  const $ = (name, fallback) => typeof globalThis[name] !== "undefined" ? globalThis[name] : fallback;
  const LEAVE_TYPE   = $("LEAVE_TYPE",   "年假");
  const START_DAY    = $("START_DAY",    "18");
  const START_MONTH  = Number($("START_MONTH",  9));  // Number() 兼容 CLI 注入的字符串 "9"
  const START_PERIOD = $("START_PERIOD", "上午");
  const END_DAY      = $("END_DAY",      "18");
  const END_MONTH    = Number($("END_MONTH",    9));
  const END_PERIOD   = $("END_PERIOD",   "下午");
  const REASON       = $("REASON",       "家里有事");

  const clickFull = el => {
    if (!el) return;
    ["mouseover", "mousedown", "mouseup", "click"].forEach(type => {
      el.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, view: win }));
    });
  };

  async function ensureMonth(targetMonth, maxAttempts = 20) {
    const getCurrentMonth = () => {
      const el = doc.querySelector(".rc-calendar-month-select");
      if (el) {
        const text = el.innerText.trim();
        const match = text.match(/(\d+)/);
        if (match) return parseInt(match[1], 10);
      }
      return null;
    };

    let current = getCurrentMonth();
    if (current === null) return false;
    if (current === targetMonth) return true;

    const nextBtn = doc.querySelector(".rc-calendar-next-month-btn");
    const prevBtn = doc.querySelector(".rc-calendar-prev-month-btn");

    let attempts = 0;
    while (current !== targetMonth && attempts < maxAttempts) {
      const btn = targetMonth > current ? nextBtn : prevBtn;
      if (!btn) break;
      clickFull(btn);
      await sleep(400);
      current = getCurrentMonth();
      attempts++;
    }
    return current === targetMonth;
  }

  const result = { steps: [], fields: {} };

  // --- 检查表单是否已打开 ---
  const hasForm = !!(doc.querySelector(".pk_leave_type") && doc.querySelector("[attrcode=showbegindate]"));
  if (!hasForm) {
    clickFull(doc.querySelector("[nodekey=\"leave\"]"));
    await sleep(1500);
    clickFull([...doc.querySelectorAll("*")].find(n => n.innerText?.trim() === "新增"));
    await sleep(2000);
  }

  // --- 选择请假类型 ---
  try {
    const icon = doc.querySelector(".pk_leave_type .icon-refer, .icon-refer");
    if (icon) {
      clickFull(icon);
      await sleep(1000);
      const td = [...doc.querySelectorAll(".refer-td")].find(el => el.innerText.trim() === LEAVE_TYPE);
      if (td) {
        td.dispatchEvent(new MouseEvent("dblclick", { bubbles: true, cancelable: true }));
        await sleep(200);
        const input = doc.querySelector(".pk_leave_type input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.leaveType = LEAVE_TYPE;
        result.steps.push("leave_type: ok");
      }
    }
  } catch (e) { result.steps.push("leave_type: " + e.message); }

  await sleep(2000);

  // --- 选择开始日期 ---
  try {
    const startField = doc.querySelector("[attrcode=showbegindate]");
    if (startField) {
      const icon = startField.querySelector(".u-input-group-btn, .iconfont");
      clickFull(icon);
      await sleep(800);
      await ensureMonth(START_MONTH);
      await sleep(300);
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = win.getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.display !== "none" && s.visibility !== "hidden";
      };
      const target = [...doc.querySelectorAll(".u-calendar-date, .u-calendar-cell, td")]
        .filter(visible)
        .find(el => (el.innerText || "").trim() === START_DAY);
      if (target) {
        clickFull(target);
        await sleep(200);
        const input = doc.querySelector("[attrcode=showbegindate] input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.startDate = START_DAY;
        result.steps.push("start_date: ok");
      }
    }
  } catch (e) { result.steps.push("start_date: " + e.message); }

  await sleep(300);

  // --- 选择开始时段 ---
  try {
    const startPeriodField = doc.querySelector(".start_day_type");
    if (startPeriodField) {
      clickFull(startPeriodField);
      await sleep(500);
      const option = [...doc.querySelectorAll("li, div, span")].find(el => (el.innerText || "").trim() === START_PERIOD);
      if (option) {
        clickFull(option);
        await sleep(200);
        const input = doc.querySelector(".start_day_type input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.startPeriod = START_PERIOD;
        result.steps.push("start_period: ok");
      }
    }
  } catch (e) { result.steps.push("start_period: " + e.message); }

  await sleep(300);

  // --- 选择结束日期 ---
  try {
    const endField = doc.querySelector("[attrcode=showenddate]");
    if (endField) {
      const icon = endField.querySelector(".u-input-group-btn, .iconfont");
      clickFull(icon);
      await sleep(800);
      await ensureMonth(END_MONTH);
      await sleep(300);
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = win.getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.display !== "none" && s.visibility !== "hidden";
      };
      const target = [...doc.querySelectorAll(".u-calendar-date, .u-calendar-cell, td")]
        .filter(visible)
        .find(el => (el.innerText || "").trim() === END_DAY);
      if (target) {
        clickFull(target);
        await sleep(200);
        const input = doc.querySelector("[attrcode=showenddate] input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.endDate = END_DAY;
        result.steps.push("end_date: ok");
      }
    }
  } catch (e) { result.steps.push("end_date: " + e.message); }

  await sleep(300);

  // --- 选择结束时段 ---
  try {
    const arrow = doc.querySelector(".end_day_type .u-select-arrow") || doc.querySelector(".u-select-arrow");
    if (arrow) {
      clickFull(arrow);
      await sleep(1500);
      let option = [...doc.querySelectorAll(".u-select-dropdown li, .u-select-item")]
        .find(el => (el.innerText || "").trim() === END_PERIOD);
      if (!option) {
        option = [...doc.querySelectorAll("*")].find(el => {
          const text = (el.innerText || "").trim();
          return text === END_PERIOD && el.offsetParent !== null;
        });
      }
      if (option) {
        clickFull(option);
        await sleep(200);
        const input = doc.querySelector(".end_day_type input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.endPeriod = END_PERIOD;
        result.steps.push("end_period: ok");
      }
    }
  } catch (e) { result.steps.push("end_period: " + e.message); }

  await sleep(300);

  // --- 填写请假原因 ---
  try {
    const reasonField = doc.querySelector(".leaveremark");
    if (reasonField) {
      const input = reasonField.querySelector("textarea, input");
      if (input) {
        const setter = Object.getOwnPropertyDescriptor(input.constructor.prototype, "value")?.set;
        if (setter) setter.call(input, REASON);
        else input.value = REASON;
        ["focus", "input", "change", "blur"].forEach(type => {
          input.dispatchEvent(new Event(type, { bubbles: true, cancelable: true }));
        });
        result.fields.reason = REASON;
        result.steps.push("reason: ok");
      }
    }
  } catch (e) { result.steps.push("reason: " + e.message); }

  const filledCount = Object.keys(result.fields).length;

  return {
    success: filledCount >= 6,
    fields: result.fields,
    steps: result.steps,
    ready: filledCount >= 6,
    needs: filledCount < 6 ? "fix_missing" : "verify_submit"
  };
})()