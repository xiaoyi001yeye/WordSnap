# WordSnap

`WordSnap` 是一个 Flutter 学习应用 MVP，围绕“拍照识词 -> 生成考试 -> 完成考试 -> 记忆分析 -> 错题巩固”闭环设计。

## 当前已完成
- 引导页、主导航壳层、首页/学习/单词本/统计四个主页面
- 拍照识别流程 MVP：已接通系统相机和相册入口，并支持多个识别场景预设
- 识别结果筛选：可勾选本次参与考试的单词
- 考试设置：支持按本次识别、默认词本、复习队列三种范围出题
- 答题闭环：完成考试后会生成成绩、分析和错题详情
- 本地学习状态：识别记录、考试历史、收藏词、复习队列已通过 `shared_preferences` 持久化
- 统一主题、设置持久化、响应式和兼容导航能力

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

项目现在已经包含 `ios/` 和 `android/` 平台工程。装好 Flutter 后，可以在项目根目录执行：

```bash
flutter pub get
flutter run
```

## GitHub 构建 APK

项目已经补上 GitHub Actions APK 构建工作流：

- [.github/workflows/build-apk.yml](/Users/wyn/code/WordSnap/.github/workflows/build-apk.yml)

触发方式：

- 手动触发 `Build APK`
- 推送到 `main` / `master`
- 推送版本标签 `v0.1.0` 这类标签

说明：

- 由于当前仓库还没有提交 Flutter 平台工程，CI 会先执行 `flutter create --platforms=android .` 自动补齐 Android 工程
- CI 使用 `flutter build apk --release` 直接生成一个通用安装包 `wordsnap-release.apk`
- `main` / `master` 和手动构建会同时保留 Actions Artifact，并把 `wordsnap-release.apk` 直接更新到 `WordSnap Latest Installers` 预发布页；Release Assets 里的安装包是独立文件，不需要先下载 zip 再解压
- 如果是 `v*` 标签触发，还会自动创建 GitHub Release 并附上 `wordsnap-release.apk`

## GitHub 构建 macOS DMG

项目也已经补上 GitHub Actions macOS DMG 构建工作流：

- [.github/workflows/build-macos-dmg.yml](/Users/wyn/code/WordSnap/.github/workflows/build-macos-dmg.yml)

触发方式：

- 手动触发 `Build WordSnap macOS DMG`
- 推送到 `main` / `master`

说明：

- 如果仓库里还没有 `macos/` 平台工程，CI 会先执行 `flutter create --platforms=macos .` 自动补齐
- 每次非 PR 构建都会同时保留 Actions Artifact，并把 DMG 直接更新到 `WordSnap Latest Installers` 预发布页；Release Assets 里的安装包是独立文件，不需要先下载 zip 再解压
- macOS 桌面版当前支持“相册导入”测试主流程，`拍照` 按钮会在桌面端自动降级禁用
