# DeepSeek Harness Lulu 主题一键安装包

从 GitHub `Code -> Download ZIP` 下载并解压后，双击：

```text
Install-and-start-DeepSeekHarness.cmd
```

目标电脑不需要预先安装 DeepSeek Harness、Node.js、Git 或 pnpm，也不需要寻找程序目录。安装器会联网下载经过校验的便携 Node.js、固定版本 DeepSeek Harness 和 WebView2 启动依赖，随后安装 Lulu 主题、创建桌面快捷方式并启动。

默认安装位置：

```text
D:\DeepSeekHarness
```

如果电脑没有 D 盘，则自动安装到：

```text
%LOCALAPPDATA%\DeepSeekHarness
```

安装器支持重复运行。已下载并安装成功的组件不会重复下载。也可以从 PowerShell 指定位置：

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install-to-harness.ps1 -InstallRoot 'E:\DeepSeekHarness'
```

安装需要 Windows 10/11 x64、可用网络和约 2 GB 可用磁盘空间。首次启动后进入“设置 -> 模型”配置自己的模型提供方。安装包不会收集或上传 API Key、凭据、会话、日志、工作区、附件或自定义主题。

主题插件源文件位于 `profile-template/web/plugins/dsh-theme-lulu`。主题保持动态模式，并包含手机连接入口。
