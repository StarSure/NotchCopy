# Developer ID 签名与 Apple 公证

这份流程准备于开发者会员开通前。脚本和本地测试可先完成，但只有会员生效、证书与认证配置就绪后，才能实际提交 Apple 并验证下载包。

## 个人会员注册（本人操作）

在 Mac App Store 安装 Apple 官方的 [Apple Developer](https://apps.apple.com/app/apple-developer/id640199958)，打开后进入“账户”。用准备作为开发者的 Apple 账户登录，选择注册，并按页面完成法定姓名、个人身份验证、协议与会员订阅。

账号登录、验证码、身份证/自拍等身份验证、协议接受与付款由账户本人在 Apple 界面完成。不要把 Apple 密码、验证码或证件信息发到聊天或提交到仓库。会员价格和自动续订条款以本人看到的购买确认页为准；不同商店地区可能显示不同币种。

等账户页面显示有效的 Apple Developer Program 会员资格，再进行下面步骤。如果仍显示注册审核中，先等待 Apple 的结果，不重复购买。

官方说明：https://developer.apple.com/cn/help/account/membership/enrolling-in-the-app/

## 创建签名证书

在 Xcode 的 Settings → Accounts 中添加该开发者 Apple 账户，选择付费团队，进入 Manage Certificates，创建 **Developer ID Application** 证书。也可在 Apple Developer 账户的 Certificates 页面创建该类型证书。

本项目直接分发 `.app`，不需要为当前 ZIP 流程创建 Developer ID Installer 证书。签名私钥保留在本机 Keychain；不默认导出到 GitHub 或写入环境文件。

使用下面的只读命令查看可用签名身份，记下完整的 Developer ID Application 名称：

```sh
security find-identity -v -p codesigning
```

官方说明：https://developer.apple.com/help/account/certificates/create-developer-id-certificates/

## 保存公证认证到本机 Keychain（本人操作）

在本人 Terminal 中执行：

```sh
xcrun notarytool store-credentials 'NotchCopy-Notary'
```

也可从 Finder 打开 `Scripts/store-notary-credentials.command`。Apple 官方工具会交互询问 Apple 账户、Team ID 和 App 专用密码，并验证后存入本机 Keychain。App 专用密码需在 Apple 账户管理网站中由本人创建；不要使用普通 Apple 登录密码，不要把任何密码填入脚本、命令行参数、GitHub 文件或聊天。

脚本只引用 Keychain profile 名称，不读取或输出其中的密码。此流程不要求将签名私钥或公证认证上传为 GitHub Secrets。

## 签名、公证与打包

正式发布前，先将 `VERSION` 递增为新版本，例如 `0.4.1`，避免与现有未公证的 `0.4.0` 混淆。

先查看执行计划（不会签名或联网）：

```sh
python3 Scripts/notarize.py --plan
```

具备会员、证书与 Keychain profile 后执行；替换下面的示例证书名称：

```sh
python3 Scripts/notarize.py \
  --identity 'Developer ID Application: YOUR LEGAL NAME (TEAMID)' \
  --profile 'NotchCopy-Notary'
```

脚本会依次执行：

1. 检查本机确有匹配的有效 Developer ID Application 身份。
2. 构建 Apple Silicon / Intel 通用应用，使用 Hardened Runtime、安全时间戳与正式证书签名。
3. 验证正式签名，创建提交 ZIP，并交给 Apple notary service。
4. 保存提交 ID，等待 Apple 处理。仅 `Accepted` 可以继续；下载 Apple 的结果日志供检查。
5. 对 `.app` 附加并验证公证票据，再验证代码签名与本机 Gatekeeper 评估。
6. 以上全部成功后，重新打包附有票据的 `.app`，生成发布 ZIP 与 SHA-256 校验文件。

ZIP 本身不能附加公证票据；必须给里面的 `.app` 附加票据后再重新压缩。不能继续发布提交公证之前的旧 ZIP。

输出目录为 `dist/notarized/v版本号/`。只将其中的 `NotchCopy-…-universal-notarized.zip` 和 `SHA256SUMS.txt` 作为发布附件；认证信息、提交状态文件与 Apple 日志不需要公开。

如果 Apple 处理超过等待时间，提交仍会在服务端继续，稍后执行下面的命令恢复等待，避免重复上传：

```sh
python3 Scripts/notarize.py --resume --profile 'NotchCopy-Notary'
```

随后按 `apple-notary-log.json` 检查 Apple 返回的问题或警告。即使已有 `Accepted`，也必须等票据、签名和 Gatekeeper 验证全部成功，才算可发布。

官方流程：https://developer.apple.com/documentation/security/customizing-the-notarization-workflow

## 当前边界

- 仓库中的普通 macOS CI 继续构建未公证的测试包，不声称它已获得 Apple 公证。
- 没有真实证书和认证时，本地测试只能验证执行顺序与失败阻断，不能代替 Apple 实际结果。
- 正式验收还应从 GitHub 下载最终公证包，在保持默认 Gatekeeper 设置的 Mac 上测试首次打开。正常的“来自互联网，是否打开”确认仍可能出现。
