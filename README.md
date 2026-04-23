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
- 推送版本标签 `v0.1.0` 这类标签

说明：

- 由于当前仓库还没有提交 Flutter 平台工程，CI 会先执行 `flutter create --platforms=android .` 自动补齐 Android 工程
- 每次执行都会上传 `wordsnap-release-apk` artifact
- 如果是 `v*` 标签触发，还会自动创建 GitHub Release 并附上 APK
