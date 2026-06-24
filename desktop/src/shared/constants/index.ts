export const ROUTES = {
  TODAY: '/today',
  CALENDAR: '/calendar',
  VAULT: '/vault',
  SEARCH: '/search',
  REVIEW: '/review',
} as const;

export const EMPTY_STATE_GUIDES = [
  { action: '设置今日重点', description: '告诉自己今天最重要的事情是什么' },
  { action: '新建日程', description: '安排今天要发生的具体时间段' },
  { action: '写一条快速记录', description: '随时捕捉想法和事件' },
  { action: '晚上完成复盘', description: '回顾今天并规划明天' },
] as const;
