export function studioPanelClass(extra = ''): string {
  const classes = [
    'rounded-[28px]',
    'border',
    'border-black/10',
    'bg-white/75',
    'backdrop-blur-xl',
    'shadow-[0_24px_80px_rgba(15,23,42,0.08)]',
    'dark:border-white/10',
    'dark:bg-black/20',
  ]
  if (extra.trim()) {
    classes.push(extra.trim())
  }
  return classes.join(' ')
}

export function studioStatusBadge(status: string): string {
  switch (status) {
    case 'running':
    case 'connected':
      return 'bg-emerald-500/12 text-emerald-700 ring-1 ring-emerald-500/20 dark:text-emerald-300'
    case 'completed':
      return 'bg-sky-500/12 text-sky-700 ring-1 ring-sky-500/20 dark:text-sky-300'
    case 'failed':
    case 'reject':
    case 'disconnected':
      return 'bg-rose-500/12 text-rose-700 ring-1 ring-rose-500/20 dark:text-rose-300'
    case 'queued':
    case 'pending':
    case 'pending_confirmation':
    case 'connecting':
    case 'reconnecting':
      return 'bg-amber-500/12 text-amber-700 ring-1 ring-amber-500/20 dark:text-amber-300'
    default:
      return 'bg-bg-secondary/50 text-text-secondary ring-1 ring-border/10'
  }
}

export function studioSeverityBadge(severity: string): string {
  switch (severity) {
    case 'high':
      return 'bg-rose-500/12 text-rose-700 ring-1 ring-rose-500/20 dark:text-rose-300'
    case 'medium':
      return 'bg-amber-500/12 text-amber-700 ring-1 ring-amber-500/20 dark:text-amber-300'
    case 'low':
      return 'bg-sky-500/12 text-sky-700 ring-1 ring-sky-500/20 dark:text-sky-300'
    default:
      return studioStatusBadge(severity)
  }
}

export function formatStudioTime(value?: string | number | null): string {
  if (!value) {
    return 'N/A'
  }

  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return String(value)
  }

  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

export function truncateStudioText(value: string, max = 120): string {
  const text = value.trim()
  if (text.length <= max) {
    return text
  }
  return `${text.slice(0, max - 1)}…`
}
