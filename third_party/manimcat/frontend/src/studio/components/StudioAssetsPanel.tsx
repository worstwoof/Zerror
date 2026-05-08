import type { StudioFileAttachment, StudioRun, StudioSession, StudioTask, StudioWork, StudioWorkResult } from '../protocol/studio-agent-types'
import { translateResultKind, translateRunStatus, translateWorkStatus, translateWorkType } from '../labels'
import { formatStudioTime, studioStatusBadge, truncateStudioText } from '../theme'
import { useI18n } from '../../i18n'

interface StudioWorkListItem {
  work: StudioWork
  latestTask: StudioTask | null
  result: StudioWorkResult | null
}

interface StudioAssetsPanelProps {
  session: StudioSession | null
  works: StudioWorkListItem[]
  selectedWorkId: string | null
  work: StudioWork | null
  result: StudioWorkResult | null
  latestRun: StudioRun | null
  onSelectWork: (workId: string) => void
}

export function StudioAssetsPanel({
  session,
  works,
  selectedWorkId,
  work,
  result,
  latestRun,
  onSelectWork,
}: StudioAssetsPanelProps) {
  const { t } = useI18n()
  const previewAttachment = result?.attachments?.find(isPreviewAttachment) ?? result?.attachments?.[0] ?? null

  return (
    <aside className="flex h-full min-h-0 w-[360px] shrink-0 flex-col gap-6 overflow-hidden px-6 pb-6 pt-8 shadow-[inset_-8px_0_12px_-8px_rgba(0,0,0,0.04)] dark:shadow-[inset_-8px_0_12px_-8px_rgba(0,0,0,0.2)]">
      <div className="shrink-0">
        <div className="flex items-center justify-between">
          <div className="text-[10px] uppercase tracking-[0.34em] text-text-secondary/45">{t('studio.preview')}</div>
          <span className="studio-paw-float text-sm opacity-30">🐾</span>
        </div>
        <div className="mt-3 flex items-start justify-between gap-3">
          <div>
            <h2 className="text-lg font-medium text-text-primary/90">{work?.title ?? t('studio.waitingOutput')}</h2>
            <div className="mt-2 text-xs leading-6 text-text-secondary/60">
              {session?.title ?? t('studio.sessionLabel')} · {latestRun ? translateRunStatus(latestRun.status, t) : t('studio.idle')}
            </div>
          </div>
          <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${studioStatusBadge(work?.status ?? latestRun?.status ?? 'idle')}`}>
            {work ? translateWorkStatus(work.status, t) : latestRun ? translateRunStatus(latestRun.status, t) : t('studio.idle')}
          </span>
        </div>
      </div>

      <section className="shrink-0 overflow-hidden">
        <div className="aspect-video">
          <PreviewSurface attachment={previewAttachment} result={result} />
        </div>
        {(previewAttachment || result?.summary) && (
          <div className="px-1 py-4">
            <div className="text-[13px] leading-6 text-text-primary/70">{result?.summary}</div>
            <div className="mt-2 flex flex-wrap gap-2 text-[10px] uppercase tracking-widest text-text-secondary/40">
              <span>{result ? translateResultKind(result.kind, t) : ''}</span>
              {result && <span>·</span>}
              <span>{result ? formatStudioTime(result.createdAt) : ''}</span>
            </div>
          </div>
        )}
      </section>

      <section className="flex min-h-0 flex-1 flex-col overflow-hidden">
        <div className="flex items-center justify-between gap-3 px-1">
          <div>
            <div className="text-[9px] font-bold uppercase tracking-[0.3em] text-text-secondary/35">{t('studio.libraryWorks')}</div>
          </div>
          <div className="font-mono text-[10px] text-text-secondary/40">{works.length.toString().padStart(2, '0')}</div>
        </div>

        <div className="mt-6 min-h-0 flex-1 space-y-2 overflow-y-auto pr-2">
          {works.map((entry) => {
            const { work: item, latestTask } = entry
            const selected = item.id === selectedWorkId
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => onSelectWork(item.id)}
                className={`w-full rounded-xl px-5 py-4 text-left transition-all duration-300 ${
                  selected
                    ? 'bg-bg-secondary/40 shadow-sm'
                    : 'hover:bg-bg-secondary/20'
                }`}
              >
                <div className="flex items-center justify-between gap-3">
                  <div className="min-w-0">
                    <div className={`truncate text-[13px] font-bold transition-colors ${selected ? 'text-text-primary' : 'text-text-primary/60'}`}>
                      {item.title}
                    </div>
                    <div className="mt-1 text-[9px] font-bold uppercase tracking-[0.2em] text-text-secondary/30">{translateWorkType(item.type, t)}</div>
                  </div>
                  <span className={`shrink-0 rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-tighter ${studioStatusBadge(item.status)}`}>
                    {translateWorkStatus(item.status, t)}
                  </span>
                </div>
                <div className="mt-3 space-y-1.5 text-[11px] leading-5 text-text-secondary/50">
                  <div className="flex items-center gap-2">
                    <span className="h-1 w-1 rounded-full bg-current opacity-30" />
                    <span className="truncate">{latestTask ? truncateStudioText(latestTask.title, 42) : t('studio.waitingEllipsis')}</span>
                  </div>
                </div>
              </button>
            )
          })}
        </div>
      </section>
    </aside>
  )
}

function PreviewSurface({
  attachment,
  result,
}: {
  attachment: StudioFileAttachment | null | undefined
  result: StudioWorkResult | null
}) {
  const { t } = useI18n()
  if (attachment?.mimeType?.startsWith('video/') || isVideoPath(attachment?.path)) {
    return <video src={attachment?.path} controls className="h-full w-full object-contain" />
  }

  if (attachment?.mimeType?.startsWith('image/') || isImagePath(attachment?.path)) {
    return <img src={attachment?.path} alt={attachment?.name ?? t('common.preview')} className="h-full w-full object-contain" />
  }

  if (result?.kind === 'failure-report') {
    return (
      <div className="flex h-full items-center justify-center opacity-30">
        <div className="text-[10px] font-bold uppercase tracking-[0.4em] text-rose-500/70">{t('studio.renderFailed')}</div>
      </div>
    )
  }

  // 无产出时保持空白
  return null
}

function isPreviewAttachment(attachment: { path: string; mimeType?: string } | undefined) {
  if (!attachment) {
    return false
  }

  return (
    attachment.mimeType?.startsWith('video/') ||
    attachment.mimeType?.startsWith('image/') ||
    isVideoPath(attachment.path) ||
    isImagePath(attachment.path)
  )
}

function isVideoPath(path?: string) {
  return Boolean(path && /\.(mp4|webm|mov|m4v)$/i.test(path))
}

function isImagePath(path?: string) {
  return Boolean(path && /\.(png|jpg|jpeg|gif|webp|svg)$/i.test(path))
}
