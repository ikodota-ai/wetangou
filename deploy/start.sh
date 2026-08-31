#!/bin/bash
# ============================================================================
# 洞天团购 —— 服务器启停 / 发版脚本
#
# 放在 /data/wwwroot/daodian/start.sh（web root 之外 —— 这个文件含 RDS 密码
# 和 OSS AK/SK，放进 www/ 等于公网可下载）。
#
# 用法：
#   ./start.sh              重启后端（停旧 → 起新）
#   ./start.sh stop         只停
#   ./start.sh status       看状态
#   ./start.sh web          只换前端 dist（不动后端）
#   ./start.sh all          换前端 + 重启后端
#
# 敏感信息建议改从环境变量读（见下方 DB_PASS 等），不要长期明文留在文件里。
# 至少 chmod 600 start.sh，别让同机其他账号读到。
# ============================================================================

set -u   # 用未定义变量直接报错
# 不加 set -e：停服务那步进程不存在时会返非 0，属正常情况，需要自己控制

# 本脚本就放在 /data/wwwroot/daodian/ 下，和 jar、dist.zip、logs 同级。
# 所以 APP_DIR 不写死，按脚本自身所在目录推导 —— 换目录、改名都不用动代码，
# 也避免"脚本在 A 目录、APP_DIR 却指向 B"这种改一半留下的坑。
# cd + pwd 会把软链接和相对路径都解成绝对路径（后面 pgrep 按全路径匹配，必须绝对）。
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

JAR="${JAR:-$APP_DIR/ruoyi-admin.jar}"
JAVA="${JAVA:-/opt/jdk17/bin/java}"
LOG_DIR="$APP_DIR/logs"
# stdout.log 只接 nohup 重定向的控制台输出（启动横幅、启动失败的堆栈）。
# 业务日志（sys-info / sys-error / sys-user）由 logback 单独写，靠上面的
# -Dlog.path 指过来 —— 详见 start_app 里的说明。
LOG="$LOG_DIR/stdout.log"
# 前端站点根。nginx 的 root 必须指到 $WWW（后台在 $WWW/admin/）——
# 两边对不上就是后台白屏或 404，改任一边记得同步另一边。
WWW="${WWW:-$APP_DIR/www}"
ZIP="${ZIP:-$APP_DIR/dist.zip}"
PORT="${PORT:-8083}"

# ---- 敏感配置：优先读环境变量，没有再用默认值 ----
# 想彻底不留明文：写进 /etc/dytuangou/dytuangou.env，
# 调用前 set -a; . /etc/dytuangou/dytuangou.env; set +a
DB_URL="${DB_URL:-jdbc:mysql://rm-wz9n4ot89173fp840.mysql.rds.aliyuncs.com:3306/bx_wetuangou?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=GMT%2B8}"
DB_USER="${DB_USER:-rds_root}"
DB_PASS="${DB_PASS:-uoLpa5Rewj83UDo4}"

# Redis 独占 db3（见部署指南 §7.3）。服务器上 Redis 还有别的业务，
# 用 db0 会和别人撞 key，清缓存时也不敢 flushdb。
REDIS_DB="${REDIS_DB:-3}"

# JWT 密钥。必须固定写死，不能每次启动 openssl rand 现生成 ——
# 那样重启后所有人的 token 立即失效，全被踢下线。
TOKEN_SECRET="${TOKEN_SECRET:-NbYJcKnPYRfiVevISeCj3iW84x0qPOnTpOxqMJYNABBHogOJX1dfhlxz4H1H3qm}"

# OSS。access-key/secret-key 在 application-prod.yml 里刻意没给默认值
# （${OSS_ACCESS_KEY} 无冒号兜底），漏传会直接
# Could not resolve placeholder 启动失败 —— 属于设计如此，早暴露好过传图时才炸。
OSS_ENDPOINT="${OSS_ENDPOINT:-https://oss-cn-shenzhen.aliyuncs.com}"
OSS_REGION="${OSS_REGION:-cn-shenzhen}"
OSS_BUCKET="${OSS_BUCKET:-wetuango}"
OSS_AK="${OSS_AK:-LTAI5t8EPaBkF1BzGV4WRgVv}"
OSS_SK="${OSS_SK:-ahgDNAXVXlWb5WIpbhwh8iVJyMw5dI}"
# 外网访问域名。不配的话 S3StorageAdapter 会拼成 endpoint/bucket/key 的
# path 风格，阿里云 OSS 不认这种形式，图片链接打不开。
OSS_PUBLIC_DOMAIN="${OSS_PUBLIC_DOMAIN:-https://wetuango.oss-cn-shenzhen.aliyuncs.com}"

# ----------------------------------------------------------------------------
# 找出本应用的 java 进程
#
# 不能直接用 pgrep -f java —— 服务器上可能跑着别的 java 服务，全 kill 会误伤。
# 按 jar 的完整路径匹配，只命中本应用。
#
# 末尾排除自己：pgrep -f 会匹配命令行文本，而本脚本的命令行里就含
# "ruoyi-admin.jar" 这个字符串（比如 ./start.sh 带参数时），
# 不排除的话脚本可能把自己 kill 掉。
# ----------------------------------------------------------------------------
find_pids() {
  pgrep -f "$JAR" 2>/dev/null | grep -v "^$$\$"
}

stop_app() {
  local pids
  pids=$(find_pids)
  if [ -z "$pids" ]; then
    echo "[stop] 没有在跑的进程"
    return 0
  fi

  echo "[stop] 发现进程：$pids"
  # 先 TERM 让它优雅退出（Spring Boot 会关连接池、跑 shutdown hook）。
  # 直接 -9 可能留下未刷盘的日志和没释放的端口。
  kill $pids 2>/dev/null

  local i=0
  while [ $i -lt 15 ]; do
    sleep 1
    [ -z "$(find_pids)" ] && { echo "[stop] 已优雅退出（${i}s）"; return 0; }
    i=$((i+1))
  done

  # 15 秒还没退，才动 -9
  echo "[stop] 15s 未退出，强制 kill -9"
  kill -9 $(find_pids) 2>/dev/null
  sleep 2
  if [ -n "$(find_pids)" ]; then
    echo "[stop] 仍未杀掉，请手动检查：ps -ef | grep ruoyi-admin.jar" >&2
    return 1
  fi
  echo "[stop] 已强制结束"
}

start_app() {
  [ -f "$JAR" ] || { echo "[start] 找不到 $JAR" >&2; return 1; }
  mkdir -p "$LOG_DIR"

  # stdout.log 用 >> 追加（不是 >），这样上次崩溃的堆栈不会被本次启动覆盖掉,
  # 正是要排查问题的时候最需要它。代价是会一直涨，所以超过 50M 就先归档一份。
  # 业务日志有 logback 自己轮转，这里只兜 stdout/stderr。
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 52428800 ]; then
    mv "$LOG" "$LOG.$(date +%Y%m%d%H%M%S)"
    echo "[start] stdout.log 超 50M，已归档"
  fi

  echo "[start] 启动中..."
  # -Dlog.path 不能省，也不能拿 --logging.file.name 代替：
  # 项目用的是自带的 logback.xml，里面写死 ${log.path:-/Users/mac/ruoyi/logs}
  # —— 那是开发机的绝对路径。服务器上不传这个参数，logback 就去建
  # /Users/mac/ruoyi/logs，建不了就把业务日志整个丢掉（sys-error.log 也没了，
  # 出问题时无从查起），而且它是 JVM 系统属性，必须放在 -jar 前面。
  # 本地实测：只传 --logging.file.name 不会生成任何文件，纯属无效参数。
  nohup "$JAVA" \
    -Xms512m -Xmx1024m \
    -Dfile.encoding=UTF-8 \
    -Dlog.path="$LOG_DIR" \
    -jar "$JAR" \
    --spring.profiles.active=prod \
    --server.port=$PORT \
    --server.forward-headers-strategy=native \
    --spring.datasource.druid.master.url="$DB_URL" \
    --spring.datasource.druid.master.username="$DB_USER" \
    --spring.datasource.druid.master.password="$DB_PASS" \
    --spring.data.redis.database=$REDIS_DB \
    --token.secret="$TOKEN_SECRET" \
    --ruoyi.storage.s3.endpoint="$OSS_ENDPOINT" \
    --ruoyi.storage.s3.region="$OSS_REGION" \
    --ruoyi.storage.s3.bucket="$OSS_BUCKET" \
    --ruoyi.storage.s3.access-key="$OSS_AK" \
    --ruoyi.storage.s3.secret-key="$OSS_SK" \
    --ruoyi.storage.s3.public-domain="$OSS_PUBLIC_DOMAIN" \
    --ruoyi.profile="$APP_DIR/uploadPath" \
    >> "$LOG" 2>&1 &

  echo "[start] PID=$! 日志 $LOG"

  # 等端口真的起来再返回。启动约 60-90s，别一看到 PID 就说成功 ——
  # 配置错误时进程会起来几秒又退出。
  local i=0
  while [ $i -lt 60 ]; do
    sleep 2
    if curl -sf -o /dev/null "http://127.0.0.1:$PORT/api/ping" 2>/dev/null; then
      echo "[start] 健康检查通过（$((i*2))s）"
      return 0
    fi
    if [ -z "$(find_pids)" ]; then
      echo "[start] 进程已退出，看日志：tail -100 $LOG" >&2
      return 1
    fi
    i=$((i+1))
  done
  echo "[start] 120s 内未通过健康检查，看日志：tail -100 $LOG" >&2
  return 1
}

status_app() {
  local pids
  pids=$(find_pids)
  if [ -z "$pids" ]; then
    echo "[status] 未运行"
    return 1
  fi
  echo "[status] 运行中 PID=$pids"
  curl -s -o /dev/null -w "[status] /api/ping -> %{http_code}\n" "http://127.0.0.1:$PORT/api/ping"
}

# ----------------------------------------------------------------------------
# 换前端 dist
#
# 不用 "rm -rf www/admin && unzip && mv www/dist www/admin"：
# mv 的目标若已存在（rm 因权限/占用没删干净），它不是改名而是**移动进去**，
# 结果变成 www/admin/dist/，而且退出码仍是 0 不报错 —— 只会看到后台白屏。
#
# 改成原子切换：先把新版落到 admin.new（此刻必定不存在，是真改名），
# 旧的挪到 admin.old，再把 new 顶上。
# 好处一是 mv 语义确定，二是能清掉上个版本残留的 hash 文件，
# 三是切换窗口只有两次 mv 之间的毫秒级，用户几乎撞不上 404。
# ----------------------------------------------------------------------------
deploy_web() {
  [ -f "$ZIP" ] || { echo "[web] 找不到 $ZIP" >&2; return 1; }

  local unpack="$APP_DIR/.unpack.$$"
  rm -rf "$unpack" "$WWW/admin.new"
  mkdir -p "$unpack" "$WWW"

  echo "[web] 解压 $ZIP"
  unzip -q "$ZIP" -d "$unpack" || { echo "[web] 解压失败" >&2; rm -rf "$unpack"; return 1; }

  # 兼容两种打包结构：包内带 dist/ 顶层目录，或直接就是 index.html
  local src
  if [ -d "$unpack/dist" ]; then
    src="$unpack/dist"
  elif [ -f "$unpack/index.html" ]; then
    src="$unpack"
  else
    echo "[web] 包里既没有 dist/ 也没有 index.html，检查 dist.zip" >&2
    rm -rf "$unpack"; return 1
  fi
  [ -f "$src/index.html" ] || { echo "[web] $src 下没有 index.html" >&2; rm -rf "$unpack"; return 1; }

  mv "$src" "$WWW/admin.new" || { echo "[web] 落盘失败" >&2; rm -rf "$unpack"; return 1; }

  rm -rf "$WWW/admin.old"
  [ -d "$WWW/admin" ] && mv "$WWW/admin" "$WWW/admin.old"
  mv "$WWW/admin.new" "$WWW/admin" || {
    echo "[web] 切换失败，回滚" >&2
    [ -d "$WWW/admin.old" ] && mv "$WWW/admin.old" "$WWW/admin"
    rm -rf "$unpack"; return 1
  }

  chown -R www:www "$WWW/admin" 2>/dev/null || true
  rm -rf "$unpack" "$WWW/admin.old"
  echo "[web] 完成：$WWW/admin"
}

case "${1:-restart}" in
  stop)     stop_app ;;
  start)    start_app ;;
  restart)  stop_app && start_app ;;
  status)   status_app ;;
  web)      deploy_web ;;
  all)      deploy_web && stop_app && start_app ;;
  *)
    echo "用法: $0 {restart|start|stop|status|web|all}"
    echo "  restart  重启后端（默认）"
    echo "  web      只换前端 dist"
    echo "  all      换前端 + 重启后端"
    exit 1 ;;
esac
