/**
 * 历史记录面板 - 工作空间内嵌模块
 */

import { useCallback, useEffect, useRef, useState } from 'react';
import { getHistoryList, deleteHistoryRecord } from '../lib/api';
import type { HistoryRecord } from '../types/api';
import { useI18n } from '../i18n';

interface HistoryPanelProps {
  isActive: boolean;
  onReusePrompt?: (prompt: string) => void;
}

export function HistoryPanel({ isActive, onReusePrompt }: HistoryPanelProps) {
  const { t } = useI18n();
  const [records, setRecords] = useState<HistoryRecord[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const loadedRef = useRef(false);

  const loadHistory = useCallback(async (pageNum: number, append = false) => {
    setLoading(true);
    setError(null);
    try {
      const data = await getHistoryList(pageNum, 12);
      setRecords(prev => append ? [...prev, ...data.records] : data.records);
      setHasMore(data.hasMore);
      setPage(pageNum);
    } catch (err) {
      setError(err instanceof Error ? err.message : t('history.loadFailed'));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    if (isActive && !loadedRef.current) {
      loadedRef.current = true;
      void loadHistory(1);
    }
  }, [isActive, loadHistory]);

  const handleLoadMore = () => {
    if (!loading && hasMore) {
      void loadHistory(page + 1, true);
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteHistoryRecord(id);
      setRecords(prev => prev.filter(r => r.id !== id));
      setConfirmDeleteId(null);
    } catch {
      // silently fail
    }
  };

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    return date.toLocaleDateString(undefined, {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <div className="animate-fade-in">
      <h2 className="text-2xl font-light text-text-primary mb-8">{t('history.title')}</h2>

      {error && (
        <div className="rounded-2xl bg-red-50/80 dark:bg-red-900/20 border border-red-200/50 dark:border-red-700/40 p-4 text-sm text-red-600 dark:text-red-300 mb-6">
          {error}
        </div>
      )}

      {!loading && records.length === 0 && !error && (
        <div className="flex flex-col items-center justify-center py-24 text-center">
          <svg className="w-16 h-16 text-text-secondary/20 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p className="text-text-secondary/50 text-sm">{t('history.empty')}</p>
          <p className="text-text-secondary/30 text-xs mt-1">{t('history.emptyHint')}</p>
        </div>
      )}

      {records.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {records.map(record => (
            <div
              key={record.id}
              className="group rounded-2xl bg-bg-secondary/25 border border-bg-tertiary/30 overflow-hidden hover:border-bg-tertiary/60 transition-colors"
            >
              {/* 卡片头部：状态 + 时间 */}
              <div className="px-4 pt-4 pb-3 flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className={`w-2 h-2 rounded-full ${record.status === 'completed' ? 'bg-green-400/80' : 'bg-red-400/80'}`} />
                  <span className="text-[11px] text-text-secondary/60">{formatDate(record.created_at)}</span>
                </div>
                <div className="flex items-center gap-1">
                  <span className="text-[10px] uppercase tracking-wider text-text-secondary/40 bg-bg-tertiary/30 px-2 py-0.5 rounded">
                    {record.output_mode}
                  </span>
                  <span className="text-[10px] uppercase tracking-wider text-text-secondary/40 bg-bg-tertiary/30 px-2 py-0.5 rounded">
                    {record.quality}
                  </span>
                </div>
              </div>

              {/* 提示词预览 */}
              <div className="px-4 pb-3">
                <p className="text-sm text-text-primary/80 line-clamp-3 leading-relaxed">{record.prompt}</p>
              </div>

              {/* 代码展开区 */}
              {expandedId === record.id && record.code && (
                <div className="px-4 pb-3">
                  <pre className="text-[11px] text-text-secondary/70 bg-bg-primary/50 rounded-lg p-3 max-h-48 overflow-auto font-mono leading-relaxed">
                    {record.code}
                  </pre>
                </div>
              )}

              {/* 操作栏 */}
              <div className="px-4 py-3 border-t border-bg-tertiary/20 flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                {record.code && (
                  <button
                    onClick={() => setExpandedId(expandedId === record.id ? null : record.id)}
                    className="text-[11px] text-text-secondary/60 hover:text-text-primary px-2 py-1 rounded hover:bg-bg-tertiary/30 transition-colors"
                  >
                    {t('history.viewCode')}
                  </button>
                )}
                {onReusePrompt && (
                  <button
                    onClick={() => onReusePrompt(record.prompt)}
                    className="text-[11px] text-text-secondary/60 hover:text-text-primary px-2 py-1 rounded hover:bg-bg-tertiary/30 transition-colors"
                  >
                    {t('history.reuse')}
                  </button>
                )}
                <div className="flex-1" />
                {confirmDeleteId === record.id ? (
                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => void handleDelete(record.id)}
                      className="text-[11px] text-red-400 hover:text-red-300 px-2 py-1 rounded hover:bg-red-500/10 transition-colors"
                    >
                      {t('common.confirm')}
                    </button>
                    <button
                      onClick={() => setConfirmDeleteId(null)}
                      className="text-[11px] text-text-secondary/60 hover:text-text-primary px-2 py-1 rounded hover:bg-bg-tertiary/30 transition-colors"
                    >
                      {t('common.cancel')}
                    </button>
                  </div>
                ) : (
                  <button
                    onClick={() => setConfirmDeleteId(record.id)}
                    className="text-[11px] text-text-secondary/40 hover:text-red-400 px-2 py-1 rounded hover:bg-red-500/10 transition-colors"
                  >
                    {t('history.delete')}
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* 加载更多 */}
      {records.length > 0 && (
        <div className="flex justify-center mt-8">
          {hasMore ? (
            <button
              onClick={handleLoadMore}
              disabled={loading}
              className="px-6 py-2 text-xs text-text-secondary/70 hover:text-text-primary bg-bg-secondary/30 hover:bg-bg-secondary/50 rounded-lg transition-colors disabled:opacity-50"
            >
              {loading ? t('common.loading') : t('history.loadMore')}
            </button>
          ) : (
            <span className="text-xs text-text-secondary/30">{t('history.noMore')}</span>
          )}
        </div>
      )}

      {/* 初始加载 */}
      {loading && records.length === 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5 animate-pulse">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="rounded-2xl bg-bg-secondary/25 border border-bg-tertiary/30 h-40" />
          ))}
        </div>
      )}
    </div>
  );
}
