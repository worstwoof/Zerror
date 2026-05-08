import type { MouseEvent as ReactMouseEvent } from 'react'
import { useI18n } from '../../../i18n'
import type { StudioFileAttachment, StudioWorkResult } from '../../protocol/studio-agent-types'
import type { PlotPreviewVariant } from '../types'

interface PlotPreviewSurfaceProps {
  attachment: StudioFileAttachment | null | undefined
  previewSrc?: string
  result: StudioWorkResult | null
  canNavigate: boolean
  currentIndex: number
  total: number
  variant: PlotPreviewVariant
  onOpen: () => void
  onContextMenu: (event: ReactMouseEvent<HTMLDivElement>) => void
  onPrev: () => void
  onNext: () => void
}

export function PlotPreviewSurface({
  attachment,
  previewSrc,
  result,
  canNavigate,
  currentIndex,
  total,
  variant,
  onOpen,
  onContextMenu,
  onPrev,
  onNext,
}: PlotPreviewSurfaceProps) {
  const { t } = useI18n()
  const isMinimal = variant === 'pure-minimal-top'

  if (attachment?.mimeType?.startsWith('image/') || isImagePath(attachment?.path)) {
    return (
      <div className="relative flex h-full w-full items-center justify-center overflow-visible">
        {canNavigate && (
          <>
            <button
              type="button"
              onClick={onPrev}
              className={`absolute left-2 top-1/2 z-10 -translate-y-1/2 font-mono text-sm transition sm:left-4 ${
                isMinimal ? 'text-text-secondary/45 hover:text-text-primary dark:text-white/40 dark:hover:text-white' : 'text-text-secondary/70 hover:text-text-primary dark:text-white/55 dark:hover:text-white'
              }`}
            >
              ←
            </button>
            <button
              type="button"
              onClick={onNext}
              className={`absolute right-2 top-1/2 z-10 -translate-y-1/2 font-mono text-sm transition sm:right-4 ${
                isMinimal ? 'text-text-secondary/45 hover:text-text-primary dark:text-white/40 dark:hover:text-white' : 'text-text-secondary/70 hover:text-text-primary dark:text-white/55 dark:hover:text-white'
              }`}
            >
              →
            </button>
            <div
              className={`pointer-events-none absolute left-1/2 z-10 -translate-x-1/2 font-mono text-[10px] tracking-[0.24em] ${
                isMinimal
                  ? 'bottom-5 rounded-full border border-border/10 bg-bg-secondary/70 px-3 py-1 text-text-secondary/60 backdrop-blur-md dark:border-white/10 dark:bg-bg-secondary/74 dark:text-text-secondary/80'
                  : 'bottom-4 rounded-full border border-black/10 bg-white/70 px-3 py-1 text-text-primary/80 backdrop-blur-md dark:border-white/10 dark:bg-bg-secondary/82 dark:text-text-primary/90'
              }`}
            >
              {String(currentIndex + 1).padStart(2, '0')} / {String(total).padStart(2, '0')}
            </div>
          </>
        )}
        <div
          role="button"
          tabIndex={0}
          onClick={(event: ReactMouseEvent<HTMLDivElement>) => {
            if (event.button !== 0) {
              return
            }
            onOpen()
          }}
          onKeyDown={(event) => {
            if (event.key === 'Enter' || event.key === ' ') {
              event.preventDefault()
              onOpen()
            }
          }}
          onContextMenu={onContextMenu}
          className={`flex h-full w-full cursor-zoom-in items-center justify-center animate-fade-in-soft ${
            isMinimal ? 'px-4 py-3 sm:px-8 sm:py-6' : ''
          }`}
          title={t('image.openTitle')}
        >
          <div className={`relative flex h-full w-full items-center justify-center overflow-hidden transition-all duration-500 ${
            isMinimal
              ? 'bg-transparent'
              : 'bg-transparent'
          }`}>
            <img
              src={previewSrc ?? attachment?.path}
              alt={attachment?.name ?? t('studio.plot.previewAlt')}
              className="relative z-[1] max-h-full max-w-full object-contain"
            />
          </div>
        </div>
      </div>
    )
  }

  if (result?.kind === 'failure-report') {
    return (
      <div className={`flex flex-col items-center justify-center ${isMinimal ? 'opacity-24' : 'opacity-30'}`}>
        <div className={`font-medium uppercase tracking-widest ${isMinimal ? 'font-mono text-[11px] text-rose-600/60 dark:text-rose-300/55' : 'text-sm text-rose-600/70 dark:text-rose-300/65'}`}>
          {t('studio.renderFailed')}
        </div>
      </div>
    )
  }

  return (
    <div className={`flex h-full w-full items-center justify-center ${isMinimal ? 'opacity-30 transition-opacity duration-500 hover:opacity-60' : 'opacity-22 dark:opacity-30'}`}>
      <span className={`font-mono uppercase text-text-secondary/55 dark:text-white/40 ${isMinimal ? 'text-[12px] tracking-[0.34em]' : 'text-[11px] tracking-[0.28em]'}`}>
        [ Canvas Area ]
      </span>
    </div>
  )
}

function isImagePath(path?: string) {
  return Boolean(path && /\.(png|jpg|jpeg|gif|webp|svg)$/i.test(path))
}
