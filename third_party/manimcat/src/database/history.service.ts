/**
 * Database - 历史记录服务
 * 提供 CRUD 操作，与 Supabase history 表交互
 * 当数据库未启用时，所有方法安全地返回空结果
 * 所有查询均按 client_id 隔离
 */

import { getSupabaseClient } from './client'
import type { HistoryRow, CreateHistoryInput, PaginatedResult } from './types'

const TABLE = 'history'

/**
 * 创建一条历史记录
 */
export async function createHistory(input: CreateHistoryInput): Promise<HistoryRow | null> {
  const client = getSupabaseClient()
  if (!client) return null

  const { data, error } = await client
    .from(TABLE)
    .insert(input)
    .select()
    .single()

  if (error) {
    console.error('[History] Failed to create record:', error.message)
    return null
  }

  return data as HistoryRow
}

/**
 * 分页查询历史记录（按 client_id 隔离，按创建时间倒序）
 */
export async function listHistory(
  clientId: string,
  page = 1,
  pageSize = 12
): Promise<PaginatedResult<HistoryRow>> {
  const empty: PaginatedResult<HistoryRow> = {
    records: [],
    total: 0,
    page,
    pageSize,
    hasMore: false,
  }

  const client = getSupabaseClient()
  if (!client) return empty

  const from = (page - 1) * pageSize
  const to = from + pageSize - 1

  // 查询总数
  const { count, error: countError } = await client
    .from(TABLE)
    .select('*', { count: 'exact', head: true })
    .eq('client_id', clientId)

  if (countError) {
    console.error('[History] Failed to count records:', countError.message)
    return empty
  }

  const total = count ?? 0

  // 查询分页数据
  const { data, error } = await client
    .from(TABLE)
    .select('*')
    .eq('client_id', clientId)
    .order('created_at', { ascending: false })
    .range(from, to)

  if (error) {
    console.error('[History] Failed to list records:', error.message)
    return empty
  }

  const records = (data ?? []) as HistoryRow[]

  return {
    records,
    total,
    page,
    pageSize,
    hasMore: from + records.length < total,
  }
}

/**
 * 获取单条历史记录（按 client_id 隔离）
 */
export async function getHistory(id: string, clientId: string): Promise<HistoryRow | null> {
  const client = getSupabaseClient()
  if (!client) return null

  const { data, error } = await client
    .from(TABLE)
    .select('*')
    .eq('id', id)
    .eq('client_id', clientId)
    .single()

  if (error) {
    console.error('[History] Failed to get record:', error.message)
    return null
  }

  return data as HistoryRow
}

/**
 * 删除单条历史记录（按 client_id 隔离）
 */
export async function deleteHistory(id: string, clientId: string): Promise<boolean> {
  const client = getSupabaseClient()
  if (!client) return false

  const { error } = await client
    .from(TABLE)
    .delete()
    .eq('id', id)
    .eq('client_id', clientId)

  if (error) {
    console.error('[History] Failed to delete record:', error.message)
    return false
  }

  return true
}
