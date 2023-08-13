---
title: JAVA SPI机制详解
date: 2023-03-13 21:59:14
updated: 2023-03-13 21:59:14
tags:
categories:
comments:
---

## 什么是Java SPI

SPI（Service Provider Interface）机制是Java提供的一种服务发现机制，它允许第三方为某个接口创建实现，并将实现放在classpath下的META-INF/services目录中，由接口的提供方在运行时动态加载实现。
<!-- more -->
SPI机制的实现步骤如下：

1. 定义接口：首先需要定义一个接口，该接口的实现类将会被动态加载。

2. 创建实现类：然后需要创建实现该接口的类，该类需要实现该接口的所有方法。

3. 创建服务配置文件：在resources目录下创建/META-INF/services/接口全限定名的文件，文件中填写实现类的全限定名。

4. 加载实现类：在运行时，通过ServiceLoader.load(接口类型)方法加载实现类。

5. 调用实现类：通过迭代器遍历获取到的实现类，调用实现类的方法。

示例代码如下：

1. 定义服务接口

首先需要定义一个服务接口，该接口定义了一组服务接口方法，例如：

```java
public interface MyService {
    void doSomething();
}
```

2.创建服务提供者

接下来需要创建一个或多个服务提供者，实现上述服务接口，例如：

```java
public class MyServiceImpl1 implements MyService {
    public void doSomething() {
        System.out.println("MyServiceImpl1 doSomething");
    }
}

public class MyServiceImpl2 implements MyService {
    public void doSomething() {
        System.out.println("MyServiceImpl2 doSomething");
    }
}
```

3.创建服务提供者配置文件

在classpath下创建一个名为 `META-INF/services` 的目录，在该目录下创建一个以服务接口全限定名为文件名的文件，例如：`META-INF/services/com.example.MyService`，文件内容为服务提供者的全限定名，例如：

```java
com.example.MyServiceImpl1
com.example.MyServiceImpl2
```

4.加载服务提供者

使用 `ServiceLoader` 类加载服务提供者，例如：

```java
ServiceLoader<MyService> loader = ServiceLoader.load(MyService.class);
```

5.使用服务提供者

使用 `ServiceLoader` 类的 `iterator()` 方法获取服务提供者的迭代器，然后遍历迭代器获取服务提供者的实例，例如：

```java
for (MyService myService : loader) {
    myService.doSomething();
}
```

上述代码会依次输出：

```java
MyServiceImpl1 doSomething
MyServiceImpl2 doSomething
```

说明两个服务提供者都被成功加载并执行。

需要注意的是，SPI机制要求服务接口和服务提供者实现类都必须是公共的，并且服务提供者的实现类必须有一个无参构造函数。

## JDK中的SPI使用

JDK中有很多地方使用了SPI，以下是一些例子：

1. JDBC驱动：JDBC规范定义了一种SPI机制，允许开发人员编写自己的JDBC驱动程序。JDBC驱动程序必须实现java.sql.Driver接口，同时还需要在META-INF/services目录下提供一个名为java.sql.Driver的文件，文件内容为该驱动程序的实现类名。

2. 日志框架：JDK自带的日志框架java.util.logging也使用了SPI机制。开发人员可以通过实现java.util.logging.Handler接口来自定义日志输出方式，然后在META-INF/services目录下提供一个名为java.util.logging.Handler的文件，文件内容为该自定义Handler的实现类名。

3. XML解析器：JDK自带的XML解析器javax.xml.parsers.DocumentBuilderFactory也使用了SPI机制。开发人员可以通过实现javax.xml.parsers.DocumentBuilderFactory接口来自定义XML解析器，然后在META-INF/services目录下提供一个名为javax.xml.parsers.DocumentBuilderFactory的文件，文件内容为该自定义解析器的实现类名。

4. Servlet容器：Servlet规范也定义了一种SPI机制，允许开发人员编写自己的Servlet容器。开发人员可以通过实现javax.servlet.ServletContainerInitializer接口来自定义Servlet容器，然后在META-INF/services目录下提供一个名为javax.servlet.ServletContainerInitializer的文件，文件内容为该自定义容器的实现类名。

5. Java NIO中的SelectorProvider：SelectorProvider是一个抽象类，用于提供Selector的实现。在Java NIO中，可以通过SelectorProvider.provider()方法获取系统默认的SelectorProvider实例。不同的操作系统平台会提供不同的SelectorProvider实现，因此SelectorProvider的具体实现类是通过SPI机制加载的。

## JAVA SPI的底层实现原理

在JDK中，Java SPI的实现方式主要是通过`ServiceLoader`类实现的。它是一个用于加载服务实现类的工具类，它的实现方式主要包括以下几个方面：

1. 根据接口名称从META-INF/services目录下加载配置文件。

2. 解析配置文件，获取实现类的全限定名。

3. 使用反射机制创建实现类的实例。

4. 将实例缓存起来，避免重复创建。

下面我们来详细介绍一下这个实现方式：

1. 根据接口名称从META-INF/services目录下加载配置文件。

在Java SPI机制中，每个服务提供者都必须提供一个配置文件，该配置文件的名称为“接口全限定名”，位于META-INF/services目录下。例如，如果我们要使用JDBC的Driver接口，那么对应的配置文件就是META-INF/services/java.sql.Driver。

2.解析配置文件，获取实现类的全限定名。

在解析配置文件时，ServiceLoader类会读取该文件的每一行，每行内容为一个实现类的全限定名。例如，如果我们要使用JDBC的Driver接口，那么对应的配置文件内容可能如下所示：

```java
com.mysql.jdbc.Driver
org.postgresql.Driver
```

3.使用反射机制创建实现类的实例。

在获取到实现类的全限定名后，ServiceLoader类会使用反射机制创建该实现类的实例。

4.将实例缓存起来，避免重复创建。

为了避免重复创建实例，ServiceLoader类会将创建的实例缓存起来，下次再需要该实例时，直接返回缓存中的实例。

总的来说，Java SPI机制的实现方式比较简单，主要是通过配置文件和反射机制来实现的。它的优点是可以动态替换实现类，缺点是无法对实现类进行版本管理。
