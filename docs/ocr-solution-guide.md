# WordSnap OCR 方案说明

## 目标

`WordSnap` 当前的目标不是做通用文档理解，而是完成这条链路：

1. 用户拍照或从相册导入图片
2. 从图片里识别文本
3. 抽取英文单词
4. 让用户勾选单词并继续生成考试

围绕这个目标，OCR 方案可以分成三类：

- 端侧原生 OCR
- 自建 PaddleOCR 服务
- 第三方云 OCR API

当前仓库已经落地的是：

- App 侧接入 `PaddleOCR` 官方 `/ocr` 服务接口
- 对识别结果做英文单词抽取
- 在设置页中配置 OCR 服务地址
- 用脚本一键启动官方 PaddleOCR 服务

## 什么时候用什么方案

### 方案 A：iOS Vision + Android ML Kit

适用场景：

- 想优先做真机离线可用
- 想避免图片上传
- 想减少后端运维
- 想把首版稳定性和延迟放在第一位

优点：

- 延迟低
- 不依赖网络
- 没有持续调用费用
- 更适合课本、试卷、截图这种中等复杂度场景

代价：

- 需要分别维护 iOS 和 Android 原生能力
- Flutter 侧要做平台桥接
- 如果要追求两端完全一致的结果，调试成本更高

推荐级别：

- 长期最优

### 方案 B：自建 PaddleOCR 服务

适用场景：

- 想快速把 OCR 功能真正跑起来
- 希望 iOS / Android 先共用同一套识别结果
- 允许手机把图片发给自己的服务
- 愿意维护一台本地电脑、局域网机器或云服务器

优点：

- 模型和推理逻辑统一
- 结果一致性比双端原生更好
- 方便后续替换模型、加预处理、加词典补全
- 当前仓库已经实现了这种接法

代价：

- 依赖网络
- 需要启动服务
- 真机调试时要处理局域网访问、HTTP 明文、服务器可用性

推荐级别：

- 当前阶段最实用

### 方案 C：第三方云 OCR API

适用场景：

- 希望最快验证产品
- 不想维护 OCR 模型和推理环境
- 识别量不大

优点：

- 接入快
- 通常文档 OCR 效果不错
- 能力成熟

代价：

- 依赖外部服务
- 存在隐私和合规问题
- 免费额度有限
- 成本会随调用量持续增长

推荐级别：

- 适合 MVP 或兜底，不适合作为长期唯一方案

## 当前项目为什么先落地 PaddleOCR 服务

虽然 PaddleOCR 的移动模型不算大，但“模型不大”不等于“Flutter 端侧接入简单”。

如果要在当前项目里做真正的端侧 PaddleOCR，至少要解决：

- Android 原生推理 runtime 集成
- 模型文件管理
- 图片预处理和后处理
- Flutter 与 native 的桥接
- iOS 侧单独的运行时与工程接入
- 包体、内存、首帧时延和热启动时的权衡

在现有仓库结构下，直接上端侧 PaddleOCR 的工程风险明显高于先接官方服务。因此当前实现优先选择“PaddleOCR 官方 Serving pipeline + Flutter 客户端接入”。

## 当前仓库已实现的内容

### App 侧

- 设置页新增 `PaddleOCR` 服务地址配置
- 识别页点击按钮后会调用 PaddleOCR `/ocr`
- 从 OCR 文本里抽取英文单词
- 结果页展示：
  - 识别出的单词
  - 原始 OCR 文本
  - 识别引擎和文本行数
  - 未匹配到本地词义的单词提示

### 工具脚本

新增脚本：

- [tools/start_paddleocr_server.sh](/Users/weiyi/code/WordSnap/tools/start_paddleocr_server.sh)

用途：

- 创建 Python 虚拟环境
- 安装官方 `PaddleX OCR`
- 安装官方 serving 组件
- 启动 `OCR` 服务

启动方式：

```bash
./tools/start_paddleocr_server.sh
```

默认会在：

- `http://0.0.0.0:8080/ocr`

提供 OCR 接口。

## 真机使用说明

### Android

当前工程已经放开：

- `INTERNET`
- `cleartextTraffic`

所以可以直接访问局域网里的 `http://<电脑IP>:8080/ocr`

### iPhone

当前工程已经为了开发调试放开了 ATS 明文限制，因此可以访问局域网 HTTP 服务。

真机调试时不要填：

- `http://127.0.0.1:8080/ocr`
- `http://localhost:8080/ocr`

因为这会指向手机自己，不是你的电脑。

应该填写电脑在同一局域网中的地址，例如：

- `http://192.168.1.10:8080/ocr`

## 资源要求

### 当前已实现方案：PaddleOCR 服务

App 端要求：

- 正常网络访问能力
- 能访问你的局域网或云端 OCR 服务
- 不要求手机本地额外加载 OCR 模型

服务端要求：

- Python 3 环境
- 能安装 `paddlex[ocr]`
- CPU 即可运行

建议：

- 开发期先用 CPU
- 如果后续批量识别或响应速度要求更高，再考虑 GPU

### 如果以后上端侧 PaddleOCR

需要额外考虑：

- App 包体会增加
- 首次加载模型时间
- 推理内存峰值
- Android 原生 runtime 兼容性
- iOS 原生接入复杂度

对于课本页、试卷页这类静态图片场景，真正的瓶颈往往不是 GPU 不够，而是：

- 原图太大
- 图像模糊
- 角度倾斜
- 同时跑多个推理任务

## 应该优先怎么演进

### 第一阶段

使用当前已经实现的 PaddleOCR 服务版，把链路跑通。

目标：

- 让真实图片能稳定出单词
- 跑通结果筛选
- 验证识别准确率

### 第二阶段

补强 OCR 后处理。

建议补的能力：

- 裁切和旋转校正
- 行噪声过滤
- 页码、题号、纯数字过滤
- 英文单词词典匹配
- 低置信度高亮提示

### 第三阶段

如果服务端方案效果稳定，再决定是否转端侧原生：

- `iOS` 用 `Vision`
- `Android` 用 `ML Kit`

如果对统一模型和统一结果有强要求，再评估端侧 PaddleOCR native 方案。

## 免费 OCR API 选择建议

如果只是临时验证产品，可以考虑：

- `OCR.space`
- `Google Cloud Vision` 免费额度
- `Azure AI Vision` 免费额度

但它们更适合作为：

- 临时验证
- 备用兜底
- 低量级 demo

不建议把“长期免费”作为产品核心假设。

## 官方参考

- PaddleOCR OCR pipeline usage:
  [PaddleOCR OCR Pipeline](https://www.paddleocr.ai/v3.3.0/en/version3.x/pipeline_usage/OCR.html)
- PaddleOCR on-device deployment:
  [PaddleOCR On-Device Deployment](https://www.paddleocr.ai/v3.3.0/en/version3.x/deployment/on_device_deployment.html)
- Apple Vision:
  [Vision Framework](https://developer.apple.com/documentation/vision/)
- Google ML Kit text recognition:
  [Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)
  [iOS](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios)
