# DeepSeek Harness Lulu Theme Plugin

一个给 DeepSeek Harness / DSH Web 使用的主题插件。安装后，打开 DeepSeek Harness 页面会自动出现 `切换主题` 按钮，内置永久主题库，支持自定义图片和视频主题。

## 用户最快使用方式

### 方式一:下载已封装好的 DeepSeek Harness 包

如果仓库 Releases 页面提供了 `DeepSeek-Harness-*-Lulu-Theme.zip`:

1. 下载 zip。
2. 解压。
3. 双击启动 DeepSeek Harness。
4. 打开 Harness 页面后，右上角会自动出现 `切换主题`。

这种方式不需要手动安装插件，主题插件已经封装在 Harness 的 `profile-template/web` 中。

### 方式二:安装到你已有的原生 DeepSeek Harness

下载本仓库后，在 PowerShell 里运行:

```powershell
cd DeepseekHarness-Theme-Plugin
.\install-to-harness.ps1 -HarnessRoot "D:\path\to\DeepSeek-Harness-Chrome-Portable"
```

把 `D:\path\to\DeepSeek-Harness-Chrome-Portable` 换成你的 DeepSeek Harness 根目录。这个目录下面应该能看到:

```text
app/
profile-template/
launcher/
runtime/
```

脚本会自动完成两件事:

- 复制主题插件到 `profile-template/web/plugins/dsh-theme-lulu`。
- 在 `profile-template/web/cordis.patch.yml` 中追加默认挂载项。

安装后启动 DeepSeek Harness，主题会自动加载。

## 已封装的 Harness profile 配置

本仓库包含一个可覆盖到 DeepSeek Harness 的 profile overlay:

```text
portable-overlay/profile-template/web/plugins/dsh-theme-lulu/
portable-overlay/profile-template/web/cordis.patch.append.yml
```

核心 Cordis 挂载配置是:

```yaml
- insert:
    - id: lulu-theme
      name: './plugins/dsh-theme-lulu/lib/index.js'
```

这表示插件作为 Host 端 Cordis 插件随 Harness Web profile 启动，不需要用户进入插件市场手动安装。

## 功能

- 内置 10 套可直接使用的主题背景。
- 支持上传 PNG、JPEG、WebP、GIF、MP4、WebM 作为永久主题。
- 图片和视频保留原始文件，不压缩。
- 支持视频循环播放、静音/音量控制、预览封面。
- 自动提取媒体主色，并同步到 Harness 的品牌色和按钮色。
- 支持跨窗口共享当前主题状态。
- 支持删除内置主题入口和自定义主题文件。
- 通过 Cordis `webServer` 服务注入脚本，无需修改 Harness 前端源码。

## 使用

启动 DeepSeek Harness 后，页面右上角会出现 `切换主题` 按钮。

打开面板后可以:

- 切换内置主题。
- 添加本地图片或视频作为主题。
- 调整透明度、虚化、曝光、亮度、对比度、饱和度、缩放、动画速度、视频音量。
- 删除不需要的主题。
- 将自定义图片加入当前对话输入区。

## 存储位置

插件默认使用以下目录保存数据:

```text
${DSH_HOME}/custom-themes
${DSH_HOME}/theme-state.json
```

如果没有设置 `DSH_HOME`，则使用当前进程工作目录下的 `data` 目录:

```text
./data/custom-themes
./data/theme-state.json
```

自定义图片和视频会保存在 `custom-themes` 中，主题状态保存在 `theme-state.json` 中。

## 路由

插件注册以下 HTTP 路由:

- `GET /lulu-theme.js`:浏览器主题脚本。
- `GET /lulu-assets/:index`:内置主题背景。
- `GET /lulu-custom-themes`:列出自定义主题。
- `POST /lulu-custom-themes`:上传自定义主题。
- `DELETE /lulu-custom-themes`:删除自定义主题，需要 `x-lulu-theme-id` header。
- `GET /lulu-custom-assets/:file`:读取自定义主题文件，支持视频 Range 请求。
- `GET /lulu-theme-state`:读取共享主题状态。
- `PUT /lulu-theme-state`:保存共享主题状态。

## 安全和限制

- 上传文件最大 200 MiB。
- 只允许 `image/png`、`image/jpeg`、`image/webp`、`image/gif`、`video/mp4`、`video/webm`。
- 自定义主题文件只在本地 Harness 数据目录中保存，不会自动上传到第三方服务。
- 插件会向 Harness 页面注入浏览器脚本，并修改页面样式变量。升级 Harness 后如果 DOM 结构大改，部分 UI 适配可能需要调整。

## 开发者安装

如果你只想把它作为普通 Cordis 插件开发使用，可以加载 npm 包入口:

```yaml
- id: lulu-theme
  name: './plugins/dsh-theme-lulu/lib/index.js'
```

项目结构:

```text
lib/index.js                                      Cordis Host 插件入口
lib/desktop-theme.js                              浏览器主题 UI 和样式注入脚本
install-to-harness.ps1                            安装到现有 Harness 的脚本
portable-overlay/profile-template/web/...         可直接叠加到 Harness profile 的覆盖层
package.json                                      npm 包信息
README.md                                         使用说明
LICENSE                                           MIT 许可证
```

## License

MIT
