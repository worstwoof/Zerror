import type { VideoConfig } from '../types'

export const DEFAULT_JOB_TIMEOUT_SECONDS = 1200
export const MAX_JOB_TIMEOUT_SECONDS = 3000

export function resolveJobTimeoutSeconds(videoConfig?: VideoConfig): number {
  const input = videoConfig?.timeout
  if (!Number.isFinite(input) || !input || input <= 0) {
    return DEFAULT_JOB_TIMEOUT_SECONDS
  }

  return Math.min(Math.floor(input), MAX_JOB_TIMEOUT_SECONDS)
}

export function resolveJobTimeoutMs(videoConfig?: VideoConfig): number {
  return resolveJobTimeoutSeconds(videoConfig) * 1000
}
