# 验证记录 · Validation record

Family Kitchen 0.3。菜单：56 套晚餐 + 20 套早餐，全部中英文对照步骤；配图 70/76（6 套辣菜暂无配图）。

## 核心逻辑回归 · Core logic

`python3 scripts/check_core.py` —— 用原有 XCTest 场景生成独立 Swift 断言运行器，不依赖 XCTest（本机默认工具链无法导入 XCTest）。脚本会自动编译 `Sources/FamilyCore` 下的所有文件。

```text
PASS testScalingAndAggregation
PASS testPurchasedAndStoredNeverDoubleCount
PASS testReplaceRecomputesAndClearsVotes
PASS testPlanDailyAndBalanced
PASS testCookDeductsOnlyOnceAndConfirmedStockOnly
PASS testConfirmDuplicateReplacesTotal
PASS testPersistenceRoundTripAndCorruption
PASS testWarningsAndCatalogIntegrity
PASS testDiscreteUnitsRoundedPerMeal
PASS testNewPlanKeepsPurchasedGroceries
PASS testRecognitionDoesNotInventResults
PASS testExpandedCatalogCountsAndIdentifiers
PASS testSpicyMealsAreOptInAndScaleForOne
PASS testRotationUsesWholeCatalog
PASS testConsecutiveWeeksVaryAndMaintainProteinRange
PASS testAllSwapsScaleAndPreservePurchasedGroceries
PASS testInvalidPersistentDataIsRejected
PASS testApprovalProgressAndConfirmAll
PASS testSwapOptionsStayInSlotAndAvoidRepeats
PASS testEveryIngredientHasReferenceNutrition
PASS testMealNutritionIsPerPersonAndPlausible
PASS testDayAndWeekNutritionCoversPlannedMealsOnly
PASS testOldSavedFileMigratesInsteadOfBreaking
PASS testFileFromANewerAppIsRefusedRatherThanOverwritten
PASS testAllergenExclusionsRemoveMealsEverywhere
PASS testSeasonTableIsSaneAndPlanningFollowsTheMonth
PASS testHistoryRecordsMealsAndDiscouragesRepeats
PASS testEveryRecipeIsFullyBilingual
PASS testRecipeLanguagePreferenceSelectsText
PASS testPortionsFollowAdultsChildrenAndGuests
PASS testKitchenNameIsTheFamilysOwn
PASS testImportReadsSchemaRecipeFromAPage
PASS testFamilyAddedDishesBehaveLikeAnyOther
PASS testNoConsumptionWhenPlanningOrSkippingDeduction
34 scenarios passed; 4294 assertions.
```

覆盖范围包括：份量按成人份缩放与采购汇总、购买与收纳不重复计数、换菜重算、存档迁移与版本拒绝、过敏原过滤、时令推荐、饮食历史与重复惩罚、营养表一致性、全部菜谱双语步骤与安全温度、网页导入解析、自建菜品的保存与删除。

## 编译 · Build

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FamilyTable.xcodeproj -scheme FamilyTable -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

结果：`** BUILD SUCCEEDED **`。

注意：`swiftc -parse` 只检查语法，不检查调用签名，不能替代上面的 `xcodebuild`。

## 尚未验证 · Not verified

- 本机未安装 iOS Simulator runtime，UI 测试与界面观感均未实际运行。
- 真机启动、布局、相机、深色模式、网页导入与完整交互尚未验收，见 `DEVICE_ACCEPTANCE.md`。
- 菜谱时间与营养为估算值，未经厨房实测或实验室测定。
