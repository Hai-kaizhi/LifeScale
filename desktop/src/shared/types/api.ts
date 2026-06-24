/** Standard API response envelope */
export interface ApiResponse<T, TPermissions = unknown, TStatus extends string = string> {
  code: number;
  success: boolean;
  message: string;
  data: T;
  status?: TStatus;
  permissions?: TPermissions;
}

/** Paginated list response */
export interface ApiListData<T, TPermissions = unknown> {
  list: T[];
  total: number;
  pageNo: number;
  pageSize: number;
  status?: string;
  permissions?: TPermissions;
}

/** Paginated list response */
export interface ApiListResponse<T, TPermissions = unknown> {
  code: number;
  success: boolean;
  message: string;
  data: ApiListData<T, TPermissions>;
}

/** Request state for UI rendering */
export type RequestStatus = 'idle' | 'loading' | 'success' | 'error';
