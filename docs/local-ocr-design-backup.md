# 本地 OCR 方案备份设计

## 目的

这份文档用于保存 `WordSnap` 之前的本地 OCR 方案关键逻辑，方便未来在需要离线识别时恢复。

当前主链路已经切到火山引擎方舟，不再使用下面这套运行时代码。

## 旧方案概览

旧方案采用“Flutter + 平台原生 OCR”：

- Android：ML Kit 文本识别
- iOS：Vision `VNRecognizeTextRequest`
- Flutter：`MethodChannel` 统一桥接结果

旧链路目标：

1. 用户拍照或从相册导入图片
2. 原生侧读取图片并做 OCR
3. Flutter 侧接收文本行、置信度、引擎标识
4. 应用进一步抽取英文单词、音标和词书条目

## 旧方案关键文件

Android：

- `android/app/src/main/kotlin/com/example/wordsnap/MainActivity.kt`
- `android/app/build.gradle.kts`

iOS：

- `ios/Runner/SceneDelegate.swift`

Flutter：

- `lib/features/study/native_ocr_service.dart`
- `lib/features/study/word_snap_demo_service.dart`
- `lib/features/study/study_flow_pages.dart`

## 旧方案的数据结构

旧实现里 Flutter 侧大致维护这些结构：

- `NativeOcrLine`
  - 原始文本行
  - 置信度
- `NativeOcrWord`
  - 单词原文
  - 归一化单词
  - 置信度
- `NativeOcrEntry`
  - 词条单词
  - 音标
  - 中文释义/词性
  - 原始来源文本

其中最关键的恢复点是：

- 先拿到原始文本行
- 再做词条归并，而不是只抽单个 token

## Android 旧实现摘要

Android 侧用 ML Kit 中文识别器：

- `ChineseTextRecognizerOptions`
- 从 `textBlocks -> lines` 提取文本
- 每行返回 `text` 和 `score`

旧实现优点：

- 端侧离线
- 响应快
- 不依赖网络

旧实现问题：

- 词书条目中间间距大时，容易把一条条目拆散
- 需要单独维护 Android 原生代码

## iOS 旧实现摘要

iOS 侧用 Vision：

- `VNRecognizeTextRequest`
- `.accurate`
- `recognitionLanguages = ["zh-Hans", "en-US"]`
- `automaticallyDetectsLanguage = true`

旧实现优点：

- 无额外云成本
- 原生集成自然

旧实现问题：

- 与 Android 结果一致性需要额外校准
- 仍然要维护平台桥接

## Flutter 旧实现摘要

Flutter 侧做了两层处理：

1. OCR 原始结果解析
2. 词条与单词提取

重点规则包括：

- 正则抽取音标
- 识别包含中文的文本行
- 尝试把连续 1 到 3 行合并为一条词书条目
- 当整条词条解析失败时，再回退到英文 token 抽取

这个“整条词条优先，token 回退”的思路，是以后如果重做本地方案时最值得保留的部分。

## 为什么先下线

这套方案虽然能离线，但当前阶段存在几个问题：

- Android / iOS 双端维护成本高
- 平台差异会带来结果不一致
- Flutter 与原生桥接会增加包体和工程复杂度
- 词书场景更适合直接让视觉模型做结构化理解

## 如果以后要恢复

推荐恢复顺序：

1. 先恢复 Flutter 侧的条目归并与后处理逻辑
2. 再恢复 Android ML Kit 识别
3. 再恢复 iOS Vision 识别
4. 最后统一调试两端返回格式

恢复时重点检查：

- `MethodChannel` 名称和消息格式
- Android NDK / ML Kit 依赖版本
- iOS SceneDelegate 中的 OCR 请求配置
- 词条归并规则是否仍适合当前 UI

## 结论

本地 OCR 方案并没有被否定，它更像是一个“离线备份方向”：

- 当我们优先要产品速度和条目理解质量时，先用火山引擎
- 当我们未来更看重离线能力和隐私时，可以按这份文档把本地方案重新接回来
