#!/usr/bin/env bash
# V2.6.2 openid 优先身份识别 smoke
# 期望：
#  - 普通 openid（未绑 staff）→ loginType=member, isStaff=false
#  - openid 绑 staff 且 status=0 → loginType=staff, isStaff=true, isOwner=true
#  - openid 绑 staff 但 status=1 → 兜底 member, isStaff=false, hasStaffAccount=true
#  - 未绑任何账号的 openid → loginType=member, isStaff=false, hasStaffAccount=false
set -u
H=http://127.0.0.1:8080
PASS=0; FAIL=0

login() {
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"code\":\"$1\",\"nickName\":\"c53\",\"appid\":\"wx9e147c4e2151b123\"}" \
    $H/api/auth/login
}

check() {
  local label="$1" expected="$2" got="$3"
  if [ "$expected" = "$got" ]; then echo "  ✅ $label (=$got)"; PASS=$((PASS+1))
  else echo "  ❌ $label  expect=$expected got=$got"; FAIL=$((FAIL+1)); fi
}

# 准备：把 user 59 (owner_c43) openid 绑到 mock_c53_owner
cat > /tmp/SetC53.java <<'JEOF'
import java.sql.*;
public class SetC53 {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      // 重置：user 59 openid = mock_c53_owner, status=0
      s.execute("UPDATE sys_user SET openid='mock_c53_owner', openid_bound=1, status='0' WHERE user_id=59");
      // member 1000197 openid = mock_c53_plain
      s.execute("UPDATE biz_member SET openid='mock_c53_plain' WHERE member_id=1000197");
      System.out.println("[ok] setup done");
    }
  }
}
JEOF
cd /tmp && javac SetC53.java 2>&1
java -cp "/tmp:/Users/mac/.m2/repository/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar" SetC53 2>&1
cd /Users/mac/dev/dytuangou
# 清缓存
redis-cli -h 127.0.0.1 -p 6379 DEL 'sys_config:wx.miniapp.mockEnabled' 'merchant:id:1' 'merchant:appid:wx9e147c4e2151b123' 2>&1 | head -3

echo ""
echo "【1】纯会员 openid:"
R1=$(login c53_plain)
LT1=$(echo "$R1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('loginType',''))")
IS1=$(echo "$R1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('isStaff',''))")
HSA1=$(echo "$R1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hasStaffAccount',''))")
check "纯会员 loginType" "member" "$LT1"
check "纯会员 isStaff" "False" "$IS1"
check "纯会员 hasStaffAccount" "False" "$HSA1"

echo ""
echo "【2】openid 绑 staff:"
R2=$(login c53_owner)
LT2=$(echo "$R2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('loginType',''))")
IS2=$(echo "$R2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('isStaff',''))")
OWNER2=$(echo "$R2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('isOwner',''))")
ROLE2=$(echo "$R2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('staffRole',''))")
TOKEN2=$(echo "$R2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")
check "员工 loginType" "staff" "$LT2"
check "员工 isStaff" "True" "$IS2"
check "员工 isOwner" "True" "$OWNER2"
check "员工 staffRole" "OWNER" "$ROLE2"

# 用 staff token 调 /me
ME=$(curl -s -H "X-App-Id: wx9e147c4e2151b123" -H "Authorization: Bearer $TOKEN2" $H/api/merchant/staff/me)
USERID=$(echo "$ME" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['userId'])")
check "staff token /me 拿 userId=59" "59" "$USERID"

echo ""
echo "【3】openid 绑 staff 但 status=1:"
cat > /tmp/DisableC53.java <<'JEOF'
import java.sql.*;
public class DisableC53 {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      s.execute("UPDATE sys_user SET status='1' WHERE user_id=59");
    }
  }
}
JEOF
cd /tmp && javac DisableC53.java 2>&1
java -cp "/tmp:/Users/mac/.m2/repository/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar" DisableC53 2>&1
cd /Users/mac/dev/dytuangou
R3=$(login c53_owner)
LT3=$(echo "$R3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('loginType',''))")
IS3=$(echo "$R3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('isStaff',''))")
HSA3=$(echo "$R3" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hasStaffAccount',''))")
check "停用员工 loginType" "member" "$LT3"
check "停用员工 isStaff" "False" "$IS3"
check "停用员工 hasStaffAccount" "True" "$HSA3"

# 恢复
cat > /tmp/EnableC53.java <<'JEOF'
import java.sql.*;
public class EnableC53 {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      s.execute("UPDATE sys_user SET status='0' WHERE user_id=59");
    }
  }
}
JEOF
cd /tmp && javac EnableC53.java 2>&1
java -cp "/tmp:/Users/mac/.m2/repository/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar" EnableC53 2>&1

echo ""
echo "============================="
echo "V2.6.2 openid 优先身份识别 smoke: $PASS pass / $FAIL fail"
[ "$FAIL" = "0" ]
