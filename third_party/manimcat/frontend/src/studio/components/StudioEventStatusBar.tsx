import type { StudioRun } from '../protocol/studio-agent-types'
import { translateEventStatus, translateRunStatus, translateSnapshotStatus } from '../labels'
import { formatStudioTime, studioPanelClass, studioStatusBadge, truncateStudioText } from '../theme'
import { useI18n } from '../../i18n'

interface StudioEventStatusBarProps {
  sessionTitle?: string
  snapshotStatus: string
  eventStatus: string
  lastEventType?: string | null
  lastEventAt?: number | null
  eventError?: string | null
  latestRun?: StudioRun | null
  latestAssistantText?: string
  latestQuestion?: {
    question: string
    details?: string
  } | null
}

export function StudioEventStatusBar({
  sessionTitle,
  snapshotStatus,
  eventStatus,
  lastEventType,
  lastEventAt,
  eventError,
  latestRun,
  latestAssistantText,
  latestQuestion,
}: StudioEventStatusBarProps) {
  const { t } = useI18n()
  return (
    <section className={studioPanelClass('p-4')}>
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-xs uppercase tracking-[0.28em] text-text-secondary">{t('studio.event.session')}</span>
        <span className="text-sm font-medium text-text-primary">{sessionTitle ?? t('studio.initializing')}</span>
        <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${studioStatusBadge(snapshotStatus)}`}>
          {t('studio.event.snapshot', { status: translateSnapshotStatus(snapshotStatus, t) })}
        </span>
        <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${studioStatusBadge(eventStatus)}`}>
          {t('studio.event.events', { status: translateEventStatus(eventStatus, t) })}
        </span>
        {latestRun && (
          <span className={`rounded-full px-2.5 py-1 text-xs font-medium ${studioStatusBadge(latestRun.status)}`}>
            {t('studio.event.run', { status: translateRunStatus(latestRun.status, t) })}
          </span>
        )}
      </div>

      <div className="mt-3 grid gap-3 text-sm text-text-secondary md:grid-cols-3">
        <div>
          <div className="text-xs uppercase tracking-[0.2em]">{t('studio.event.latestEvent')}</div>
          <div className="mt-1 text-text-primary">{lastEventType ?? t('studio.event.waitingForStream')}</div>
          <div className="mt-1 text-xs">{formatStudioTime(lastEventAt)}</div>
        </div>
        <div>
          <div className="text-xs uppercase tracking-[0.2em]">{t('studio.event.assistantStream')}</div>
          <div className="mt-1 text-text-primary">{latestAssistantText ? truncateStudioText(latestAssistantText) : t('studio.event.noLiveText')}</div>
        </div>
        <div>
          <div className="text-xs uppercase tracking-[0.2em]">{t('studio.event.pendingQuestion')}</div>
          <div className="mt-1 text-text-primary">{latestQuestion?.question ?? t('studio.event.none')}</div>
          {latestQuestion?.details && <div className="mt-1 text-xs">{truncateStudioText(latestQuestion.details, 90)}</div>}
        </div>
      </div>

      {eventError && <div className="mt-3 text-sm text-rose-600 dark:text-rose-300">{eventError}</div>}
    </section>
  )
}
