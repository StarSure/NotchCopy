# 参与开发

使用 Swift 6 / Xcode 16+。提交前执行：

```sh
swift test
Scripts/build.sh
```

涉及架构支持或打包时再执行 `Scripts/build.sh --universal`。CI 会运行测试并构建双架构应用。

请将修改限制在文案工作流，并保留默认隐藏、收起时点击穿透、正常跨屏移动、本机数据兼容和原有许可证。新行为应包含边界或回归测试，不用测试复刻视图布局。

界面变更请附上使用示例数据的截图，避免上传个人文案、数据目录、日志或凭据。使用 `dist/NotchCopy.app/Contents/MacOS/NotchCopy --demo --show` 启动截图模式。

问题报告建议包含 macOS 版本、芯片类型、是否有物理刘海、显示器排列和复现步骤。不要提交真实文案文件；使用脱敏的最小示例。
