# 照片选区工具设计文档

## 1. 文档目的

本文档描述 WordSnap 当前照片选区工具的操作逻辑，覆盖用户如何选择照片、如何调整识别区域、选区数据如何保存和换算，以及开始识别时选区如何影响图片预处理与 OCR 输入。

本文基于当前代码实现整理，主要对应：

- `lib/features/study/study_flow_pages.dart`
- `lib/features/study/native_image_processing_service.dart`
- `android/app/src/main/kotlin/com/example/wordsnap/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`

当前照片选区工具不是独立路由，而是嵌入在“拍照识别”流程中的图片预览与框选组件。

## 2. 使用场景

照片选区工具用于在拍照或相册导入后，让用户框定需要 OCR 的图片区域。

典型目标是：

- 排除教材、试卷、屏幕截图中的无关区域
- 减少上传图片体积
- 降低 OCR 识别干扰
- 在移动端优先使用原生图片处理能力完成裁切、缩放和压缩

工具当前服务于“开始识别”按钮之前的准备阶段。用户完成框选后，不需要额外保存；点击“开始识别”时，当前选区会作为识别输入的一部分即时生效。

## 3. 用户流程

### 3.1 进入拍照识别页

用户进入 `RecognitionDemoPage` 后，页面显示“采集方式”区域。

当前支持两种采集方式：

1. 拍照
2. 相册导入

移动端支持直接拉起系统相机；非 Android/iOS 平台默认使用相册导入，并在尝试拍照时提示桌面版暂不支持直接拍照。

### 3.2 选择图片

用户点击“拍照”或“相册导入”后，页面通过 `image_picker` 打开系统相机或相册。

选择图片时会传入以下约束：

- `imageQuality: 92`
- `maxWidth: 2400`
- `maxHeight: 2400`

图片选择完成后：

- `_selectedImagePath` 保存图片路径
- `_recognitionSelection` 重置为默认选区
- 选区组件显示在页面中

默认选区为：

```dart
Rect.fromLTWH(0.14, 0.12, 0.72, 0.76)
```

含义是：

- 左边距为图片宽度的 14%
- 上边距为图片高度的 12%
- 选区宽度为图片宽度的 72%
- 选区高度为图片高度的 76%

如果用户取消选择，会显示“没有选择图片”的提示。如果系统相机或相册打开失败，会提示检查权限后重试。

### 3.3 Android 图片选择恢复

页面初始化时会调用 `retrieveLostData()` 尝试恢复上次未完成的图片选择。

如果恢复到图片：

- 使用恢复到的第一张图片作为当前图片
- 选区重置为默认选区
- 清空图片选择错误

如果没有恢复到可用图片，会显示恢复失败提示。

### 3.4 清除图片

用户点击“清除图片”后：

- 当前图片路径清空
- 选区恢复默认值
- 图片选择错误清空
- 识别错误清空
- 采集方式根据平台恢复默认值

移动端默认回到“拍照”，非移动端默认回到“相册导入”。

## 4. 选区组件结构

照片选区由 `_RecognitionImageSelector` 负责渲染和交互。

组件输入：

- `imagePath`：当前图片路径
- `selection`：当前选区，使用归一化坐标
- `onSelectionChanged`：选区变化回调
- `onOpenFullscreen`：查看大图回调

内部常量：

```dart
static const double _minSelectionSize = 0.16;
static const double _handleSize = 22;
```

含义：

- 最小选区宽高均为图片尺寸的 16%
- 四角拖拽点尺寸为 22 logical pixels

组件会缓存每个图片路径对应的尺寸读取任务，避免同一图片重复解码获取尺寸。

## 5. 预览布局逻辑

选区组件首先检查图片文件是否仍然存在。如果文件不存在，组件显示“图片文件已不存在，请重新拍照或重新导入。”

如果图片存在，组件会：

1. 读取图片真实尺寸
2. 根据组件宽度计算预览高度
3. 使用 `BoxFit.contain` 计算图片在预览区域中的实际显示矩形
4. 将归一化选区映射到预览坐标
5. 在图片上绘制遮罩、虚线选区框和四角拖拽点

预览高度计算规则：

```dart
previewHeight = clamp(previewWidth * 0.68, 280.0, 420.0)
```

因此：

- 窄屏时预览高度不低于 280
- 宽屏时预览高度不超过 420
- 中间尺寸按宽度的 68% 计算

图片显示使用 `Image.file(imageFile, fit: BoxFit.contain)`。由于 `BoxFit.contain` 可能产生上下或左右留白，选区计算只针对真实图片显示区域，不针对整个预览容器。

真实图片显示区域通过 `applyBoxFit(BoxFit.contain, imageSize, previewSize)` 计算。

## 6. 选区坐标模型

当前选区使用归一化矩形 `Rect` 表示。

坐标范围：

- `left`: 0.0 到 1.0
- `top`: 0.0 到 1.0
- `right`: 0.0 到 1.0
- `bottom`: 0.0 到 1.0

选区坐标始终相对于原图，而不是相对于预览容器。

示例：

```dart
Rect.fromLTWH(0.14, 0.12, 0.72, 0.76)
```

表示选区覆盖原图中间偏大的区域，无论图片在当前屏幕上被缩放到多大，选区语义都保持不变。

归一化选区映射到预览坐标时使用：

```dart
Rect.fromLTWH(
  imageRect.left + selection.left * imageRect.width,
  imageRect.top + selection.top * imageRect.height,
  selection.width * imageRect.width,
  selection.height * imageRect.height,
)
```

这个映射保证了：

- 图片有留白时，选区不会漂移到留白区域
- 预览尺寸变化时，选区仍然覆盖原图中的同一比例区域
- 裁切阶段可以直接使用归一化坐标换算原图像素区域

## 7. 操作逻辑

### 7.1 移动选区

用户拖拽选区框内部区域时，触发 `_moveSelection()`。

移动步骤：

1. 将手势位移 `delta` 从预览像素换算为图片归一化比例
2. 将新的 `left` 限制在 `0.0` 到 `1.0 - selection.width`
3. 将新的 `top` 限制在 `0.0` 到 `1.0 - selection.height`
4. 保持选区宽高不变
5. 回传新的 `Rect.fromLTWH(left, top, width, height)`

关键逻辑：

```dart
dx = delta.dx / imageRect.width
dy = delta.dy / imageRect.height
```

边界效果：

- 向左拖到头时，选区左边不会小于图片左边界
- 向右拖到头时，选区右边不会超过图片右边界
- 向上或向下拖动同理
- 移动不会改变选区大小

### 7.2 调整选区大小

用户拖拽四角圆形控制点时，触发 `_resizeSelection()`。

四个控制点分别对应：

- 左上
- 右上
- 左下
- 右下

调整步骤：

1. 将手势位移从预览像素换算为图片归一化比例
2. 根据控制点所在水平位置决定调整 `left` 或 `right`
3. 根据控制点所在垂直位置决定调整 `top` 或 `bottom`
4. 将变化后的边界限制在图片范围内
5. 保证宽高不低于 `_minSelectionSize`
6. 回传新的 `Rect.fromLTRB(left, top, right, bottom)`

水平调整规则：

- 拖拽左侧控制点时，修改 `left`
- 拖拽右侧控制点时，修改 `right`

垂直调整规则：

- 拖拽上侧控制点时，修改 `top`
- 拖拽下侧控制点时，修改 `bottom`

最小尺寸规则：

```dart
_minSelectionSize = 0.16
```

因此选区不能被缩小到小于图片宽度 16% 或图片高度 16%。

当前调整逻辑不会锁定宽高比，也不会进行吸附或网格对齐。

### 7.3 查看大图

选区组件右下角有“查看大图”按钮。点击后进入 `_FullImagePreviewPage`。

大图预览用于查看图片内容，但当前不提供在大图页直接编辑选区的能力。选区调整仍在原页面的选区组件中完成。

## 8. 视觉反馈

当前选区工具提供三类视觉反馈。

### 8.1 图片外遮罩

`_SelectionScrimPainter` 在图片显示区域内绘制半透明黑色遮罩，并从遮罩中挖掉选区区域。

遮罩颜色：

```dart
Colors.black.withValues(alpha: 0.16)
```

效果是：

- 选区内部保持清晰
- 选区外区域轻微变暗
- 用户能快速判断当前 OCR 关注范围

### 8.2 选区虚线框

`_SelectionBorderPainter` 使用 `AppTheme.primaryBlue` 绘制选区虚线边框。

边框参数：

- 线宽：2.5
- dash：10.0
- gap：6.0

选区边框随选区大小变化而重绘，边框本身不拦截内部移动手势。

### 8.3 四角控制点

四个控制点为白色圆点，蓝色边框，带轻微阴影。

控制点尺寸：

```dart
22 logical pixels
```

控制点使用不透明命中区域，便于用户在移动端拖拽。

## 9. 开始识别时的图片处理

用户点击“开始识别”后，页面进入 `_openResult()` 流程。

前置条件：

- 已选择图片
- OCR API Key 已配置
- 当前没有正在选择图片
- 当前没有正在识别

识别开始后：

1. 显示识别日志浮层
2. 清空之前的识别日志
3. 调用 `_prepareImageForRecognition()`
4. 使用处理后的图片路径调用 OCR 服务
5. OCR 完成后进入识别结果页

### 9.1 选区标准化

识别前会先调用 `_normalizeSelection()`，将当前选区四个边界限制在 `0.0` 到 `1.0`。

随后通过 `_isFullImageSelection()` 判断是否接近整图：

```dart
selection.left <= 0.01 &&
selection.top <= 0.01 &&
selection.right >= 0.99 &&
selection.bottom >= 0.99
```

只要选区基本覆盖整张图片，就视为整图识别。

### 9.2 直接上传原图

如果同时满足以下条件，会直接上传原图：

- 当前选区视为整图
- 原图大小不超过 3 MB

直接上传阈值：

```dart
3 * 1024 * 1024
```

这种情况下不会执行裁切或缩放。

### 9.3 移动端原生处理

Android 和 iOS 上优先调用 `NativeImageProcessingService.prepareRecognitionImage()`。

传递参数：

- 图片路径
- 归一化 `left`
- 归一化 `top`
- 归一化 `right`
- 归一化 `bottom`
- 最大长边 `_maxRecognitionLongSide`

最大长边当前为：

```dart
2200
```

原生处理职责：

- 根据 EXIF 或 UIImage orientation 纠正方向
- 按选区裁切
- 如果长边超过 2200，则等比缩放
- 压缩为更小的 JPEG
- 返回处理后的临时文件路径和处理元数据

Flutter 侧会根据返回结果记录日志，包括：

- 输出尺寸
- JPEG 质量
- 原始大小和输出大小
- 是否裁切
- 是否缩放

如果原生处理失败，会自动回退到 Dart 图片处理流程。

### 9.4 Dart 回退处理

非移动端或原生处理失败时，使用 Dart fallback。

回退处理逻辑：

1. 读取原图字节
2. 解码为 `ui.Image`
3. 根据选区换算裁切矩形
4. 计算是否需要缩放到最大长边 2200
5. 使用 `Canvas.drawImageRect()` 绘制裁切与缩放后的图片
6. 编码为 PNG
7. 写入系统临时目录
8. 返回临时文件路径

如果是整图选择，并且处理后的 PNG 不比原图小，则继续使用原图上传。

Dart fallback 的裁切输出最小宽高限制为 8 像素，用于避免极小区域导致无效图片。

## 10. OCR 输入关系

选区工具本身不直接调用 OCR。它只负责维护和输出当前图片选区。

实际 OCR 链路为：

1. 选区工具更新 `_recognitionSelection`
2. 用户点击“开始识别”
3. `_prepareImageForRecognition()` 根据选区生成识别图片
4. `WordSnapDemoService.createRecognitionCaptureFromVolcengineOcr()` 保存待识别图片
5. `VolcengineOcrService.recognizeImage()` 调用大模型视觉识别
6. 识别结果整理为 `RecognitionCapture`
7. 页面跳转到 `RecognitionResultPage`

因此，OCR 服务接收到的是已经按当前选区处理后的图片，而不是原图加坐标。

## 11. 当前边界与限制

当前实现有以下明确边界：

- 选区只有矩形，不支持多边形、套索或多区域选择
- 四角缩放不锁定宽高比
- 不支持旋转图片或旋转选区
- 不支持双指缩放预览后再选区
- 大图预览页不能编辑选区
- 没有“重置选区”独立按钮，清除图片会连同图片一起重置
- 没有网格线、吸附线或 OCR 文本行辅助
- 选区状态只保存在当前页面内，不跨页面或重启持久化
- 选区最小尺寸按图片比例限制，不按实际像素或 OCR 可读性动态调整

这些限制是当前操作逻辑的一部分，不代表后续不能扩展。

## 12. 设计意图总结

当前照片选区工具采用“轻量框选 + 点击识别时即时裁切”的设计。

核心设计取舍是：

- 用归一化坐标保存选区，降低预览尺寸、屏幕尺寸和图片原始尺寸之间的耦合
- 用 `BoxFit.contain` 的实际图片矩形做手势换算，避免留白区域影响选区
- 保持交互简单，只提供移动和四角缩放
- 移动端优先使用原生处理，提升大图裁切、方向纠正和压缩稳定性
- 非移动端保留 Dart fallback，保证功能闭环
- OCR 服务只接收处理后的图片，避免 OCR 层感知选区细节

这套逻辑适合当前“拍照或相册导入后快速识别单词”的使用场景，复杂编辑能力可以作为后续版本单独扩展。
