---
name: chaoxing
description: 超星(chaoxing)平台在线作业自动答题。当用户提到要在超星平台(mooc1.chaoxing.com / mooc2-ans.chaoxing.com)完成作业、考试、章节测试、在线答题等任务时使用此skill。也适用于超星平台的Java课程、面向对象程序设计等课程作业。触发词包括：超星、chaoxing、学习通、在线作业、自动答题、填写答案等。
---

# 超星平台自动答题

## 概述

此 skill 通过 CDP (Chrome DevTools Protocol) 操控用户本地浏览器，自动完成超星（学习通）平台上的作业。支持单选题、多选题、填空题、判断题等常见题型。

## 依赖与前置条件

使用此 skill 前，**必须**确认以下依赖已就绪。如未安装，先引导用户完成安装再继续。

### 必需外部依赖

| 依赖 | 用途 | 检查方式 | 安装方式 |
|------|------|----------|----------|
| **Node.js 22+** | CDP Proxy 运行环境 | `node -v` | `brew install node` 或 [nodejs.org](https://nodejs.org) |
| **Chrome/Edge 浏览器** | CDP 远程调试载体 | 需开启远程调试 | 已安装则无需重装 |
| **web-access skill** | CDP Proxy 和浏览器操控 API | `Skill` 工具调用 `web-access:web-access` | `find-skills` 搜索安装 |

### 第一步：加载 web-access skill 并检查环境

**先调用 `Skill` 工具加载 `web-access:web-access`**。web-access skill 加载后会提供其 base directory 路径（以 `Base directory for this skill:` 开头），记下这个路径，后续需要用其中的 `scripts/check-deps.mjs` 检查环境。

执行环境检查（`<WEB_ACCESS_BASE>` 替换为 web-access skill 的实际 base directory）：

```bash
node "<WEB_ACCESS_BASE>/scripts/check-deps.mjs"
```

期望输出包含：
```
node: ok
chrome: ok (port XXXX)
proxy: ready
```

如果报 `chrome: not connected`，说明浏览器远程调试未开启。让用户按下方说明操作。

### 第二步：开启浏览器远程调试

在浏览器地址栏输入：
- Chrome: `chrome://inspect/#remote-debugging`
- Edge: `edge://inspect/#remote-debugging`

勾选 **"Allow remote debugging for this browser instance"**，可能需要重启浏览器。

### Edge 浏览器用户必读（macOS / Linux / Windows）

**web-access skill 原生只支持 Chrome。** Edge 用户需要修改 web-access skill 的两个脚本文件，在其中添加 Edge 的 DevToolsActivePort 路径。

可使用本 skill 自带的修复脚本一键完成（自动识别平台）：

```bash
bash <CHAOXING_SKILL_BASE>/scripts/edge-fix.sh <WEB_ACCESS_BASE>
```

`<CHAOXING_SKILL_BASE>` 为本 skill 的安装目录，`<WEB_ACCESS_BASE>` 为 web-access skill 的 base directory。

也可以手动修改 — 在 `check-deps.mjs` 和 `cdp-proxy.mjs` 中分别添加对应平台的 Edge 路径：

| 平台 | 要添加的路径 |
|------|-------------|
| macOS | `path.join(home, 'Library/Application Support/Microsoft Edge/DevToolsActivePort'),` |
| Linux | `path.join(home, '.config/microsoft-edge/DevToolsActivePort'),` |
| Windows | `path.join(localAppData, 'Microsoft Edge/User Data/DevToolsActivePort'),` |

在 `check-deps.mjs` 中找到对应平台的 `case` / `return` 数组，在 Chromium 行之后追加；在 `cdp-proxy.mjs` 中找到 `discoverChromePort()` 函数对应平台的 `possiblePaths.push(...)` 段末尾追加。

修改后重新运行 `check-deps.mjs` 验证。

### 使用前确认清单

- [ ] Node.js 22+ 已安装
- [ ] Chrome/Edge 浏览器已打开
- [ ] 浏览器远程调试已开启（`check-deps.mjs` 通过）
- [ ] CDP Proxy 已连接（`proxy: ready`）
- [ ] 用户已在超星平台打开目标作业页面

---

## 答题流程

### 第一步：定位作业页面

```bash
curl -s http://localhost:3456/targets
```

在返回的 JSON 数组中，找到 title 为"作业作答"（或"考试作答"）且 url 包含 `chaoxing.com/mooc-ans/mooc2/work/dowork` 的 targetId。如果同时存在多个，优先选择最近打开的（数组中靠后的）。

### 第二步：读取题目内容

先滚动到底部触发懒加载，再提取题目文本：

```bash
# 滚动到底部
curl -s "http://localhost:3456/scroll?target=TARGET_ID&direction=bottom"

# 提取所有文字内容
curl -s -X POST "http://localhost:3456/eval?target=TARGET_ID" -d 'document.body.innerText'
```

### 第三步：分析题目并确定答案

根据提取的题目文本，逐题分析确定正确答案。超星平台常见题型：

- **单选题**：从 A/B/C/D 中选出 1 个正确答案
- **填空题**：在空白处填写正确内容（可能一道题有多个空）
- **判断题**：对（A）或错（B）

分析答案时注意题目可能重复出现（同一知识点换表述），答案应保持一致。

### 第四步：获取题目ID和填空映射

一次性获取题目 ID 列表和 textarea 到 UEditor 的映射：

```bash
curl -s -X POST "http://localhost:3456/eval?target=TARGET_ID" -d '
(() => {
  const result = [];
  const qLis = document.querySelectorAll(".questionLi");
  qLis.forEach((li, i) => {
    const text = (li.innerText || "").substring(0, 60).replace(/\n/g, " ");
    result.push(i + ": id=" + li.id + " | " + text);
  });
  result.push("---TEXTAREA_MAP---");
  const textareas = document.querySelectorAll("textarea[id^=answerEditor]");
  textareas.forEach((ta, i) => {
    result.push("textarea " + i + ": " + ta.id + " -> ueditorInstant" + i);
  });
  return result.join("\n");
})()
```

### 第五步：填入所有答案（一次 eval 完成）

将所有答案通过一次 eval 调用填入，减少网络往返。

#### 单选题和判断题 — 点击选项

题目容器 `div.questionLi` 内有 `div.answerBg[role="radio"]`（带 `onclick="addChoice(this)"`），其中 `span[data]` 标识选项：

| 题型 | data 属性值 |
|------|------------|
| 单选题 | `"A"`, `"B"`, `"C"`, `"D"` |
| 判断题 | `"true"`（对/A）或 `"false"`（错/B） |

点击方式：找到选项 span → 定位父元素 `.answerBg` → `scrollIntoView` → `click()`：

```javascript
const span = questionDiv.querySelector('span[data="C"]');    // 单选题选C
const span = questionDiv.querySelector('span[data="true"]');  // 判断题选对
const answerBg = span.closest(".answerBg");
answerBg.scrollIntoView({ block: "center" });
answerBg.click();
```

#### 填空题 — UEditor API（关键！）

超星填空题使用 **UEditor** 富文本编辑器。每个填空对应一个 UEditor 实例，命名规则为 `ueditorInstant0`, `ueditorInstant1` ... 按 textarea 在 DOM 中的出现顺序递增。

**绝对不要用 `setContent()`！** 它会将内容当做 HTML 解析，导致 `<T>`、`<>`、`<E>` 等包含尖括号的字符被过滤或转义。这是实战中踩过的坑。

**正确做法：使用 `body.innerText` 直接设置纯文本：**

```javascript
const inst = UE.instants["ueditorInstant" + index];
inst.body.innerText = "答案内容";
```

#### 完整填充脚本模板

将以下模板中的答案数据替换后执行：

```bash
curl -s -X POST "http://localhost:3456/eval?target=TARGET_ID" -d '
(() => {
  // === 填空题答案（按 textarea 在 DOM 中的顺序排列）===
  const fillAnswers = [
    "第1空答案",
    "第2空答案",
    // ... 依次对应 ueditorInstant0, ueditorInstant1, ...
  ];

  let ok = 0, errs = [];
  for (let i = 0; i < fillAnswers.length; i++) {
    const inst = UE.instants["ueditorInstant" + i];
    if (!inst || !inst.body) { errs.push("ueditorInstant" + i + " 不存在"); continue; }
    try {
      inst.body.innerText = fillAnswers[i];
      ok++;
    } catch(e) { errs.push(i + ":" + e.message); }
  }

  // === 单选题答案（questionId -> 选项 data 值）===
  const singleChoice = {
    question404811xxx: "A",
    question404811xxx: "C",
    // ...
  };

  let sc = 0;
  for (const [qid, dv] of Object.entries(singleChoice)) {
    const div = document.getElementById(qid);
    if (!div) { errs.push(qid + " 不存在"); continue; }
    const span = div.querySelector("span[data=\"" + dv + "\"]");
    if (!span) { errs.push(qid + " 无选项" + dv); continue; }
    span.closest(".answerBg").scrollIntoView({ block: "center" });
    span.closest(".answerBg").click();
    sc++;
  }

  // === 判断题答案（questionId -> "true" 或 "false"）===
  const trueFalse = {
    question404811xxx: "true",
    question404811xxx: "false",
    // ...
  };

  let tfc = 0;
  for (const [qid, dv] of Object.entries(trueFalse)) {
    const div = document.getElementById(qid);
    if (!div) { errs.push(qid + " 不存在"); continue; }
    const span = div.querySelector("span[data=\"" + dv + "\"]");
    if (!span) { errs.push(qid + " 无选项" + dv); continue; }
    span.closest(".answerBg").scrollIntoView({ block: "center" });
    span.closest(".answerBg").click();
    tfc++;
  }

  return "填空:" + ok + "/" + fillAnswers.length +
         " | 单选:" + sc + "/" + Object.keys(singleChoice).length +
         " | 判断:" + tfc + "/" + Object.keys(trueFalse).length +
         (errs.length ? "\n错误:" + errs.join(",") : "\n全部成功!");
})()
```

### 第六步：验证

填充后抽查几个答案确认正确写入：

```bash
curl -s -X POST "http://localhost:3456/eval?target=TARGET_ID" -d '
(() => {
  const result = [];
  result.push("单选抽查: answer=" + document.getElementById("answer404811xxx")?.value);
  result.push("填空抽查[0]: " + UE.instants["ueditorInstant0"]?.body?.innerText);
  result.push("判断抽查: answer=" + document.getElementById("answer404811xxx")?.value);
  return result.join("\n");
})()
```

验证通过后截图让用户看到页面状态：

```bash
curl -s "http://localhost:3456/screenshot?target=TARGET_ID&file=/tmp/homework_done.png"
```

---

## 页面结构参考

| DOM 元素 | 说明 |
|----------|------|
| `div.questionLi[id^=question]` | 每道题的容器，id 为 question 后跟数字 |
| `input[type=hidden][id^=answer]` | 选择题/判断题答案存储，value 由 addChoice 更新 |
| `textarea[id^=answerEditor]` | 填空题底层 textarea，不直接赋值，通过 UEditor 操作 |
| `UE.instants["ueditorInstantN"]` | 第 N 个填空的 UEditor 实例 |
| `div.answerBg[role=radio]` | 可点击选项，onclick 触发 addChoice(this) |
| `span[data="A/B/C/D"]` | 单选题选项标识 |
| `span[data="true/false"]` | 判断题选项标识 |
| `div.stem_answer` | 选项容器，包裹多个 answerBg |

## 注意事项

1. **填空题用 `body.innerText`**：UEditor 的 `setContent()` 将输入当 HTML 解析，尖括号会被过滤。`body.innerText` 是安全的纯文本设置方式。
2. **滚动加载**：填充前必须滚动到底部，确保所有题目 DOM 已渲染到页面中。
3. **一次 eval 完成**：将填空、单选、判断的填充逻辑合并在一次 eval 调用中，减少网络往返次数。
4. **验证必做**：填充后抽查答案确认正确写入，特别是填空题容易出现编辑器内容未同步的情况。
5. **不操作用户原有 tab**：仅在用户当前打开的作业页面 tab 内操作，不创建新 tab，不关闭用户 tab。完成后不代为提交，让用户自行核对后决定。
6. **路径使用变量**：web-access 的脚本路径通过 skill 加载时提供的 base directory 动态获取，不硬编码绝对路径。
