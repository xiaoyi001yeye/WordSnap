# WordSnap Material 3 组件替换设计文档

## 1. 文档目的

本文档用于评估 `WordSnap` 现有 UI 是否适合全面收敛到 Material 3 组件体系，并给出一份可执行的替换设计方案。

本次目标是先完成分析和设计，不直接修改业务代码。

主要覆盖以下范围：

- 全局主题与设计 token
- 页面骨架与导航
- 表单、按钮、卡片、列表、弹窗、提示反馈
- 当前大量自定义的“伪组件”是否可用 Material 3 语义重建
- 哪些组件不适合强行替换为标准控件，而应改造成“基于 Material 3 token 的业务组件”

主要参考代码：

- `lib/core/theme/app_theme.dart`
- `lib/app/word_snap_app.dart`
- `lib/features/onboarding/onboarding_page.dart`
- `lib/features/shell/word_snap_shell.dart`
- `lib/features/study/study_flow_pages.dart`
- `lib/core/update/update_dialog.dart`

## 2. 结论摘要

结论是：`可以换`，但不建议理解成“把每个自定义 widget 都机械替换成同名的 Material 3 标准控件”。

更准确的说法是：

1. 项目已经开启了 `useMaterial3: true`，说明主题层已进入 Material 3 模式。
2. 现有很多页面已经使用了 Material 组件，但组件语义和视觉风格还没有完全收敛到 Material 3。
3. 大约 70% 到 80% 的 UI 可以直接或低风险地替换为标准 Material 3 组件。
4. 剩余 20% 到 30% 是强业务定制界面，比如 OCR 选区、答题选项格、双人对战答题区、环形图等，这些不应硬套标准控件，而应保留业务结构，用 Material 3 的颜色、shape、状态层、排版和交互规则进行“Material 3 化”。

所以这次迁移的正确目标不是：

- “消灭所有自定义 widget”

而是：

- “让所有 UI 都遵守 Material 3 的组件语义、设计 token 和交互反馈”

## 3. 现状分析

## 3.1 已经在使用 Material 3 的部分

项目已经具备 Material 3 迁移基础：

- `ThemeData(useMaterial3: true)` 已在明暗主题中启用
- 已使用 `NavigationBar`
- 已使用 `FilledButton`
- 已使用 `AlertDialog`
- 已使用 `SnackBar`
- 已使用 `SwitchListTile`
- 已使用 `ListTile`
- 已使用 `TextField`
- 已使用 `LinearProgressIndicator` / `CircularProgressIndicator`

说明当前不是“从零迁移”，而是“从混合态 UI 收敛到更一致的 M3 体系”。

## 3.2 当前主要问题

虽然已经打开了 Material 3 开关，但不少关键区域仍然是“Material 容器 + 手工装饰”的实现方式，导致下面几个问题：

1. 组件语义不统一

- 同样是可选择项，有的用 `InkWell + Container`
- 有的用 `Card`
- 有的用 `OutlinedButton`
- 有的用自定义 badge

2. 状态表达不统一

- 选中态、禁用态、危险态、成功态大量依赖手工颜色
- 没有统一走 `ColorScheme`、`WidgetState`、state layer

3. 视觉层级不统一

- 很多卡片和按钮都自己写圆角、边框、背景色
- 和 Material 3 的 surface/container/elevation 语义没有完全对齐

4. 组件复用边界不清晰

- `_SegmentButton`、`_ScopeOption`、`_OptionButton`、`_StatCard`、`_MemoryBadge`、`_VersionBadge` 这类组件，本质上已经是设计系统组件，但目前还只是页面私有实现

## 3.3 当前最典型的“可替换目标”

### 可直接替换或显著收敛的组件

- 选择器：`_SegmentButton`
- 范围卡片：`_ScopeOption`
- 标签/徽标：`_ExamCountBadge`、`_MemoryBadge`、`_VersionBadge`
- 统计卡片：`_StatCard`
- 设置表单中的 `DropdownButtonFormField`
- 更新弹窗中的日志区域容器
- 各类警告/错误提示条 `Container`

### 不建议强行替换为标准控件的组件

- OCR 图片预览与选区组件
- 双人答题共享选项格
- 自定义环形图 `CustomPainter`
- 题目选项大卡片
- 发音面板

这些组件更适合保留业务结构，但重新建立在 Material 3 token 和交互模式之上。

## 4. 迁移原则

## 4.1 先统一 token，再替换组件

迁移顺序建议是：

1. 先整理 `ColorScheme`、Typography、Shape、Elevation、State Layer
2. 再替换标准组件
3. 最后重构业务自定义组件

如果直接从页面上逐个替换，很容易出现“控件名字换成 M3 了，但整体视觉反而更碎”的问题。

## 4.2 优先使用 Material 3 语义组件，不再手工画通用控件

后续原则应该是：

- 能用 `FilledButton` 就不用 `Container + InkWell`
- 能用 `SegmentedButton` 就不用自定义分段选择器
- 能用 `Chip` 家族就不用自定义圆角标签
- 能用 `ListTile` / `SwitchListTile` / `RadioListTile` 就不用纯手工列表行
- 能用 `Badge` 表达数量就不用单独写数字泡泡

## 4.3 特殊业务组件允许保留，但必须 M3 化

像 OCR 选区、双人答题半区、答题选项大格、分析图表这类区域，本身不是 Material 标准控件的职责，不需要硬改成标准控件。

这类组件的要求应当变成：

- 使用 `Theme.of(context).colorScheme`
- 使用统一圆角体系
- 使用统一排版等级
- 使用统一选中态/禁用态/错误态表达
- 使用 Material 3 的 motion 和 state layer 逻辑

## 5. 组件映射设计

下表描述“当前实现模式 -> 推荐的 Material 3 方案”。

| 当前模式 | 典型位置 | 推荐 M3 方案 | 说明 |
| --- | --- | --- | --- |
| `NavigationBar` | 主壳底部导航 | 保持 | 已是标准 M3 方案 |
| `AppBar` | 各主页面 | 保持并统一样式 | 可进一步对齐 `surface`、滚动行为、标题层级 |
| `ElevatedButton` 主行动作 | 多处 | 优先改为 `FilledButton` | M3 中更推荐 filled/filled tonal |
| `OutlinedButton` 次行动作 | 多处 | 保持 | 统一高度、shape、状态色 |
| `TextButton` 弱操作 | onboarding、dialog | 保持 | 统一文本层级和点击热区 |
| `Container + InkWell` 双项切换 | `_SegmentButton` | `SegmentedButton` | 适合拍照/相册导入二选一 |
| `Container + InkWell` 范围选择卡片 | `_ScopeOption` | `RadioListTile` + `Card.outlined` 或 `ListTile` + `Radio` | 适合带标题、副标题、数量的单选项 |
| 自定义数字/状态 badge | `_VersionBadge`、`_ExamCountBadge`、`_MemoryBadge` | `Chip` / `AssistChip` / `Badge` | 是否可点击决定用 `Chip` 还是 `Badge` |
| 自定义统计块 | `_StatCard` | `Card.filled` + 标准排版 | 保留统计视觉，但不再手工拼色块容器 |
| 自定义错误提示条 | 拍照识别页 | `MaterialBanner` 或 `Card` + `ListTile` + state color | 如果是页内持续提示，优先 `MaterialBanner` |
| `DropdownButtonFormField` | 设置页 | `DropdownMenu` | 更贴近 M3 |
| `TextField` | 设置页 | 保持 | 但统一为 M3 filled/outlined 输入样式 |
| `SwitchListTile` | 设置页 | 保持 | 已符合 M3 语义 |
| `AlertDialog` | 删除确认、更新弹窗 | 保持 | 已是标准 M3 组件 |
| 日志展示容器 | 更新弹窗 | `ExpansionTile` + `SelectableText` 或 `FilledCard` | 避免纯手写边框容器 |
| 进度条 | 统计页、分析页、更新页 | 保持 | 已是标准 M3 组件 |
| 识别日志浮层 | 拍照识别流程 | `ModalBottomSheet` 或 `Dialog.fullscreen` | 比纯 overlay 更符合 M3 信息层级 |
| 答题选项大卡片 | `_OptionButton` | `OutlinedButton` / `FilledButton.tonal` 的卡片化封装 | 保持大点击区域，但切到 M3 语义 |
| 双人对战答题区 | `_TwoPlayerSharedAnswerGrid` | 保留自定义结构，内部使用 M3 token | 不建议强行标准化成现成控件 |
| 分析图 legend 与状态点 | `_LegendRow` | `ListTile` 精简版或 `Chip` | 视最终视觉选择 |

## 6. 页面级替换方案

## 6.1 Onboarding

当前页面特点：

- `PageView`
- 顶部跳过按钮
- 手工分页指示器
- 图标卡片
- 底部主按钮

建议：

- 顶部 `TextButton` 保留
- 底部主按钮改为统一 `FilledButton`
- “开始前你会得到”这块保留 `Card`
- 分页指示器可以继续自定义，也可评估 `TabPageSelector`

结论：

- onboarding 不需要强行全换标准组件
- 重点是把配色、按钮、卡片、标题层级收敛到 M3

## 6.2 首页

当前页面特点：

- 顶部有品牌版本 badge
- 一张强视觉主卡片
- 单词本摘要卡
- 最近学习列表

建议：

- 主卡片保留“品牌 Hero Card”定位，但实现应基于 M3 `Card`
- 版本号显示可改成 `Badge` 或小型 `AssistChip`
- 最近学习列表统一为 `Card` 内 `ListTile`
- “我的单词本”摘要可继续用 `ListTile`

结论：

- 首页不是问题页，更多是统一 token 和变体

## 6.3 单词本

当前页面特点：

- 顶部三块统计卡
- 单词条目卡
- 自定义 badge
- 删除按钮

建议：

- 顶部统计块改为统一 `Card.filled` 变体
- “已考 X 次”适合 `AssistChip`
- 记忆程度标签适合 `FilterChip` 的只读变体或静态 `Chip`
- 删除按钮可继续使用 `IconButton`，危险态走 `colorScheme.error`

结论：

- 单词本页非常适合 Material 3 化，收益高、风险低

## 6.4 拍照识别页

当前页面特点：

- 采集方式二选一
- 错误提示条
- 图片预览与裁剪入口
- 识别过程浮层

建议：

- “拍照 / 相册导入”切换改为 `SegmentedButton`
- 错误和提醒信息改为 `MaterialBanner` 或 `Card.outlined`
- 图片预览仍保留自定义业务组件
- 识别日志浮层改为 `ModalBottomSheet` 更符合 M3 的层级和可关闭方式

结论：

- 这一页不是全部换标准控件，而是“标准控件 + 自定义媒体组件”的组合

## 6.5 识别结果页

当前页面特点：

- 识别总数与说明
- 单词选择列表
- 复选框选择
- 底部行动按钮

建议：

- 单词列表尽量用 `CheckboxListTile` / `ListTile` + `Checkbox`
- 批量操作按钮统一为 `FilledButton` / `OutlinedButton`
- 汇总说明卡统一为 `Card`

结论：

- 识别结果页可高度标准化

## 6.6 考试设置页

当前页面特点：

- 范围切换
- 配置项卡片
- 开始考试按钮

建议：

- 紧凑型二选一或三选一使用 `SegmentedButton`
- 带说明文案和计数的范围选择项用 `RadioListTile` + `Card.outlined`
- 题目数量、模式配置可逐步过渡到 `DropdownMenu`、`SwitchListTile`、`Slider`、`MenuAnchor`

结论：

- 这是最适合沉淀“表单型 M3 组件”的一页

## 6.7 答题页

当前页面特点：

- 进度条
- 单词大标题
- 发音按钮面板
- 九宫格或大卡片选项
- 双人模式共享作答区

建议：

- 顶部进度条保留
- 发音面板可改造成两个 `FilledButton.tonalIcon` 风格按钮
- 单人答题选项建议基于 `OutlinedButton` 或 `FilledButton.tonal` 重新封装
- 双人对战区保留自定义布局，但状态色、圆角、按压反馈、禁用态要走统一 M3 token

结论：

- 答题页不可能 100% 只用标准组件
- 但完全可以做到“体验上符合 Material 3”

## 6.8 分析页与错题页

当前页面特点：

- 环形图
- 分布条
- 错题列表
- 加入/移出复习按钮

建议：

- 环形图保留 `CustomPainter`
- 图例可用 `ListTile` 精简版或 `Chip`
- 错题项继续使用 `Card`
- “加入复习 / 移出复习”动作建议改为 `FilledButton.tonal`

结论：

- 数据页适合 Material 3 风格化，但图表仍然是业务自定义

## 6.9 设置页

当前页面特点：

- 主题切换
- 应用更新入口
- OCR 提供商选择
- API Key 输入
- 考试偏好展示
- 本地数据展示

建议：

- `SwitchListTile` 保持
- 更新入口继续 `ListTile`
- `DropdownButtonFormField` 替换为 `DropdownMenu`
- API Key 输入保留 `TextField`
- “清空 / 保存”操作改为 `OutlinedButton` + `FilledButton`
- 只读配置展示区可以考虑使用 `ListTile` 组，减少纯 `Row` 文本布局

结论：

- 设置页是最容易一次性完成 M3 收敛的页面

## 6.10 更新弹窗

当前页面特点：

- `AlertDialog`
- 版本信息
- 更新说明
- 下载进度
- 诊断日志容器

建议：

- `AlertDialog` 保持
- 进度条保持
- 日志区改为 `ExpansionTile` + `SelectableText`
- 主按钮继续使用 `FilledButton`

结论：

- 更新弹窗已经非常接近 M3，只需收敛日志容器和信息层级

## 7. 设计系统层建议

为了避免后续再次出现“页面私有手工控件越来越多”的情况，建议在正式改造时补一层共享 UI 组件。

建议新增一层 `shared ui` 概念，但当前阶段只先规划，不动代码。

建议抽象的组件目录方向：

- `AppPageSectionCard`
- `AppStatCard`
- `AppStatusChip`
- `AppSelectableOptionTile`
- `AppSegmentedSelector`
- `AppFeedbackBanner`
- `AppMetricRow`

这层组件的职责不是隐藏 Material，而是把 WordSnap 常用的 M3 组合固化下来。

## 8. 主题改造建议

虽然项目已经开启 `useMaterial3: true`，但主题定义仍有进一步收敛空间。

建议后续主题改造重点如下：

## 8.1 颜色体系

当前存在不少直接写死的颜色：

- `0xFFE9F0FF`
- `0xFFE4EAF5`
- `0xFFF8FAFF`
- `0xFFFFE7E7`
- `0xFFE9F8EF`

建议迁移目标：

- 主要由 `ColorScheme` 提供颜色
- 将成功、警告、危险扩展为语义 token
- 少量品牌色保留在 `AppTheme`

## 8.2 圆角体系

当前圆角尺寸较多：

- 12
- 14
- 16
- 18
- 22
- 24
- 28
- 999

建议收敛为有限的 shape scale，例如：

- small: 12
- medium: 16
- large: 20
- extraLarge: 28
- full: 999

## 8.3 按钮体系

建议明确按钮语义：

- `FilledButton`：页面主动作
- `FilledButton.tonal`：强调但次一级动作
- `OutlinedButton`：次动作
- `TextButton`：弱操作
- `IconButton`：局部辅助操作

避免继续混用 `ElevatedButton` 和手工高亮容器来表达主动作。

## 8.4 卡片体系

建议把卡片语义明确成三类：

- `OutlinedCard`：信息分组、列表项
- `FilledCard`：弱强调模块、统计块
- 品牌 Hero Card：首页主卡片等少数强视觉区域

## 9. 不建议强改的部分

以下内容不建议以“必须替换成官方标准组件”为目标：

1. OCR 图片选区

- 这是媒体编辑交互，不是普通表单
- 应保留业务组件

2. 双人对战答题半区

- 这是强业务玩法组件
- Material 3 没有现成等价物

3. 环形图

- 属于数据可视化，不需要标准组件替代

4. 题目选项大宫格

- 可以改用 M3 语义封装
- 但不必退化成普通 `ListTile`

## 10. 分阶段实施建议

建议按风险由低到高推进。

### Phase 1：主题与通用组件

- 收敛 `ColorScheme`
- 收敛 shape scale
- 收敛按钮主题
- 收敛卡片主题
- 定义共享 badge/chip/stat card/selectable tile 方案

### Phase 2：低风险页面替换

- 设置页
- 更新弹窗
- 首页信息卡
- 单词本列表卡

### Phase 3：流程页标准化

- 拍照识别页的 segmented selector、banner、浮层
- 识别结果页
- 考试设置页

### Phase 4：复杂交互区 M3 化

- 单人答题选项
- 双人答题区域
- 发音面板
- 分析页图例和指标区

## 11. 风险与注意事项

1. 不要把“Material 3 化”理解为“去掉所有品牌感”

- 首页主卡、学习反馈、答题节奏仍然需要品牌识别度

2. 不要一边迁移一边继续增加新的页面私有组件

- 否则后面会再次发散

3. 复杂业务组件要先定交互语义，再定控件形态

- 特别是答题选项和双人模式

4. 颜色迁移要先做语义映射

- 不能简单把红蓝黄绿全部直接换成 `primary`/`secondary`

## 12. 验收标准

后续正式实施时，建议以以下标准判断是否完成 Material 3 收敛：

1. 所有主操作、次操作、弱操作都能映射到明确的 M3 按钮语义
2. 所有选择器都优先使用 `SegmentedButton`、`Radio`、`Checkbox`、`Switch`、`Chip` 家族
3. 通用信息分组都优先使用标准卡片和列表组件
4. 所有状态颜色优先来自 `ColorScheme` 和语义 token
5. 复杂业务组件虽然仍为自定义，但视觉和交互规则与 M3 一致

## 13. 推荐后续行动

如果下一步开始真正改代码，建议不要一次性“全项目大换血”，而是按下面顺序推进：

1. 先改 `theme` 和通用组件策略
2. 再改 `SettingsPage`、`UpdateDialog`、`WordBookTab`
3. 再改 `RecognitionDemoPage` 和 `ExamSetupPage`
4. 最后处理 `ExamPage`、双人模式和分析页

这样收益最大、返工最少，也更适合在不跑本地 Flutter 校验的前提下，让 GitHub Actions 分阶段接住验证。
