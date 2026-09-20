# Zhang Kitchen · 张家厨房

**Version 0.2 · by Frank Zhang**

An iPhone app that turns "what's for dinner?" into a question the whole family answers once a week — and then does the shopping list, the fridge map and the recipe for you.

一款 iPhone 应用：一周只操心一次"今天吃什么"，剩下的采购清单、冰箱位置和菜谱，交给它。

---

# English

## What this app is for

Cooking for a family of five is rarely about cooking. It's the deciding, the forgetting, the second trip to the store, and the ten minutes spent looking for the ginger. Zhang Kitchen exists to take those parts away.

Once a week you sit down together for a few minutes. The app proposes seven days of breakfasts and dinners. The children swap what they don't want. You confirm. From that one decision the app produces the grocery list, tells everyone where to put the food when it comes home, and each evening shows the recipe in Chinese with the exact shelf each ingredient is sitting on.

It grew out of one particular family — five people, mild Chinese and simple Western food, dinner on the table in about half an hour, noodles and rice taking turns, children who should have a say in what they eat — but the household, the allergies and the portions are all yours to set.

## A week in five steps

The Today screen shows these five steps and where you are in them, so nobody has to remember the order.

**1. Plan the week · 排菜单**
Open **Week**, pick the starting day, tap *Plan this week's menu*. You get seven days of breakfast and dinner. The suggestions avoid spice, alternate rice and noodles, vary the protein, keep dinners around thirty minutes, never repeat a dinner within the week, and favour food you already have.

**2. Everyone chooses · 一起点餐**
Tap any meal. Each child votes, sees the picture, and can swap the dish — the six closest alternatives come first, the full catalogue is one tap further. A parent confirms each meal, or confirms all fourteen at once. Disagreement is settled by the parent, on purpose.

**3. Shop once · 一次买齐**
The **Shopping** list is built from the confirmed menu: every ingredient scaled to your family size, added up across the week, minus whatever you have already confirmed in the pantry. Names are in English and Chinese, grouped by aisle-like categories. Tick items off as you go.

**4. Put it away · 收纳归位**
After shopping, **Put away** suggests a shelf for each item based on how it needs to be stored and how your kitchen is actually laid out. Whoever puts it away confirms where it really went and how much was really bought — children can do this part. Only then does it count as pantry stock.

**5. Cook tonight · 照着做饭**
**Today** shows the day's breakfast and dinner, the recipe steps in Chinese, the amounts for your family size, and — the part that saves the most time — where each ingredient is right now. After dinner, one tap records the meal as cooked.

## Who's at the table

Add the people who live here, by name, in **Pantry → Family & storage**. Mark each one child or adult: the children are the ones who get a vote on every meal, and their names appear on the meal screen. Any number of people works — the app has no opinion about how big your family is.

Portions follow that list, and the stepper can be raised for guests.

## Allergies and foods to avoid

The same screen carries the major allergens: milk, egg, fish, shellfish, peanut, tree nuts, wheat/gluten, soy and sesame. Exclude one and it is **never recommended and never offered as a swap**. If you deliberately choose a dish that contains it, the app still lets you — and flags it clearly, on the card, in the meal review and in the recipe.

This matches ingredients, not the label in your hand. Two that surprise people: ordinary soy sauce is brewed with wheat, and most dried soba is cut with wheat flour — both are marked. Cross-contact from shared equipment is invisible to any app, so a family managing a real allergy still reads every package.

## Cooking with the seasons

Menus follow the calendar. Produce at its US seasonal peak — cheaper, better tasting, less often shipped across a hemisphere — is favoured when the week is planned, so July leans on tomatoes, zucchini, cucumbers and peaches, while January leans on cabbage, broccoli, bok choy and oranges.

Each recipe shows what is at its peak this month and what is out of season, the recipe list has an **in season this month** filter, and the browse screen names the produce that is good right now. Out-of-season food is never blocked — it is simply not pushed at you.

## What we've eaten

Every meal you mark as cooked is recorded, and whenever a planned week is replaced the old week is archived too. Open **Week → What we've eaten** to see it by week, along with the dishes that have come round most often in the last 90 days.

The record distinguishes **cooked** (someone confirmed it that day) from **planned** (it was on the menu and the week moved on). The app does not claim to know whether the second kind was eaten.

Next week's menu uses this memory: anything eaten in the last fortnight is pushed well down the list, and a dish that keeps reappearing within three months is nudged down too. About two years of meals are kept, on this iPhone only.

## Nutrition

Every recipe and every planned day shows an estimate, per person: calories, a labelled bar for protein / carbohydrate / fat, plus fibre and sodium.

- Figures come from reference values for ingredients **as bought** — raw meat, dry pasta, drained cans.
- They are not measurements of the finished dish, and cooking losses, leftovers and who eats how much are not modelled.
- Only breakfast and dinner are planned here, so a day total is **never** a claim about a whole day's needs. Lunch and snacks are outside the app.
- It is a way to compare one meal or one week against another. It is not medical or age-specific advice.

## What it deliberately does not do

Being honest about this is part of the design.

- **No automatic photo recognition.** You can photograph a shelf to jog your memory, but you confirm each ingredient yourself. A photo never decides freshness or quantity.
- **Nothing is assumed into your pantry.** Only amounts someone confirmed are subtracted from the shopping list.
- **Planning a meal does not consume ingredients.** Stock changes when you shop, put away, or finish cooking.
- **Suggested shelves are suggestions**, shown separately from the place you actually confirmed.
- **Everything stays on this iPhone.** No account, no cloud sync, no uploads. Parent and child roles are a family agreement on a shared device, not passwords.
- **Recipe pictures are AI-generated illustrations** made for this app — not photographs of tested cooking.
- **Times and nutrition are estimates**, not kitchen-tested or laboratory-measured.
- **Allergen filtering is ingredient-level**, not label-level, and cross-contact is not modelled.
- **Seasonal data is a national US generalisation.** Your local market is the better authority.

## Running it on your iPhone

1. Install the full Xcode (16 or newer) on a Mac.
2. Open `FamilyTable.xcodeproj` and choose the **FamilyTable** scheme.
3. To use a simulator, pick one and press **⌘R**. No account or API key is ever required.
4. To use a real iPhone: connect it, enable Developer Mode, then under **Signing & Capabilities** choose your own Apple team and, if needed, a unique bundle identifier. Then run.
5. The camera needs a real iPhone; the simulator can still import from Photos. Photo access uses the system picker, so only the pictures you choose ever reach the app.

## For developers

```sh
# Build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FamilyTable.xcodeproj -scheme FamilyTable -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Core logic checks (no XCTest runtime needed)
python3 scripts/check_core.py

# Regenerate the app icon
swift scripts/make_icon.swift FamilyTable/Assets.xcassets/AppIcon.appiconset/icon-1024.png 1024
```

- `FamilyTable/` — SwiftUI screens, the `Brand` design system, and recipe images.
- `Sources/FamilyCore/` — recipes, ingredients, nutrition tables and all planning logic, free of UI.
- `Tests/` — core scenarios and UI tests. `scripts/check_core.py` runs the core scenarios without XCTest, which this machine's default toolchain cannot import; it compiles every file in `Sources/FamilyCore` automatically.
- The icon is drawn in Core Graphics by `scripts/make_icon.swift`, and `BrandMark` in `FamilyTable/Brand.swift` redraws the same 1024-unit coordinates in SwiftUI, so the home-screen icon and the in-app mark stay identical.
- Note that `swiftc -parse` only checks syntax, never call signatures. Use the `xcodebuild` command above after touching SwiftUI.
- Saved files are versioned and migrated on load (`FamilyState.currentVersion`, `migrate()`): older files open and are upgraded, and a file written by a *newer* app is refused rather than overwritten. Add fields freely; add a conversion to `migrate()` whenever the shape of existing data changes.
- Current scope: one active week at a time, on one device. No cloud sync, list export, store grouping, barcode scanning, custom recipes or custom ingredients. 56 dinners, 20 breakfasts, 79 bilingual ingredients with nutrition, allergen and seasonality tables.
- Still on the list before selling: custom recipes, real food photography, cooking every recipe to verify the times, CloudKit family sharing, dark mode, and App Store paperwork (privacy labels, policy URL, listing).
- **Not yet accepted on a device.** It compiles, and the core logic is covered by 28 scenarios and ~4,000 assertions, but launch, layout, camera and full interaction have not been signed off on a real iPhone.

## Food safety

The app links to these rather than guessing at shelf life from a photo:

- [FDA · Are You Storing Food Safely?](https://www.fda.gov/consumers/consumer-updates/are-you-storing-food-safely)
- [FDA · Safe Food Handling](https://www.fda.gov/food/buy-store-serve-safe-food/safe-food-handling)
- [FoodSafety.gov · Cold Food Storage Charts](https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts)

Fridge ≤ 40°F / 4°C, freezer ≤ 0°F / −18°C. Freeze raw meat and fish meant for later in the week, and move it to the fridge to thaw in advance.

---

# 中文

## 这个应用是做什么的

给五口之家做饭，难的往往不是做饭本身，而是决定吃什么、忘了买什么、再跑一趟超市，以及找生姜花掉的那十分钟。张家厨房就是来拿掉这些部分的。

每周全家只需坐下来几分钟：应用先排出七天的早餐和晚餐，孩子把不想吃的换掉，家长确认。从这一次决定出发，应用会生成采购清单，告诉大家买回来的东西该放哪里，并在每天傍晚显示中文菜谱，以及每样食材此刻放在哪一层。

它源于一个具体的家庭：五口人、不辣的中餐和简单西餐、晚餐大约半小时上桌、面食与米饭轮换，以及应该对吃什么有发言权的孩子——但家庭成员、过敏设置和份量都可以按你自己的情况来定。

## 一周五步

Today 页会显示这五步和你当前所在的位置，不需要记顺序。

**1. 排菜单 · Plan the week**
打开 **Week**，选择起始日，点 *Plan this week's menu*，得到七天早餐和晚餐。推荐会避开辣味、米面轮换、蛋白质来源有变化、晚餐控制在半小时左右、一周内晚餐不重复，并优先用上家里已有的食材。

**2. 一起点餐 · Everyone chooses**
点任意一餐：孩子看图投票，也可以换菜——最合适的六个备选排在前面，全部菜品再点一下就能展开。家长逐餐确认，或一次确认全部十四餐。出现分歧时由家长决定，这是有意的设计。

**3. 一次买齐 · Shop once**
**Shopping** 清单由确认后的菜单生成：每样食材按家庭人数缩放、跨菜合并，再减去你已在储藏中确认的数量。中英文对照，按类别分组，买的时候逐项打勾。

**4. 收纳归位 · Put it away**
买完后，**Put away** 会结合储存要求和你家的真实布局，为每件物品建议位置。谁收纳谁确认实际放在哪里、实际买了多少——这一步孩子可以做。确认之后才算入库存。

**5. 照着做饭 · Cook tonight**
**Today** 显示当天的早餐和晚餐、中文步骤、按家庭人数的用量，以及最省时间的那一项：每样食材现在放在哪里。吃完后一点即可记录为已完成。

## 家里有谁

在 **Pantry → Family & storage** 中按名字添加家庭成员，并标记为孩子或成人：孩子会出现在每一餐的投票中，显示的是他们自己的名字。人数不限，应用不预设家庭规模。

份量按这份名单计算，有客人时可以用步进器临时调高。

## 过敏与忌口

同一页可以设置主要过敏原：奶、蛋、鱼、甲壳类、花生、坚果、小麦／麸质、大豆、芝麻。勾选后，含该过敏原的菜**不会被推荐，也不会出现在换菜选项里**。如果你主动选择含该过敏原的菜，应用仍然允许，但会在卡片、选餐页和菜谱中明确标注。

这是按食材匹配，不是按你手上的包装标签。两处容易被忽略：普通生抽是用小麦酿造的，市售干荞麦面通常也掺了小麦粉，两者都已标记。共用设备造成的交叉污染是任何应用都看不到的，真正有过敏的家庭仍需逐一查看包装。

## 顺着时令做饭

菜单会跟着季节走。处于美国应季高峰的果蔬——更便宜、更好吃、也更少需要长途运输——在排菜单时会被优先考虑：七月偏向番茄、西葫芦、黄瓜和桃子，一月偏向卷心菜、西兰花、小白菜和橙子。

每道菜会显示本月哪些食材正当季、哪些已过季；菜品列表有 **in season this month（只看应季）** 筛选；浏览页会列出当下最好的时令食材。非应季的食材不会被禁止，只是不会被主动推荐。

## 吃过什么

每一餐点了"已完成"都会被记录；替换旧的周计划时，旧的一周也会归档。打开 **Week → What we've eaten**，可以按周查看，并看到近 90 天里出现最频繁的菜。

记录区分**已完成**（当天有人确认做了）和**已排入**（当时在菜单上，然后这一周过去了）。应用不会假设后者一定吃过。

排下周菜单时会用上这份记忆：最近两周吃过的会被明显往后排，三个月内反复出现的也会被下调。记录保留约两年，只存在这台 iPhone 上。

## 营养

每道菜、每个已排好的日子，都会显示每人的估算：热量，带文字标签的蛋白质／碳水／脂肪比例条，以及膳食纤维和钠。

- 数值来自食材**购买状态**的参考值——生肉、干意面、沥干的罐头。
- 这不是成品菜的实测值，烹饪损耗、剩菜、每个人实际吃多少都没有计入。
- 这里只安排早餐和晚餐，所以一天的合计**绝不**代表全天所需。午餐和零食不在本应用范围内。
- 它适合用来比较不同餐次或不同周之间的差异，不能作为医学建议或按年龄的营养指导。

## 刻意不做的事

把这些说清楚，本身就是设计的一部分。

- **不做照片自动识别。** 可以拍下冰箱帮助回忆，但每样食材由你自己确认。照片不判断新鲜度和数量。
- **不替你假设库存。** 只有确认过的数量才会从采购清单中扣除。
- **只是排进菜单不会消耗食材。** 库存只在采购、收纳、做完饭时变化。
- **建议位置只是建议**，与你实际确认的位置分开显示。
- **数据全部留在这台 iPhone 上。** 没有账号、云同步或上传。家长与孩子的角色是共用设备上的家庭约定，不是密码账户。
- **菜品图片是为本应用生成的 AI 示意图**，不是实拍。
- **时间与营养都是估算**，没有经过厨房实测或实验室测定。
- **过敏原按食材判断**，不是按包装标签，也不考虑交叉污染。
- **时令数据是美国全国性的概括**，当地市场永远更准确。

## 在 iPhone 上运行

1. 在 Mac 上安装完整版 Xcode（建议 16 或更新）。
2. 打开 `FamilyTable.xcodeproj`，选择 **FamilyTable** scheme。
3. 用模拟器：选好设备后按 **⌘R**。全程不需要注册账号或填写 API key。
4. 用真机：连接 iPhone 并开启开发者模式，在 **Signing & Capabilities** 中选择自己的 Apple Team，必要时改一个唯一的 Bundle Identifier，然后运行。
5. 相机功能需要真机；模拟器可以测试从"照片"导入。照片使用系统选择器，只有你选中的图片会进入应用。

## 开发者信息

```sh
# 编译
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FamilyTable.xcodeproj -scheme FamilyTable -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# 核心逻辑检查（不需要 XCTest 运行环境）
python3 scripts/check_core.py

# 重新生成应用图标
swift scripts/make_icon.swift FamilyTable/Assets.xcassets/AppIcon.appiconset/icon-1024.png 1024
```

- `FamilyTable/`：SwiftUI 页面、`Brand` 设计系统与菜品图片。
- `Sources/FamilyCore/`：菜谱、食材、营养表与全部排菜逻辑，不含 UI。
- `Tests/`：核心场景与 UI 测试。`scripts/check_core.py` 在不依赖 XCTest 的情况下运行核心场景（本机默认工具链无法导入 XCTest），并自动编译 `Sources/FamilyCore` 下的所有文件。
- 图标由 `scripts/make_icon.swift` 用 Core Graphics 绘制，`FamilyTable/Brand.swift` 中的 `BrandMark` 用同一套 1024 坐标在 SwiftUI 里重绘，因此主屏图标与应用内标识完全一致。
- 注意 `swiftc -parse` 只检查语法，不检查调用签名。改动 SwiftUI 后请用上面的 `xcodebuild` 验证。
- 存档带版本号并在读取时迁移（`FamilyState.currentVersion`、`migrate()`）：旧文件会被打开并升级；由**更新版本**写入的文件会被拒绝而不是覆盖。新增字段可以随意添加；既有数据的结构发生变化时，请在 `migrate()` 中补上转换逻辑。
- 当前范围：单设备、单个进行中的周计划。没有云同步、清单导出、按商店分组、条码扫描、自建菜谱与自建食材。共 56 套晚餐、20 套早餐、79 种双语食材，并配有营养、过敏原与时令数据。
- 上架前仍待完成：自建菜谱、真实菜品摄影、逐道实测烹饪时间、CloudKit 家庭共享、深色模式，以及 App Store 材料（隐私标签、隐私政策链接、商店页面）。
- **尚未在设备上完成验收。** 可以编译，核心逻辑有 28 个场景约 4000 条断言覆盖，但启动、布局、相机与完整交互还没有在真机上逐项确认。

## 食品安全

应用不会根据照片猜测保质期，而是链接到以下权威资料：

- [FDA · 安全储存食物](https://www.fda.gov/consumers/consumer-updates/are-you-storing-food-safely)
- [FDA · 食品安全操作](https://www.fda.gov/food/buy-store-serve-safe-food/safe-food-handling)
- [FoodSafety.gov · 冷藏储存时间表](https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts)

冷藏 ≤ 40°F / 4°C，冷冻 ≤ 0°F / −18°C。本周后几天才用的生肉和鱼请及时冷冻，并提前移到冷藏室解冻。
