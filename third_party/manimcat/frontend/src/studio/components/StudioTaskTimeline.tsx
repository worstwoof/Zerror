import type { StudioTask } from '../protocol/studio-agent-types'
import { translateTaskStatus, translateTaskType } from '../labels'
import { formatStudioTime } from '../theme'
import { useI18n } from '../../i18n'

interface StudioTaskTimelineProps {
  tasks: StudioTask[]
}

export function StudioTaskTimeline({ tasks }: StudioTaskTimelineProps) {
  const { t } = useI18n()
  if (!tasks.length) {
    return <div className="text-sm text-text-secondary/55">{t('studio.timeline.empty')}</div>
  }

  return (
    <div className="relative ml-2">
      <div className="absolute bottom-0 left-[5px] top-0 w-px bg-border/10" />

      {tasks.map((task, index) => (
        <div key={task.id} className={`relative flex gap-3 pl-5 ${index > 0 ? 'mt-4' : ''}`}>
          <div className={`absolute left-0 top-1.5 h-2.5 w-2.5 rounded-full ${taskDotColor(task.status)}`} />
          <div className="min-w-0 flex-1">
            <div className="text-sm text-text-primary/84">{task.title}</div>
            <div className="mt-0.5 text-[11px] text-text-secondary/50">
              {translateTaskType(task.type, t)} · {translateTaskStatus(task.status, t)} · {formatStudioTime(task.updatedAt)}
            </div>
            {task.detail && <div className="mt-1 text-xs leading-5 text-text-secondary/55">{task.detail}</div>}
          </div>
        </div>
      ))}
    </div>
  )
}

function taskDotColor(status: string) {
  switch (status) {
    case 'running':
      return 'bg-emerald-500'
    case 'completed':
      return 'bg-sky-500'
    case 'failed':
      return 'bg-rose-500'
    case 'queued':
    case 'pending_confirmation':
      return 'bg-amber-500'
    default:
      return 'bg-text-secondary/30'
  }
}
