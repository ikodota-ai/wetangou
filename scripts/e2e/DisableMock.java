import java.sql.*;
public class DisableMock {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      s.execute("UPDATE sys_config SET config_value='false' WHERE config_key='wx.miniapp.mockEnabled'");
      s.execute("UPDATE sys_config SET config_value='false' WHERE config_key='wx.pay.mockEnabled'");
      System.out.println("[ok] mock disabled");
    }
  }
}
