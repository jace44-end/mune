import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppColor } from '../common/Theme';
import { DataStore } from '../common/Store';
import { ALL_TAGS, Preference } from '../model/Models';

const DOMAIN: number = 0x0000;

/**
 * 个人偏好设置：喜欢的口味、忌口、单餐价格上限与每周预算
 */
@Component
export struct PreferenceView {
  @StorageLink('preference') preference: Preference = new Preference();
  /** 统一弹窗提示：走 UIContext 的 PromptAction，替代已废弃的全局 showToast */
  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    } catch (err) {
      hilog.error(DOMAIN, 'Toast', 'showToast failed');
    }
  }

  private save(liked: string[], disliked: string[], maxPrice: number, budget: number): void {
    const next: Preference = new Preference();
    next.likedTags = liked;
    next.dislikedTags = disliked;
    next.maxPricePerMeal = maxPrice;
    next.weeklyBudget = budget;
    DataStore.setPreference(next);
  }

  private toggleLiked(tag: string): void {
    let liked: string[] = this.preference.likedTags;
    let disliked: string[] = this.preference.dislikedTags;
    if (liked.indexOf(tag) >= 0) {
      liked = liked.filter((item: string) => item !== tag);
    } else {
      liked = liked.concat([tag]);
      disliked = disliked.filter((item: string) => item !== tag);
    }
    this.save(liked, disliked, this.preference.maxPricePerMeal, this.preference.weeklyBudget);
  }

  private toggleDisliked(tag: string): void {
    let liked: string[] = this.preference.likedTags;
    let disliked: string[] = this.preference.dislikedTags;
    if (disliked.indexOf(tag) >= 0) {
      disliked = disliked.filter((item: string) => item !== tag);
    } else {
      disliked = disliked.concat([tag]);
      liked = liked.filter((item: string) => item !== tag);
    }
    this.save(liked, disliked, this.preference.maxPricePerMeal, this.preference.weeklyBudget);
  }

  @Builder
  cardTitle(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.TEXT)
        .width('100%')
      Text(subtitle)
        .fontSize(12)
        .fontColor(AppColor.TEXT_SUB)
        .margin({ top: 4 })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      Text('个人偏好')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColor.TEXT)
        .width('100%')

      Text('偏好会影响「周餐单」页的候选排序、推荐标记与自动排餐结果。')
        .fontSize(12)
        .fontColor(AppColor.TEXT_SUB)
        .margin({ top: 6 })
        .width('100%')

      Column() {
        this.cardTitle('喜欢吃什么', '被选中的标签会在候选菜品里加分')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(ALL_TAGS, (tag: string) => {
            Text(tag)
              .fontSize(13)
              .fontColor(this.preference.likedTags.indexOf(tag) >= 0 ? Color.White : AppColor.TEXT)
              .backgroundColor(this.preference.likedTags.indexOf(tag) >= 0 ? AppColor.PRIMARY : AppColor.FILL)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.toggleLiked(tag);
              })
          }, (tag: string) => 'like_' + tag)
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColor.CARD)
      .borderRadius(12)
      .margin({ top: 16 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.cardTitle('忌口与不喜欢', '含这些标签的菜品会被扣分并标记为「偏离偏好」')
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(ALL_TAGS, (tag: string) => {
            Text(tag)
              .fontSize(13)
              .fontColor(this.preference.dislikedTags.indexOf(tag) >= 0 ? Color.White : AppColor.TEXT)
              .backgroundColor(this.preference.dislikedTags.indexOf(tag) >= 0 ? AppColor.DANGER : AppColor.FILL)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(14)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.toggleDisliked(tag);
              })
          }, (tag: string) => 'dislike_' + tag)
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColor.CARD)
      .borderRadius(12)
      .margin({ top: 12 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        this.cardTitle('预算约束', '单餐超上限或整周超预算时，会在周餐单页给出提醒')

        Row() {
          Text('单餐价格上限')
            .fontSize(13)
            .fontColor(AppColor.TEXT)
          Blank()
          Text('¥' + this.preference.maxPricePerMeal.toFixed(0))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.PRIMARY)
        }
        .width('100%')
        .margin({ top: 16 })

        Slider({
          value: this.preference.maxPricePerMeal,
          min: 5,
          max: 40,
          step: 1,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .selectedColor(AppColor.PRIMARY)
          .trackColor(AppColor.FILL)
          .onChange((newValue: number) => {
            this.save(this.preference.likedTags, this.preference.dislikedTags, newValue,
              this.preference.weeklyBudget);
          })

        Row() {
          Text('每周餐费预算')
            .fontSize(13)
            .fontColor(AppColor.TEXT)
          Blank()
          Text('¥' + this.preference.weeklyBudget.toFixed(0))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColor.PRIMARY)
        }
        .width('100%')
        .margin({ top: 20 })

        Slider({
          value: this.preference.weeklyBudget,
          min: 50,
          max: 600,
          step: 10,
          style: SliderStyle.OutSet
        })
          .width('100%')
          .selectedColor(AppColor.PRIMARY)
          .trackColor(AppColor.FILL)
          .onChange((newValue: number) => {
            this.save(this.preference.likedTags, this.preference.dislikedTags,
              this.preference.maxPricePerMeal, newValue);
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColor.CARD)
      .borderRadius(12)
      .margin({ top: 12 })
      .alignItems(HorizontalAlign.Start)

      Row() {
        Column() {
          Text('当前偏好摘要')
            .fontSize(13)
            .fontColor(AppColor.TEXT_SUB)
          Text('喜欢：' + (this.preference.likedTags.length === 0 ? '未设置' : this.preference.likedTags.join('、')))
            .fontSize(13)
            .fontColor(AppColor.TEXT)
            .margin({ top: 6 })
            .width('100%')
          Text('忌口：' + (this.preference.dislikedTags.length === 0 ? '未设置' : this.preference.dislikedTags.join('、')))
            .fontSize(13)
            .fontColor(AppColor.TEXT)
            .margin({ top: 4 })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('恢复默认')
          .fontSize(13)
          .height(34)
          .backgroundColor(AppColor.FILL)
          .fontColor(AppColor.TEXT)
          .borderRadius(8)
          .onClick(() => {
            const preset: Preference = new Preference();
            preset.likedTags = ['清淡', '荤菜', '汤', '性价比'];
            preset.dislikedTags = ['辣', '油炸'];
            preset.maxPricePerMeal = 16;
            preset.weeklyBudget = 240;
            DataStore.setPreference(preset);
            this.toast('已恢复默认偏好');
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(AppColor.CARD)
      .borderRadius(12)
      .margin({ top: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
  }
}
