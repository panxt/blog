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
1、Graylog系统中的任务均实现于Job接口，此接口如下，包含一个工厂方法模式接口和任务执行动作。

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

2、核心调度服务JobSchedulerService实现于Guava AbstractExecutionThreadService。

注：Guava包里的Service用于封装一个服务对象的运行状态、包括start和stop等方法。例如web服务器，RPC服务器、计时器等可以实现这个接口。对此类服务的状态管理并不轻松、需要对服务的开启/关闭进行妥善管理、特别是在多线程环境下尤为复杂。Guava 包提供了一些基础类帮助你管理复杂的状态转换逻辑和同步细节。

```java
    @Override
    protected void run() throws Exception {
        // Safety measure to make sure everything is started before we start job scheduling.
        LOG.debug("Waiting for server to enter RUNNING status before starting the scheduler loop");
        try {
            // 等待服务运行
            serverStatus.awaitRunning();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            LOG.debug("Was interrupted while waiting for server to enter RUNNING state. Aborting.");
            return;
        }
        LOG.debug("Server entered RUNNING state, starting scheduler loop");

        boolean executionEnabled = true;
        // 死循环判断当前service的运行状态
        while (isRunning()) {
            // 配置文件进行配置是否允不同节点进行执行
            if (!schedulerConfig.canExecute()) {
                executionEnabled = logExecutionConfigState(executionEnabled, false);
                clock.sleepUninterruptibly(1, TimeUnit.SECONDS);
                continue;
            }
            executionEnabled = logExecutionConfigState(executionEnabled, true);

            LOG.debug("Starting scheduler loop iteration");
            try {
                // 核心调度方法
                if (!jobExecutionEngine.execute() && isRunning()) {
                    // When the execution engine returned false, there are either no free worker threads or no
                    // runnable triggers. To avoid busy spinning we sleep for the configured duration or until
                    // we receive a job completion event via the scheduler event bus.
                    if (sleeper.sleep(loopSleepDuration.getQuantity(), loopSleepDuration.getUnit())) {
                        LOG.debug("Waited for {} {} because there are either no free worker threads or no runnable triggers",
                                    loopSleepDuration.getQuantity(), loopSleepDuration.getUnit());
                    }
                }
            } catch (InterruptedException e) {
                LOG.debug("Received interrupted exception", e);
            } catch (Exception e) {
                LOG.error("Error running job execution engine", e);
            }
            LOG.debug("Ending scheduler loop iteration");
        }
    }
```


