---
title: Graylog源码解析(1)-任务调度模块详解
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
告警模块是SIEM产品中重要的模块，下文将在源码层面解析在Graylog中实现此模块的任务调度模块的实现细节。
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
                // 仅在canExecute()状态转变后进行日志提示输出
                executionEnabled = logExecutionConfigState(executionEnabled, false);
                clock.sleepUninterruptibly(1, TimeUnit.SECONDS);
                continue;
            }
            executionEnabled = logExecutionConfigState(executionEnabled, true);

            LOG.debug("Starting scheduler loop iteration");
            try {
                // 核心调度方法
                // jobExecutionEngine.execute()此方法是多个节点能否分布式执行任务的关键实现，开源版本Graylog默认只有主节点能执行任务，
                // 如果自己想基于开源版本实现分布式执行任务，需要修改此方法的实现。
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

可中断睡眠器，在不中断线程的情况下模拟睡眠，可灵活控制睡眠时间和唤醒时机。

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

3、JobExecutionEngine执行引擎检查可运行的触发器，并在给定的工作线程池中启动作业执行。

```java
/**
     * Execute the engine. This will try to lock a trigger and execute the job if there are free slots in the
     * worker pool and the engine is not shutting down.
     *
     * @return true if a job trigger has been locked and the related job has been triggered, false otherwise
     */
    public boolean execute() {
        // Cleanup stale scheduler state *before* processing any triggers for the first time.
        // This is a no-op after the first invocation.
        // 每次启动之前，会修改当前节点在数据库中的处于running状态的触发器状态，使其置于runnable状态。
        if (shouldCleanup.get()) {
            cleanup();
        }
        // We want to avoid a call to the database if there are no free slots in the pool or the engine is shutting down
        // 判断执行条件
        if (isRunning.get() && workerPool.hasFreeSlots()) {
            // 按照FIELD_NEXT_TIME顺序，获取未被上锁或已上锁但锁超过5min超时时间(默认)的触发器。
            final Optional<JobTriggerDto> triggerOptional = jobTriggerService.nextRunnableTrigger();

            if (triggerOptional.isPresent()) {
                final JobTriggerDto trigger = triggerOptional.get();
                // 线程池执行触发器任务
                if (!workerPool.execute(() -> handleTrigger(trigger))) {
                    // The job couldn't be executed so we have to release the trigger again with the same nextTime
                    // 此触发器无法执行时，更新状态为RUNNABLE，且nextTime不变，把触发器释放。
                    jobTriggerService.releaseTrigger(trigger, JobTriggerUpdate.withNextTime(trigger.nextTime()));
                    return false;
                }
                return true;
            }
        }
        return false;
    }
```

`handleTrigger(JobTriggerDto trigger)`执行触发器，获取trigger、obDefinition、job这些需要执行的方法和参数。

```java
private void handleTrigger(JobTriggerDto trigger) {
        LOG.trace("Locked trigger {} (owner={})", trigger.id(), trigger.lock().owner());

        try {
            final JobDefinitionDto jobDefinition = jobDefinitionService.get(trigger.jobDefinitionId())
                    .orElseThrow(() -> new IllegalStateException("Couldn't find job definition " + trigger.jobDefinitionId()));

            final Job job = jobFactory.get(jobDefinition.config().type()).create(jobDefinition);
            if (job == null) {
                throw new IllegalStateException("Couldn't find job factory for type " + jobDefinition.config().type());
            }

            executionTime.time(() -> executeJob(trigger, jobDefinition, job));
        } catch (IllegalStateException e) {
            // The trigger cannot be handled because of a permanent error so we mark the trigger as defective
            LOG.error("Couldn't handle trigger due to a permanent error {} - trigger won't be retried", trigger.id(), e);
            jobTriggerService.setTriggerError(trigger);
        } catch (Exception e) {
            // The trigger cannot be handled because of an unknown error, retry in a few seconds
            // TODO: Check if we need to implement a max-retry after which the trigger is set to ERROR
            final DateTime nextTime = DateTime.now(DateTimeZone.UTC).plusSeconds(5);
            LOG.error("Couldn't handle trigger {} - retrying at {}", trigger.id(), nextTime, e);
            jobTriggerService.releaseTrigger(trigger, JobTriggerUpdate.withNextTime(nextTime));
        } finally {
            // 任务执行结束，有可执行资源，调用InterruptibleSleeper.interrupt()方法，中断JobSchedulerService的睡眠，让其继续执行。
            eventBus.post(JobCompletedEvent.INSTANCE);
        }
    }
```

最终的Job执行的方法，源码增加了些指标监控注解和方法。

```java
@WithSpan
    private void executeJob(JobTriggerDto trigger, JobDefinitionDto jobDefinition, Job job) {
        Span.current().setAttribute(SCHEDULER_JOB_CLASS, job.getClass().getSimpleName())
                .setAttribute(SCHEDULER_JOB_DEFINITION_TYPE, jobDefinition.config().type())
                .setAttribute(SCHEDULER_JOB_DEFINITION_TITLE, jobDefinition.title())
                .setAttribute(SCHEDULER_JOB_DEFINITION_ID, Strings.valueOf(jobDefinition.id()));
        try {
            if (LOG.isDebugEnabled()) {
                LOG.debug("Execute job: {}/{}/{} (job-class={} trigger={} config={})", jobDefinition.title(), jobDefinition.id(),
                        jobDefinition.config().type(), job.getClass().getSimpleName(), trigger.id(), jobDefinition.config());
            }
            // 调用Job接口执行方法，执行不同类型的Job实现类的方法。
            final JobTriggerUpdate triggerUpdate = job.execute(JobExecutionContext.create(trigger, jobDefinition, jobTriggerUpdatesFactory.create(trigger), isRunning, jobTriggerService));

            if (triggerUpdate == null) {
                executionFailed.inc();
                throw new IllegalStateException("Job#execute() must not return null - this is a bug in the job class");
            }
            executionSuccessful.inc();

            LOG.trace("Update trigger: trigger={} update={}", trigger.id(), triggerUpdate);
            jobTriggerService.releaseTrigger(trigger, triggerUpdate);
        } catch (JobExecutionException e) {
            LOG.error("Job execution error - trigger={} job={}", trigger.id(), jobDefinition.id(), e);
            executionFailed.inc();

            jobTriggerService.releaseTrigger(e.getTrigger(), e.getUpdate());
        } catch (Exception e) {
            executionFailed.inc();
            // This is an unhandled job execution error so we mark the trigger as defective
            LOG.error("Unhandled job execution error - trigger={} job={}", trigger.id(), jobDefinition.id(), e);

            // Calculate the next time in the future based on the trigger schedule. We cannot do much else because we
            // don't know what happened and we also got no instructions from the job. (no JobExecutionException)
            final DateTime nextFutureTime = scheduleStrategies.nextFutureTime(trigger).orElse(null);

            jobTriggerService.releaseTrigger(trigger, JobTriggerUpdate.withNextTime(nextFutureTime));
        }
    }
```

4、DBJobTriggerService控制任务触发器的服务，使用MongoDB作为分布式锁。

```java
/**
     * Locks and returns the next runnable trigger. The caller needs to take care of releasing the trigger lock.
     *
     * @return next runnable trigger if any exists, an empty {@link Optional} otherwise
     */
    public Optional<JobTriggerDto> nextRunnableTrigger() {
        final DateTime now = clock.nowUTC();

        final Query constraintsQuery = MongoQueryUtils.getArrayIsContainedQuery(FIELD_CONSTRAINTS, schedulerCapabilitiesService.getNodeCapabilities());

        final Query query = DBQuery.or(DBQuery.and(
                        // We cannot lock a trigger that is already locked by another node
                        // 查询处于RUNNABLE状态的触发器
                        DBQuery.is(FIELD_LOCK_OWNER, null),
                        DBQuery.is(FIELD_STATUS, JobTriggerStatus.RUNNABLE),
                        DBQuery.lessThanEquals(FIELD_START_TIME, now),
                        constraintsQuery,

                        DBQuery.or( // Skip triggers that have an endTime which is due
                                DBQuery.notExists(FIELD_END_TIME),
                                DBQuery.is(FIELD_END_TIME, null),
                                DBQuery.greaterThan(FIELD_END_TIME, Optional.of(now))
                        ),
                        // TODO: Using the wall clock time here can be problematic if the node time is off
                        //       The scheduler should not lock any new triggers if it detects that its clock is wrong
                        DBQuery.lessThanEquals(FIELD_NEXT_TIME, now)
                ), DBQuery.and(
                        // 查询RUNNING状态、不属于本节点、且超过超时时间的触发器。
                        // 起到一定负载作用，均衡各节点间性能差异。
                        DBQuery.notEquals(FIELD_LOCK_OWNER, null),
                        DBQuery.notEquals(FIELD_LOCK_OWNER, nodeId),
                        DBQuery.is(FIELD_STATUS, JobTriggerStatus.RUNNING),
                        constraintsQuery,
                        DBQuery.lessThan(FIELD_LAST_LOCK_TIME, now.minus(lockExpirationDuration.toMilliseconds())))
        );
        // We want to lock the trigger with the oldest next time
        final DBSort.SortBuilder sort = DBSort.asc(FIELD_NEXT_TIME);

        final DBUpdate.Builder lockUpdate = DBUpdate.set(FIELD_LOCK_OWNER, nodeId)
                .set(FIELD_LAST_LOCK_OWNER, nodeId)
                .set(FIELD_STATUS, JobTriggerStatus.RUNNING)
                .set(FIELD_TRIGGERED_AT, Optional.of(now))
                .set(FIELD_LAST_LOCK_TIME, now);

        // Atomically update, lock and return the next runnable trigger
        // MongoDB findAndModify 是一个原子性操作，故可以用它实现分布式锁，避免并发问题。
        final JobTriggerDto trigger = db.findAndModify(
                query,
                null,
                sort,
                false,
                lockUpdate,
                true, // We need the modified object so we have access to the lock information
                false
        );
        return Optional.ofNullable(trigger);
    }
```

```java
 /**
     * Releases a locked trigger. The trigger is only released if it's owned by the calling node.
     *
     * @param trigger       trigger that should be released
     * @param triggerUpdate update to apply to the trigger
     * @return true if the trigger has been modified, false otherwise
     */
    public boolean releaseTrigger(JobTriggerDto trigger, JobTriggerUpdate triggerUpdate) {
        requireNonNull(trigger, "trigger cannot be null");
        requireNonNull(triggerUpdate, "triggerUpdate cannot be null");

        final Query query = DBQuery.and(
                // Make sure that the owner still owns the trigger
                // 将属于自己的触发器进行释放，修改状态。
                DBQuery.is(FIELD_LOCK_OWNER, nodeId),
                DBQuery.is(FIELD_ID, getId(trigger)),
                // Only release running triggers. The trigger might have been paused while the trigger was running
                // so we don't want to set it to RUNNABLE again.
                // TODO: This is an issue. If a user set it to PAUSED, we will not unlock it. Figure something out.
                //       Maybe a manual trigger pause will set "nextStatus" if the trigger is currently running?
                //       That next status would need to be set on release.
                DBQuery.is(FIELD_STATUS, JobTriggerStatus.RUNNING)
        );
        final DBUpdate.Builder update = DBUpdate.set(FIELD_LOCK_OWNER, null);

        // An empty next time indicates that this trigger should not be fired anymore. (e.g. for "once" schedules)
        if (triggerUpdate.nextTime().isPresent()) {     
            if (triggerUpdate.status().isPresent()) {
                update.set(FIELD_STATUS, triggerUpdate.status().get());
            } else {
                update.set(FIELD_STATUS, JobTriggerStatus.RUNNABLE);
            }
            update.set(FIELD_NEXT_TIME, triggerUpdate.nextTime().get());
        } else {
            update.set(FIELD_STATUS, triggerUpdate.status().orElse(JobTriggerStatus.COMPLETE));
        }

        if (triggerUpdate.data().isPresent()) {
            update.set(FIELD_DATA, triggerUpdate.data());
        }

        final int changedDocs = db.update(query, update).getN();
        if (changedDocs > 1) {
            throw new IllegalStateException("Expected to release only one trigger (id=" + trigger.id() + ") but database query modified " + changedDocs);
        }
        return changedDocs == 1;
    }
```

5、JobWorkerPool为告警引擎使用的线程池。

Job执行线程池核心方法：

```java
/**
     * Exeute the given job in the worker pool if there are any free slots.
     *
     * @param job the job to execute
     * @return true if the job could be executed, false otherwise
     */
    public boolean execute(final Runnable job) {
        // If there are no available slots, we won't do anything
        final boolean acquired = slots.tryAcquire();
        if (!acquired) {
            return false;
        }

        try {
            executor.execute(() -> {
                try {
                    job.run();
                } catch (Exception e) {
                    LOG.error("Unhandled job execution error", e);
                } finally {
                    slots.release();
                }
            });
            return true;
        } catch (RejectedExecutionException e) {
            // This should not happen because we always check the semaphore before submitting jobs to the pool
            slots.release();
            return false;
        }
    }
```

`Semaphore`使用的是公平策略，毕竟告警规则执行以时间顺序执行更优。
`shutdownCallback`为`jobHeartbeatExecutor.scheduleAtFixedRate(this::updateLockedJobs, 0, 15, TimeUnit.SECONDS);`触发器更新定时器，更新触发器的FIELD_LAST_LOCK_TIME字段。

```java
    @Inject
    public JobWorkerPool(@Assisted String name,
                         @Assisted int poolSize,
                         @Assisted Runnable shutdownCallback,
                         GracefulShutdownService gracefulShutdownService,
                         MetricRegistry metricRegistry) {
        this.shutdownCallback = shutdownCallback;
        this.poolSize = poolSize;
        checkArgument(NAME_PATTERN.matcher(name).matches(), "Pool name must match %s", NAME_PATTERN);

        this.executor = buildExecutor(name, poolSize, metricRegistry);
        this.slots = new Semaphore(poolSize, true);

        registerMetrics(metricRegistry, poolSize);
        gracefulShutdownService.register(this);
    }
```

核心工作线程池构造参数：

1. 创建线程工厂：
   - 使用 `ThreadFactoryBuilder` 创建线程工厂，可以设置线程的属性，如是否为守护线程、线程名称格式等。
   - `setDaemon(true)` 表示创建的线程为守护线程，守护线程不会阻止程序的退出。
   - `setNameFormat(NAME_PREFIX + "[" + name + "]-%d")` 设置线程名称的格式，其中 `NAME_PREFIX` 和 `name` 是变量，`%d` 表示线程编号。

2. 创建监控增强的线程工厂：
   - 使用 `InstrumentedThreadFactory` 封装之前创建的线程工厂，以实现监控线程创建和销毁的指标。

3. 创建队列：
   - 创建一个 `SynchronousQueue`，它是一个没有容量的阻塞队列，用于在生产者和消费者之间传递任务。

4. 创建线程池：
   - 使用 `ThreadPoolExecutor` 创建线程池，其中参数解释如下：
     - `1`：核心线程数，表示线程池中始终保持的活动线程数量。
     - `poolSize`：最大线程数，表示线程池中允许存在的最大线程数量。
     - `60L`：非核心线程的空闲时间，超过该时间将被终止。
     - `TimeUnit.SECONDS`：时间单位，用于指定时间参数的单位。
     - `workQueue`：工作队列，用于存放等待执行的任务。
     - `itf`：线程工厂，用于创建线程。

5. 创建监控增强的 `ExecutorService`：
   - 使用 `InstrumentedExecutorService` 封装之前创建的线程池，以实现监控线程池的执行指标。

总的来说，这段代码构建了一个线程池，其中线程池的核心和最大线程数由 `poolSize` 参数指定，线程的创建和销毁由 `InstrumentedThreadFactory` 和 `InstrumentedExecutorService` 实现，同时使用了一个 `SynchronousQueue` 作为工作队列，用于传递任务。整个线程池还通过监控指标进行监控。这种构建方式通常用于多线程任务的并发执行，并结合监控框架对线程池的性能和行为进行监控和度量。

```java
    private static ExecutorService buildExecutor(String name, int poolSize, MetricRegistry metricRegistry) {
        final ThreadFactory threadFactory = new ThreadFactoryBuilder()
                .setDaemon(true)
                .setNameFormat(NAME_PREFIX + "[" + name + "]-%d")
                .setUncaughtExceptionHandler((t, e) -> LOG.error("Unhandled exception", e))
                .build();
        final InstrumentedThreadFactory itf = new InstrumentedThreadFactory(threadFactory, metricRegistry, name(JobWorkerPool.class, name));
        final SynchronousQueue<Runnable> workQueue = new SynchronousQueue<>();

        final ThreadPoolExecutor executor = new ThreadPoolExecutor(1, poolSize, 60L, TimeUnit.SECONDS, workQueue, itf);
        return new InstrumentedExecutorService(executor, metricRegistry, name(EXECUTOR_NAME, name));
    }
```

需要注意`SynchronousQueue`使用场景和用途：
`SynchronousQueue` 是 Java 并发包中的一个阻塞队列实现，它具有特殊的特性，用途主要是在生产者和消费者之间进行任务传递。与其他阻塞队列（如 `ArrayBlockingQueue` 或 `LinkedBlockingQueue`）不同，`SynchronousQueue` 没有实际的容量，它仅仅是用于在线程间传递数据的一种机制。

**用途：**

1. **线程传递任务：** `SynchronousQueue` 适用于需要在线程间传递任务而不保留任务的队列。例如，生产者线程生成任务，然后将任务放入 `SynchronousQueue`，消费者线程从队列中取出任务并执行。这样可以实现任务的异步传递和执行。

2. **线程池任务传递：** 在一些线程池实现中，任务提交给线程池时可能会使用 `SynchronousQueue`，这样可以确保线程池不会积累任务，而是通过阻塞等待消费者线程的处理。

3. **同步协作：** `SynchronousQueue` 还可以用于多个线程之间的同步协作，特别是在一个线程必须等待另一个线程完成某个操作后才能继续执行的情况。

**优点：**

1. **零容量：** `SynchronousQueue` 没有实际的容量，它可以避免任务积累，从而可以确保任务的实时处理。

2. **高并发：** `SynchronousQueue` 可以在高并发情况下有效地传递任务，由于没有实际的存储，它可以避免线程切换的开销。

3. **一对一传递：** 每个插入操作都会等待对应的取出操作，这保证了任务的一对一传递。

4. **线程之间的协作：** 可以用于线程之间的协作，确保一个线程等待另一个线程的结果或操作完成。

**注意事项：**

- `SynchronousQueue` 的主要特性是无法存储元素，因此插入操作必须等待相应的取出操作，反之亦然。这可能会导致一些线程阻塞，需要谨慎使用，以免造成死锁。

总之，`SynchronousQueue` 在需要高效地传递任务或线程之间的同步协作时非常有用。但由于其特殊的特性，需要在合适的场景中使用，以确保不会导致线程阻塞或死锁。

6、总结。

以上就是Graylog的任务调度机制实现细节，Graylog原生有两种子类继承Job类，一个是`EventProcessorExecutionJob`Graylog的告警模块，另一个是`EventNotificationExecutionJob`Graylog的通知模块。
