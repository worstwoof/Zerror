import type {
  StudioRun,
  StudioTask,
  StudioWork,
  StudioWorkResult,
} from '../protocol/studio-agent-types'
import type { StudioReviewViewModel } from '../store/studio-selectors'
import { formatStudioTime, studioSeverityBadge, truncateStudioText } from '../theme'
import { translateEventStatus, translateResultKind, translateRunStatus, translateSeverity, translateSnapshotStatus } from '../labels'
import { StudioTaskTimeline } from './StudioTaskTimeline'
import { useI18n } from '../../i18n'

interface StudioPipelinePanelProps {
  latestRun: StudioRun | null
  work: StudioWork | null
  result: StudioWorkResult | null
  tasks: StudioTask[]
  review: StudioReviewViewModel | null
  latestAssistantText: string
  latestQuestion: { question: string; details?: string } | null
  snapshotStatus: 'idle' | 'loading' | 'ready' | 'error'
  eventStatus: 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'disconnected'
  errorMessage?: string | null
  onRefresh: () => Promise<void> | void
}

export function StudioPipelinePanel({
  latestRun,
  work,
  result,
  tasks,
  review,
  latestAssistantText,
  latestQuestion,
  snapshotStatus,
  eventStatus,
  errorMessage,
  onRefresh,
}: StudioPipelinePanelProps) {
  const { t } = useI18n()
  const findings = review?.findings ?? []
  const activeTask =
    [...tasks].reverse().find((task) => task.status === 'running' || task.status === 'queued' || task.status === 'pending_confirmation') ??
    tasks.at(-1) ??
    null

  return (
    <aside className="flex h-full min-h-0 w-[360px] shrink-0 flex-col overflow-hidden px-6 pb-6 pt-8 shadow-[inset_8px_0_12px_-8px_rgba(0,0,0,0.04)] dark:shadow-[inset_8px_0_12px_-8px_rgba(0,0,0,0.2)]">
      <div className="min-h-0 flex-1 overflow-y-auto pr-1">
        <section>
          <div className="flex items-center justify-between gap-3">
            <div>
              <div className="flex items-center gap-2">
                <div className="text-[10px] uppercase tracking-[0.3em] text-text-secondary/45">{t('studio.pipeline.execution')}</div>
                <span className="studio-paw-float text-sm opacity-30" style={{ animationDelay: '1.5s' }}>🐾</span>
              </div>
              <div className="mt-2 text-base font-medium text-text-primary/88">{work?.title ?? t('studio.pipeline.waitingTarget')}</div>
            </div>
            <button
              type="button"
              onClick={() => void onRefresh()}
              className="px-3 py-1.5 text-[11px] text-text-secondary/50 transition hover:text-text-primary/70"
            >
              {t('studio.pipeline.refresh')}
            </button>
          </div>

          <div className="mt-5 space-y-2.5">
            <StatusRow label={t('studio.pipeline.running')} value={latestRun ? translateRunStatus(latestRun.status, t) : t('studio.idle')} tone={latestRun?.status ?? 'idle'} />
            <StatusRow label={t('studio.pipeline.eventStream')} value={translateEventStatus(eventStatus, t)} tone={eventStatus} />
            <StatusRow label={t('studio.pipeline.snapshot')} value={translateSnapshotStatus(snapshotStatus, t)} tone={snapshotStatus} />
            <StatusRow label={t('studio.pipeline.currentTask')} value={activeTask ? activeTask.title : t('studio.pipeline.none')} tone={activeTask?.status ?? 'idle'} />
          </div>
        </section>

        <SectionDivider />

        {latestQuestion && (
          <>
            <section className="border-l-2 border-amber-500/40 pl-4">
              <div className="text-[10px] uppercase tracking-[0.3em] text-amber-700/65 dark:text-amber-400/65">{t('studio.pipeline.pendingQuestion')}</div>
              <div className="mt-3 text-sm leading-7 text-text-primary/86">{latestQuestion.question}</div>
              {latestQuestion.details && <div className="mt-2 text-xs leading-6 text-text-secondary/62">{latestQuestion.details}</div>}
            </section>
            <SectionDivider />
          </>
        )}

        {errorMessage && (
          <>
            <section className="border-l-2 border-rose-500/40 pl-4">
              <div className="text-[10px] uppercase tracking-[0.3em] text-rose-700/65 dark:text-rose-400/65">{t('studio.pipeline.statusError')}</div>
              <div className="mt-3 text-sm leading-7 text-text-primary/86">{errorMessage}</div>
            </section>
            <SectionDivider />
          </>
        )}

        {latestAssistantText && (
          <>
            <section className="border-l-2 border-sky-500/40 pl-4">
              <div className="text-[10px] uppercase tracking-[0.3em] text-sky-700/65 dark:text-sky-400/65">{t('studio.pipeline.latestFeedback')}</div>
              <div className="mt-3 text-sm leading-7 text-text-primary/82">{truncateStudioText(latestAssistantText, 180)}</div>
            </section>
            <SectionDivider />
          </>
        )}

        <section>
          <div className="flex items-center justify-between gap-3">
            <div>
              <div className="text-[10px] uppercase tracking-[0.3em] text-text-secondary/45">{t('studio.pipeline.timeline')}</div>
              <div className="mt-1 text-sm text-text-secondary/60">{t('studio.pipeline.timelineHint')}</div>
            </div>
            <span className="rounded-full bg-bg-secondary/50 px-3 py-1 text-xs text-text-secondary/65">{tasks.length}</span>
          </div>
          <div className="mt-5 max-h-[28vh] overflow-y-auto pr-1">
            <StudioTaskTimeline tasks={tasks} />
          </div>
        </section>

        <SectionDivider />

        {result && (
          <>
            <section>
              <div className="text-[10px] uppercase tracking-[0.3em] text-text-secondary/45">{t('studio.pipeline.resultSummary')}</div>
              <div className="mt-3 flex items-center justify-between gap-3">
                <div className="text-sm font-medium text-text-primary/86">{translateResultKind(result.kind, t)}</div>
                <div className="text-xs text-text-secondary/55">{formatStudioTime(result.createdAt)}</div>
              </div>
              <div className="mt-3 text-sm leading-7 text-text-secondary/70">{result.summary}</div>
              {findings.length > 0 && (
                <div className="mt-4 space-y-3">
                  {findings.slice(0, 2).map((finding) => (
                    <div key={`${finding.code}-${finding.title}`} className="border-l-2 pl-3" style={{ borderColor: severityColor(finding.severity) }}>
                      <div className="flex items-start justify-between gap-3">
                        <div className="text-sm text-text-primary/84">{finding.title}</div>
                        <span className={`rounded-full px-2 py-0.5 text-[10px] font-medium ${studioSeverityBadge(finding.severity)}`}>
                          {translateSeverity(finding.severity, t)}
                        </span>
                      </div>
                      <div className="mt-1.5 text-[11px] leading-5 text-text-secondary/65">{truncateStudioText(finding.rationale, 100)}</div>
                    </div>
                  ))}
                </div>
              )}
            </section>
            <SectionDivider />
          </>
        )}
      </div>
    </aside>
  )
}

function SectionDivider() {
  return <div className="my-5 border-b border-border/8" />
}

function StatusRow({ label, value, tone }: { label: string; value: string; tone: string }) {
  return (
    <div className="flex items-center justify-between gap-3 py-1.5">
      <div className="flex items-center gap-2.5">
        <div className={`h-1.5 w-1.5 rounded-full ${statusDotColor(tone)}`} />
        <div className="text-xs text-text-secondary/50">{label}</div>
      </div>
      <div className="text-xs text-text-primary/75">{value}</div>
    </div>
  )
}

function statusDotColor(tone: string) {
  switch (tone) {
    case 'running':
    case 'connected':
      return 'bg-emerald-500'
    case 'completed':
    case 'ready':
      return 'bg-sky-500'
    case 'failed':
    case 'disconnected':
    case 'error':
      return 'bg-rose-500'
    case 'queued':
    case 'pending':
    case 'pending_confirmation':
    case 'connecting':
    case 'reconnecting':
    case 'loading':
      return 'bg-amber-500'
    default:
      return 'bg-text-secondary/30'
  }
}

function severityColor(severity: string) {
  switch (severity) {
    case 'high':
      return 'rgb(244 63 94 / 0.4)'
    case 'medium':
      return 'rgb(245 158 11 / 0.4)'
    case 'low':
      return 'rgb(14 165 233 / 0.4)'
    default:
      return 'rgb(0 0 0 / 0.1)'
  }
}
