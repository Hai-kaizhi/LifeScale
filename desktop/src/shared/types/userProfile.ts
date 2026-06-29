/**
 * 用户个人资料（展示型），与后端 UserProfileDTO 对齐。
 * 字段与后端 /api/user/profile 一一对应。
 */
export interface UserProfile {
  /** 昵称（展示名）。 */
  nickname: string;
  /** 头像 URL，留空则前端按昵称首字渲染。 */
  avatarUrl: string;
  /** 问候语，如「早安」。 */
  greeting: string;
  /** 每日提示 / 励志金句。 */
  motivationalQuote: string;
}

/**
 * 个人资料更新载荷：部分更新，未提供（undefined）的字段不更新。
 */
export interface UpdateUserProfilePayload {
  nickname?: string;
  avatarUrl?: string;
  greeting?: string;
  motivationalQuote?: string;
}

/**
 * 未登录（本地模式）使用的固定默认资料。只读，不会变化。
 * greeting / motivationalQuote 在今日页等处直接展示，昵称留空（侧边栏显示「未登录」）。
 */
export const DEFAULT_USER_PROFILE: UserProfile = {
  nickname: '',
  avatarUrl: '',
  greeting: '早安',
  motivationalQuote: '专注当下，重视行动，让每一天都成为进步的刻度。',
};
