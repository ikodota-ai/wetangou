import java.sql.*;
public class DisableMock {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      s.execute("UPDATE sys_config SET config_value='false' WHERE config_key='wx.miniapp.mockEnabled'");
      s.execute("UPDATE sys_config SET config_value='false' WHERE config_key='wx.pay.mockEnabled'");
      // 同时把商户的 mock_enabled 改回 '1'（关闭）
      s.execute("UPDATE biz_merchant SET mock_enabled='1'");
      System.out.println("[ok] mock disabled (sys_config + biz_merchant)");
    }
  }
}
