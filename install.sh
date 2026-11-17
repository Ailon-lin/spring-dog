#!/usr/bin/env bash
# RIG-Puppy 一键安装：spring-dog（烧录）+ rig-hub（中转）+ rig-dog（MCP 适配器）
# 用法：curl -fsSL https://ailon-lin.github.io/spring-dog/install.sh | bash
# 只写 ~/.rig-puppy/ 与 ~/.agents/skills/spring-dog-cli，不需要 sudo。
set -euo pipefail

RELEASE_BASE="${RIG_PUPPY_RELEASE_BASE:-https://github.com/Ailon-lin/spring-dog/releases/latest/download}"
HOME_DIR="${RIG_PUPPY_HOME:-$HOME/.rig-puppy}"
SKILL_DIR="$HOME/.agents/skills/spring-dog-cli"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) die "暂只支持 macOS / Linux（Windows 未支持）" ;;
esac

command -v curl >/dev/null || die "缺少 curl"
command -v node >/dev/null || die "缺少 Node.js ≥ 18：https://nodejs.org/"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[ "$NODE_MAJOR" -ge 18 ] || die "Node.js 版本过低（$(node -v)），需要 ≥ 18"
command -v python3 >/dev/null || die "缺少 Python 3.10+"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' \
  || die "Python 版本过低（$(python3 -V)），需要 ≥ 3.10"

mkdir -p "$HOME_DIR/bin" "$HOME_DIR/lib"
chmod 700 "$HOME_DIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
  say "下载 $1"
  curl -fL --retry 3 --connect-timeout 15 -o "$TMP/$1" "$RELEASE_BASE/$1" \
    || die "下载失败：$RELEASE_BASE/$1"
}

fetch SHA256SUMS
for f in spring-dog-cli.tar.gz rig-hub.pyz rig-dog.pyz; do fetch "$f"; done

say "校验 SHA-256"
( cd "$TMP"
  if command -v shasum >/dev/null; then SUM="shasum -a 256"; else SUM="sha256sum"; fi
  grep -E ' (spring-dog-cli\.tar\.gz|rig-hub\.pyz|rig-dog\.pyz)$' SHA256SUMS | $SUM -c - ) \
  || die "校验不通过，已中止，未改动任何文件"

say "安装技能到 $SKILL_DIR"
rm -rf "$SKILL_DIR.new" && mkdir -p "$SKILL_DIR.new"
tar -xzf "$TMP/spring-dog-cli.tar.gz" -C "$SKILL_DIR.new" --strip-components=1
rm -rf "$SKILL_DIR" && mv "$SKILL_DIR.new" "$SKILL_DIR"
if [ -d "$HOME/.claude" ]; then
  mkdir -p "$HOME/.claude/skills"
  ln -sfn "$SKILL_DIR" "$HOME/.claude/skills/spring-dog-cli"
fi

install -m 0644 "$TMP/rig-hub.pyz" "$HOME_DIR/lib/rig-hub.pyz"
install -m 0644 "$TMP/rig-dog.pyz" "$HOME_DIR/lib/rig-dog.pyz"

cat > "$HOME_DIR/bin/spring-dog" <<EOF
#!/usr/bin/env bash
exec node "$SKILL_DIR/scripts/spring-dog.mjs" "\$@"
EOF
cat > "$HOME_DIR/bin/rig-hub" <<EOF
#!/usr/bin/env bash
exec python3 "$HOME_DIR/lib/rig-hub.pyz" "\$@"
EOF
cat > "$HOME_DIR/bin/rig-dog" <<EOF
#!/usr/bin/env bash
export RIG_DOG_ENV_FILE="\${RIG_DOG_ENV_FILE:-$HOME_DIR/dog.env}"
exec python3 "$HOME_DIR/lib/rig-dog.pyz" "\$@"
EOF
chmod 0755 "$HOME_DIR/bin/"*

if ! python3 -m esptool version >/dev/null 2>&1 && ! command -v esptool.py >/dev/null; then
  warn "未检测到 esptool。烧录前请运行：python3 -m pip install --user esptool"
fi

say "完成。入口在 $HOME_DIR/bin/"
echo "  $HOME_DIR/bin/spring-dog doctor"
echo "  $HOME_DIR/bin/rig-hub --version"
echo "下一步：把 https://ailon-lin.github.io/spring-dog/agent.md 交给你的 AI，或按网页步骤继续。"
