package com.lifescale.backend.user.util;

/**
 * 密码强度统一校验（P0-8）：长度 ≥ 8 位，且同时包含字母与数字。
 * <p>
 * 集中到单一来源，注册流程与生产引导用户（Bootstrap）共用同一规则，避免策略漂移。
 * 校验不通过抛 {@link IllegalArgumentException}，由 {@code GlobalExceptionHandler} 映射为 400。
 */
public final class PasswordPolicy {

    /** 最小长度。 */
    public static final int MIN_LENGTH = 8;
    /** 最大长度（与 RegisterRequest @Size 上限对齐）。 */
    public static final int MAX_LENGTH = 64;

    private PasswordPolicy() {
    }

    /** 校验密码强度；不通过抛 IllegalArgumentException（含可读中文提示）。 */
    public static void validate(String password) {
        if (password == null || password.length() < MIN_LENGTH) {
            throw new IllegalArgumentException("密码至少 " + MIN_LENGTH + " 位");
        }
        if (password.length() > MAX_LENGTH) {
            throw new IllegalArgumentException("密码不能超过 " + MAX_LENGTH + " 位");
        }
        boolean hasLetter = false;
        boolean hasDigit = false;
        for (int i = 0; i < password.length(); i++) {
            char c = password.charAt(i);
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
                hasLetter = true;
            } else if (c >= '0' && c <= '9') {
                hasDigit = true;
            }
            if (hasLetter && hasDigit) {
                break;
            }
        }
        if (!hasLetter || !hasDigit) {
            throw new IllegalArgumentException("密码需同时包含字母和数字");
        }
    }
}
