/**
 * 数据模型：菜品、偏好、餐单安排
 * 全部为纯本地数据，不涉及账号与服务端。
 */

export enum MealType {
  BREAKFAST = 'breakfast',
  LUNCH = 'lunch',
  DINNER = 'dinner'
}

/** 餐次顺序（早餐 / 午餐 / 晚餐） */
export const MEAL_TYPES: string[] = [MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER];

/** 餐次中文名，与 MEAL_TYPES 一一对应 */
export const MEAL_LABELS: string[] = ['早餐', '午餐', '晚餐'];

/** 可选口味 / 属性标签 */
export const ALL_TAGS: string[] = ['辣', '清淡', '荤菜', '素菜', '汤', '主食', '面食', '油炸', '甜', '性价比'];

/** 食堂窗口候选 */
export const CANTEENS: string[] = ['一食堂', '二食堂', '三食堂', '清真食堂', '面包房'];

/** 一道菜 */
export class Dish {
  id: string = '';
  name: string = '';
  price: number = 0;
  canteen: string = '';
  /** 属于哪一餐：MealType */
  mealType: string = MealType.LUNCH;
  tags: string[] = [];
  /** 供应日期 yyyy-MM-dd */
  date: string = '';
}

/** 个人偏好 */
export class Preference {
  likedTags: string[] = [];
  dislikedTags: string[] = [];
  /** 单餐可接受最高价（元） */
  maxPricePerMeal: number = 15;
  /** 每周餐费预算（元） */
  weeklyBudget: number = 200;
}

/** 一周餐单中的一个格子 */
export class PlanSlot {
  /** yyyy-MM-dd */
  date: string = '';
  /** MealType */
  mealType: string = MealType.LUNCH;
  /** 选中的菜品 id，空字符串表示未选 */
  dishId: string = '';
}

export function mealLabel(mealType: string): string {
  const index: number = MEAL_TYPES.indexOf(mealType);
  return index >= 0 ? MEAL_LABELS[index] : mealType;
}

export function dishTagsText(dish: Dish): string {
  return dish.tags.length === 0 ? '无标签' : dish.tags.join(' · ');
}
