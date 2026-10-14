# 校园食堂菜单整理台

鸿蒙 PC 校园应用选题 **096 校园食堂菜单整理台** 的可运行原型工程。

> 主题要求：录入每日菜单、价格和个人偏好；在大屏上对比选择并规划一周餐单。

工程为 **纯本地** 实现：不需要账号、不需要服务端，数据保存在本机 preferences 中，符合选题文档里「原型方式说明」对「本地」的定义。

---

## 一、用 DevEco Studio 打开

1. 打开 DevEco Studio（建议 **5.0.0 Release 及以上**，HarmonyOS SDK **API 12+**）。
2. `File → Open`，选择本目录 `CanteenMenuPlanner`（**选择含 `build-profile.json5` 的那一层**，不要选到 `entry`）。
3. 等待首次 `Sync` 完成（会下载 hvigor 依赖，需要联网）。
4. 配置自动签名：`File → Project Structure → Signing Configs → 勾选 Automatically generate signature`（需登录华为开发者账号）。
5. 选择设备后点运行：
   - 有鸿蒙 PC / 2in1 设备或模拟器 → 直接运行，界面为「左侧导航 + 大屏三栏」布局；
   - 只有手机模拟器 → 也能跑，宽度小于 840vp 时自动切换为「底部标签栏」布局。

### 版本不匹配怎么办（兜底方案）

本工程按 **API 12 / hvigor 5.0.0** 生成。如果你的 DevEco 版本或 SDK 版本不同：

- 只改根目录 `build-profile.json5` 里的 `compatibleSdkVersion`（例如 `"5.0.5(17)"`、`"6.0.0(20)"`），保持同一格式 `"版本号(API号)"`；
- 若 `Sync` 报 hvigor 版本不存在，打开 `hvigor/hvigor-config.json5`，把 `hvigorVersion` 与 `dependencies` 里的 `@ohos/hvigor-ohos-plugin` 改成 DevEco 提示的版本，或直接让 IDE 的「Sync」自动修复；
- **最稳妥的方式**：用 DevEco 新建一个 `Empty Ability` 模板工程（选择 `2in1` 设备类型），然后把本工程的 `entry/src/main` 整个目录覆盖过去，再覆盖 `AppScope/app.json5`。业务代码不需要任何改动。

---

## 二、工程结构

```
CanteenMenuPlanner
├── AppScope/app.json5                       应用级配置（包名、版本、图标）
├── build-profile.json5                      编译 SDK / 产物配置
├── hvigor/hvigor-config.json5               hvigor 版本
└── entry/src/main
    ├── module.json5                         模块配置（deviceTypes 含 2in1 / tablet / phone）
    ├── resources/base/...                   字符串、颜色、图标、页面路由
    └── ets
        ├── entryability/EntryAbility.ets    入口：先装载本地数据，再加载界面
        ├── model/Models.ets                 Dish / Preference / PlanSlot 与常量
        ├── common
        │   ├── DateUtil.ets                 周视图日期计算（周一为一周起点）
        │   ├── Theme.ets                    统一配色
        │   └── Store.ets                    数据仓库：增删改查 + 持久化 + 推荐算法
        ├── view
        │   ├── WeekPlanView.ets             ★ 周餐单规划（大屏 3×7 网格 + 候选 + 概览）
        │   ├── MenuInputView.ets            菜单录入（单条 + 键盘批量）
        │   ├── PreferenceView.ets           个人偏好设置
        │   └── TagChip.ets                  可选中标签胶囊
        └── pages/Index.ets                  主框架（响应式导航）
```

---

## 三、功能对照选题要求

| 要求 | 实现位置 |
| --- | --- |
| 录入每日菜单 | 「菜单录入」→ 选日期（本周 7 天 + 上下周）→ 选餐次 → 填菜名/价格/食堂/标签 |
| 录入价格 | 同一表单的「价格」输入框；批量录入格式为 `菜名,价格`（每行一条） |
| 录入个人偏好 | 「我的偏好」→ 喜欢的口味标签、忌口标签、单餐价格上限、每周预算 |
| 在大屏上对比选择 | 「周餐单」左区为 3 行（早/午/晚）× 7 列（周一~周日）网格；点任意格子，右区按**偏好匹配度排序**列出候选菜品，并标注「推荐」/「偏离偏好」 |
| 规划一周餐单 | 逐格选择或点「自动排餐单」一键填充；底部实时显示本周花费、日均花费、已安排格数、偏好命中率 |

### 几个刻意做的 PC 端特性

- **大屏信息密度**：7 天 × 3 餐一次铺满，右侧常驻概览与候选，不用来回翻页。
- **键鼠效率**：批量录入支持键盘逐行敲 `菜名,价格`，一次提交多道菜。
- **窗口自适应**：窗口宽度跨过 840vp 时，布局在「左侧导航」和「底部标签栏」之间自动切换（`Index.ets` 的 `onAreaChange`）。
- **预算可视化**：超单餐上限的价格标红，整周超预算时给出文字提醒。

### 推荐算法（`Store.ets`）

- 打分：命中喜欢标签 `+2`，命中忌口 `-4`，价格不超单餐上限 `+1`、超了 `-2`。
- 自动排餐：按打分从高到低取菜，跳过本周已用过的菜，并尽量不让当天花费超过「周预算 ÷ 7」。

---

## 四、数据存储

- 使用 `@kit.ArkData` 的 `preferences`，库名 `canteen_menu_store`，三个键：`dishes` / `preference` / `plan`。
- 内存数据在 `DataStore`（静态字段），通过 `AppStorage` 暴露给 UI，UI 用 `@StorageLink` 订阅，写入时整体替换数组以触发刷新。
- **首次启动会自动灌入一周示例菜单**（7 天 × 3 餐），可以直接看到效果；在「菜单录入」里删除或清空即可换成自己的数据。

---

## 五、可以继续扩展的方向

1. 菜品图片（`Image` + 本地相册选择）与图片对照选择。
2. 多周历史餐单留存、按食堂做花费统计。
3. 营养维度（热量/蛋白）打标签，和预算一起做多目标推荐。
4. 导出本周餐单为表格文件，或复制到剪贴板。

---

## 六、说明

`.tools/gen_icons.py` 是生成 `app_icon.png` / `startIcon.png` 等占位图标的脚本（纯标准库，可直接删）。正式提交时可替换为设计好的图标资源，保持文件名不变即可。
