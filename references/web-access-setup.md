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
4. 运行 chaoxing skill 自带的修复脚本：`bash edge-fix.sh <WEB_ACCESS_BASE>`

## CDP Proxy API 端口

CDP Proxy 默认运行在 `http://localhost:3456`，提供以下端点：

| 端点 | 方法 | 用途 |
|------|------|------|
| `/targets` | GET | 列出浏览器所有 tab |
| `/new?url=` | GET | 创建新后台 tab |
| `/close?target=` | GET | 关闭指定 tab |
| `/navigate?target=&url=` | GET | 导航到新 URL |
| `/eval?target=` | POST | 在页面中执行 JavaScript |
| `/click?target=` | POST | 点击 CSS 选择器对应的元素 |
| `/scroll?target=&direction=` | GET | 滚动页面 |
| `/screenshot?target=&file=` | GET | 截图保存 |
| `/info?target=` | GET | 获取页面标题/URL/状态 |

## 致谢

web-access skill 是本项目的核心依赖，提供了浏览器操控能力。感谢 web-access skill 的开发者。
