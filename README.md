# 超星平台自动答题 Skill

一个 Claude Code skill，通过 CDP (Chrome DevTools Protocol) 操控浏览器，自动完成[超星（学习通）](https://www.chaoxing.com/)平台上的在线作业。

支持单选题、填空题、判断题的自动读取、分析和答案填充。

## 致谢

本项目基于 **[web-access skill](https://github.com/anthropics/claude-code)** 提供的浏览器 CDP 操控能力。web-access 是本项目的核心依赖，没有它就无法实现对浏览器的自动化操作。在此对 web-access 的开发者表示衷心感谢。

## 功能特性

- 自动识别超星平台作业页面结构
- 支持单选题（A/B/C/D 选项点击）
- 支持判断题（对/错选项点击）
- 支持填空题（通过 UEditor API 纯文本填充，避免 HTML 转义问题）
- 一次请求完成所有题目填充，高效快速
- 兼容 Chrome 和 Edge 浏览器
- 支持 macOS、Linux、Windows 三大平台

## 平台支持

| 平台 | Chrome | Edge | 备注 |
|------|--------|------|------|
| macOS | 原生支持 | 需运行 `edge-fix.sh` | |
| Linux | 原生支持 | 需运行 `edge-fix.sh` | |
| Windows | 原生支持 | 需运行 `edge-fix.sh` | WSL / Git Bash 均可运行脚本 |

web-access skill 原生只集成了 Chrome 的 DevToolsActivePort 路径。Edge 用户需运行本项目自带的 `edge-fix.sh` 脚本，自动在 web-access 的配置中添加对应平台的 Edge 路径。

## 前置依赖

| 依赖 | 版本要求 | 说明 |
|------|----------|------|
| Claude Code | 最新版 | skill 运行平台 |
| web-access skill | - | 浏览器 CDP 操控（需单独安装） |
| Node.js | 22+ | CDP Proxy 运行环境 |
| Chrome 或 Edge | 最新版 | 需开启远程调试 |

## 安装

### 1. 安装 web-access skill

在 Claude Code 中执行：

```
/find-skills web-access
```

按提示完成安装。

### 2. 安装 chaoxing skill

将本仓库克隆或下载到 Claude Code 的 skills 目录：

```bash
git clone https://github.com/mel0nyrame/chaoxing-skill.git ~/.claude/skills/chaoxing
```

或者手动复制：

```bash
cp -r chaoxing-skill ~/.claude/skills/chaoxing
```

### 3. 开启浏览器远程调试

**Chrome：**
1. 打开 Chrome
2. 地址栏输入 `chrome://inspect/#remote-debugging`
3. 勾选 "Allow remote debugging for this browser instance"
4. 可能需要重启浏览器

**Edge：**
1. 打开 Edge
2. 地址栏输入 `edge://inspect/#remote-debugging`
3. 勾选 "Allow remote debugging for this browser instance"
4. 运行 Edge 兼容修复脚本（自动识别当前平台）：
   ```bash
   bash ~/.claude/skills/chaoxing/scripts/edge-fix.sh <WEB_ACCESS_BASE_DIR>
   ```
   脚本会在 web-access 的 `check-deps.mjs` 和 `cdp-proxy.mjs` 中添加对应平台的 Edge DevToolsActivePort 路径：

   | 平台 | 添加的路径 |
   |------|-----------|
   | macOS | `~/Library/Application Support/Microsoft Edge/DevToolsActivePort` |
   | Linux | `~/.config/microsoft-edge/DevToolsActivePort` |
   | Windows | `%LOCALAPPDATA%/Microsoft Edge/User Data/DevToolsActivePort` |

### 4. 验证环境

在 Claude Code 中加载 skill 后，环境检查会自动运行。也可以手动验证：

```bash
node "<WEB_ACCESS_BASE>/scripts/check-deps.mjs"
```

期望输出：
```
node: ok
chrome: ok (port XXXX)
proxy: ready
```

## 使用方式

1. 在浏览器中打开超星平台的作业页面
2. 在 Claude Code 中输入类似以下的指令：
   - "帮我完成这个超星作业"
   - "填写当前页面的题目"
   - "自动答题"
3. Claude 会自动加载 chaoxing skill，读取题目、分析答案、并填入页面
4. 填充完成后，确认无误手动点击页面上的「提交」按钮

## 项目结构

```
chaoxing-skill/
├── SKILL.md                    # skill 定义文件
├── README.md                   # 本文件
├── LICENSE                     # MIT License
├── scripts/
│   └── edge-fix.sh             # Edge 兼容修复（macOS/Linux/Windows）
└── references/
    └── web-access-setup.md     # web-access 安装配置详细指引
```

## 支持的题型

| 题型 | 实现方式 | 说明 |
|------|----------|------|
| 单选题 | `span[data="A/B/C/D"]` → click `.answerBg[role=radio]` | 选 1 个正确选项 |
| 多选题 | `span[data="A/B/C/D"]` → 逐个 click `.answerBg[role=checkbox]` | 选多个正确选项，分别点击 |
| 判断题 | `span[data="true/false"]` → click `.answerBg[role=radio]` | 对 = A(true), 错 = B(false) |
| 填空题 | `UE.instants[N].body.innerText` | 通过 UEditor API 纯文本填充 |

## 已知限制

- 仅支持超星平台（`mooc1.chaoxing.com` / `mooc2-ans.chaoxing.com`）的作业页面
- 需要用户在浏览器中保持登录状态
- 不支持需要文件上传的题目
- 程序题（编程填空）可能需要额外处理

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 填空题答案消失/截断 | `setContent()` 把 `<T>` 当 HTML 标签过滤 | 使用 `inst.body.innerText` 代替 |
| 判断题选项点不上 | data 值是 `true/false` 不是 `A/B` | 判断题用 `span[data="true"]` / `span[data="false"]` |
| 部分题目没填上 | 懒加载导致 DOM 未渲染 | 填充前先滚动到底部，等 1-2 秒 |
| `UE is not defined` | UEditor JS 未加载完 | 等 2-3 秒后重试 |
| curl 连接 localhost:3456 失败 | CDP Proxy 未启动或端口不同 | 检查 `CDP_PROXY_PORT` 环境变量 |
| textarea 内容对了但页面空白 | UEditor 未自动回写 | 设置 `body.innerText` 后编辑器在焦点变化时会自动同步 |

## 注意事项

1. **不要使用 `setContent()`**：超星填空题使用 UEditor 富文本编辑器，`setContent()` 会将内容当 HTML 解析，导致尖括号（`<T>`、`<>` 等）被过滤。应使用 `body.innerText` 设置纯文本。
2. **滚动加载**：部分页面采用懒加载，填充前需滚动到底部确保所有题目 DOM 已渲染。
3. **手动提交**：skill 不会自动点击提交按钮，由用户自行核对后提交。
4. **仅用于合法用途**：请确保你对该课程有合法的访问权限。

## 贡献

欢迎提交 Issue 和 Pull Request。

## License

MIT License — 详见 [LICENSE](LICENSE) 文件。
