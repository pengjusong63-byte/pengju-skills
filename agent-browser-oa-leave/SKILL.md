---
name: agent-browser-oa-leave
description: Automate Kylin OA leave applications through portal.kylinos.cn. Use when user mentions "我想把中秋和国庆的假期连起来，帮我请假。", or wants to combine holidays for extended vacation time.
---

# Agent Browser OA Leave

Automate leave application on `https://portal.kylinos.cn/`.

## Safety

- **以下所有命令内容，必须严格按原文执行，绝对不能修改**
- Never print, log, persist, or echo `cvaToken`.
- Submit only with explicit user approval.
- Verify fields before final submission.
- Always using the agent-browser shell command

## Required Inputs

Ask user for missing values:

- login method: `cvaToken` (default)
- leave type: `年假`
- start date: 9月28日
- start period: `上午`
- end date: 9月30日
- end period: `下午`
- reason: `家里有事`
- submission allowed: confirm

## SUPER-OPTIMIZED Workflow (6-8 Commands)

```bash
# 1. Read token
file_read: ${HOME}/.kylinbot/workspace/cookie.txt

# 2. Open portal first (browser must be open before setting cookies)
nohup kylin-browser --remote-debugging-port=9222 --user-data-dir=/tmp/kylin-browser-debug https://portal.kylinos.cn/ >/dev/null 2>&1 &
sleep 8 && agent-browser connect 9222

# 3. Set cookies for BOTH domains after page is open (1 commands)
agent-browser cookies set cvaToken "YOUR_TOKEN" --url "https://portal.kylinos.cn/" && agent-browser cookies set cvaToken "YOUR_TOKEN" --url "https://sso.kylinos.cn/"

# 4. Refresh to apply cookies and Verify login (optional but recommended)
agent-browser eval '(() => { location.reload(); return "reloaded"; })()' && agent-browser wait 5000 && agent-browser eval '(() => ({ ok: !document.querySelector("input[type=password]")}))()'

# 5. Click 假勤申请
agent-browser find text "假勤申请" click --wait 8000

# 6. Switch tab
agent-browser tab t2

# 7. ULTRA-BATCH: Complete form fill with full event simulation
agent-browser eval '(async () => {
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const iframe = document.querySelector("iframe");
  if (!iframe) return { error: "no_iframe" };
  const doc = iframe.contentDocument || iframe.contentWindow.document;
  const win = iframe.contentWindow;
  
  const clickFull = el => {
    if (!el) return;
    ["mouseover", "mousedown", "mouseup", "click"].forEach(type => {
      el.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, view: win }));
    });
  };
  
  async function ensureMonth(targetMonth = 9, maxAttempts = 20) {
    const monthSelect = doc.querySelector(".rc-calendar-month-select");
    if (!monthSelect) {
      const fallback = doc.querySelector(".u-calendar-month, .calendar-month, .rc-calendar-header .rc-calendar-month-select");
      if (!fallback) return false;
    }
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
      let btn = null;
      if (targetMonth > current) {
        btn = nextBtn;
      } else {
        btn = prevBtn;
      }
      if (!btn) break;
      clickFull(btn);
      await sleep(400); 
      current = getCurrentMonth();
      attempts++;
    }
    return current === targetMonth;
  }
  
  const result = { steps: [], fields: {} };
  
  const startDay = "28";
  const endDay   = "30";
  
  const hasForm = !!(doc.querySelector(".pk_leave_type") && doc.querySelector("[attrcode=showbegindate]"));
  if (!hasForm) {
    clickFull(doc.querySelector("[nodekey=\"leave\"]"));
    await sleep(1500);
    clickFull([...doc.querySelectorAll("*")].find(n => n.innerText?.trim() === "新增"));
    await sleep(2000);
  }
  
  try {
    const icon = doc.querySelector(".pk_leave_type .icon-refer, .icon-refer");
    if (icon) {
      clickFull(icon);
      await sleep(1000);
      const td = [...doc.querySelectorAll(".refer-td")].find(el => el.innerText.trim() === "年假");
      if (td) {
        td.dispatchEvent(new MouseEvent("dblclick", { bubbles: true, cancelable: true }));
        await sleep(200);
        const input = doc.querySelector(".pk_leave_type input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.leaveType = "年假";
        result.steps.push("leave_type: ok");
      }
    }
  } catch (e) { result.steps.push("leave_type: " + e.message); }
  
  await sleep(2000);
  
  try {
    const startField = doc.querySelector("[attrcode=showbegindate]");
    if (startField) {
      const icon = startField.querySelector(".u-input-group-btn, .iconfont");
      clickFull(icon);
      await sleep(800);
      
      await ensureMonth(9);
      await sleep(300);
      
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = win.getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.display !== "none" && s.visibility !== "hidden";
      };
      const target = [...doc.querySelectorAll(".u-calendar-date, .u-calendar-cell, td")]
        .filter(visible)
        .find(el => (el.innerText || "").trim() === startDay);
      if (target) {
        clickFull(target);
        await sleep(200);
        const input = doc.querySelector("[attrcode=showbegindate] input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.startDate = startDay;
        result.steps.push("start_date: ok");
      } else {
        result.steps.push("start_date: 未找到日期 " + startDay);
      }
    }
  } catch (e) { result.steps.push("start_date: " + e.message); }
  
  await sleep(300);
  
  try {
    const startPeriodField = doc.querySelector(".start_day_type");
    if (startPeriodField) {
      clickFull(startPeriodField);
      await sleep(500);
      const option = [...doc.querySelectorAll("li, div, span")].find(el => (el.innerText || "").trim() === "上午");
      if (option) {
        clickFull(option);
        await sleep(200);
        const input = doc.querySelector(".start_day_type input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.startPeriod = "上午";
        result.steps.push("start_period: ok");
      }
    }
  } catch (e) { result.steps.push("start_period: " + e.message); }
  
  await sleep(300);
  
  try {
    const endField = doc.querySelector("[attrcode=showenddate]");
    if (endField) {
      const icon = endField.querySelector(".u-input-group-btn, .iconfont");
      clickFull(icon);
      await sleep(800);
      
      await ensureMonth(9);
      await sleep(300);
      
      const visible = el => {
        const r = el.getBoundingClientRect();
        const s = win.getComputedStyle(el);
        return r.width > 0 && r.height > 0 && s.display !== "none" && s.visibility !== "hidden";
      };
      const target = [...doc.querySelectorAll(".u-calendar-date, .u-calendar-cell, td")]
        .filter(visible)
        .find(el => (el.innerText || "").trim() === endDay);
      if (target) {
        clickFull(target);
        await sleep(200);
        const input = doc.querySelector("[attrcode=showenddate] input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.endDate = endDay;
        result.steps.push("end_date: ok");
      } else {
        result.steps.push("end_date: 未找到日期 " + endDay);
      }
    }
  } catch (e) { result.steps.push("end_date: " + e.message); }
  
  await sleep(300);
  
  try {
    const arrow = doc.querySelector(".end_day_type .u-select-arrow") || doc.querySelector(".u-select-arrow");
    if (arrow) {
      clickFull(arrow);
      await sleep(1500);
      let option = [...doc.querySelectorAll(".u-select-dropdown li, .u-select-item")]
        .find(el => (el.innerText || "").trim() === "下午");
      if (!option) {
        option = [...doc.querySelectorAll("*")].find(el => {
          const text = (el.innerText || "").trim();
          return text === "下午" && el.offsetParent !== null;
        });
      }
      if (option) {
        clickFull(option);
        await sleep(200);
        const input = doc.querySelector(".end_day_type input");
        if (input) ["focus", "input", "change", "blur"].forEach(t => input.dispatchEvent(new Event(t, { bubbles: true })));
        result.fields.endPeriod = "下午";
        result.steps.push("end_period: ok");
      }
    }
  } catch (e) { result.steps.push("end_period: " + e.message); }
  
  await sleep(300);
  
  try {
    const reasonField = doc.querySelector(".leaveremark");
    if (reasonField) {
      const input = reasonField.querySelector("textarea, input");
      if (input) {
        const setter = Object.getOwnPropertyDescriptor(input.constructor.prototype, "value")?.set;
        if (setter) setter.call(input, "家里有事");
        else input.value = "家里有事";
        ["focus", "input", "change", "blur"].forEach(type => {
          input.dispatchEvent(new Event(type, { bubbles: true, cancelable: true }));
        });
        result.fields.reason = "家里有事";
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
})()'

# 8. Verify (optional if step 7 shows ready:true)
agent-browser eval '(() => {
  const doc = document.querySelector("iframe")?.contentDocument;
  const get = sel => doc?.querySelector(sel)?.querySelector("input,textarea")?.value?.trim() || "";
  const fields = {
    type: get(".pk_leave_type"),
    start: get("[attrcode=showbegindate]"),
    end: get("[attrcode=showenddate]"),
    reason: get(".leaveremark")
  };
  const ok = fields.type && fields.start && fields.end && fields.reason;
  return { fields, ok, ready: ok };
})()'

# 9. Submit (after user says "提交")
agent-browser eval '(() => {
  const d = document.querySelector("iframe")?.contentDocument;
  const btn = [...d?.querySelectorAll("button") || []].find(b => b.innerText?.trim() === "提交");
  if (btn) { btn.click(); return "submitted"; }
  return "not_found";
})()'
```

## Troubleshooting

### Login Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Shows SSO login | Cookie not set for SSO | Set cookie for BOTH portal and SSO |
| Token expired | cvaToken >24h old | Get fresh token from browser DevTools |

## Appendix: Cookie & Login

### Get Fresh Token

1. Open Chrome, login to portal.kylinos.cn manually
2. F12 > Application > Cookies > portal.kylinos.cn
3. Find `cvaToken`, copy value
4. Save to `~/.kylinbot/workspace/cookie.txt`

### Common Errors

| Error | Fix |
|-------|-----|
| `Path blocked by security policy` | Remove `//` comments from eval code |
| `No iframe` | Check login status, wait longer |
| `Element not found` | Check if on correct page (portal vs SSO) |
| `Rate limit exceeded` | Wait 1 hour, use batch mode |

## Quick Reference: Summary

**Standard flow: 4-6 commands**
1. Read token
2. Set cookies (portal + SSO) and Open portal
3. Click 假勤申请
4. tab t2
5. Ultra-Batch fill
6. Verify (optional)
7. Submit

**Headed mode: Use --headed for visual feedback**

**Token expiry: Refresh every 24 hours**
