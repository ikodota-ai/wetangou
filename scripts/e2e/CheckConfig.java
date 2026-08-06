import java.sql.*;
public class CheckConfig {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      ResultSet rs = s.executeQuery("SELECT config_key, config_value FROM sys_config WHERE config_key LIKE 'wx.%'");
      while (rs.next()) System.out.println(rs.getString(1)+"="+rs.getString(2));
      rs.close();
      rs = s.executeQuery("SELECT merchant_id, merchant_name, mock_enabled FROM biz_merchant");
      while (rs.next()) System.out.println("merchant "+rs.getLong(1)+" "+rs.getString(2)+" mock="+rs.getString(3));
    }
  }
}
