#region

using System.Data.Common;
using System.Data.SQLite;

#endregion

using (DbConnection conn = new SQLiteConnection("Data Source=test.db;"))
{
    conn.Open();
    DbCommand cmd = conn.CreateCommand();
    cmd.CommandText = "SELECT * FROM MESSAGES";
    using (DbDataReader reader = cmd.ExecuteReader())
    {
        while (reader.Read()) Console.WriteLine(reader.GetString(0));
    }
}
