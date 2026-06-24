// 桌面端统一从这里读取后端 API 基础地址，后续服务封装都应复用该常量。
export const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8080/api";
