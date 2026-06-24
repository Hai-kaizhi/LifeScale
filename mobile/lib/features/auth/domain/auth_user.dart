/// 当前登录用户（领域实体，区别于传输层 [CurrentUser]/[AuthSession] DTO）。
class AuthUser {
  const AuthUser({required this.id, required this.username, this.email});

  final int id;
  final String username;
  final String? email;
}
