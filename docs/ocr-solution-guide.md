# WordSnap OCR 方案说明

## 当前方案

`WordSnap` 当前已经切换到火山引擎方舟图片理解方案：

1. 用户在设置页手动填写火山引擎 API Key
2. 应用把拍摄或导入的图片转成 base64
3. 使用轻量 `http` 请求直连方舟 OpenAI 兼容接口
4. 由视觉模型输出结构化 JSON
5. 应用把 JSON 解析成“单词 + 音标 + 词性/释义”的词条，再进入考试流程

当前接入默认使用模型：

- `Doubao-1.5-vision-pro`

当前接口地址：

- `https://ark.cn-beijing.volces.com/api/v3/chat/completions`

参考文档：

- 火山方舟快速开始：
  [https://www.volcengine.com/docs/82379/1928261?lang=zh](https://www.volcengine.com/docs/82379/1928261?lang=zh)

## 为什么改成火山引擎

这次切换的原因主要有三点：

- 词书条目更适合让视觉模型直接理解整条结构，而不是先做原始 OCR 再靠本地规则拼接
- 用户可以自行填写 API Key，不需要我们在客户端内置密钥
- 运行时去掉 Android ML Kit、iOS Vision 和 Flutter `MethodChannel` 桥接后，主链路代码更轻，平台维护成本更低

## 识别链路

当前链路的重点不是“通用文档 OCR”，而是“词书条目识别”：

- 优先把一条词书内容识别成一个词条
- 尽量保留音标
- 尽量保留词性和中文释义
- 同时保留原始识别文本，方便人工核对

模型输出的目标 JSON 结构：

```json
{
  "raw_text": "danger /ˈdeɪndʒə(r)/ n. 危险",
  "entries": [
    {
      "word": "danger",
      "phonetic": "/ˈdeɪndʒə(r)/",
      "part_of_speech": "n.",
      "meaning": "危险",
      "source_text": "danger /ˈdeɪndʒə(r)/ n. 危险",
      "confidence": 0.93
    }
  ]
}
```

应用侧再把它转换成内部 `WordEntry`：

- `word`
- `phonetic`
- `meaning`
- `confidence`

## 用户配置

用户需要在应用设置页填写：

- 火山引擎 API Key

当前版本不要求用户手动填写：

- Endpoint
- Model ID

这样可以减少配置复杂度，先把识别链路稳定下来。

## 安全与限制

当前实现是客户端直连第三方服务，因此有几个明确限制：

- API Key 存在本地设置里，适合个人自用，不适合共享发行环境
- 图片会上传到火山引擎进行识别，不再是纯离线方案
- 识别质量依赖模型输出和网络稳定性
- 调用成本会随识别量增加

如果后续要面向更大范围发布，建议把 Key 下沉到自有服务层，避免把第三方密钥直接留在终端。

## 历史方案归档

之前的本地原生 OCR 方案没有直接丢弃，关键设计已经保存到：

- [docs/local-ocr-design-backup.md](/Users/weiyi/code/WordSnap/docs/local-ocr-design-backup.md)

如果以后需要恢复离线识别，可以按那份文档重新接回 Android / iOS 端的本地能力。
