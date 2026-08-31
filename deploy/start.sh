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

APP_DIR=/data/wwwroot/daodian
JAR="$APP_DIR/ruoyi-admin.jar"
JAVA=/opt/jdk17/bin/java
LOG_DIR="$APP_DIR/logs"
LOG="$LOG_DIR/stdout.log"
WWW="$APP_DIR/www"
ZIP="$APP_DIR/dist.zip"
PORT=8083

# ---- 敏感配置：优先读环境变量，没有再用默认值 ----
DB_URL="${DB_URL:-jdbc:mysql://rm-wz9n4ot89173fp840.mysql.rds.aliyuncs.com:3306/bx_wetuangou?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=GMT%2B8}"
DB_USER="${DB_USER:-rds_root}"
DB_PASS="${DB_PASS:-T3Z1Zpt6HPJjRSjhqoiBbKtyu5Ku6UDU}"

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

  echo "[start] 启动中..."
  nohup "$JAVA" \
    -Xms512m -Xmx1024m \
    -Dfile.encoding=UTF-8 \
    -jar "$JAR" \
    --spring.profiles.active=prod \
    --server.port=$PORT \
    --server.forward-headers-strategy=native \
    --spring.datasource.druid.master.url="$DB_URL" \
    --spring.datasource.druid.master.username="$DB_USER" \
    --spring.datasource.druid.master.password="$DB_PASS" \
    --ruoyi.storage.s3.public-domain=https://wetuango.oss-cn-shenzhen.aliyuncs.com \
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
