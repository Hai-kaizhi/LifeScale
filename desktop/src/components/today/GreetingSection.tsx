import { useUserProfile } from '../../hooks/useUserProfile';

/**
 * 今日页问候区。
 * 未登录：使用固定默认资料（只读），问候语 + 默认每日提示。
 * 已登录：显示用户资料中的问候语、昵称和每日提示。
 */
export function GreetingSection() {
  const { profile, isAuthenticated } = useUserProfile();
  // 未登录昵称为空时，不显示具体名字，只显示问候语。
  const namePart = isAuthenticated && profile.nickname.trim() ? `，${profile.nickname}` : '';

  return (
    <section className="greeting-section" aria-label="今日问候">
      <h2 className="greeting-title">
        {profile.greeting}
        {namePart} <span aria-hidden="true">👋</span>
      </h2>
      <p className="greeting-subtitle">{profile.motivationalQuote}</p>
    </section>
  );
}
