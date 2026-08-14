#!/usr/bin/env bash
# E12: Controller 越权风险审计
# 扫描 ruoyi-system + ruoyi-admin 下所有 *Controller.java，列出
# 1. @GetMapping(value = "/{xxxId}") 端点（按主键查详情，理论需 guard）
# 2. 该方法体是否显式调 guard（checkXxxDataScope / TenantFilterHelper / TenantContextHolder / assertDataScope）
#
# 用法: bash .github/scripts/audit-controller-scope.sh
# 输出: table (file:endpoint, risk)
# 注意: 无 guard 端点不一定是裸越权（TenantSqlInterceptor 自动改写 SQL 加 IN 过滤兜底），
#       但客户端可能收到 200+空 data 而非明确 403，UX 差。强烈建议补 guard。
set -e

CTRL_DIRS=("ruoyi-system/src/main/java/com/ruoyi/biz/controller" "ruoyi-admin/src/main/java/com/ruoyi/web/controller/biz" "ruoyi-admin/src/main/java/com/ruoyi/web/api")

WARN=0
INFO=0
echo "Controller 越权风险审计（GET /{id} 端点）"
echo "══════════════════════════════════════════════════════════════════════════"
printf "%-55s | %-22s | %s\n" "Controller" "Endpoint" "Risk"
echo "──────────────────────────────────────────────────────────────────────────"

for dir in "${CTRL_DIRS[@]}"; do
  for f in "$dir"/*Controller.java; do
    [ -f "$f" ] || continue
    cn=$(basename "$f" .java)
    # 找所有 @GetMapping(value = "/{xxxId}") 行号
    grep -nE '@GetMapping\(value = "/\{[A-Za-z]+Id\}"\)|@GetMapping\(value = "/\{[A-Za-z]+No\}"\)' "$f" 2>/dev/null | while IFS=: read -r lineno ep; do
      ep_path=$(echo "$ep" | sed -E 's|.*value = "/([^"]+)".*|/\1|')
      # 找该行向下最近的 { 与对应 } (简单方法体范围，假设方法体无嵌套 {} - 对 java getter 不准确但本项目 getInfo 内部 if 不嵌套)
      end_lineno=$(awk -v start="$lineno" '
        NR >= start { in_method=0; for (i=start; i<=NR; i++) {} }
        NR >= start {
          line = $0
          if (in_method == 0) {
            if (line ~ /\{/) { in_method = 1; depth = 1; next }
          } else {
            n_open = gsub(/\{/, "{", line)
            n_close = gsub(/\}/, "}", line)
            depth += n_open - n_close
            if (depth <= 0) { print NR; exit }
          }
        }
      ' "$f")
      if [ -z "$end_lineno" ]; then
        method_body=$(sed -n "${lineno},/^[[:space:]]*}/p" "$f")
      else
        method_body=$(sed -n "${lineno},${end_lineno}p" "$f")
      fi
      # 检查方法体是否调 guard
      if echo "$method_body" | grep -qE "check[A-Za-z]*DataScope|TenantFilterHelper\.|TenantContextHolder\.|assertDataScope"; then
        status="✅ has guard"
        INFO=$((INFO+1))
      else
        status="⚠️  no guard (依赖 TenantSqlInterceptor 兜底)"
        WARN=$((WARN+1))
      fi
      printf "%-55s | %-22s | %s\n" "$dir/$cn" "$ep_path" "$status"
    done
  done
done

echo "══════════════════════════════════════════════════════════════════════════"
echo "总览: ✅ 多个有 guard，⚠️  多个无 guard"
echo ""
echo "解释: 无 guard 端点不一定是裸越权（TenantSqlInterceptor 自动加 IN 过滤），"
echo "      但 UX 差（返 200+空 data 而非 403）。强烈建议补 guard。"
