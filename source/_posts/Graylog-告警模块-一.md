---
title: 'Graylog:告警模块(一)'
date: 2023-03-06 21:49:46
updated: 2023-03-06 21:49:46
tags:
    - Graylog
    - 告警
    - java
categories:
    - [Graylog]
comments:
---
告警模块是SIEM产品中重要的模块，下文将在源码层面解析在Graylog中是如何实现此模块的。
<!-- more -->
1、Graylog系统中的任务均实现于Job接口，此接口如下，包含一个抽象工厂方法和任务执行动作。
(抽象工厂方法进行解析)
```java
/**
 * Interface to be implemented by job classes.
 */
public interface Job {
    interface Factory<TYPE extends Job> {
        TYPE create(JobDefinitionDto jobDefinition);
    }

    /**
     * Called by the scheduler when a trigger fires to execute the job. It returns a {@link JobTriggerUpdate} that
     * instructs the scheduler about the next trigger execution time, trigger data and others.
     *
     * @param ctx the job execution context
     * @return the trigger update
     * @throws JobExecutionException if the job execution fails
     */
    JobTriggerUpdate execute(JobExecutionContext ctx) throws JobExecutionException;
}
```



