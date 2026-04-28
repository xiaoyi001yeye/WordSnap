# WordSnap iPhone 调试试用指南

这份文档适用于没有付费 Apple Developer 账号、但想把 WordSnap 跑到自己 iPhone 上试用的情况。

## 能做到什么

- 可以用普通 Apple ID 在自己的 iPhone 上调试运行。
- 可以在手机上试用拍照、识别、答题、单词本等主流程。
- 可以反复通过 Xcode 安装最新代码。

## 做不到什么

- 不能把 app 长期分发给别人安装。
- 不能使用 TestFlight。
- 不能上架 App Store。
- 免费 Apple ID 的真机签名通常只有短期有效期，到期后需要重新用 Xcode 安装。
- GitHub Actions 产出的 unsigned IPA 没有苹果签名，普通 iPhone 不能直接安装。

## 准备

- 一台 Mac。
- Xcode。
- 一台 iPhone。
- 一个普通 Apple ID。
- 已安装 Flutter，并且本机能打开这个 Flutter 项目。

## 第一次配置

1. 用 USB 连接 iPhone 和 Mac。
2. 打开 Xcode。
3. 在 Xcode 里登录 Apple ID：`Xcode -> Settings -> Accounts`。
4. 打开项目里的 `ios/Runner.xcworkspace`。
5. 在左侧选择 `Runner` 项目，再选择 `Runner` target。
6. 打开 `Signing & Capabilities`。
7. 勾选 `Automatically manage signing`。
8. `Team` 选择你的 Personal Team。
9. 把 `Bundle Identifier` 改成唯一值，例如：

```text
com.weiyi.wordsnap
```

不要继续使用默认的 `com.example.wordsnap`，这个 ID 太通用，容易冲突。

## 运行到 iPhone

1. 在 Xcode 顶部设备列表里选择你的 iPhone。
2. 点击 Run。
3. 如果手机提示不信任开发者，在 iPhone 上打开：

```text
设置 -> 通用 -> VPN 与设备管理
```

找到你的 Apple ID 开发者证书并信任。

4. 回到 Xcode 再点 Run。

## 日常试用流程

每次代码更新后：

1. 拉取最新代码。
2. 打开 `ios/Runner.xcworkspace`。
3. 选择 iPhone。
4. 点击 Run。

如果签名过期，重新 Run 一次即可。

## GitHub Actions 的 IPA 包

仓库包含 `Build WordSnap iOS IPA` workflow：

```text
.github/workflows/build-ios-ipa.yml
```

它会在 GitHub Actions 里执行：

```text
flutter build ios --release --no-codesign
```

然后把 `Runner.app` 打成：

```text
wordsnap-ios-unsigned.ipa
```

注意：这个 IPA 是未签名包，主要用途是验证 CI 能产出 iOS app bundle，或留给以后有证书时再签名。没有 Apple Developer 签名时，它不能直接装到普通 iPhone。

## 什么时候需要付费 Apple Developer 账号

如果你想做到下面任意一项，就需要付费 Apple Developer 账号：

- 给别人安装试用。
- 用 TestFlight 分发。
- 上架 App Store。
- 生成可长期安装的 Ad Hoc 或 App Store IPA。
