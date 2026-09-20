# Zhang Family Kitchen · 张家厨房

**版本 0.1 · 作者 Frank Zhang**

原生 SwiftUI iPhone 首版，iOS 17+。实际工程目录：`/Users/frank/Documents/Claude_Projects/Zhang_Family_Kitchen`。没有网页替代品，没有第三方依赖或服务购买。

应用图标与 App 内标识由 `scripts/make_icon.swift` 用 Core Graphics 直接绘制（一碗热饭 + 筷子，深绿底），`FamilyTable/Brand.swift` 中的 `BrandMark` 用同一套坐标在 SwiftUI 里重绘，因此主屏图标和 Today 页顶部标识完全一致。重新生成：

```sh
swift scripts/make_icon.swift FamilyTable/Assets.xcassets/AppIcon.appiconset/icon-1024.png 1024
```

## 点餐与采购主线（0.1 新增）

以前"排下周菜单"只是 Week 页里一个不显眼的按钮。现在是一条明确的三步主线：

1. **Plan（排菜单）**：Today 页在没有当日安排时直接给出 **Plan next week's menu** 按钮；Week 页在未排菜单时显示大卡片，选起始日后点 **Plan this week's menu · 生成一周菜单**，得到连续七天早餐与晚餐。
2. **Order（点餐确认）**：Week 页顶部显示周区间与"已确认 X/14"进度条。点任意一餐可投票、换菜或 **Confirm this meal · 确认这一餐**；也可以一次 **Confirm all 14 meals**。换菜页先给 6 个最合适的备选（不辣、快手、本周未重复），再按需展开全部选项，可选打开辣味。
3. **Shop（采购）**：Week 页底部 **Build my shopping list · N items to buy** 直接跳到 Shopping 页；Shopping 页顶部写明"这是哪一周菜单的清单、还有几样要买"，清单为空时也给出返回排菜单的按钮。未确认的餐仍会标注清单为临时状态。

## 在 iPhone / 模拟器运行

1. 在 Mac 安装完整 Xcode（建议 Xcode 16 或更新；核心 Package 测试需要支持 Swift 6 的工具链），并安装 iOS Simulator runtime。
2. 用 Xcode 打开 `FamilyTable.xcodeproj`，选择 **FamilyTable** scheme。
3. 选择 iPhone 模拟器，按 **⌘R**。首次无需注册账号或填写 API key。
4. 真机：连接 iPhone，打开 Developer Mode；在 target 的 **Signing & Capabilities** 选择自己的 Apple Team，必要时改成唯一 Bundle Identifier，再选择设备运行。无需发布 App Store。
5. 相机功能需真实 iPhone；模拟器可测试 Photos 导入。照片权限采用系统 PhotosPicker，仅选中的照片会进入本地 App。

有完整 Xcode 时也可构建：

```sh
xcodebuild -project FamilyTable.xcodeproj -scheme FamilyTable -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## 首次体验流程

1. **Pantry → Family & storage settings**：默认五人，可调六人；按真实布局添加冷藏层、抽屉、酸奶区、门格、冷冻柜、常温柜等，选择温区。系统不预设真实位置。
2. **Pantry**：导入数张照片或拍照；点照片查看，再手动确认食材、实际数量和位置。相同食材+位置替换总量，避免重复入账。未确认数量不抵扣。
3. **Week**：默认下周一，可改起始日，点 **Plan this week's menu · 生成一周菜单**，生成连续七天早餐/晚餐。推荐考虑不辣、整餐时间、喜欢的菜、主食交替、库存和七种不重复晚餐。早餐从20套中轮换，不声称了解孩子偏好。
4. 点某餐，三个孩子分别投票、看图换菜；家长逐餐确认，或在 Week 页一次确认全部。换菜清空原投票与确认，采购自动重算。连续同主食或超出时间目标会提示。
5. **Shopping**：双语分类清单，人数缩放、跨菜合并、扣确认库存。标记购买后数量留在待收纳状态，可 Undo。
6. **Put away**：区分建议位置与实际位置；确认实际购买数量和放置处才入库存。孩子放好后可一起确认。额外采购量保留为库存。
7. **Today / Recipes**：直接查每样食材的实际位置。做完饭后选择扣除配方量或仅标记完成；剩余和实际用量差异在 Pantry 点库存修正。

## 已交付

- 五个原生页面与收纳、设置、选餐详情；温暖奶油色/绿色配色、菜品图片卡片、自绘应用图标与品牌标识。
- 排菜单 → 逐餐确认 → 采购清单的引导式主线，各页之间可直接跳转。
- 56 套完整晚餐、20 套早餐、79 种统一双语食材/调料；每套都有中文步骤、份数和整餐时间；70 张 AI 菜品示意图已全部入库，完整清单见 `MENU_CATALOG.md`。
- 晚餐均配主食、蛋白质与蔬菜；蛋白来源含鸡、牛、鱼、蛋、豆腐。仅规划早餐晚餐，不保证全天或特定年龄营养。
- 规则推荐无未配置 AI 依赖；照片全留本机，识别接口明确抛出未配置错误。
- JSON 原子持久化；保存失败显式提示，损坏存档不静默覆盖。数量、位置、投票、购物、收纳、照片列表均持久化。
- 已购、已收纳、已做饭为独立状态；仅安排菜单不消耗库存。

## 验证与实际限制

本轮已增加早餐/晚餐筛选、60周推荐覆盖回归、相机权限拒绝提示、照片后台处理及独立 UI 测试目标。完整菜单见 `MENU_CATALOG.md`，设备验收阻塞与步骤见 `DEVICE_ACCEPTANCE.md`。

0.1 已用 Xcode 27 对 iOS Simulator SDK 完成整体编译，`** BUILD SUCCEEDED **`：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FamilyTable.xcodeproj -scheme FamilyTable -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

系统默认开发路径仍指向 Command Line Tools，因此命令里显式指定 `DEVELOPER_DIR`；标准 `swift test` 在该环境导入 XCTest 时仍被阻止。提供 `scripts/check_core.py`，用原有 XCTest 场景生成独立 Swift 断言运行器，不依赖 XCTest；执行记录见 `VALIDATION.md`。注意 `swiftc -parse` 只检查语法，不检查调用签名——0.1 就曾因此漏掉一处 `LabeledContent` 参数标签错误，改动 SwiftUI 后应以上面的 `xcodebuild` 为准。**编译通过不等于验收：启动、布局、相机及完整交互仍未在模拟器或 iPhone 上逐项确认。**

```sh
python3 scripts/check_core.py
# 完整 Xcode 环境下：
swift test
```

当前范围限制：单机一份活动周计划，无云同步、历史周管理、购物导出、商店分组、条码/自动视觉识别、营养素精算、年龄档案、任意自建菜谱与自建食材。手动库存支持内置79种食材。推荐从50套不辣完整晚餐模板中逐日安排一周，不是自由组合多道独立菜；寿司未加入。每次重建计划会确认替换，但保留购买记录和库存。家长/孩子是共享设备上的协作角色，没有 PIN 身份验证。照片删除与存档恢复界面尚未加入。

菜谱时间是5–6人的估计，需速煮米、已解冻食材、双灶并行；超过6人提示额外时间，尚未经家庭实测。食材量按人数等比例并对个/片每餐向上取整，不能代替儿童按年龄的实际分量调整。默认食材储存区仅针对通常包装状态，开封后按标签；收纳时请冻结稍后几天使用的生肉/鱼并提前冷藏解冻。

图片由内置 image_gen 工具逐道生成，已完成的图片均标记 AI 成品示意图；不是占位素材或菜谱实拍。完整生成提示及本地资源清单见 `IMAGE_PROVENANCE.json`。视觉主料已逐图人工检查，细小装饰不作为采购依据。

## 储存安全依据

- [FDA 安全储存食物](https://www.fda.gov/consumers/consumer-updates/are-you-storing-food-safely)：冷藏温度、不依赖外观判断安全。
- [FDA 食品安全操作](https://www.fda.gov/food/buy-store-serve-safe-food/safe-food-handling)：生熟分开、温度计、解冻。
- [FoodSafety.gov 冷藏时间表](https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts)：不同食材储存期限；应用内提供链接，不根据照片猜保鲜期。

## 工程结构

`FamilyTable/` 为 SwiftUI 与图片资源；`Sources/FamilyCore/` 为共享业务逻辑与内置菜谱；`Tests/FamilyCoreTests/` 为测试；`scripts/create_project.py` 可重建工程文件。没有账号凭证或上传端点。迁移时已逐文件 SHA-256 校验，新目录与原文件完全一致后移除旧副本。

## 可选辣味湘菜与川菜

新增湘味辣椒炒肉、小炒牛肉、剁椒鱼柳，以及川味麻婆豆腐、宫保鸡丁、鱼香肉丝，共6套家常整餐。Recipes 的 Flavor 菜单可筛选湘菜/川菜，卡片与详情标注辣度；默认推荐始终保持不辣，收藏辣菜也不会自动纳入。Week 中可主动换入辣菜，按家庭人数计入采购；换菜页明确提示辣味。详情 View portions 可查看1–12人用量，仅用于查看，不改变周计划采购人数。单独给一人做的额外餐尚不能独立排入同一天计划。新增6套以菜系标识展示，尚无菜品图片，原70张图片保留。辣度取决于辣椒品种和品牌，步骤提供减辣方式。
