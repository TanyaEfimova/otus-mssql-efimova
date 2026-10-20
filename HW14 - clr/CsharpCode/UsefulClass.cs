using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

namespace UsefulClassNamespace
{
    public class UsefulClass
    {
        [SqlFunction(FillRowMethodName = "SplitStringFillRow", TableDefinition = "PartID INT, Part NVARCHAR(MAX), ")]
        public static IEnumerator SplitString(SqlString text, char[] delimiter)

        {
            if (text.IsNull) yield break;

            int valueIndex = 1;

            foreach (string s in text.Value.Split(delimiter, StringSplitOptions.RemoveEmptyEntries))
            {

                yield return new KeyValuePair<int, string>(valueIndex++, s.Trim());

            }
        }

        public static void SplitStringFillRow(object oKeyValuePair, out SqlInt32 valueIndex, out SqlString value)

        {

            KeyValuePair<int, string> keyValuePair = (KeyValuePair<int, string>)oKeyValuePair;

            valueIndex = keyValuePair.Key;

            value = keyValuePair.Value;

        }
    }
}
