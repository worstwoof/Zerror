/**
 * History Routes
 * 历史记录 API 路由
 * 所有查询均按 x-client-id 请求头隔离
 */

import express from 'express'
import { isDatabaseReady, listHistory, deleteHistory } from '../database'
import { getRequestClientId } from '../utils/request-client-id'

const router = express.Router()

/**
 * 从请求头中读取 client_id
 */
function getClientId(req: express.Request): string {
  return getRequestClientId(req) || ''
}

/**
 * GET /api/history
 * 分页获取历史记录（按 client_id 隔离）
 */
router.get('/history', async (req, res) => {
  const clientId = getClientId(req)

  if (!isDatabaseReady() || !clientId) {
    return res.json({
      records: [],
      total: 0,
      page: 1,
      pageSize: 12,
      hasMore: false,
    })
  }

  const page = Math.max(1, parseInt(String(req.query.page)) || 1)
  const pageSize = Math.min(50, Math.max(1, parseInt(String(req.query.pageSize)) || 12))

  try {
    const result = await listHistory(clientId, page, pageSize)
    return res.json(result)
  } catch (err) {
    console.error('[History Route] List failed:', err)
    return res.status(500).json({ error: 'Failed to load history' })
  }
})

/**
 * DELETE /api/history/:id
 * 删除单条历史记录（按 client_id 隔离）
 */
router.delete('/history/:id', async (req, res) => {
  const clientId = getClientId(req)

  if (!isDatabaseReady() || !clientId) {
    return res.status(404).json({ error: 'History feature is not enabled' })
  }

  const { id } = req.params

  try {
    const ok = await deleteHistory(id, clientId)
    if (!ok) {
      return res.status(404).json({ error: 'Record not found or delete failed' })
    }
    return res.json({ success: true })
  } catch (err) {
    console.error('[History Route] Delete failed:', err)
    return res.status(500).json({ error: 'Failed to delete record' })
  }
})

export default router
