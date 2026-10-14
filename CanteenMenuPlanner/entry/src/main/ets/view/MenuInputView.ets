import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor } from '../common/Theme';
import { DataStore } from '../common/Store';
import { shortDate, todayStr, weekDatesByOffset, WEEK_LABELS } from '../common/DateUtil';
import { ALL_TAGS, CANTEENS, Dish, mealLabel, MEAL_LABELS, MEAL_TYPES, MealType } from '../model/Models';

const DOMAIN: number = 0x0000;

/**
 * 菜单录入：录入每日菜单、价格、食堂与标签，支持键盘批量录入
 */
@Component
export struct MenuInputView {
  @StorageLink('dishes') dishes: Dish[] = [];

  @State weekOffset: number = 0;
  @State inputDate: string = todayStr();
  @State inputMeal: string = MealType.LUNCH;
  @State nameText: string = '';
  @State priceText: string = '';
  @State canteenText: string = CANTEENS[0];
  @State tags: string[] = [];
  @State batchText: string = '';
  /** 统一弹窗提示：走 UIContext 的 PromptAction，替代已废弃的全局 showToast */
  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
      hilog.error(DOMAIN, 'Toast', 'showToast failed');
    }
  }

  private currentDates(): string[] {
    return weekDatesByOffset(this.weekOffset);
  }

  private listOfCurrentMeal(): Dish[] {
    return this.dishes.filter((d: Dish) => d.date === this.inputDate && d.mealType === this.inputMeal);
  }

  private mealTotal(): number {
    const list: Dish[] = this.listOfCurrentMeal();
    let sum: number = 0;
    for (let i = 0; i < list.length; i++) {
      sum += list[i].price;
    }
    return sum;
  }

  private toggleTag(tag: string): void {
    if (this.tags.indexOf(tag) >= 0) {
      this.tags = this.tags.filter((item: string) => item !== tag);
    } else {
      this.tags = this.tags.concat([tag]);
    }
  }

  private buildDish(name: string, price: number): Dish {
    const dish: Dish = new Dish();
    dish.id = DataStore.newDishId(this.inputDate, this.inputMeal);
    dish.name = name;
    dish.price = price;
    dish.canteen = this.canteenText;
    dish.tags = this.tags;
    dish.date = this.inputDate;
    dish.mealType = this.inputMeal;
    return dish;
  }

  private submitOne(): void {
    const name: string = this.nameText.trim();
    const price: number = parseFloat(this.priceText);
    if (name === '') {
      this.toast('请先填写菜名');
      return;
    }
    if (isNaN(price) || price < 0) {
      this.toast('请填写正确的价格');
      return;
    }
    DataStore.addDish(this.buildDish(name, price));
    this.nameText = '';
    this.priceText = '';
    this.toast('已添加：' + name);
  }

  private submitBatch(): void {
    if (this.batchText.trim() === '') {
      this.toast('请先按「菜名,价格」格式填写');
      return;
    }
    const normalized: string = this.batchText.split('，').join(',');
    const rawLines: string[] = normalized.split('\n');
    const list: Dish[] = [];
    let failed: number = 0;
    for (let i = 0; i < rawLines.length; i++) {
      const line: string = rawLines[i].trim();
      if (line === '') {
        continue;
      }
      const parts: string[] = line.split(',');
      const name: string = parts[0].trim();
      const price: number = parts.length > 1 ? parseFloat(parts[1].trim()) : NaN;
      if (name === '' || isNaN(price)) {
        failed++;
        continue;
      }
      list.push(this.buildDish(name, price));
    }
    if (list.length > 0) {
      DataStore.addDishes(list);
      this.batchText = '';
    }
    this.toast('批量添加 ' + list.length.toString() + ' 道菜' +
      (failed > 0 ? '，' + failed.toString() + ' 行格式不正确' : ''));
  }

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor(AppColor.TEXT)
      .width('100%')
      .margin({ bottom: 10 })
  }

  @Builder
  datePicker() {
    Column() {
      Row() {
        Text('供应日期与餐次')
          .fontSize(13)
          .fontColor(AppColor.TEXT_SUB)
        Blank()
        Button('上一周')
          .fontSize(12)
          .height(28)
          .backgroundColor(AppColor.FILL)
          .fontColor(AppColor.TEXT)
          .borderRadius(6)
          .onClick(() => {
            this.weekOffset = this.weekOffset - 1;
          })
        Button('下一周')
          .fontSize(12)
          .height(28)
          .backgroundColor(AppColor.FILL)
          .fontColor(AppColor.TEXT)
          .borderRadius(6)
          .margin({ left: 8 })
          .onClick(() => {
            this.weekOffset = this.weekOffset + 1;
          })
      }
      .width('100%')

      Row() {
        ForEach(this.currentDates(), (date: string, index: number) => {
          Column() {
            Text(WEEK_LABELS[index])
              .fontSize(12)
              .fontColor(this.inputDate === date ? Color.White : AppColor.TEXT)
            Text(shortDate(date))
              .fontSize(11)
              .fontColor(this.inputDate === date ? Color.White : AppColor.TEXT_SUB)
              .margin({ top: 2 })
          }
          .layoutWeight(1)
          .height(52)
          .margin({ right: 6 })
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.inputDate === date ? AppColor.PRIMARY : AppColor.FILL)
          .borderRadius(8)
          .onClick(() => {
            this.inputDate = date;
          })
        }, (date: string) => 'd_' + date)
      }
      .width('100%')
      .margin({ top: 10 })

      Row() {
        ForEach(MEAL_TYPES, (meal: string, index: number) => {
          Text(MEAL_LABELS[index])
            .fontSize(13)
            .fontColor(this.inputMeal === meal ? Color.White : AppColor.TEXT)
            .backgroundColor(this.inputMeal === meal ? AppColor.PRIMARY : AppColor.FILL)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(36)
            .margin({ right: 6 })
            .borderRadius(8)
            .onClick(() => {
              this.inputMeal = meal;
            })
        }, (meal: string) => 'm_' + meal)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.CARD)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  singleForm() {
    Column() {
      this.sectionTitle('新增一道菜')

      Row() {
        TextInput({ text: this.nameText, placeholder: '菜名，例如 番茄炒蛋' })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(AppColor.FILL)
          .borderRadius(8)
          .onChange((value: string) => {
            this.nameText = value;
          })
        TextInput({ text: this.priceText, placeholder: '价格' })
          .width(110)
          .height(40)
          .type(InputType.Number)
          .backgroundColor(AppColor.FILL)
          .borderRadius(8)
          .margin({ left: 10 })
          .onChange((value: string) => {
            this.priceText = value;
          })
      }
      .width('100%')

      Text('食堂窗口')
        .fontSize(13)
        .fontColor(AppColor.TEXT_SUB)
        .width('100%')
        .margin({ top: 14 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(CANTEENS, (canteen: string) => {
          Text(canteen)
            .fontSize(13)
            .fontColor(this.canteenText === canteen ? Color.White : AppColor.TEXT)
            .backgroundColor(this.canteenText === canteen ? AppColor.PRIMARY : AppColor.FILL)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.canteenText = canteen;
            })
        }, (canteen: string) => canteen)
      }
      .width('100%')
      .margin({ top: 8 })

      Text('口味 / 属性标签')
        .fontSize(13)
        .fontColor(AppColor.TEXT_SUB)
        .width('100%')
        .margin({ top: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(ALL_TAGS, (tag: string) => {
          Text(tag)
            .fontSize(13)
            .fontColor(this.tags.indexOf(tag) >= 0 ? Color.White : AppColor.TEXT)
            .backgroundColor(this.tags.indexOf(tag) >= 0 ? AppColor.PRIMARY : AppColor.FILL)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(14)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.toggleTag(tag);
            })
        }, (tag: string) => tag)
      }
      .width('100%')
      .margin({ top: 8 })

      Button('添加到菜单')
        .width('100%')
        .height(40)
        .fontSize(14)
        .backgroundColor(AppColor.PRIMARY)
        .fontColor(Color.White)
        .borderRadius(8)
        .margin({ top: 8 })
        .onClick(() => {
          this.submitOne();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.CARD)
    .borderRadius(12)
    .margin({ top: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  batchForm() {
    Column() {
      this.sectionTitle('批量录入（每行一条：菜名,价格）')

      TextArea({ text: this.batchText, placeholder: '番茄炒蛋,12\n红烧肉,18\n清炒时蔬,9' })
        .width('100%')
        .height(110)
        .backgroundColor(AppColor.FILL)
        .borderRadius(8)
        .onChange((value: string) => {
          this.batchText = value;
        })

      Row() {
        Text('将使用当前食堂与标签：' + (this.tags.length === 0 ? '无标签' : this.tags.join('、')))
          .fontSize(12)
          .fontColor(AppColor.TEXT_SUB)
          .layoutWeight(1)
        Button('批量添加')
          .fontSize(13)
          .height(34)
          .backgroundColor(AppColor.PRIMARY)
          .fontColor(Color.White)
          .borderRadius(8)
          .onClick(() => {
            this.submitBatch();
          })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColor.CARD)
    .borderRadius(12)
    .margin({ top: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  mealList() {
    Column() {
      Row() {
        Text(shortDate(this.inputDate) + ' ' + mealLabel(this.inputMeal) + ' 菜单')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.TEXT)
        Blank()
        Text('共 ' + this.listOfCurrentMeal().length.toString() + ' 道 · 合计 ¥' + this.mealTotal().toFixed(1))
          .fontSize(12)
          .fontColor(AppColor.TEXT_SUB)
      }
      .width('100%')

      if (this.listOfCurrentMeal().length === 0) {
        Text('这一天还没有录入该餐次的菜品')
          .fontSize(13)
          .fontColor(AppColor.TEXT_SUB)
          .margin({ top: 20 })
          .width('100%')
      }

      List() {
        ForEach(this.listOfCurrentMeal(), (dish: Dish) => {
          ListItem() {
            Row() {
              Column() {
                Text(dish.name)
                  .fontSize(14)
                  .fontColor(AppColor.TEXT)
                Text(dish.canteen + ' · ' + (dish.tags.length === 0 ? '无标签' : dish.tags.join(' ')))
                  .fontSize(11)
                  .fontColor(AppColor.TEXT_SUB)
                  .margin({ top: 3 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text('¥' + dish.price.toFixed(1))
                .fontSize(14)
                .fontColor(AppColor.TEXT)

              Text('删除')
                .fontSize(12)
                .fontColor(AppColor.DANGER)
                .margin({ left: 12 })
                .onClick(() => {
                  DataStore.removeDish(dish.id);
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

      Button('清空这一餐的菜品')
        .width('100%')
        .height(34)
        .fontSize(13)
        .backgroundColor(AppColor.FILL)
        .fontColor(AppColor.TEXT)
        .borderRadius(8)
        .onClick(() => {
          DataStore.removeDishesOf(this.inputDate, this.inputMeal);
          this.toast('已清空该餐次菜品');
        })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor(AppColor.CARD)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Row() {
      Column() {
        this.datePicker()
        this.singleForm()
        this.batchForm()
      }
      .layoutWeight(1)
      .height('100%')
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.mealList()
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
