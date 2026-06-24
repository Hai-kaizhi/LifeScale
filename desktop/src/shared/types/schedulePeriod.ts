export interface SchedulePeriod {
  id: string;
  code: string;
  name: string;
  startTime: string;
  endTime: string;
  startMinute: number;
  endMinute: number;
  sortOrder: number;
}

export const DEFAULT_SCHEDULE_PERIODS: SchedulePeriod[] = [
  {
    id: 'before_dawn',
    code: 'before_dawn',
    name: '凌晨',
    startTime: '00:00',
    endTime: '06:00',
    startMinute: 0,
    endMinute: 360,
    sortOrder: 10,
  },
  {
    id: 'early_morning',
    code: 'early_morning',
    name: '早晨',
    startTime: '06:00',
    endTime: '09:00',
    startMinute: 360,
    endMinute: 540,
    sortOrder: 20,
  },
  {
    id: 'morning',
    code: 'morning',
    name: '上午',
    startTime: '09:00',
    endTime: '12:00',
    startMinute: 540,
    endMinute: 720,
    sortOrder: 30,
  },
  {
    id: 'afternoon',
    code: 'afternoon',
    name: '下午',
    startTime: '12:00',
    endTime: '18:00',
    startMinute: 720,
    endMinute: 1080,
    sortOrder: 40,
  },
  {
    id: 'evening',
    code: 'evening',
    name: '晚上',
    startTime: '18:00',
    endTime: '24:00',
    startMinute: 1080,
    endMinute: 1440,
    sortOrder: 50,
  },
];
