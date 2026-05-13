#!/usr/bin/env bash
# edge-fix.sh — 修改 web-access skill 的脚本使其支持 Edge 浏览器（macOS / Linux / Windows）
# 用法: bash edge-fix.sh <WEB_ACCESS_BASE_DIR>
# 示例: bash edge-fix.sh ~/.claude/plugins/cache/web-access/web-access/2.4.2/skills/web-access

set -e

if [ -z "$1" ]; then
  echo "用法: bash edge-fix.sh <WEB_ACCESS_BASE_DIR>"
  echo "示例: bash edge-fix.sh ~/.claude/plugins/cache/web-access/web-access/2.4.2/skills/web-access"
  exit 1
fi

WEB_ACCESS_BASE="$1"
CHECK_DEPS="${WEB_ACCESS_BASE}/scripts/check-deps.mjs"
CDP_PROXY="${WEB_ACCESS_BASE}/scripts/cdp-proxy.mjs"

if [ ! -f "$CHECK_DEPS" ]; then
  echo "错误: 找不到 $CHECK_DEPS"
  echo "请确认 WEB_ACCESS_BASE_DIR 路径正确"
  exit 1
fi

if [ ! -f "$CDP_PROXY" ]; then
  echo "错误: 找不到 $CDP_PROXY"
  exit 1
fi

# 各平台的 Edge DevToolsActivePort 路径
# macOS
DARWIN_EDGE="path.join(home, 'Library/Application Support/Microsoft Edge/DevToolsActivePort'),"
# Linux
LINUX_EDGE="path.join(home, '.config/microsoft-edge/DevToolsActivePort'),"
# Windows
WIN32_EDGE="path.join(localAppData, 'Microsoft Edge/User Data/DevToolsActivePort'),"

echo "==> 修改 check-deps.mjs ..."

if grep -q "Microsoft Edge" "$CHECK_DEPS"; then
  echo "  check-deps.mjs 已包含 Edge 路径，跳过"
else
  # 在 Chromium 行之后、每个平台的 return 数组闭合前插入 Edge 路径
  # macOS (darwin)
  if grep -q "Library/Application Support/Chromium/DevToolsActivePort" "$CHECK_DEPS"; then
    sed -i.bak "/Library\/Application Support\/Chromium\/DevToolsActivePort/a\\
      ${DARWIN_EDGE}" "$CHECK_DEPS"
    echo "  check-deps.mjs → 已添加 macOS Edge 路径"
  fi
  # Linux
  if grep -q ".config/chromium/DevToolsActivePort" "$CHECK_DEPS"; then
    sed -i.bak "/\.config\/chromium\/DevToolsActivePort/a\\
      ${LINUX_EDGE}" "$CHECK_DEPS"
    echo "  check-deps.mjs → 已添加 Linux Edge 路径"
  fi
  # Windows (win32)
  if grep -q "LocalAppData.*Chromium.*DevToolsActivePort\|Chromium/User Data/DevToolsActivePort" "$CHECK_DEPS"; then
    sed -i.bak "/Chromium\/User Data\/DevToolsActivePort/a\\
      ${WIN32_EDGE}" "$CHECK_DEPS"
    echo "  check-deps.mjs → 已添加 Windows Edge 路径"
  fi
  rm -f "${CHECK_DEPS}.bak"
fi

echo "==> 修改 cdp-proxy.mjs ..."

if grep -q "Microsoft Edge" "$CDP_PROXY"; then
  echo "  cdp-proxy.mjs 已包含 Edge 路径，跳过"
else
  # macOS (darwin)
  if grep -q "Library/Application Support/Chromium/DevToolsActivePort" "$CDP_PROXY"; then
    sed -i.bak "/Library\/Application Support\/Chromium\/DevToolsActivePort/a\\
      ${DARWIN_EDGE}" "$CDP_PROXY"
    echo "  cdp-proxy.mjs → 已添加 macOS Edge 路径"
  fi
  # Linux
  if grep -q ".config/chromium/DevToolsActivePort" "$CDP_PROXY"; then
    sed -i.bak "/\.config\/chromium\/DevToolsActivePort/a\\
      ${LINUX_EDGE}" "$CDP_PROXY"
    echo "  cdp-proxy.mjs → 已添加 Linux Edge 路径"
  fi
  # Windows (win32)
  if grep -q "Chromium.*User Data.*DevToolsActivePort\|LocalAppData.*Chromium.*DevToolsActivePort" "$CDP_PROXY"; then
    sed -i.bak "/Chromium\/User Data\/DevToolsActivePort/a\\
      ${WIN32_EDGE}" "$CDP_PROXY"
    echo "  cdp-proxy.mjs → 已添加 Windows Edge 路径"
  fi
  rm -f "${CDP_PROXY}.bak"
fi

echo ""
echo "==> 修改完成！已为 macOS / Linux / Windows 添加 Edge 支持"
echo "  请重新运行 check-deps.mjs 验证："
echo "  node ${CHECK_DEPS}"
