import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor } from '../common/Theme';
import { DataStore } from '../common/Store';
import { shortDate, weekDatesByOffset, WEEK_LABELS } from '../common/DateUtil';
import { Dish, mealLabel, MEAL_TYPES, Preference, PlanSlot } from '../model/Models';

const DOMAIN: number = 0x0000;

/**
 * 周餐单规划（核心页面）
 * 大屏布局：左侧 3×7 周视图，右侧候选菜品 + 本周概览
 */
@Component
export struct WeekPlanView {
  @StorageLink('dishes') dishes: Dish[] = [];
  @StorageLink('plan') plan: PlanSlot[] = [];
  @StorageLink('preference') preference: Preference = new Preference();

  @State weekOffset: number = 0;
  @State pickingDate: string = '';
  @State pickingMeal: string = '';
  /** 统一弹窗提示：走 UIContext 的 PromptAction，替代已废弃的全局 showToast */
  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
      hilog.error(DOMAIN, 'Toast', 'showToast failed');
    }
  }

  // ---------------- 数据计算 ----------------
  private currentDates(): string[] {
    return weekDatesByOffset(this.weekOffset);
  }

  private weekTitle(): string {
    const dates: string[] = this.currentDates();
    let suffix: string = '';
    if (this.weekOffset === 0) {
      suffix = '（本周）';
    } else if (this.weekOffset === -1) {
      suffix = '（上周）';
    } else if (this.weekOffset === 1) {
      suffix = '（下周）';
    }
    return shortDate(dates[0]) + ' - ' + shortDate(dates[6]) + ' ' + suffix;
  }

  private dishById(id: string): Dish | null {
    for (let i = 0; i < this.dishes.length; i++) {
      if (this.dishes[i].id === id) {
        return this.dishes[i];
      }
    }
    return null;
  }

  private plannedDish(date: string, meal: string): Dish | null {
    for (let i = 0; i < this.plan.length; i++) {
      const slot: PlanSlot = this.plan[i];
      if (slot.date === date && slot.mealType === meal && slot.dishId !== '') {
        return this.dishById(slot.dishId);
      }
    }
    return null;
  }

  private plannedName(date: string, meal: string): string {
    const dish: Dish | null = this.plannedDish(date, meal);
    if (dish === null) {
      return '';
    }
    return dish.name;
  }

  private plannedPrice(date: string, meal: string): string {
    const dish: Dish | null = this.plannedDish(date, meal);
    if (dish === null) {
      return '';
    }
    return '¥' + dish.price.toFixed(1);
  }

  private plannedPriceColor(date: string, meal: string): string {
    const dish: Dish | null = this.plannedDish(date, meal);
    if (dish === null) {
      return AppColor.TEXT_SUB;
    }
    return dish.price > this.preference.maxPricePerMeal ? AppColor.DANGER : AppColor.TEXT_SUB;
  }

  private isPicking(date: string, meal: string): boolean {
    return this.pickingDate === date && this.pickingMeal === meal;
  }

  private plannedCount(): number {
    const dates: string[] = this.currentDates();
    let count: number = 0;
    for (let i = 0; i < this.plan.length; i++) {
      if (dates.indexOf(this.plan[i].date) >= 0 && this.plan[i].dishId !== '') {
        count++;
      }
    }
    return count;
  }

  private weekCost(): number {
    const dates: string[] = this.currentDates();
    let sum: number = 0;
    for (let i = 0; i < this.plan.length; i++) {
      const slot: PlanSlot = this.plan[i];
      if (dates.indexOf(slot.date) < 0) {
        continue;
      }
      const dish: Dish | null = this.dishById(slot.dishId);
      if (dish !== null) {
        sum += dish.price;
      }
    }
    return sum;
  }

  private hitCount(): number {
    const dates: string[] = this.currentDates();
    let hit: number = 0;
    for (let i = 0; i < this.plan.length; i++) {
      const slot: PlanSlot = this.plan[i];
      if (dates.indexOf(slot.date) < 0) {
        continue;
      }
      const dish: Dish | null = this.dishById(slot.dishId);
      if (dish !== null && DataStore.isPreferred(dish)) {
        hit++;
      }
    }
    return hit;
  }

  private hitRate(): number {
    const total: number = this.plannedCount();
    if (total === 0) {
      return 0;
    }
    return Math.round(this.hitCount() * 100 / total);
  }

  private budgetPercent(): number {
    const budget: number = this.preference.weeklyBudget;
    if (budget <= 0) {
      return 0;
    }
    return Math.round(this.weekCost() * 100 / budget);
  }

  private candidates(): Dish[] {
    if (this.pickingDate === '') {
      return [];
    }
    const list: Dish[] = this.dishes.filter(
      (d: Dish) => d.date === this.pickingDate && d.mealType === this.pickingMeal);
    return list.sort((a: Dish, b: Dish) => DataStore.score(b) - DataStore.score(a));
  }

  private weekdayOf(date: string): string {
    const dates: string[] = this.currentDates();
    const index: number = dates.indexOf(date);
    return index >= 0 ? WEEK_LABELS[index] : '';
  }

  // ---------------- 交互 ----------------
  private pickDish(dish: Dish): void {
    DataStore.setPlanSlot(this.pickingDate, this.pickingMeal, dish.id);
  }

  private clearSlot(date: string, meal: string): void {
    DataStore.setPlanSlot(date, meal, '');
  }

  private autoFill(): void {
    const ok: boolean = DataStore.autoPlan(this.currentDates());
    this.toast(ok ? '已按偏好与预算自动排好一周餐单' : '本周还没有可用的菜品，请先录入菜单');
  }

  private clearAll(): void {
    DataStore.clearWeek(this.currentDates());
    this.toast('已清空本周餐单');
  }

  // ---------------- UI ----------------
  @Builder
  toolBar() {
    Row() {
      Button('上周')
        .fontSize(13)
        .height(32)
        .backgroundColor(AppColor.CARD)
        .fontColor(AppColor.TEXT)
        .borderRadius(8)
        .onClick(() => {
          this.weekOffset = this.weekOffset - 1;
          this.pickingDate = '';
        })
      Button('本周')
        .fontSize(13)
        .height(32)
        .backgroundColor(AppColor.CARD)
        .fontColor(AppColor.PRIMARY)
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => {
          this.weekOffset = 0;
          this.pickingDate = '';
        })
      Button('下周')
        .fontSize(13)
        .height(32)
        .backgroundColor(AppColor.CARD)
        .fontColor(AppColor.TEXT)
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => {
          this.weekOffset = this.weekOffset + 1;
          this.pickingDate = '';
        })

      Text(this.weekTitle())
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.TEXT)
        .margin({ left: 16 })

      Blank()

      Button('自动排餐单')
        .fontSize(13)
        .height(32)
        .backgroundColor(AppColor.PRIMARY)
        .fontColor(Color.White)
        .borderRadius(8)
        .onClick(() => {
          this.autoFill();
        })
      Button('清空本周')
        .fontSize(13)
        .height(32)
        .backgroundColor(AppColor.FILL)
        .fontColor(AppColor.TEXT)
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => {
          this.clearAll();
        })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  gridHeader() {
    Row() {
      Text('')
        .width(64)
      ForEach(this.currentDates(), (date: string, index: number) => {
        Column() {
          Text(WEEK_LABELS[index])
            .fontSize(13)
            .fontColor(AppColor.TEXT)
          Text(shortDate(date))
            .fontSize(11)
            .fontColor(AppColor.TEXT_SUB)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .margin({ left: 6 })
      }, (date: string) => 'h_' + date)
    }
    .width('100%')
    .height(40)
  }

  @Builder
  mealRow(meal: string) {
    Row() {
      Text(mealLabel(meal))
        .fontSize(13)
        .fontColor(AppColor.TEXT)
        .width(64)

      ForEach(this.currentDates(), (date: string) => {
        Column() {
          if (this.plannedName(date, meal) === '') {
            Text('＋')
              .fontSize(20)
              .fontColor(AppColor.TEXT_SUB)
          } else {
            Text(this.plannedName(date, meal))
              .fontSize(13)
              .fontColor(AppColor.TEXT)
              .textAlign(TextAlign.Center)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.plannedPrice(date, meal))
              .fontSize(11)
              .fontColor(this.plannedPriceColor(date, meal))
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .height(78)
        .margin({ left: 6 })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.isPicking(date, meal) ? AppColor.PRIMARY_SOFT : AppColor.CARD)
        .borderRadius(8)
        .border({
          width: this.isPicking(date, meal) ? 1.5 : 0.5,
          color: this.isPicking(date, meal) ? AppColor.PRIMARY : AppColor.DIVIDER
        })
        .onClick(() => {
          this.pickingDate = date;
          this.pickingMeal = meal;
        })
      }, (date: string) => meal + '_' + date)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  statItem(label: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
      Text(label)
        .fontSize(12)
        .fontColor(AppColor.TEXT_SUB)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  statsBar() {
    Column() {
      Row() {
        this.statItem('本周花费', '¥' + this.weekCost().toFixed(1), AppColor.TEXT)
        this.statItem('日均花费', '¥' + (this.weekCost() / 7).toFixed(1), AppColor.TEXT)
        this.statItem('已安排', this.plannedCount().toString() + ' / 21', AppColor.TEXT)
        this.statItem('偏好命中率', this.hitRate().toString() + '%',
          this.hitRate() >= 70 ? AppColor.SUCCESS : AppColor.WARN)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.CARD)
    .borderRadius(12)
    .margin({ top: 4 })
  }

  @Builder
  overviewPanel() {
    Column() {
      Text('本周概览')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.TEXT)
        .width('100%')

      Row() {
        Text('预算使用')
          .fontSize(13)
          .fontColor(AppColor.TEXT_SUB)
        Blank()
        Text('¥' + this.weekCost().toFixed(1) + ' / ¥' + this.preference.weeklyBudget.toFixed(0))
          .fontSize(13)
          .fontColor(this.budgetPercent() > 100 ? AppColor.DANGER : AppColor.TEXT)
      }
      .width('100%')
      .margin({ top: 16 })

      Progress({ value: this.budgetPercent(), total: 100, type: ProgressType.Linear })
        .color(this.budgetPercent() > 100 ? AppColor.DANGER : AppColor.PRIMARY)
        .width('100%')
        .margin({ top: 8 })

      if (this.budgetPercent() > 100) {
        Text('已超出每周预算，建议换掉部分高价菜品')
          .fontSize(12)
          .fontColor(AppColor.DANGER)
          .margin({ top: 8 })
          .width('100%')
      }

      Divider()
        .color(AppColor.DIVIDER)
        .margin({ top: 16, bottom: 16 })

      Row() {
        Text('单餐价格上限')
          .fontSize(13)
          .fontColor(AppColor.TEXT_SUB)
        Blank()
        Text('¥' + this.preference.maxPricePerMeal.toFixed(0))
          .fontSize(13)
          .fontColor(AppColor.TEXT)
      }
      .width('100%')

      Row() {
        Text('忌口标签')
          .fontSize(13)
          .fontColor(AppColor.TEXT_SUB)
        Blank()
        Text(this.preference.dislikedTags.length === 0 ? '未设置' : this.preference.dislikedTags.join('、'))
          .fontSize(13)
          .fontColor(AppColor.TEXT)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.CARD)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  candidatePanel() {
    Column() {
      if (this.pickingDate === '') {
        Text('点击左侧任意格子，为这一餐挑选菜品')
          .fontSize(13)
          .fontColor(AppColor.TEXT_SUB)
          .margin({ top: 20 })
      } else {
        Row() {
          Text(this.weekdayOf(this.pickingDate) + ' ' + mealLabel(this.pickingMeal))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.TEXT)
          Blank()
          Text('取消')
            .fontSize(13)
            .fontColor(AppColor.PRIMARY)
            .onClick(() => {
              this.pickingDate = '';
            })
        }
        .width('100%')

        Text('候选菜品（按与你偏好的匹配度排序）')
          .fontSize(12)
          .fontColor(AppColor.TEXT_SUB)
          .margin({ top: 6, bottom: 12 })
          .width('100%')

        if (this.candidates().length === 0) {
          Text('这一天还没有录入该餐次的菜品，请先到「菜单录入」添加')
            .fontSize(13)
            .fontColor(AppColor.TEXT_SUB)
            .margin({ top: 8 })
            .width('100%')
        }

        List() {
          ForEach(this.candidates(), (dish: Dish, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Row() {
                    Text(dish.name)
                      .fontSize(14)
                      .fontColor(AppColor.TEXT)
                    if (index === 0) {
                      Text('推荐')
                        .fontSize(10)
                        .fontColor(Color.White)
                        .backgroundColor(AppColor.SUCCESS)
                        .borderRadius(4)
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .margin({ left: 6 })
                    }
                    if (!DataStore.isPreferred(dish)) {
                      Text('偏离偏好')
                        .fontSize(10)
                        .fontColor(AppColor.WARN)
                        .backgroundColor('#FDF1E3')
                        .borderRadius(4)
                        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                        .margin({ left: 6 })
                    }
                  }
                  Text(dish.canteen + ' · ' + dish.tags.join(' '))
                    .fontSize(11)
                    .fontColor(AppColor.TEXT_SUB)
                    .margin({ top: 3 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('¥' + dish.price.toFixed(1))
                  .fontSize(14)
                  .fontColor(dish.price > this.preference.maxPricePerMeal ? AppColor.DANGER : AppColor.TEXT)

                Button('选它')
                  .fontSize(12)
                  .height(28)
                  .backgroundColor(AppColor.PRIMARY_SOFT)
                  .fontColor(AppColor.PRIMARY)
                  .borderRadius(6)
                  .margin({ left: 10 })
                  .onClick(() => {
                    this.pickDish(dish);
                  })
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }
          }, (dish: Dish) => dish.id)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)

        Divider()
          .color(AppColor.DIVIDER)
          .margin({ top: 8, bottom: 12 })

        Button('清空这一格')
          .fontSize(13)
          .width('100%')
          .height(34)
          .backgroundColor(AppColor.FILL)
          .fontColor(AppColor.TEXT)
          .borderRadius(8)
          .onClick(() => {
            this.clearSlot(this.pickingDate, this.pickingMeal);
          })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.CARD)
    .borderRadius(12)
    .margin({ top: 12 })
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  build() {
    Row() {
      Column() {
        this.toolBar()
        this.gridHeader()
        ForEach(MEAL_TYPES, (meal: string) => {
          this.mealRow(meal)
        }, (meal: string) => meal)
        this.statsBar()
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.overviewPanel()
        this.candidatePanel()
      }
      .width(340)
      .height('100%')
      .margin({ left: 12 })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(VerticalAlign.Top)
  }
}
