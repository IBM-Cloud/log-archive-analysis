# Historical analysis of Cloud Observability data
This is a companion repository for the [blog post](todo)

## Creating the resources

See [CLI Getting Started](https://cloud.ibm.com/docs/cli?topic=cli-getting-started).

Login to IBM Cloud via the command line:
```
ibmcloud login
```

Initialize the default resource group used by the command line by listing the resource groups and setting the default.

```
ibmcloud resource groups
ibmcloud target -g <your-default-resource-group>
```

Create an instance of [Object Storage](https://cloud.ibm.com/catalog/services/cloud-object-storage). If you already have Object Storage instance with a lite plan, use standard instead of lite.

```
ibmcloud resource service-instance-create logging-archive cloud-object-storage lite global
```

Create an instance of [Data Engine](https://cloud.ibm.com/catalog/services/sql-query). Replace us-south by your region, if needed. If you already have Data Engine instance with a lite plan, use standard instead of lite.



```
ibmcloud resource service-instance-create logging-archive sql-query lite us-south
```

Create an instance of [Watson Studio[(https://cloud.ibm.com/catalog/services/watson-studio).

```
ibmcloud resource service-instance-create loggin-history data-science-experience free-v1 us-south
```

Create a service ID and API key for the logging dashboard to write archives to the COS bucket:
```
(log-archive) log-archive $ ic iam service-id-create logging-archive
Creating service ID logging-history bound to current account as pquiring@us.ibm.com...
OK
Service ID logging-history is created successfully

ID            ServiceId-d0064f26-9aa1-4c11-aace-4971ede16e1b
Name          logging-history
Description
CRN           crn:v1:bluemix:public:iam-identity::a/713c783d9a507a53135fe6793c37cc74::serviceid:ServiceId-d0064f26-9aa1-4c11-aace-4971ede16e1b
Version       1-806f4a18966164d30d93f15b287fea80
Locked        false

ibmcloud iam service-api-key-create logging-history logging-history
```
Take note of the API Key this will be required in a later step




API key: QsH9If0GcHXv3pMPuMwZsuPJMxzOsUVVM48FC6HA4W_P

## Stuff

```
SELECT * FROM cos://us-south/activitytrackerarchiving000/ LIMIT 50

SELECT * FROM FLATTEN(cos://us-south/activitytrackerarchiving000/  STORED AS JSON) LIMIT 1


SELECT * FROM cos://us-east/deleteme0123/example.json STORED AS JSON LIMIT 50
SELECT * FROM cos://us-east/deleteme0123/example2.json.gz STORED AS JSON LIMIT 50

SELECT * FROM cos://us-south/activitytrackerarchiving000/  STORED AS JSON LIMIT 1

SELECT * FROM cos://us-east/deleteme0123/data00.json STORED AS JSON LIMIT 50 INTO cos://us-south/sql-3d9a7cc0-f590-4293-9849-1960d537e1a9/result/ STORED AS JSON

SELECT * FROM FLATTEN(cos://us-south/activitytrackerarchiving000/  STORED AS JSON) LIMIT 1 INTO cos://us-south/sql-3d9a7cc0-f590-4293-9849-1960d537e1a9/result/ STORED AS JSON

SELECT * FROM cos://us-south/activitytrackerarchiving000/year=2022/month=07/day=06/399484262a.2022-07-06.2000.json.gz  STORED AS JSON LIMIT 1 INTO cos://us-south/sql-3d9a7cc0-f590-4293-9849-1960d537e1a9/result/ STORED AS JSON

SELECT * FROM FLATTEN(cos://us-south/activitytrackerarchiving000/year=2022/month=07/day=06/399484262a.2022-07-06.2000.json.gz  STORED AS JSON )
WHERE 
INTO cos://us-south/sql-3d9a7cc0-f590-4293-9849-1960d537e1a9/result/ STORED AS JSON

WHERE NOT(_source_outcome RLIKE 'success')

SELECT * FROM FLATTEN(cos://us-south/activitytrackerarchiving000/ STORED AS JSON)
WHERE NOT(_source__app RLIKE 'crn:v1:bluemix:public:cloud-object-storage:.*')
INTO cos://us-south/sql-3d9a7cc0-f590-4293-9849-1960d537e1a9/result/ STORED AS JSON


```

notebook:

```
import ibmcloudsql
import sqlparse 
from pygments import highlight
from pygments.lexers import get_lexer_by_name
from pygments.formatters import HtmlFormatter, Terminal256Formatter
lexer = get_lexer_by_name("sql", stripall=True)
formatter = Terminal256Formatter

apikey='VzOR-c4M0WIDDJVRmAHCRgkjidap41sYcrMhrJTkUdtH'
instancecrn='crn:v1:bluemix:public:sql-query:us-south:a/713c783d9a507a53135fe6793c37cc74:3d9a7cc0-f590-4293-9849-1960d537e1a9::'
dataengineurl='cos://s3.us-south.cloud-object-storage.appdomain.cloud/dataengine002/notebook'
logsurl="cos://s3.us-south.cloud-object-storage.appdomain.cloud/activitytrackerarchiving002"

sqlClient = ibmcloudsql.SQLQuery(apikey, instancecrn, client_info='notebook', target_cos_url=dataengineurl, max_concurrent_jobs=4, max_tries=3 )
#sqlClient.configure()  # use this if you want to change the API key or Data Engine CRN later
    
sqlClient.logon()
print('\nYour Data Engine web console link:\n')
sqlClient.sql_ui_link()

def sql_format(sql):
    formatted_sql = sqlparse.format(sql, reindent=True, indent_tabs=True, keyword_case='upper')
    return highlight(formatted_sql, lexer, formatter)

def sql_format_print(sql):
    print('\nYour SQL statement is:\n')
    print(sql_format(sql))

def sql_into(sql, intourl):
    if " INTO " not in sql:
        return sql + f' INTO {intourl}myQueryResult STORED AS JSON'
    return sql

def sql_r(sql):
    global dataengineurl
    sql=sql_into(sql, dataengineurl)
    sql_format_print(sql)
    result_df = sqlClient.run_sql(sql)
    print(result_df.head(10))
    return result_df

sql_r(f"SELECT * FROM FLATTEN({logsurl}  STORED AS JSON) LIMIT 100").head(10)

result_df = sql_r(f"SELECT year, month, _source__line   FROM FLATTEN({logsurl} STORED AS JSON) WHERE _source_outcome NOT REGEXP 'success' LIMIT 100")
result_df.head(100)
result_df["_source__line"].head(2)


sqlClient.get_schema_data(logbucket, dry_run=True)
sqlClient.get_schema_data(logbucket)

```