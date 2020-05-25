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

## github图标显示问题
Step 1: 首先下载一个GitHub图标，放在/yelee/source/img/目录下，命名为GitHub.png，注意是GitHub，而不是Github和github；

Step 2: 接下来删除在`/yelee/source/css/_partial/customise/social-icon.styl`的46-50行，然后在`img-logo` = 添加`GitHub white 100`。

GitHub white 100 的意思是github添加白色背景且透明度为100，背景可以自行选择

# Travis相关
## 注册Travis
使用github账户登陆即可
## 相关设置
设置监控哪一个仓库
设置github的token,并选为不可见,避免安全风险
## 最后给出我的.travis.yml文件
两个都生效,第一个是网上收集的,但我用的是第二个,Hexo官网上的
### 第一份
```yaml
language: node_js   #设置语言
node_js: stable     #设置相应的版本
cache:
    directories:
        - node_modules    #据说可以减少travis构建时间
# before_install:
#   - npm install -g hexo
#   - npm install -g hexo-cli
install:
  - npm install   #安装hexo及插件
# before_script:
#   - npm install -g mocha
#   - git clone --branch master https://github.com/Longxr/Longxr.github.io.git public
script:
  - hexo cl   #清除
  - hexo g   #生成
after_script:
  - cd ./public
  - git init
  - git config user.name "XXX"   #修改成自己的github用户名
  - git config user.email "XXX@XXX.com"   #修改成自己的GitHub邮箱 GH-PAGES-TOCKEN
  - git add .
  - git commit -m "update by Travis-CI"
  - git push --force --quiet "https://${GH_token}@${GH_REF}" master:gh-pages #GH_token就是在travis中设置的token
branches:
  only:
  - master #只监测这个分支，一有动静就开始构建
env:
    global:
        - GH_REF: github.com/XXX/blog.git
```
### 第二份
```yaml
sudo: false
language: node_js
node_js: stable  # use nodejs v10 LTS
cache: npm
branches:
  only:
    - master # build master branch only
script:
  - hexo generate # generate static files
deploy:
  provider: pages
  skip-cleanup: true
  github-token: $ghtoken
  keep-history: true
  on:
    branch: master
  local-dir: public
```
# 我的博客仓库
如有疑问可以访问查看源码:[BLOG](https://github.com/panxt/blog)  
# 相关参考
[Hexo博客系列（二）：安装和配置 | Setsuna's Blog](http://www.isetsuna.com/hexo/install-config/)  
[hexo - 学渣的成长之路 - 博客园](https://www.cnblogs.com/alex21/p/5376578.html)  
[Hexo博客+Next主题深度优化与定制 - Sanarous的博客](https://bestzuo.cn/posts/blog-establish.html)  
[使用Travis CI自动部署Hexo博客 | Ritboy's Blog](https://blog.ritboy.com/articles/4283262726.html)  
[Hexo使用Travis CI自动化部署 | Longxr's blog](https://longxuan.ren/2017/05/10/Hexo-Travis-CI/)  
[将 Hexo 部署到 GitHub Pages | Hexo](https://hexo.io/zh-cn/docs/github-pages)  
