import java.sql.*;
public class SeedStaff {
  public static void main(String[] a) throws Exception {
    String url = "jdbc:mysql://127.0.0.1:3306/ry-vue?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true";
    try (Connection c = DriverManager.getConnection(url, "root", "133301"); Statement s = c.createStatement()) {
      ResultSet rs = s.executeQuery("DESC sys_user");
      while (rs.next()) System.out.print(rs.getString(1) + " ");
      System.out.println();
      rs.close();
      rs = s.executeQuery("SELECT * FROM sys_user WHERE user_id=7");
      while (rs.next()) System.out.println("uid=7 cols:");
      ResultSetMetaData md = rs.getMetaData();
      for (int i=1; i<=md.getColumnCount(); i++) System.out.print(md.getColumnName(i) + "=" + rs.getString(i) + "  ");
      System.out.println();
    }
  }
}
