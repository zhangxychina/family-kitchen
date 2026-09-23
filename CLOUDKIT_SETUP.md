# iCloud 家庭共享：配置与验收

第一版代码位于 `feature/icloud-family-sharing`。无需自建服务器或应用密码，使用设备已登录的 iCloud 账号。尚未连接家庭时，原有本机功能保持可用。

## 开发者配置

1. 安装完整 Xcode 及 iOS SDK，打开 `FamilyKitchen.xcodeproj`，选择 FamilyKitchen target。
2. 在 Signing & Capabilities 中选择自己的 Apple Developer Team，并设置该 Team 可用的 Bundle Identifier。
3. 添加 iCloud capability，勾选 CloudKit，创建或选择该 Team 的容器。本仓库已配置为 `iCloud.com.zhangxychina.familykitchen`（Bundle ID `com.zhangxychina.familykitchen`，Team `2HKWUJYXM7`）；换用其他账号时，三者都需在 `scripts/create_project.py` 中改成自己的。注意：`com.familykitchen.app` 已被他人注册，不能使用。
4. 将 Debug 和 Release 的 `CLOUDKIT_CONTAINER_IDENTIFIER` 都设置为实际容器 ID。`FamilyKitchen.entitlements` 和 `Info.plist` 均引用此变量，必须保持一致。若修改工程生成器配置，也更新 `scripts/create_project.py`，防止重新生成工程后丢失设置。
5. 保持 `CKSharingSupported = YES`。应用通过 SwiftUI AppDelegate + SceneDelegate 同时接收冷启动和运行中的共享邀请。
6. 在两台 iPhone 上分别登录不同 iCloud 账号，启用应用的 iCloud 访问，用同一 Team、Bundle ID、容器和 CloudKit 环境签名安装。
7. 在 Development 环境创建一次家庭以初始化 schema；在 CloudKit Console 中检查 `FamilyKitchen` record type 的 `name`（String）和 `state`（Asset）字段以及系统分享记录。向 TestFlight / App Store 发布前，把开发 schema 部署到 Production；开发数据不会自动复制到 Production。

应用内有设置向导：**Kitchen → ⚙︎ Settings → Family sharing**。它会先检查两件在上传任何数据之前就能确认的事——本机是否登录 iCloud、此版本能否访问上面第 3–4 步配置的 CloudKit 容器——并分别给出明确说明（前者由家人在系统设置中解决，后者由开发者在 Xcode 中解决）。两项都通过之前，"创建家庭/查找家庭"保持不可用。

已在 Xcode 27 + iOS 27 模拟器上完成：整包构建、72 条核心场景、17 条界面测试（含家庭共享设置流程、无 iCloud 账号时应用完整可用）。**仍未完成**：双 iCloud 账号的真实云端验收，见文末清单。

## 如何使用

- 所有者：Kitchen → Settings → Family sharing → 用当前厨房创建家庭 → 邀请与管理成员。
- 系统共享面板只允许私人邀请，可向成员授予读写权限。家庭组不等于苹果“家人共享”，双方不必属于同一个苹果家庭组。
- 受邀者：打开收到的 iCloud 链接 → 确认加入。当前本机厨房单独保留，不会自动混入受邀家庭。
- 重装／换机：先在本机打开“查找我的家庭”，再选择连接。扫描私人数据库和共享数据库中的项目专用 zone。
- 每台设备同时连接一个家庭。系统面板管理成员、停止共享或退出；“返回本机厨房”仅断开此设备并恢复原本机厨房，不撤销云端成员关系。

## 同步设计与边界

- 所有者使用私人 CloudKit 数据库，受邀成员使用共享数据库；每个所有者使用固定 `FamilyKitchen-v1` zone 和 `Kitchen` 根记录。根记录与 `CKShare` 原子创建，私人分享不开放 public access。
- v1 将共享厨房保存为一个 CKAsset 快照，以 `.ifServerRecordUnchanged` 条件写入。用同一记录承载关联数据，让采购、入库等操作在云端原子提交。
- 本地保存 `icloud-session.json`，同时包含工作副本、上次确认的云端祖先、账号及记录引用。每次保存原子替换该文件；退出或进程被杀后，未同步修改仍在。
- 原 `family.json` 作为独立的本机厨房保留。连接／断开／解决冲突前，将相关版本保存到 Application Support/FamilyKitchen/Backups 下。备份不上传、不自动删除，当前没有备份管理 UI。
- 上传时三方比较祖先、本机和云端版本。厨房事务（菜单、库存、采购、菜谱、储藏位置等）作为一个关联区域；家庭资料和厨房名称可独立合并。同一区域不同修改会提示选择整个本机或云端版本，并备份双方。不会自动相加库存或重复采购；取舍粒度较粗，属于第一版有意保守的设计。
- 数据上传在本地修改后短暂防抖；前台每 30 秒拉取，回到前台和手动同步也会拉取。没有后台推送订阅，不承诺即时同步。网络恢复后前台周期重试。
- 写入期间的新修改会再次基于已确认云端版本合并，未确认的修改保持待同步。服务器版本冲突会保留本机队列，供下次重新拉取；业务冲突则暂停并要求选择。
- 共享照片和显示偏好被排除。语音识别仍在本机；确认后的业务改动会作为厨房数据同步。
- 重启后会核对 iCloud 身份，但**核对期间照常显示本机已有的共享副本**：数据本来就在这台设备上，看不等于泄露；需要等待确认的是**上传**（`sync` 只在 `verify` 成功后写入）。离线冷启动可以正常使用，状态栏显示"离线，使用本机副本"，期间的修改保存在本机，能连上后再上传。只有在账号**确实变更**或权限被收回时，才隐藏共享厨房并停止编辑，绝不把旧数据上传到新账号。
- 本机备份最多保留 20 份（`FamilyCloudController.backupsKept`），按时间命名，超出后删除最旧的；设置页会显示当前份数。备份不上传。
- v1 使用 CloudKit 的所有者／成员权限；没有独立的儿童登录权限、所有权转移、多家庭同时编辑或照片共享。

## 双账号验收清单（待实际执行）

1. A 有现有菜单、库存和照片，创建家庭；验证 B 在加入前无法读取，A 可发私人邀请。
2. B 在 App 已运行和被终止两种情况下打开邀请；确认加入，验证 B 原本机厨房可恢复。
3. A 换菜，B 前台 30 秒内或手动刷新后看到相同菜单和采购；B 采购、入库，A 看到一致库存。
4. A/B 同时离线修改采购，再上线：出现明确冲突，不重复计算；分别验证采用云端和保留本机，双方备份存在。
5. A 改厨房名称、B 改库存：可自动合并。上传期间继续修改，重启后修改仍保留并最终同步。
6. 断网编辑，强制终止，重新启动后恢复网络和身份验证；本机待同步修改不能丢失。
7. 取消邀请面板、取消加入、接受邀请后网络中断、创建请求超时后重试，不应重复建家庭或覆盖原本机数据。
8. 所有者移除 B；B 刷新后不能继续访问或上传。B 切换 iCloud 账号，旧家庭数据不展示、不上传到新账号。
9. 恢复已有家庭、断开本机连接、停止共享后重新邀请；验证数据和成员权限符合界面说明。
10. A/B 使用不同语言和外观，上传后仍保持各自设置；检查 CKAsset 内没有照片路径或显示偏好。
11. 使用 Production schema 的 TestFlight 构建重新验证邀请和同步，不能只测 Development 环境。

## 本地验证命令

```sh
python3 scripts/check_core.py
swiftc -swift-version 5 -typecheck -module-cache-path /tmp/family-cloud-module-cache Sources/FamilyCore/*.swift FamilyKitchen/FamilyCloudController.swift
swiftc -frontend -parse FamilyKitchen/*.swift
plutil -lint FamilyKitchen/Info.plist FamilyKitchen/FamilyKitchen.entitlements FamilyKitchen.xcodeproj/project.pbxproj
```

完整 Xcode 环境还需要运行：

```sh
xcodebuild -project FamilyKitchen.xcodeproj -scheme FamilyKitchen -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build-for-testing
```

然后用实际签名的双设备构建完成上面的验收。
