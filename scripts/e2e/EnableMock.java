import java.sql.*;
public class EnableMock {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      s.execute("UPDATE sys_config SET config_value='true' WHERE config_key='wx.miniapp.mockEnabled'");
      System.out.println("[ok] mockEnabled=true");
    }
  }
}
