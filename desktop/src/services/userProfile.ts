import { apiGet, apiPut } from './client';
import { mockGetUserProfile, mockUpdateUserProfile } from '../mock/handlers/userProfile';
import type { UpdateUserProfilePayload, UserProfile } from '../shared/types/userProfile';

export function getUserProfile() {
  return apiGet<UserProfile>('/user/profile', () => mockGetUserProfile());
}

export function updateUserProfile(payload: UpdateUserProfilePayload) {
  return apiPut<UserProfile>('/user/profile', payload, () => mockUpdateUserProfile(payload));
}
