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
                    // 没有工作线程可用时，进行睡眠，避免busy spinning，CPU空转，造成CPU资源极大浪费。
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

```text
Busy spinning是一种CPU密集型的等待机制，也称为忙等待。当程序需要等待某个条件满足时，它会在循环中反复检查这个条件是否已经满足，如果没有满足就一直循环下去，直到条件满足才继续执行后续操作。

这种等待方式可以避免进程切换和上下文切换的开销，因为它只使用CPU资源而不会进入睡眠状态，因此可以更快地响应事件。但是，它也会占用大量的CPU时间，降低了CPU利用率，可能会影响其他程序的性能和系统的稳定性，尤其在高并发环境下容易造成资源争用，因此需要谨慎使用。

在实际应用中，busy spinning通常用于短暂等待的场景，例如自旋锁、轮询等，在长时间等待的场景下则不适合使用，应该选择其他的等待方式，如阻塞、休眠等。
```
自定义中断器，在不中断线程的情况下模拟睡眠，原理是利用了AQS底层的自旋锁，避免频繁让出和获取CPU造成线程上下文频繁切换，降低系统性能。

```java
/**
     * This class provides a sleep method that can be interrupted without interrupting threads.
     * The same could be achieved by using a {@link CountDownLatch} but that one cannot be reused and we would need
     * to create new latch objects all the time. This implementation is using a {@link Semaphore} internally which
     * can be reused.
     */
    @VisibleForTesting
    static class InterruptibleSleeper {

        private final Semaphore semaphore;

        InterruptibleSleeper() {
            this(new Semaphore(1));
        }

        @VisibleForTesting
        InterruptibleSleeper(Semaphore semaphore) {
            this.semaphore = semaphore;
        }

        /**
         * Blocks for the given duration or until interrupted via {@link #interrupt()}.
         *
         * @param duration the duration to sleep
         * @param unit     the duration unit
         * @return true if slept for the given duration, false if interrupted
         * @throws InterruptedException if the thread gets interrupted
         */
        public boolean sleep(long duration, TimeUnit unit) throws InterruptedException {
            // First we have to drain all available permits because interrupt() might get called very often and thus
            // there might be a lot of permits.
            semaphore.drainPermits();
            // Now try to acquire a permit. This won't work except #interrupt() got called in the meantime.
            // It waits for the given duration, basically emulating a sleep.
            return !semaphore.tryAcquire(duration, unit);
        }

        /**
         * Interrupt a {@link #sleep(long, TimeUnit)} call so it unblocks.
         */
        public void interrupt() {
            // Attention: this will increase available permits every time it's called.
            semaphore.release();
        }
    }
```

3、
