import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Dish, MEAL_TYPES, MealType, PlanSlot, Preference } from '../model/Models';
import { formatDate, mondayOf, weekDates } from './DateUtil';

const DOMAIN: number = 0x0000;
const TAG: string = 'DataStore';

const PREF_NAME: string = 'canteen_menu_store';
const KEY_DISHES: string = 'dishes';
const KEY_PREFERENCE: string = 'preference';
const KEY_PLAN: string = 'plan';

/**
 * 本地数据仓库：
 * - 内存中以静态字段持有数据（DataStore.dishes / preference / plan）
 * - 通过 AppStorage 暴露给 UI（@StorageLink 订阅）
 * - 通过 preferences 落盘持久化
 */
export class DataStore {
  static dishes: Dish[] = [];
  static preference: Preference = new Preference();
  static plan: PlanSlot[] = [];
  static ready: boolean = false;

  private static prefStore: preferences.Preferences | null = null;

  /** 应用启动时调用一次 */
  static async init(context: common.Context): Promise<void> {
    try {
      const options: preferences.Options = { name: PREF_NAME };
      const store: preferences.Preferences = await preferences.getPreferences(context, options);
      DataStore.prefStore = store;

      const hasDishes: boolean = await store.has(KEY_DISHES);
      const rawDishes: string = await DataStore.readString(store, KEY_DISHES, '[]');
      const rawPreference: string = await DataStore.readString(store, KEY_PREFERENCE, '');
      const rawPlan: string = await DataStore.readString(store, KEY_PLAN, '[]');

      DataStore.dishes = DataStore.parseDishes(rawDishes);
      DataStore.preference = DataStore.parsePreference(rawPreference);
      DataStore.plan = DataStore.parsePlan(rawPlan);

      // 首次启动灌入一份本周示例菜单，方便直接看到效果
      if (!hasDishes || DataStore.dishes.length === 0) {
        DataStore.dishes = DataStore.buildDemoDishes();
        DataStore.preference = DataStore.buildDemoPreference();
        await DataStore.persistDishes();
        await DataStore.persistPreference();
      }

      DataStore.ready = true;
      hilog.info(DOMAIN, TAG, 'init ok, dishes=%{public}d', DataStore.dishes.length);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err));
      DataStore.dishes = DataStore.buildDemoDishes();
      DataStore.preference = DataStore.buildDemoPreference();
      DataStore.plan = [];
      DataStore.ready = true;
    }
    DataStore.sync();
  }

  // ------------------------------------------------------------------
  // 与 UI 同步
  // ------------------------------------------------------------------
  private static sync(): void {
    AppStorage.setOrCreate<Dish[]>('dishes', DataStore.dishes);
    AppStorage.setOrCreate<PlanSlot[]>('plan', DataStore.plan);
    AppStorage.setOrCreate<Preference>('preference', DataStore.preference);
  }

  // ------------------------------------------------------------------
  // 反序列化
  // ------------------------------------------------------------------
  private static async readString(store: preferences.Preferences, key: string, def: string): Promise<string> {
    try {
      const value: preferences.ValueType = await store.get(key, def);
      if (typeof value === 'string') {
        return value;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'read %{public}s failed', key);
    }
    return def;
  }

  private static parseDishes(raw: string): Dish[] {
    if (raw === '' || raw === 'null') {
      return [];
    }
    try {
      const list: Dish[] = JSON.parse(raw) as Dish[];
      return list === null ? [] : list;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'parseDishes failed');
      return [];
    }
  }

  private static parsePlan(raw: string): PlanSlot[] {
    if (raw === '' || raw === 'null') {
      return [];
    }
    try {
      const list: PlanSlot[] = JSON.parse(raw) as PlanSlot[];
      return list === null ? [] : list;
    } catch (err) {
      return [];
    }
  }

  private static parsePreference(raw: string): Preference {
    if (raw === '' || raw === 'null') {
      return new Preference();
    }
    try {
      const p: Preference = JSON.parse(raw) as Preference;
      return p === null ? new Preference() : p;
    } catch (err) {
      return new Preference();
    }
  }

  // ------------------------------------------------------------------
  // 持久化
  // ------------------------------------------------------------------
  private static async persistDishes(): Promise<void> {
    const store: preferences.Preferences | null = DataStore.prefStore;
    if (store === null) {
      return;
    }
    try {
      await store.put(KEY_DISHES, JSON.stringify(DataStore.dishes));
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persistDishes failed');
    }
  }

  private static async persistPlan(): Promise<void> {
    const store: preferences.Preferences | null = DataStore.prefStore;
    if (store === null) {
      return;
    }
    try {
      await store.put(KEY_PLAN, JSON.stringify(DataStore.plan));
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persistPlan failed');
    }
  }

  private static async persistPreference(): Promise<void> {
    const store: preferences.Preferences | null = DataStore.prefStore;
    if (store === null) {
      return;
    }
    try {
      await store.put(KEY_PREFERENCE, JSON.stringify(DataStore.preference));
      await store.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'persistPreference failed');
    }
  }

  // ------------------------------------------------------------------
  // 查询
  // ------------------------------------------------------------------
  static findDish(id: string): Dish | null {
    for (let i = 0; i < DataStore.dishes.length; i++) {
      if (DataStore.dishes[i].id === id) {
        return DataStore.dishes[i];
      }
    }
    return null;
  }

  static dishesOf(date: string, mealType: string): Dish[] {
    return DataStore.dishes.filter((d: Dish) => d.date === date && d.mealType === mealType);
  }

  static dishesOfMealInWeek(dates: string[], mealType: string): Dish[] {
    return DataStore.dishes.filter((d: Dish) => dates.indexOf(d.date) >= 0 && d.mealType === mealType);
  }

  /** 偏好打分：喜欢标签加分，忌口扣分，价格超上限扣分 */
  static score(dish: Dish): number {
    const pref: Preference = DataStore.preference;
    let value: number = 0;
    for (let i = 0; i < dish.tags.length; i++) {
      const tag: string = dish.tags[i];
      if (pref.likedTags.indexOf(tag) >= 0) {
        value += 2;
      }
      if (pref.dislikedTags.indexOf(tag) >= 0) {
        value -= 4;
      }
    }
    if (dish.price <= pref.maxPricePerMeal) {
      value += 1;
    } else {
      value -= 2;
    }
    return value;
  }

  /** 是否命中偏好：不超单餐上限、且不含忌口标签 */
  static isPreferred(dish: Dish): boolean {
    const pref: Preference = DataStore.preference;
    if (dish.price > pref.maxPricePerMeal) {
      return false;
    }
    for (let i = 0; i < dish.tags.length; i++) {
      if (pref.dislikedTags.indexOf(dish.tags[i]) >= 0) {
        return false;
      }
    }
    return true;
  }

  // ------------------------------------------------------------------
  // 写入
  // ------------------------------------------------------------------
  static addDish(dish: Dish): void {
    DataStore.dishes = DataStore.dishes.concat([dish]);
    DataStore.persistDishes();
    DataStore.sync();
  }

  static addDishes(list: Dish[]): void {
    DataStore.dishes = DataStore.dishes.concat(list);
    DataStore.persistDishes();
    DataStore.sync();
  }

  static removeDish(id: string): void {
    DataStore.dishes = DataStore.dishes.filter((d: Dish) => d.id !== id);
    DataStore.plan = DataStore.plan.filter((s: PlanSlot) => s.dishId !== id);
    DataStore.persistDishes();
    DataStore.persistPlan();
    DataStore.sync();
  }

  /** 清空某一天某一餐的全部菜品 */
  static removeDishesOf(date: string, mealType: string): void {
    const ids: string[] = [];
    for (let i = 0; i < DataStore.dishes.length; i++) {
      const d: Dish = DataStore.dishes[i];
      if (d.date === date && d.mealType === mealType) {
        ids.push(d.id);
      }
    }
    DataStore.dishes = DataStore.dishes.filter((d: Dish) => ids.indexOf(d.id) < 0);
    DataStore.plan = DataStore.plan.filter((s: PlanSlot) => ids.indexOf(s.dishId) < 0);
    DataStore.persistDishes();
    DataStore.persistPlan();
    DataStore.sync();
  }

  static setPreference(pref: Preference): void {
    DataStore.preference = pref;
    DataStore.persistPreference();
    DataStore.sync();
  }

  static setPlanSlot(date: string, mealType: string, dishId: string): void {
    const rest: PlanSlot[] = DataStore.plan.filter(
      (s: PlanSlot) => !(s.date === date && s.mealType === mealType));
    if (dishId !== '') {
      const slot: PlanSlot = new PlanSlot();
      slot.date = date;
      slot.mealType = mealType;
      slot.dishId = dishId;
      rest.push(slot);
    }
    DataStore.plan = rest;
    DataStore.persistPlan();
    DataStore.sync();
  }

  static clearWeek(dates: string[]): void {
    DataStore.plan = DataStore.plan.filter((s: PlanSlot) => dates.indexOf(s.date) < 0);
    DataStore.persistPlan();
    DataStore.sync();
  }

  /** 按偏好与预算自动填充一周餐单 */
  static autoPlan(dates: string[]): boolean {
    const pref: Preference = DataStore.preference;
    const used: string[] = [];
    const slots: PlanSlot[] = DataStore.plan.filter((s: PlanSlot) => dates.indexOf(s.date) < 0);
    let filled: number = 0;

    for (let d = 0; d < dates.length; d++) {
      const date: string = dates[d];
      let dayCost: number = 0;
      for (let m = 0; m < MEAL_TYPES.length; m++) {
        const meal: string = MEAL_TYPES[m];
        const candidates: Dish[] = DataStore.dishesOf(date, meal)
          .filter((item: Dish) => item.price <= pref.maxPricePerMeal)
          .sort((a: Dish, b: Dish) => DataStore.score(b) - DataStore.score(a));

        if (candidates.length === 0) {
          continue;
        }

        let picked: Dish = candidates[0];
        const dayBudget: number = pref.weeklyBudget / 7;
        for (let i = 0; i < candidates.length; i++) {
          const cand: Dish = candidates[i];
          const repeated: boolean = used.indexOf(cand.id) >= 0;
          const overDayBudget: boolean = (dayCost + cand.price) > dayBudget && i < candidates.length - 1;
          if (!repeated && !overDayBudget) {
            picked = cand;
            break;
          }
        }

        used.push(picked.id);
        dayCost += picked.price;
        const slot: PlanSlot = new PlanSlot();
        slot.date = date;
        slot.mealType = meal;
        slot.dishId = picked.id;
        slots.push(slot);
        filled++;
      }
    }

    DataStore.plan = slots;
    DataStore.persistPlan();
    DataStore.sync();
    return filled > 0;
  }

  // ------------------------------------------------------------------
  // 示例数据
  // ------------------------------------------------------------------
  private static buildDemoPreference(): Preference {
    const pref: Preference = new Preference();
    pref.likedTags = ['清淡', '荤菜', '汤', '性价比'];
    pref.dislikedTags = ['辣', '油炸'];
    pref.maxPricePerMeal = 16;
    pref.weeklyBudget = 240;
    return pref;
  }

  private static makeDish(index: number, name: string, price: number, canteen: string,
    tags: string[], date: string, meal: string): Dish {
    const dish: Dish = new Dish();
    dish.id = date + '_' + meal + '_' + index.toString();
    dish.name = name;
    dish.price = price;
    dish.canteen = canteen;
    dish.tags = tags;
    dish.date = date;
    dish.mealType = meal;
    return dish;
  }

  private static buildDemoDishes(): Dish[] {
    const breakfastNames: string[] = ['小笼包', '豆浆油条', '鸡蛋灌饼', '小米粥', '煎饺', '三明治', '热干面', '燕麦牛奶杯'];
    const breakfastPrices: number[] = [5, 6, 7, 4, 8, 9, 7, 6];
    const breakfastTags: string[][] = [['主食', '荤菜'], ['清淡', '主食'], ['主食', '性价比'], ['清淡', '主食'],
      ['主食', '荤菜'], ['主食', '性价比'], ['面食', '辣'], ['清淡', '甜']];

    const lunchNames: string[] = ['番茄炒蛋', '宫保鸡丁', '红烧肉', '清炒时蔬', '鱼香肉丝', '麻婆豆腐',
      '糖醋里脊', '香菇滑鸡', '土豆牛腩', '扬州炒饭', '手撕包菜', '紫菜蛋花汤'];
    const lunchPrices: number[] = [12, 15, 18, 9, 14, 11, 16, 15, 20, 13, 8, 4];
    const lunchTags: string[][] = [['清淡', '荤菜'], ['辣', '荤菜'], ['荤菜'], ['清淡', '素菜'], ['辣', '荤菜'],
      ['辣', '素菜'], ['甜', '荤菜'], ['清淡', '荤菜'], ['荤菜', '性价比'], ['主食', '性价比'],
      ['清淡', '素菜'], ['清淡', '汤']];

    const dinnerNames: string[] = ['酸辣土豆丝', '可乐鸡翅', '蒜蓉西兰花', '回锅肉', '冬瓜排骨汤',
      '咖喱鸡饭', '牛肉拉面', '香菇青菜', '香煎鸡排', '番茄鸡蛋面'];
    const dinnerPrices: number[] = [10, 17, 11, 16, 13, 18, 15, 10, 19, 13];
    const dinnerTags: string[][] = [['辣', '素菜'], ['甜', '荤菜'], ['清淡', '素菜'], ['辣', '荤菜'],
      ['清淡', '汤'], ['荤菜', '性价比'], ['面食', '荤菜'], ['清淡', '素菜'], ['荤菜', '油炸'], ['面食', '性价比']];

    const dates: string[] = weekDates(mondayOf(new Date()));
    const canteens: string[] = ['一食堂', '二食堂', '三食堂', '清真食堂'];
    const result: Dish[] = [];

    for (let d = 0; d < dates.length; d++) {
      const date: string = dates[d];

      for (let i = 0; i < 3; i++) {
        const idx: number = (d + i) % breakfastNames.length;
        result.push(DataStore.makeDish(i, breakfastNames[idx], breakfastPrices[idx],
          canteens[(d + i) % canteens.length], breakfastTags[idx], date, MealType.BREAKFAST));
      }

      for (let i = 0; i < 4; i++) {
        const idx: number = (d * 3 + i) % lunchNames.length;
        result.push(DataStore.makeDish(i, lunchNames[idx], lunchPrices[idx],
          canteens[(d + i) % canteens.length], lunchTags[idx], date, MealType.LUNCH));
      }

      for (let i = 0; i < 3; i++) {
        const idx: number = (d * 2 + i) % dinnerNames.length;
        result.push(DataStore.makeDish(i, dinnerNames[idx], dinnerPrices[idx],
          canteens[(d + i) % canteens.length], dinnerTags[idx], date, MealType.DINNER));
      }
    }
    return result;
  }

  /** 生成菜品 id */
  static newDishId(date: string, mealType: string): string {
    return date + '_' + mealType + '_' + formatDate(new Date()) + '_' + Math.floor(Math.random() * 100000).toString();
  }
}
