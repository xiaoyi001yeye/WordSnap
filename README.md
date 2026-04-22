# WordSnap

`WordSnap` 是一个新的 Flutter 原型项目，用来把 `../Swiftick/WordFlow` 里成熟的程序架构迁移到“拍照识词 -> 生成考试 -> 结果分析 -> 巩固复习”的业务里。

## 这次迁移了什么

- 启动初始化流程：先初始化本地设置，再决定进入引导页还是主应用壳层
- 主题与系统 UI 统一管理：抽离到 `AppTheme`
- 服务层与页面层分离：`AppSettingsService` 负责持久化，`WordSnapDemoService` 负责演示业务数据
- 响应式工具：抽离 `ResponsiveHelper`
- 兼容导航：抽离 `CompatibleNavigator` / `CompatiblePageRoute`
- 基于截图补了一套完整的演示流：识别、出题、考试、成绩、分析、错题页

## 目录结构

```text
lib/
  app/
    app_initializer.dart
    word_snap_app.dart
  core/
    layout/responsive_helper.dart
    navigation/compatible_page_route.dart
    storage/app_settings_service.dart
    theme/app_theme.dart
  features/
    onboarding/onboarding_page.dart
    shell/word_snap_shell.dart
    study/study_flow_pages.dart
    study/study_models.dart
    study/word_snap_demo_service.dart
```

## 运行说明

当前工作环境里没有安装 `flutter` 命令，所以这次我完成了项目源码和架构迁移，但没法在本机直接执行构建验证。

在你本地装好 Flutter 后，可以在项目根目录执行：

```bash
flutter create .
flutter pub get
flutter run
```

`flutter create .` 的作用是补齐 Android / iOS / macOS 等平台工程文件。现有 `lib/`、`pubspec.yaml` 和文档会保留。

## GitHub 构建 APK

项目已经补上了与 `WordFlow` 对齐的 GitHub Actions 工作流：

- `.github/workflows/build-and-release.yml`

触发方式：

- 手动触发 `Build and Release`
- 推送版本标签 `v0.1.0` 这类标签

说明：

- 由于当前仓库还没有提交 Flutter 平台工程，CI 会先执行 `flutter create --platforms=android .` 自动补齐 Android 工程
- 每次执行都会上传 `wordsnap-release-apk` artifact
- 如果是 `v*.*.*` 标签触发，还会自动创建 GitHub Release 并附上 `wordsnap-release.apk`
- 如果仓库配置了签名相关 secrets，工作流会自动使用正式签名；否则按默认 release 构建流程产出 APK
