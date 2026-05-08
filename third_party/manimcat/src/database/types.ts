/**
 * Database - 类型定义
 * 与 Supabase 表结构对应
 */

/** 历史记录行（对应 history 表） */
export interface HistoryRow {
  id: string
  client_id: string
  prompt: string
  code: string | null
  output_mode: 'video' | 'image'
  quality: 'low' | 'medium' | 'high'
  status: 'completed' | 'failed'
  error?: string | null
  created_at: string
}

/** 创建历史记录请求 */
export interface CreateHistoryInput {
  client_id: string
  prompt: string
  code: string | null
  output_mode: 'video' | 'image'
  quality: 'low' | 'medium' | 'high'
  status: 'completed' | 'failed'
  error?: string | null
}

/** 分页查询结果 */
export interface PaginatedResult<T> {
  records: T[]
  total: number
  page: number
  pageSize: number
  hasMore: boolean
}
