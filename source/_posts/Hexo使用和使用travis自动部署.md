---
title: Hexo使用和使用travis自动部署
date: 2020-05-23 20:20:54
tags: 
    - hexo
    - travis
categories:
    - [blog, hexo]
---

# 序言
本文没有太过于详细的Hexo及Travis的教程，主要记录一些笔者在用Hexo在GitHub上搭Blog，并使 用Travis自动部署博客过程中的一些记录点和踩的坑，主要还是偏个人为主，末尾会放出搭建博客过程中参考的一些Blog，写的都挺详细，就不用我再赘述了。
<!-- more -->
# 问题及解决办法
先写遇到的问题及解决方法吧！

## 运行hexo d报错
出现`TypeError [ERR_INVALID_ARG_TYPE]: The "mode" argument must be integer. Received an instance of Object`,很可能就是node_js版本问题，注意替换版本就可以了，一般使用lts,这里推荐`nvm`,是一个node_js的开发环境控制工具;

## 运行hexo相关命令失败
按照报错提示运行`npm install --save`，任然失败，报错为linux软连接失败等相关信息，是因为我的hexo文件夹实在win10下初始化的，然后通过共享文件夹到本机manjaro开发机上进行同步撰写博客，没找到具体原因，猜测大概为底层文件系统原因，最终我的解决方法是在win10 hexo根目录下执行修复命令`npm install --save`，然后就都恢复了……

## 使用yelee主题时,网站在子目录下链接地址错乱
解决方法:在<https://github.com/MOxFIVE/hexo-theme-yelee>项目下的Issues中有解决 [Issues#171](https://github.com/MOxFIVE/hexo-theme-yelee/issues/171#issuecomment-357471735)

Some suggestions:

To fix "Tags" and "About me", change `layout/_partial/left-col.ejs`, line 73:
```javascript
- <li><a href="<%- theme.root_url %><%- url_for(theme.menu[i]) %>"><%= i %></a></li>
+ <li><a href="<%- url_for(theme.menu[i]) %>"><%= i %></a></li>
```
To fix floating homepage buttons on the left side of the posts, change `layout/_partial/post-nav-button.ejs`, line 9 and 19:
```javascript
- <a href="/" title="<%= __('tooltip.back2home') %>"><i class="fa fa-home"></i></a>
+ <a href="<%- url_for('/') %>" title="<%= __('tooltip.back2home') %>"><i class="fa fa-home"></i></a>
```
To fix the "Author" link in the copyright section, change `layout/_partial/post/nav.ejs`, line 4:
```javascript
- <p><span><%= __('copyright_info.author') %>:</span><a href="/" title="<%= __('tooltip.back2home') %>"><%=theme.author%></a></p>
+ <p><span><%= __('copyright_info.author') %>:</span><a href="<%- url_for('/') %>" title="<%= __('tooltip.back2home') %>"><%=theme.author%></a></p>
```
The reason is that the function url_for() has already taken care of the root directory. Read more: <https://hexo.io/docs/helpers.html#url-for>

I've so far encountered those errors, but if there are other errors the solutions will be similar. Hope the author's gonna fix it soon.

