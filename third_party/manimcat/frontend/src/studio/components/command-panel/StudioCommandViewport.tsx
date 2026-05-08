import { StudioCommandMessageList } from './StudioCommandMessageList'
import type { StudioCommandPanelStore } from './store'

interface StudioCommandViewportProps {
  store: StudioCommandPanelStore
  endRef: React.RefObject<HTMLDivElement | null>
  scrollRef: React.RefObject<HTMLDivElement | null>
  messagesLength: number
  isMinimal: boolean
  isTLayout: boolean
  variant: 'default' | 't-layout-bottom' | 'pure-minimal-bottom'
  readyLabel: string
}

export function StudioCommandViewport({
  store,
  endRef,
  scrollRef,
  messagesLength,
  isMinimal,
  isTLayout,
  variant,
  readyLabel,
}: StudioCommandViewportProps) {
  return (
    <div
      ref={scrollRef}
      className={`min-h-0 flex-1 overflow-y-auto ${isTLayout ? 'px-5 py-5' : isMinimal ? 'pl-4 pr-3 pb-4 pt-1' : 'px-8 py-10'}`}
    >
      {messagesLength === 0 && !isMinimal && (
        <div className="flex h-full flex-col items-center justify-center text-center opacity-30">
          {isTLayout ? (
            <div className="text-[13px] text-[#999]">{readyLabel}</div>
          ) : (
            <>
              <div className="mb-4 text-3xl">🐾</div>
              <div className="font-mono text-[10px] uppercase tracking-[0.4em]">{readyLabel}</div>
            </>
          )}
        </div>
      )}

      <StudioCommandMessageList store={store} endRef={endRef} variant={variant} />
    </div>
  )
}
