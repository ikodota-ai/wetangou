#!/usr/bin/env bash
# 生产启动前自检（见 doc/上线配置清单-2026-08-20.md）
#
# 用法：
#   source /etc/dytuangou/dytuangou.env
#   bash .github/scripts/preflight-prod.sh
#   # 全绿再 systemctl start dytuangou
#
# 退出码：0 = 可以上线；1 = 有阻塞项
#
# 设计原则：只读检查，不改任何配置/数据。

PASS=0; FAIL=0; WARN=0

ok()   { echo "  ✅ $1"; PASS=$((PASS+1)); }
bad()  { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
echo "=== 生产启动前自检 ($(date '+%F %T')) ==="
echo "repo: $ROOT"
echo

# ---------- 1) 启动 profile ----------
echo "[1] 启动 profile"
PROF="${SPRING_PROFILES_ACTIVE:-}"
if [ -z "$PROF" ]; then
  warn "未设置 SPRING_PROFILES_ACTIVE；请确认启动命令里有 -Dspring.profiles.active=prod,aliyun-oss"
else
  case ",$PROF," in
    *,prod,*) ok "profile 含 prod（$PROF）" ;;
    *)        bad "profile 缺 prod（当前=$PROF）→ mock 开关会退回读 sys_config" ;;
  esac
fi

# ---------- 2) JWT 密钥 ----------
echo "[2] JWT 密钥"
if [ -z "${JWT_SECRET:-}" ]; then
  bad "JWT_SECRET 未设置 → 会用仓库默认值 abcdefghijklmnopqrstuvwxyz（等于公开密钥）"
elif [ "$JWT_SECRET" = "abcdefghijklmnopqrstuvwxyz" ]; then
  bad "JWT_SECRET 还是仓库默认值，必须换：openssl rand -base64 48"
elif [ ${#JWT_SECRET} -lt 32 ]; then
  warn "JWT_SECRET 长度 ${#JWT_SECRET} < 32，建议更长"
else
  ok "JWT_SECRET 已自定义（长度 ${#JWT_SECRET}）"
fi

# ---------- 3) 数据库 ----------
echo "[3] 数据库"
case "${DB_HOST:-localhost}" in
  localhost|127.0.0.1) bad "DB_HOST=${DB_HOST:-localhost} 是本机；生产应指向 RDS" ;;
  *)                   ok "DB_HOST=$DB_HOST" ;;
esac
if [ "${DB_USER:-root}" = "root" ]; then
  bad "DB_USER=root；生产应用最小权限账号"
else
  ok "DB_USER=$DB_USER"
fi
case "${DB_PASSWORD:-}" in
  ""|133301) bad "DB_PASSWORD 为空或仍是开发密码 133301" ;;
  *)         ok "DB_PASSWORD 已自定义" ;;
esac

# ---------- 4) Druid 监控页 ----------
echo "[4] Druid 监控页"
if [ "${DRUID_STAT_ENABLED:-false}" = "true" ]; then
  warn "DRUID_STAT_ENABLED=true（会暴露 SQL/URL/会话）；排查完记得关"
  [ "${DRUID_STAT_PASSWORD:-123456}" = "123456" ] && bad "Druid 口令还是默认 123456"
else
  ok "Druid 监控页已关闭"
fi

# ---------- 5) sys_config mock 开关 ----------
echo "[5] sys_config mock 开关"
MYSQL_BIN="${MYSQL_BIN:-mysql}"
command -v "$MYSQL_BIN" >/dev/null 2>&1 || MYSQL_BIN=/usr/local/mysql/bin/mysql
if command -v "$MYSQL_BIN" >/dev/null 2>&1 && [ -n "${DB_NAME:-}" ]; then
  Q="SELECT config_key,config_value FROM sys_config WHERE config_key IN ('wx.miniapp.mockEnabled','wx.pay.mockEnabled');"
  OUT=$("$MYSQL_BIN" -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3306}" -u"${DB_USER:-root}" -p"${DB_PASSWORD:-}" "${DB_NAME}" -N -B -e "$Q" 2>/dev/null)
  if [ -z "$OUT" ]; then
    warn "连不上 DB 或查不到 mock 配置，跳过（请手工确认）"
  elif echo "$OUT" | grep -qi 'true'; then
    warn "sys_config 里 mock 仍为 true（prod profile 会代码层强制关，但建议一并改成 false）"
    echo "$OUT" | sed 's/^/      /'
  else
    ok "sys_config mock 均为 false"
  fi
else
  warn "未找到 mysql 客户端或未设 DB_NAME，跳过 DB 检查"
fi

# ---------- 6) 微信支付凭证 ----------
echo "[6] 微信支付凭证"
if command -v "$MYSQL_BIN" >/dev/null 2>&1 && [ -n "${DB_NAME:-}" ]; then
  Q2="SELECT config_key FROM sys_config WHERE config_key IN ('wx.pay.appId','wx.pay.mchId','wx.pay.apiV3Key','wx.pay.certSerialNo','wx.pay.privateKeyPath') AND (config_value IS NULL OR config_value='');"
  EMPTY=$("$MYSQL_BIN" -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3306}" -u"${DB_USER:-root}" -p"${DB_PASSWORD:-}" "${DB_NAME}" -N -B -e "$Q2" 2>/dev/null)
  if [ -n "$EMPTY" ]; then
    bad "以下支付配置为空（真实支付会失败）："
    echo "$EMPTY" | sed 's/^/      /'
  else
    ok "微信支付 5 项凭证非空"
  fi
  NURL=$("$MYSQL_BIN" -h"${DB_HOST:-127.0.0.1}" -P"${DB_PORT:-3306}" -u"${DB_USER:-root}" -p"${DB_PASSWORD:-}" "${DB_NAME}" -N -B -e "SELECT config_value FROM sys_config WHERE config_key='wx.pay.notifyUrl';" 2>/dev/null)
  case "$NURL" in
    https://your-domain.com*) bad "wx.pay.notifyUrl 还是占位值：$NURL" ;;
    https://*)                ok "notifyUrl 是 HTTPS：$NURL" ;;
    "")                       bad "wx.pay.notifyUrl 为空" ;;
    *)                        bad "wx.pay.notifyUrl 不是 HTTPS：$NURL" ;;
  esac
fi

# ---------- 7) 小程序 BASE_URL ----------
echo "[7] 小程序 BASE_URL"
CFG="$ROOT/miniprogram7/utils/config.js"
if [ -f "$CFG" ]; then
  if grep -qE "return 'http://(127\.0\.0\.1|localhost|192\.168\.|172\.|10\.)" "$CFG"; then
    IPLINE=$(grep -oE "return 'http://[0-9a-zA-Z.:]+'" "$CFG" | head -1)
    warn "config.js 默认 BASE_URL 是内网地址（$IPLINE）；单商户上线要改 HTTPS 域名，多商户代发布需确保 wx.open.apiBaseUrl 已配"
  else
    ok "config.js 默认 BASE_URL 非内网"
  fi
else
  warn "未找到 $CFG"
fi

# ---------- 8) OSS ----------
echo "[8] OSS"
if [ -z "${OSS_BUCKET:-}" ] || [ -z "${OSS_ACCESS_KEY:-}" ]; then
  warn "OSS_BUCKET / OSS_ACCESS_KEY 未设置（若用 local 存储可忽略，但图片会存在本机磁盘）"
else
  ok "OSS bucket=$OSS_BUCKET"
fi

echo
echo "=============================="
echo "preflight: PASS=$PASS FAIL=$FAIL WARN=$WARN"
if [ $FAIL -gt 0 ]; then
  echo "→ 有 $FAIL 项阻塞，处理完再上线（详见 doc/上线配置清单-2026-08-20.md）"
  exit 1
fi
echo "→ 无阻塞项。WARN 请人工确认后即可发布。"
exit 0
