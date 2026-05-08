const SESSION_STORAGE_PREFIX = 'manimcat:studio'
const MAX_RECENT_SESSIONS = 12

function getLastSessionIdKey(studioKind: string) {
  return `${SESSION_STORAGE_PREFIX}:last-session-id:${studioKind}`
}

function getRecentSessionIdsKey(studioKind: string) {
  return `${SESSION_STORAGE_PREFIX}:recent-session-ids:${studioKind}`
}

export function readLastStudioSessionId(studioKind: string): string | null {
  if (typeof window === 'undefined') {
    return null
  }

  return window.localStorage.getItem(getLastSessionIdKey(studioKind))
}

export function writeLastStudioSessionId(studioKind: string, sessionId: string) {
  if (typeof window === 'undefined') {
    return
  }

  window.localStorage.setItem(getLastSessionIdKey(studioKind), sessionId)
}

export function clearLastStudioSessionId(studioKind: string) {
  if (typeof window === 'undefined') {
    return
  }

  window.localStorage.removeItem(getLastSessionIdKey(studioKind))
}

export function readRecentStudioSessionIds(studioKind: string): string[] {
  if (typeof window === 'undefined') {
    return []
  }

  const raw = window.localStorage.getItem(getRecentSessionIdsKey(studioKind))
  if (!raw) {
    return []
  }

  try {
    const parsed = JSON.parse(raw)
    if (!Array.isArray(parsed)) {
      return []
    }

    return parsed.filter((value): value is string => typeof value === 'string')
  } catch {
    return []
  }
}

export function writeRecentStudioSessionIds(studioKind: string, sessionIds: string[]) {
  if (typeof window === 'undefined') {
    return
  }

  window.localStorage.setItem(
    getRecentSessionIdsKey(studioKind),
    JSON.stringify(sessionIds.slice(0, MAX_RECENT_SESSIONS)),
  )
}

export function rememberStudioSessionId(studioKind: string, sessionId: string) {
  const current = readRecentStudioSessionIds(studioKind)
  const next = [sessionId, ...current.filter((id) => id !== sessionId)]
  writeLastStudioSessionId(studioKind, sessionId)
  writeRecentStudioSessionIds(studioKind, next)
}

export function forgetStudioSessionId(studioKind: string, sessionId: string) {
  const current = readRecentStudioSessionIds(studioKind)
  const next = current.filter((id) => id !== sessionId)
  writeRecentStudioSessionIds(studioKind, next)

  if (readLastStudioSessionId(studioKind) === sessionId) {
    if (next[0]) {
      writeLastStudioSessionId(studioKind, next[0])
    } else {
      clearLastStudioSessionId(studioKind)
    }
  }
}
