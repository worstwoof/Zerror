import { isDatabaseReady } from '../database'

export function isRenderFailureFeatureEnabled(): boolean {
  return process.env.ENABLE_RENDER_FAILURE_LOG === 'true' && isDatabaseReady()
}

export function getRenderFailureAdminToken(): string {
  return process.env.ADMIN_EXPORT_TOKEN?.trim() || ''
}

export function isRenderFailureAdminEnabled(): boolean {
  return Boolean(getRenderFailureAdminToken())
}