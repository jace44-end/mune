import { mediaquery } from '@kit.ArkUI';
import { AppColor } from '../common/Theme';
import { MenuInputView } from '../view/MenuInputView';
import { PreferenceView } from '../view/PreferenceView';
import { WeekPlanView } from '../view/WeekPlanView';

const NAV_TITLES: string[] = ['周餐单', '菜单录入', '我的偏好'];
const NAV_SUBTITLES: string[] = ['对比选择，规划一周', '菜品、价格与标签', '口味、忌口与预算'];

/**
 * 应用主框架：大屏用左侧导航 + 内容区，窄屏自动切换为底部标签栏
 */
@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State isWide: boolean = true;

  private wideListener: mediaquery.MediaQueryListener | null = null;

  aboutToAppear(): void {
    // 走 UIContext 的 MediaQuery，替代已废弃的全局 matchMediaSync
    this.wideListener = this.getUIContext().getMediaQuery().matchMediaSync('(width > 840vp)');
    this.isWide = this.wideListener.matches;
    this.wideListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.isWide = result.matches;
    });
  }

  aboutToDisappear(): void {
    if (this.wideListener !== null) {
      this.wideListener.off('change');
    }
  }

  @Builder
  navItem(index: number) {
    Row() {
      Text('')
        .width(4)
        .height(26)
        .borderRadius(2)
        .backgroundColor(this.currentIndex === index ? AppColor.PRIMARY : Color.Transparent)

      Column() {
        Text(NAV_TITLES[index])
          .fontSize(15)
          .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.currentIndex === index ? AppColor.PRIMARY : AppColor.TEXT)
        Text(NAV_SUBTITLES[index])
          .fontSize(11)
          .fontColor(AppColor.TEXT_SUB)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .height(58)
    .padding({ left: 12, right: 12 })
    .borderRadius(10)
    .backgroundColor(this.currentIndex === index ? AppColor.PRIMARY_SOFT : Color.Transparent)
    .onClick(() => {
      this.currentIndex = index;
    })
  }

  @Builder
  bottomTab(index: number) {
    Column() {
      Text(NAV_TITLES[index])
        .fontSize(13)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.currentIndex === index ? AppColor.PRIMARY : AppColor.TEXT_SUB)
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = index;
    })
  }

  @Builder
  content() {
    if (this.currentIndex === 0) {
      WeekPlanView()
    } else if (this.currentIndex === 1) {
      MenuInputView()
    } else {
      PreferenceView()
    }
  }

  build() {
    Column() {
      Row() {
        Text('校园食堂菜单整理台')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColor.TEXT)
        Text('本地数据 · 无需登录')
          .fontSize(11)
          .fontColor(AppColor.PRIMARY)
          .backgroundColor(AppColor.PRIMARY_SOFT)
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ left: 10 })
        Blank()
        Text('录入每日菜单与价格，按个人偏好对比选择，规划一周餐单')
          .fontSize(12)
          .fontColor(AppColor.TEXT_SUB)
      }
      .width('100%')
      .height(56)
      .padding({ left: 24, right: 24 })
      .backgroundColor(AppColor.CARD)

      Divider()
        .color(AppColor.DIVIDER)

      if (this.isWide) {
        Row() {
          Column() {
            this.navItem(0)
            this.navItem(1)
            this.navItem(2)
            Blank()
            Text('数据仅保存在本机')
              .fontSize(11)
              .fontColor(AppColor.TEXT_SUB)
              .margin({ bottom: 16 })
          }
          .width(208)
          .height('100%')
          .padding({ left: 12, right: 12, top: 16 })
          .backgroundColor(AppColor.CARD)

          Column() {
            this.content()
          }
          .layoutWeight(1)
          .height('100%')
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)
      } else {
        Column() {
          Column() {
            this.content()
          }
          .layoutWeight(1)
          .width('100%')

          Divider()
            .color(AppColor.DIVIDER)

          Row() {
            this.bottomTab(0)
            this.bottomTab(1)
            this.bottomTab(2)
          }
          .width('100%')
          .height(48)
          .backgroundColor(AppColor.CARD)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColor.PAGE_BG)
  }
}
