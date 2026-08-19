# Lulu Theme for DeepSeek Harness

一个适用于 DeepSeek Harness / DSH Web 的 Cordis 主题插件。它会在 Harness 页面中加入一个永久主题库，支持内置渐变主题、自定义图片主题、自定义视频主题、透明度/虚化/曝光/亮度/对比度/饱和度/缩放/动画速度等参数调节。

## 功能

- 内置 10 套可直接使用的主题背景。
- 支持上传 PNG、JPEG、WebP、GIF、MP4、WebM 作为永久主题。
- 图片和视频保留原始文件，不压缩。
- 支持视频循环播放、静音/音量控制、预览封面。
- 自动提取媒体主色，并同步到 Harness 的品牌色和按钮色。
- 支持跨窗口共享当前主题状态。
- 支持删除内置主题入口和自定义主题文件。
- 通过 Cordis `webServer` 服务注入脚本，无需修改 Harness 前端源码。

## 安装

> 这个插件面向 DeepSeek Harness 的 Cordis 运行环境。你需要能编辑自己的 Harness composition / preset，并能安装本 npm 包或本地路径。

### 方式一:从 GitHub 安装

```bash
npm install github:<your-github-user>/dsh-lulu-theme-plugin
```

然后在你的 Cordis composition 中加入插件包，例如:

```yaml
plugins:
  - package: dsh-theme-lulu
```

具体字段名可能取决于你当前 Harness 的 composition 写法；核心是加载 npm 包 `dsh-theme-lulu` 暴露的 Cordis 插件。

### 方式二:本地开发安装

```bash
git clone https://github.com/<your-github-user>/dsh-lulu-theme-plugin.git
cd dsh-lulu-theme-plugin
npm install
npm link
```

再在 Harness 的 composition 中加载这个本地包。

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

## 开发

项目结构:

```text
lib/index.js          Cordis Host 插件入口
lib/desktop-theme.js  浏览器主题 UI 和样式注入脚本
package.json          npm 包信息
README.md             使用说明
LICENSE               MIT 许可证
```

`lib/index.js` 负责注册 HTTP 路由和注入脚本。`lib/desktop-theme.js` 运行在浏览器端，负责主题面板、背景媒体、参数调节和页面样式覆盖。

## 发布到 GitHub

```bash
git init
git add .
git commit -m "Initial Lulu theme plugin"
gh repo create dsh-lulu-theme-plugin --public --source=. --remote=origin --push
```

如果没有 GitHub CLI，也可以先创建一个公开仓库，再执行:

```bash
git remote add origin https://github.com/<your-github-user>/dsh-lulu-theme-plugin.git
git branch -M main
git push -u origin main
```

## License

MIT
