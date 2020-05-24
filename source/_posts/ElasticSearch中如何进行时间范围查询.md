---
title: ElasticSearch中如何进行时间范围查询
date: 2020-05-24 16:54:58
tags: 
    - ElasticSearch
    - Range Query
categories: ElasticSearch
comments: 
---
在开发过程中有需求是对ElasticSearch中对一定时间范围内数据进行查询,完成后做下记录.
<!-- more -->
# 数值范围查询
```
GET /_search
{
    "query": {
        "range" : {
            "age" : {
                "gte" : 10,
                "lte" : 20,
                "boost" : 2.0
            }
        }
    }
}
```
# 范围查询的符号
|  符号 | 含义 |  
| :----: | :---: |
|  gt  | >| 
|  gte  | >=| 
|  lt  | <| 
|  lte  | <=| 

# 时间范围查询
如果为`date`类型数据,可以使用`data math`,如下:
## data math
`gt`  
Rounds up to the first millisecond not covered by the rounded date.  
For example, 2014-11-18||/M rounds up to 2014-12-01T00:00:00.000, excluding the entire month of November.

`gte`  
Rounds down to the first millisecond.  
For example, 2014-11-18||/M rounds down to 2014-11-01T00:00:00.000, including the entire month.

`lt`  
Rounds down to the last millisecond before the rounded value.  
For example, 2014-11-18||/M rounds down to 2014-10-31T23:59:59.999, excluding the entire month of November.

`lte`  
Rounds up to the latest millisecond in the rounding interval.  
For example, 2014-11-18||/M rounds up to 2014-11-30T23:59:59.999, including the entire month.
## 昨天和今天的范围
`"gte" : "now-1d/d" //昨天00:00:00`   
`"lt" :  "now/d"        // 今天晚上00:00:00`
```
GET /_search
{
    "query": {
        "range" : {
            "timestamp" : {
                "gte" : "now-1d/d",
                "lt" :  "now/d"
            }
        }
    }
}
```
## 时间公式
- `+1h`: Add one hour//加一小时  
- `-1d`: Subtract one day//减一小时 
- `/d`: Round down to the nearest day//四舍五入到`最近`一天  

| 表达式 | 含义 |
|:---:|:---:|  
| y | Years |  
| M | Months |  
| w | weeks |  
| d | Days |  
| h | Hours |  
| H | Houss |  
| m | minutes |  
| s | Seconds |  

假如当前系统时间为`now = 2001-01-01 12:00:00`,则  
`now+1h` =  2001-01-01 13:00:00  
`now-1h`  =  2001-01-01 11:00:00  
`now-1h/d`  =  2001-01-01 00:00:00 //毫秒减去一小时,约等于到当天起始  
`2001.02.01\|\|+1M/d` = 2001-03-01 00:00:00 //毫秒加一个月,再约等于到当天起始     

## 时区
```
GET /_search
{
  "query": {
    "range": {
      "timestamp": {
        "time_zone": "+01:00",        
        "gte": "2020-01-01T00:00:00", 
        "lte": "now"                  
      }
    }
  }
}
```
- 时区对`now`不生效

## 踩坑
### 查今天范围内数据,写法应该为
```
GET index/_search
{
    "query": {
        "range" : {
            "timestamp" : {
                "gte" : "now-1h/d",
                "lt" :  "now/d"
            }
        }
    }
}
```
## 参考文档
[Elasticsearch Reference [7.7] » Query DSL » Term-level queries » Range query](https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-range-query.html#querying-range-fields)  
[Elasticsearch Reference [7.7] » REST APIs » API conventions » Common options](https://www.elastic.co/guide/en/elasticsearch/reference/current/common-options.html#date-math)  
[Elasticsearch中如何进行日期(数值)范围查询](https://www.cnblogs.com/shoufeng/p/11266136.html)