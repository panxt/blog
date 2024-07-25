---
title: JAVA线程中断两个示例
date: 2024-07-25 21:59:14
updated: 22024-07-25 21:59:14
tags:
categories:
comments:
---

## 线程中断

### 1. 线程中断

线程中断是指当一个线程正在运行时，另一个线程可以调用该线程的`interrupt()`方法来中断该线程的执行。当线程被中断时，该线程会抛出一个`InterruptedException`异常，该异常可以被捕获或者处理。

### 2. 线程中断示例

#### 2.1 线程中断实例1

```java
import java.util.concurrent.*;

public class IgnoredInterruptionExample {
    public static void main(String[] args) {
        // 创建一个ExecutorService
        ExecutorService executor = Executors.newSingleThreadExecutor();

        // 创建一个任务，不会响应中断
        Runnable task = () -> {
            try {
                // 模拟一个长时间运行的任务，不响应中断
                while (true) {
                    // 执行一些工作
                    System.out.println("任务正在运行...");
                    Thread.sleep(1000); // 模拟工作中的延迟

                    // 这里忽略中断信号
                    // 通常，我们应该检查 Thread.currentThread().isInterrupted() 并适当处理
                }
            } catch (InterruptedException e) {
                // 捕获InterruptedException，但不退出循环
                System.out.println("任务被中断信号捕获，但忽略它");
            }
        };

        // 提交任务并获取Future对象
        Future<?> future = executor.submit(task);

        try {
            // 等待任务完成，最多等待5秒
            future.get(5, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            // 超时异常
            System.out.println("任务超时，尝试取消...");
            future.cancel(true); // 尝试取消任务
        } catch (ExecutionException e) {
            // 任务执行期间发生异常
            System.out.println("任务执行失败: " + e.getCause());
        } catch (InterruptedException e) {
            // 当前线程被中断
            System.out.println("等待任务完成期间当前线程被中断");
        } finally {
            System.out.println("关闭ExecutorService");
            // 关闭ExecutorService
            executor.shutdownNow(); // 强制关闭，尝试中断所有正在执行的任务
        }

        // 检查任务是否被成功取消
        if (future.isCancelled()) {
            System.out.println("任务已被取消");
        } else {
            System.out.println("任务仍在运行");
        }
    }
}
```

#### 执行结果

```
任务正在运行...
任务正在运行...
任务正在运行...
任务正在运行...
任务正在运行...
任务超时，尝试取消...
任务被中断信号捕获，但忽略它
关闭ExecutorService
任务已被取消
```
#### 2.1 线程中断实例1
```java
import java.util.concurrent.*;

public class UninterruptibleTaskExample {
    public static void main(String[] args) {
        // 创建一个ExecutorService
        ExecutorService executor = Executors.newSingleThreadExecutor();

        // 创建一个任务，不会响应中断
        Runnable task = () -> {
            while (true) {
                try {
                    // 模拟一些工作，忽略中断
                    System.out.println("任务正在运行...");
                    // 使用较短的sleep时间以便快速输出日志
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                    // 捕获InterruptedException但忽略它
                    System.out.println("任务被中断信号捕获，但忽略它");
                }
            }
        };

        // 提交任务并获取Future对象
        Future<?> future = executor.submit(task);

        try {
            // 等待任务完成，最多等待5秒
            future.get(5, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            // 超时异常
            System.out.println("任务超时，尝试取消...");
            future.cancel(true); // 尝试取消任务
        } catch (ExecutionException e) {
            // 任务执行期间发生异常
            System.out.println("任务执行失败: " + e.getCause());
        } catch (InterruptedException e) {
            // 当前线程被中断
            System.out.println("等待任务完成期间当前线程被中断");
        } finally {
            System.out.println("关闭ExecutorService");
            // 关闭ExecutorService
            executor.shutdownNow(); // 强制关闭，尝试中断所有正在执行的任务
        }

        // 检查任务是否被成功取消
        if (future.isCancelled()) {
            System.out.println("任务已被取消");
        } else {
            System.out.println("任务仍在运行");
        }

        // 检查任务是否仍在运行
        try {
            // 主线程等待一段时间以观察任务是否仍在运行
            Thread.sleep(6000);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }
}
```
#### 执行结果
```
任务正在运行...
任务正在运行...
任务正在运行...
任务正在运行...
任务正在运行...
任务超时，尝试取消...
任务被中断信号捕获，但忽略它
任务正在运行...
关闭ExecutorService
任务被中断信号捕获，但忽略它
任务正在运行...
任务已被取消
任务正在运行...
任务正在运行...
任务正在运行...
任务正在运行...
```



