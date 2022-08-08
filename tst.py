#!/usr/bin/env python

import ibmcloudsql
import pandas
import sqlparse 
from pygments import highlight
from pygments.lexers import get_lexer_by_name
from pygments.formatters import HtmlFormatter, Terminal256Formatter
lexer = get_lexer_by_name("sql", stripall=True)
formatter = Terminal256Formatter(style='vim')

# keep globals in a different file in gitignore
import globals
apikey=globals.apikey
instancecrn=globals.instancecrn
dataengineurl=globals.dataengineurl
logsurl=globals.logsurl

sqlClient = ibmcloudsql.SQLQuery(apikey, instancecrn, client_info='notebook', target_cos_url=dataengineurl, max_concurrent_jobs=4, max_tries=3 )
#sqlClient.configure()  # use this if you want to change the API key or Data Engine CRN later
sqlClient.logon()
print('\\nYour Data Engine web console link:\\n')
sqlClient.sql_ui_link()

def sql_format(sql):
    formatted_sql = sqlparse.format(sql, reindent=True, indent_tabs=True, keyword_case='upper')
    return highlight(formatted_sql, lexer, formatter)

def sql_format_print(sql):
    print('\\nYour SQL statement is:\\n')
    print(sql_format(sql))

def sql_into(sql, intourl, object_name):
    if object_name == None:
      return sql + f' INTO {intourl} STORED AS JSON'
    else:
      return sql + f' INTO {intourl}/{object_name} JOBPREFIX NONE STORED AS JSON'

def sql_p(sql):
    sql_format_print(sql)
    print(sql)
    result_df = sqlClient.run_sql(sql)
    print(result_df.head(10))
    return result_df

def sql_r(sql, object_name=None):
    "If object_name provided do not use a JOBPREFIX"
    global dataengineurl
    sql=sql_into(sql, dataengineurl, object_name)
    spl_p(sql)

def tst1():
  # get the oldest 10 record. Notice all of the columns that can be used for queries
  df = sql_r(f'SELECT * FROM FLATTEN({logsurl} STORED AS JSON) LIMIT 10', "result-001")
  with pandas.option_context('display.max_colwidth', None):
      print (df)
  # find all records that are not from the sql-query (data engine) service
  df = sql_r(f'SELECT * FROM FLATTEN({logsurl} STORED AS JSON) WHERE _source__host NOT RLIKE "sql-query" LIMIT 10', "result-002")
  with pandas.option_context('display.max_colwidth', None):
      print (df)


sql_p('''SELECT * FROM FLATTEN(
  cos://s3.us-south.cloud-object-storage.appdomain.cloud/log-archive-us-data-engine-006/result-002
  STORED AS JSON
  ) WHERE _source__host NOT RLIKE "sql-query" LIMIT 100 INTO
  cos://s3.us-south.cloud-object-storage.appdomain.cloud/log-archive-us-data-engine-006/tmp
  STORED AS JSON
''')