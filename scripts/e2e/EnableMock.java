import java.sql.*;
public class EnableMock {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      // 微信小程序登录 mock
      s.execute("UPDATE sys_config SET config_value='true' WHERE config_key='wx.miniapp.mockEnabled'");
      // 微信支付 mock（独立于 wxMaConfig 的 mock 标志）
      s.execute("UPDATE sys_config SET config_value='true' WHERE config_key='wx.pay.mockEnabled'");
      // 同时把商户的 mock_enabled 改成 '0'（开启），否则商户级 mock 优先于 sys_config 仍会走真实微信
      s.execute("UPDATE biz_merchant SET mock_enabled='0'");
      System.out.println("[ok] mock enabled (wx.miniapp + wx.pay + biz_merchant)");
    }
  }
}
