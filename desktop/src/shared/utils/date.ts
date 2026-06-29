import dayjs from 'dayjs';

export function formatDate(date: string | Date = new Date()): string {
  return dayjs(date).format('YYYY-MM-DD');
}

export function getWeekday(date: string | Date = new Date()): string {
  const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
  return weekdays[dayjs(date).day()];
}

export function isToday(date: string): boolean {
  return date === formatDate();
}

export function formatDisplayDate(date: string): string {
  return dayjs(date).format('YYYY年M月D日');
}
