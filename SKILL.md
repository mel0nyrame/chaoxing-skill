---
name: chaoxing
description: 超星(chaoxing)平台在线作业自动答题。当用户提到要在超星平台(mooc1.chaoxing.com / mooc2-ans.chaoxing.com)完成作业、考试、章节测试、在线答题等任务时使用此skill。也适用于超星平台的Java课程、面向对象程序设计等课程作业。触发词包括：超星、chaoxing、学习通、在线作业、自动答题、填写答案等。
---

# 超星平台自动答题

## 概述

此 skill 通过 CDP (Chrome DevTools Protocol) 操控用户本地浏览器，自动完成超星（学习通）平台上的作业。支持单选题、多选题、填空题、判断题四种题型。

## 第零步：检测用户平台（必须先执行）

**在执行任何安装或配置命令之前**，先确认用户当前的操作系统。后续所有命令和文件路径都取决于平台。

```bash
uname -s
# 或 Windows 上:
echo $OSTYPE
# 或
ver
```

根据输出判断：

| `uname -s` 输出 | 平台 | Node.js 安装方式 | sed 语法 | 浏览器远程调试入口 |
|-----------------|------|-----------------|----------|-------------------|
| `Darwin` | macOS | `brew install node` | `sed -i ''` | `chrome://inspect` 或 `edge://inspect` |
| `Linux` | Linux | `apt install nodejs` / `snap install node` | `sed -i` | 同 macOS |
| `MINGW*` / `MSYS*` | Windows (Git Bash) | [nodejs.org](https://nodejs.org) 下载 | `sed -i` | 同 macOS |
| `Windows` (cmd/pwsh) | Windows (原生) | [nodejs.org](https://nodejs.org) 下载 | 不支持 sed，手动编辑 | 同 macOS |

**关键差异**：
- **macOS** `sed` 需要 `-i ''` 备份后缀参数，Linux 和 Git Bash 只需要 `-i`
- **Windows 原生 shell**（cmd / PowerShell）不能直接运行 bash 脚本，需用 Git Bash 或 WSL
- **curl** 在 Windows 原生 PowerShell 中是 `curl.exe`（实际是 Invoke-WebRequest 的别名），需用 `curl.exe -s` 或改用 Git Bash

确定平台后，后续所有操作使用对应平台的命令变体。在向用户展示命令时，**只展示适用于当前平台的版本**，不要一股脑展示所有平台。

**记录两个关键路径**（后续步骤中反复使用）：

| 变量 | 含义 | 获取方式 |
|------|------|----------|
| `<WEB_ACCESS_BASE>` | web-access skill 安装目录 | 加载 `web-access` skill 后，系统输出中以 `Base directory for this skill:` 开头的那一行 |
| `<CHAOXING_SKILL_BASE>` | 本 skill 安装目录 | 加载本 skill 后，系统输出中以 `Base directory for this skill:` 开头的那一行 |

两个 skill 加载后都会被系统告知其 base directory，记下来即可，无需硬编码。

## 依赖与前置条件

使用此 skill 前，**必须**确认以下依赖已就绪。如未安装，先引导用户完成安装再继续。

### 必需外部依赖

| 依赖 | 用途 | 检查方式 | macOS 安装 | Linux 安装 | Windows 安装 |
|------|------|----------|-----------|-----------|-------------|
| **Node.js 22+** | CDP Proxy 运行环境 | `node -v` | `brew install node` | `apt install nodejs` | [nodejs.org](https://nodejs.org) |
| **Chrome/Edge 浏览器** | CDP 远程调试载体 | 需开启远程调试 | 已安装则无需重装 | 已安装则无需重装 | 已安装则无需重装 |
| **web-access skill** | CDP Proxy 和浏览器操控 API | `Skill` 工具调用 `web-access:web-access` | `find-skills` 搜索 | 同左 | 同左 |

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

- **单选题**：从 A/B/C/D 中选出 1 个正确答案，标记为"(单选题)"
- **多选题**：从 A/B/C/D 中选出 2 个及以上正确答案，标记为"(多选题)"
- **填空题**：在空白处填写正确内容（可能一道题有多个空），标记为"(填空题)"
- **判断题**：对（A）或错（B），标记为"(判断题)"

分析答案时注意题目可能重复出现（同一知识点换表述），答案应保持一致。

**多选题与单选题的区别**：
- 文本标记不同：题目开头标注 `(单选题)` vs `(多选题)`
- DOM 不同：多选题的 `answerBg` 的 `role` 属性为 `"checkbox"`，单选题为 `"radio"`
- 点击行为不同：多选题点击不会取消其他选项，可以累积选择

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

**先根据第四步的输出构建映射**：

第四步返回的题目列表每一行格式为 `序号: id=questionXXXXXXXXX | 题目标题`。从中提取：
- **单选题和多选题**：用 `id` 作为 key 放入 `singleChoice` 或 `multiChoice` 对象，value 为选项字母（如 `"C"`）或字母数组（如 `["A", "B", "D"]`）
- **判断题**：用 `id` 作为 key 放入 `trueFalse` 对象，value 为 `"true"` 或 `"false"`
- **填空题**：textarea 映射行格式为 `textarea N: answerEditorXXXXXXXXX -> ueditorInstantN`。N 是数组索引，按此顺序构建 `fillAnswers` 数组

构建完成后，将所有答案通过一次 eval 调用填入。

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

**绝对不要使用转义字符！** 如 `\n`、`\t`、`\\` 等转义字符会被当作字面文本显示，而不是实际的换行或制表符。这是实战中踩过的坑。

**正确做法：使用 `body.innerText` 直接设置纯文本，换行用实际的换行符：**

```javascript
const inst = UE.instants["ueditorInstant" + index];
inst.body.innerText = "答案内容";  // 纯文本，无转义字符

// 多行答案示例 - 使用实际换行，而非 \n
inst.body.innerText = "第一行内容
第二行内容
第三行内容";
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

  // 只有在有填空题需要填时才检查 UE 是否可用
  if (fillAnswers.length > 0) {
    if (typeof UE === "undefined" || !UE.instants) {
      return "错误: UE.instants 不可用，页面可能未加载完成，等待后重试";
    }
  }

  for (let i = 0; i < fillAnswers.length; i++) {
    const inst = UE.instants["ueditorInstant" + i];
    if (!inst || !inst.body) { errs.push("ueditorInstant" + i + " 不存在"); continue; }
    try {
      inst.body.innerText = fillAnswers[i];
      ok++;
    } catch(e) { errs.push(i + ":" + e.message); }
  }

  // === 多选题答案（questionId -> 选项 data 值数组）===
  // 注意：多选题需要点击每个正确选项，每个选项独立 click()
  const multiChoice = {
    question404811xxx: ["A", "C", "D"],  // 此题选 A、C、D
    // ...
  };

  let mc = 0;
  for (const [qid, answers] of Object.entries(multiChoice)) {
    const div = document.getElementById(qid);
    if (!div) { errs.push(qid + " 不存在"); continue; }
    for (const dv of answers) {
      const span = div.querySelector("span[data=\"" + dv + "\"]");
      if (!span) { errs.push(qid + " 无选项" + dv); continue; }
      span.closest(".answerBg").scrollIntoView({ block: "center" });
      span.closest(".answerBg").click();
    }
    mc++;
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
         " | 多选:" + mc + "/" + Object.keys(multiChoice).length +
         " | 单选:" + sc + "/" + Object.keys(singleChoice).length +
         " | 判断:" + tfc + "/" + Object.keys(trueFalse).length +
         (errs.length ? "\n错误:" + errs.join(",") : "\n全部成功!");
})()
```

### 第六步：验证

填充后做**全面验证**，而非仅抽查：

```bash
curl -s -X POST "http://localhost:3456/eval?target=TARGET_ID" -d '
(() => {
  const result = [];

  // 检查 UE 是否可用
  if (typeof UE === "undefined" || !UE.instants) {
    return "错误: UE.instants 不存在，页面可能未加载完成";
  }

  // 统计每种题型的填写数量
  // 注意：超星页面有 answer4048xxx 和 answertype4048xxx 两种 hidden input
  // 这里用 [name^=answer][name*=4048] 仅匹配答案值输入，排除类型标识输入
  let filledInputs = 0, totalInputs = 0;
  document.querySelectorAll("input[name^=answer][name*=\"4048\"]").forEach(el => {
    totalInputs++;
    if (el.value && el.value.trim()) filledInputs++;
  });

  let filledEditors = 0;
  const editorCount = Object.keys(UE.instants).length;
  for (const key of Object.keys(UE.instants)) {
    const body = UE.instants[key]?.body?.innerText?.trim();
    if (body) filledEditors++;
  }

  result.push("选择题/判断题: " + filledInputs + "/" + totalInputs);
  result.push("填空题: " + filledEditors + "/" + editorCount);

  // 抽查关键答案
  result.push("--- 抽查 ---");
  result.push("单选[0]: answer=" + document.querySelector("input[name^=answer][name*=\"4048\"]")?.value);
  result.push("填空[0]: " + UE.instants["ueditorInstant0"]?.body?.innerText);

  return result.join("\n");
})()
```

验证标准：
- 选择题/判断题的 `filledInputs` 应等于题目总数（单选+判断）
- 填空题的 `filledEditors` 应等于 textarea 总数（注意多空题）
- 抽查的答案值应与预期一致

验证通过后截图让用户看到页面状态，然后**删除临时截图文件**：

```bash
curl -s "http://localhost:3456/screenshot?target=TARGET_ID&file=/tmp/homework_done.png"
# 查看截图确认后:
rm -f /tmp/homework_done.png
```

---

## 页面结构参考

| DOM 元素 | 说明 |
|----------|------|
| `div.questionLi[id^=question]` | 每道题的容器，id 为 question 后跟数字 |
| `input[type=hidden][id^=answer]` | 选择题/判断题答案存储，value 由 addChoice 更新 |
| `textarea[id^=answerEditor]` | 填空题底层 textarea，不直接赋值，通过 UEditor 操作 |
| `UE.instants["ueditorInstantN"]` | 第 N 个填空的 UEditor 实例 |
| `div.answerBg[role=radio]` | 单选/判断题可点击选项，onclick 触发 addChoice(this)，点击替换之前选择 |
| `div.answerBg[role=checkbox]` | 多选题可点击选项，点击切换状态，不取消其他选项 |
| `span[data="A/B/C/D"]` | 单选/多选题选项标识 |
| `span[data="true/false"]` | 判断题选项标识 |
| `div.stem_answer` | 选项容器，包裹多个 answerBg |

## 常见坑与排错指南

这些都是在实战中踩过的坑，务必注意。

### 坑1：UEditor 的 `setContent()` 吃掉尖括号

**现象**：填空题答案包含 `<T>`、`<>`、`<E>` 等字符，填充后变空或截断。

**原因**：`setContent()` 把输入当 HTML 解析，`<X>` 被当成非法标签丢弃。

**解决**：永不用 `setContent()`，只用 `inst.body.innerText = "答案"`。

### 坑1.5：转义字符被当作字面文本显示

**现象**：填空题答案中的换行显示为 `\n` 而不是实际换行，制表符显示为 `\t` 而不是实际缩进。

**原因**：在 JavaScript 字符串中使用了转义字符如 `\n`、`\t`，但这些字符在 `innerText` 中会被当作字面文本处理。

**解决**：在填充脚本中使用实际的换行符（直接回车），而不是转义字符 `\n`。例如：
```javascript
// 错误写法
inst.body.innerText = "第一行\n第二行";

// 正确写法
inst.body.innerText = "第一行
第二行";
```

### 坑2：判断题用 `data="true/false"` 而非 `data="A/B"`

**现象**：用 `span[data="A"]` 找不到判断题选项。

**原因**：判断题的 `span[data]` 值是 `"true"`（对）和 `"false"`（错），不是 `"A"/"B"`。

**解决**：构建答案映射时判断题用 `"true"/"false"`，单选题用 `"A"/"B"/"C"/"D"`。

### 坑3：懒加载导致题目 DOM 不完整

**现象**：`questionLi` 数量少于预期，或部分题目区域的 answerBg 不存在。

**原因**：超星页面使用懒加载，未滚动到的区域题目 DOM 未渲染。

**解决**：填充前一定先 `curl /scroll?direction=bottom`，等待 1-2 秒后再操作。如果题目很多（50+），可以滚动两次。

### 坑4：UE.instants 未定义

**现象**：执行填充脚本时报 `UE is not defined`。

**原因**：UEditor 的 JS 文件可能还没加载完，或者页面不是作业作答页。

**解决**：填充前先检查 `typeof UE !== 'undefined' && UE.instants`。如果 UE 不存在，等待 2-3 秒后重试。

### 坑5：CDP Proxy 端口冲突

**现象**：`curl localhost:3456` 连接失败。

**原因**：端口 3456 可能被占用，或者 `CDP_PROXY_PORT` 环境变量设了别的端口。

**解决**：先用 `curl -s http://localhost:3456/health` 验证 proxy 是否在此端口运行。如果用户设了 `CDP_PROXY_PORT`，使用对应端口。

### 坑6：同一知识点出重复题

**现象**：题目列表中第 14 题和第 1 题内容几乎一样。

**原因**：超星题库有时会用不同题号出相同知识点的题，选项可能相同也可能打乱。

**解决**：分析答案时逐题独立判断，不要仅凭"这题我见过"跳過。确保答案一致。

### 坑7：textarea 映射错位

**现象**：第 3 个空填的内容跑到了第 4 个空。

**原因**：填空题的 textarea 在 DOM 中的顺序 = UEditor instant 的序号。但如果页面有隐藏的 textarea（如前一页残留），映射会偏移。

**解决**：第四步获取映射后，人工核对 textarea 数量和填空题空数是否一致（注意多空题）。不一致时排查多余的 textarea 来源。

### 坑9：`[id^=answer]` 误匹配 `answertype` 输入

**现象**：验证步骤统计的 `totalInputs` 是选择题数量的两倍。

**原因**：超星每个选择题有两个隐藏 input：`answer4048xxx`（答案值）和 `answertype4048xxx`（题目类型）。选择器 `[id^=answer]` 两者都会选中。

**解决**：使用 `input[name^=answer][name*="4048"]` 仅匹配答案值输入，排除类型标识输入。

### 坑8：填充后无反馈

**现象**：eval 返回"全部成功"但页面上看不到答案。

**原因**：UEditor 通过 `body.innerText` 设置后，底层 textarea 可能未同步。需要触发 UEditor 的 change 事件或直接同步。

**解决**：设置 `body.innerText` 后，该值会由 UEditor 自动同步到底层 textarea（编辑器内部会在焦点变化/提交时自动回写）。验证步骤必须检查 `body.innerText` 而非仅检查 textarea.value。

---

## 注意事项

1. **填空题用 `body.innerText`**：UEditor 的 `setContent()` 将输入当 HTML 解析，尖括号会被过滤。
2. **滚动加载**：填充前必须滚动到底部，确保所有题目 DOM 已渲染。
3. **一次 eval 完成**：将填空、单选、判断的填充逻辑合并在一次 eval 调用中，减少网络往返。
4. **验证必做**：填充后检查每种题型的答案数量和内容，不仅抽查还要检查总数是否匹配。
5. **不操作用户原有 tab**：仅在用户当前打开的作业页面 tab 内操作，不创建/关闭 tab。完成后不代为提交。
6. **路径使用变量**：web-access 的脚本路径通过 skill 加载时的 base directory 动态获取，不硬编码。
7. **临时文件清理**：截图后及时删除 `/tmp/homework_*.png`，避免遗留临时文件。
