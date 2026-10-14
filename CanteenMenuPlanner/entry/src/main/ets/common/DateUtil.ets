/**
 * 日期工具：以「周一」为一周起点
 */

export const WEEK_LABELS: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

export function pad2(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

export function formatDate(date: Date): string {
  return date.getFullYear().toString() + '-' + pad2(date.getMonth() + 1) + '-' + pad2(date.getDate());
}

export function todayStr(): string {
  return formatDate(new Date());
}

/** 返回 date 所在周的周一 */
export function mondayOf(date: Date): Date {
  const day: number = date.getDay();
  const offset: number = day === 0 ? -6 : 1 - day;
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + offset);
}

export function addDays(date: Date, days: number): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + days);
}

/** 给定周一，返回该周 7 天的 yyyy-MM-dd */
export function weekDates(monday: Date): string[] {
  const result: string[] = [];
  for (let i = 0; i < 7; i++) {
    result.push(formatDate(addDays(monday, i)));
  }
  return result;
}

/** 2026-10-14 -> 10/14 */
export function shortDate(dateStr: string): string {
  const parts: string[] = dateStr.split('-');
  if (parts.length === 3) {
    return parts[1] + '/' + parts[2];
  }
  return dateStr;
}

/** 相对本周偏移 weekOffset 周的 7 天日期 */
export function weekDatesByOffset(weekOffset: number): string[] {
  const monday: Date = addDays(mondayOf(new Date()), weekOffset * 7);
  return weekDates(monday);
}

/** 是否同一周 */
export function sameWeek(dates: string[], date: string): boolean {
  return dates.indexOf(date) >= 0;
}
