# WordFlow 架构拆解与 WordSnap 落地

## 一、`WordFlow` 的主干结构

`../Swiftick/WordFlow` 的核心不是某个页面，而是一套比较完整的应用骨架：

1. 启动初始化
   `lib/main.dart` 先做渲染兼容初始化、系统 UI 配置、学习数据服务初始化、自动更新初始化，再启动应用。

2. 全局主题和系统样式
   `lib/utils/app_theme.dart` 统一管理颜色、文字、卡片、按钮、明暗模式和系统状态栏样式。

3. 服务层
   `LearningDataService`、`SettingsHelper`、`AutoUpdateService`、`AlgorithmManager` 等把数据、算法、配置和平台能力从页面里拆开。

4. 页面层
   页面主要负责编排交互流程，比如 onboarding、home、review、settings，不直接承载大部分底层逻辑。

5. 通用基础设施
   `ResponsiveHelper`、`CompatiblePageRoute`、`AcrylicAppBar`、`RenderCompatibilityHelper` 等承担跨页面复用能力。

## 二、适合迁移到 `WordSnap` 的技术实现

我没有把词汇学习业务原样复制，而是抽取了最有价值的架构能力：

- 应用初始化器：沿用 `AppInitializer` 模式，根据持久化状态决定首屏
- 设置持久化：参考 `SettingsHelper`，落成 `AppSettingsService`
- 主题集中管理：参考 `AppTheme`
- 响应式封装：参考 `ResponsiveHelper`
- 兼容导航层：参考 `CompatiblePageRoute`
- 服务层抽象：新增 `WordSnapDemoService`，专门负责演示业务数据和考试生成

## 三、落地后的 `WordSnap` 结构

为了比 `WordFlow` 更适合后续扩展，我把目录从“pages / utils / widgets”进一步整理成“app / core / features”：

```text
lib/
  app/      启动编排
  core/     通用基础能力
  features/ 业务模块
```

这相当于把 `WordFlow` 的经验做了二次提炼：

- `app/` 对应 `WordFlow` 的 `main.dart + AppInitializer`
- `core/` 对应 `WordFlow` 的 `utils/widgets` 中真正可复用的部分
- `features/` 对应具体业务页面与服务

## 四、当前已经完成的业务演示闭环

在当前项目里，我用这套架构串起了一个完整原型：

1. 首次进入引导页
2. 进入底部导航壳层
3. 从首页进入拍照识词演示
4. 查看识别结果
5. 进入考试设置
6. 完成答题
7. 查看成绩、分析和错题复习

## 五、下一步建议

如果你接下来要继续把 `WordSnap` 做成真应用，推荐按这个顺序推进：

1. 接入真实 OCR 服务，替换 `WordSnapDemoService` 的假数据
2. 把考试结果持久化，替换当前的会话内统计
3. 增加词本导入导出
4. 如果业务继续变大，再把 `study_flow_pages.dart` 继续拆成更细的 feature 子目录
