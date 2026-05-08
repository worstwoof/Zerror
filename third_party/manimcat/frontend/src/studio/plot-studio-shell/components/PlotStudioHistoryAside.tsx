import { useI18n } from '../../../i18n'

interface PlotStudioHistoryAsideProps<TWorkSummary extends {
  work: { id: string; title: string; status?: string }
  result?: {
    kind?: string
    attachments?: Array<{ path: string; mimeType?: string }>
  } | null
}> {
  works: TWorkSummary[]
  selectedWorkId: string | null
  historyCountLabel: string
  maxHistorySlots: number
  onSelectWork: (workId: string) => void
}

export function PlotStudioHistoryAside<TWorkSummary extends {
  work: { id: string; title: string; status?: string }
  result?: {
    kind?: string
    attachments?: Array<{ path: string; mimeType?: string }>
  } | null
}>({
  works,
  selectedWorkId,
  historyCountLabel,
  maxHistorySlots,
  onSelectWork,
}: PlotStudioHistoryAsideProps<TWorkSummary>) {
  const { t } = useI18n()

  return (
    <aside className="flex min-h-0 w-full shrink-0 flex-col md:w-[32rem] lg:w-[35rem] xl:w-[38rem]">
      <div className="mb-3 h-[1px] bg-accent opacity-[0.08] dark:opacity-[0.18]" />
      <div className="mb-4 flex items-center justify-between font-mono text-[10px] uppercase tracking-[0.4em] text-text-secondary/80">
        <span>{t('studio.plot.history')}</span>
        <span>{historyCountLabel}-{maxHistorySlots}</span>
      </div>

      <div className="no-scrollbar min-h-0 overflow-y-auto">
        <div className="grid grid-cols-3 content-start gap-4 md:gap-5">
          {works.map((entry) => {
            const isSelected = entry.work.id === selectedWorkId
            const attachment = entry.result?.attachments?.find((item) => (
              item.mimeType?.startsWith('image/') || /\.(png|jpg|jpeg|gif|webp|svg)$/i.test(item.path)
            ))
            const failed = entry.work.status === 'failed' || entry.result?.kind === 'failure-report'

            return (
              <button
                key={entry.work.id}
                type="button"
                onClick={() => onSelectWork(entry.work.id)}
                className={`group relative aspect-square overflow-hidden rounded-[1.6rem] border transition-all duration-500 ${
                  isSelected
                    ? 'border-black/10 bg-black/[0.08] dark:border-white/10 dark:bg-bg-secondary/72'
                    : 'border-transparent bg-black/[0.028] hover:bg-black/[0.05] dark:bg-bg-secondary/38 dark:hover:bg-bg-secondary/55'
                }`}
              >
                {attachment ? (
                  <img
                    src={attachment.path}
                    alt={entry.work.title}
                    className={`h-full w-full object-cover transition-all duration-700 ${
                      isSelected
                        ? 'scale-100 opacity-100'
                        : 'scale-[1.08] opacity-32 group-hover:scale-100 group-hover:opacity-72 dark:opacity-45 dark:group-hover:opacity-80'
                    }`}
                  />
                ) : failed ? (
                  <div className="flex h-full w-full items-center justify-center bg-rose-500/[0.06] text-rose-700/60 dark:bg-rose-400/[0.08] dark:text-rose-200/65">
                    <span className="font-mono text-[8px] uppercase tracking-[0.24em]">Fail</span>
                  </div>
                ) : (
                  <div className="flex h-full w-full items-center justify-center">
                    <span className="font-mono text-[8px] uppercase tracking-[0.22em] text-text-secondary/45">IMG</span>
                  </div>
                )}
                <span className="pointer-events-none absolute left-2 top-2 font-mono text-[8px] uppercase tracking-[0.24em] text-white/72 opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                  {entry.work.title.slice(0, 8)}
                </span>
              </button>
            )
          })}
          {works.length === 0 && (
            <div className="col-span-3 flex aspect-[3/1] items-center justify-center">
              <span className="font-mono text-[9px] uppercase tracking-[0.42em] text-text-secondary/40">Null Stack</span>
            </div>
          )}
        </div>
      </div>
    </aside>
  )
}
