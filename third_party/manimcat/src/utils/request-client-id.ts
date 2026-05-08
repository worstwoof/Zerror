import type express from 'express'

export function getRequestClientId(req: express.Request): string | undefined {
  const clientId = String(req.headers['x-client-id'] || '').trim()
  return clientId || undefined
}
