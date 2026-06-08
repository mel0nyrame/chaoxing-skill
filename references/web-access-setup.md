# web-access skill 安装与配置指南

## 安装

在 Claude Code 中输入以下指令安装 web-access skill：

```
/find-skills web-access
```

或直接搜索 "web access" 相关 skill 进行安装。

安装后，web-access skill 的文件位于：
```
~/.claude/plugins/cache/web-access/web-access/<version>/skills/web-access/
```

## 验证安装

加载 web-access skill 后，skill 系统会提供 base directory 路径（以 `Base directory for this skill:` 开头）。运行环境检查：

```bash
node "<WEB_ACCESS_BASE>/scripts/check-deps.mjs"
```

## 浏览器配置

### Chrome

1. 打开 Chrome
2. 地址栏输入 `chrome://inspect/#remote-debugging`
3. 勾选 "Allow remote debugging for this browser instance"
4. 可能需要重启浏览器

### Edge

1. 打开 Edge
2. 地址栏输入 `edge://inspect/#remote-debugging`
3. 勾选 "Allow remote debugging for this browser instance"
4. 使用时加 `--browser edge` 参数或设置 `WEB_ACCESS_BROWSER=edge`

## CDP Proxy API 端口

CDP Proxy 默认运行在 `http://localhost:3456`，提供以下端点：

| 端点 | 方法 | 用途 |
|------|------|------|
| `/targets` | GET | 列出浏览器所有 tab |
| `/new` | POST | 创建新后台 tab（URL 走 POST body） |
| `/close?target=` | GET | 关闭指定 tab |
| `/navigate?target=` | POST | 导航到新 URL（URL 走 POST body） |
| `/eval?target=` | POST | 在页面中执行 JavaScript |
| `/click?target=` | POST | 点击 CSS 选择器对应的元素 |
| `/clickAt?target=` | POST | 真实鼠标点击（触发文件对话框等） |
| `/setFiles?target=` | POST | 文件上传（设置 file input 路径） |
| `/scroll?target=&direction=` | GET | 滚动页面 |
| `/screenshot?target=&file=` | GET | 截图保存 |
| `/info?target=` | GET | 获取页面标题/URL/状态 |
| `/back?target=` | GET | 后退 |

### 页面内导航

两种方式打开页面内的链接：

- **`/click`**：在当前 tab 内直接点击用户视角中的可交互单元，简单直接，串行处理。适合需要在同一页面内连续操作的场景，如点击展开、翻页、进入详情等。
- **`/new` + 完整 URL**：使用目标链接的完整地址（包含所有URL参数），在新 tab 中打开。适合需要同时访问多个页面的场景。

## 致谢

web-access skill 是本项目的核心依赖，提供了浏览器操控能力。感谢 web-access skill 的开发者。
