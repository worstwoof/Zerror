import { useI18n } from '../../../i18n'
import type { StudioSession } from '../../protocol/studio-agent-types'

interface StudioCommandPanelHeaderProps {
  session: StudioSession | null
  onExit: () => void
}

export function StudioCommandPanelHeader({ session, onExit }: StudioCommandPanelHeaderProps) {
  const { t } = useI18n()

  return (
    <header className="shrink-0 flex items-center justify-between gap-4 px-8 py-5">
      <div className="flex items-center gap-3">
        <div className="h-2 w-2 rounded-full bg-accent/20 animate-pulse" />
        <div className="studio-brand-title text-[13px] font-bold uppercase tracking-[0.2em] text-text-primary/70">
          {session?.title ?? t('studio.title')}
        </div>
      </div>
      <button
        type="button"
        onClick={onExit}
        className="text-[11px] font-medium uppercase tracking-[0.28em] text-text-secondary/45 transition hover:text-rose-500/80"
      >
        {t('common.close')}
      </button>
    </header>
  )
}
