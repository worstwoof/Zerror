import { createPortal } from 'react-dom'
import { useEffect, useLayoutEffect, useRef } from 'react'
import type { ImageContextMenuState } from './context-menu-state'

export interface ImageContextMenuItem {
  key: string
  label: string
  onClick: () => void
  busy?: boolean
  disabled?: boolean
}

export function ImageContextMenu(input: {
  state: ImageContextMenuState
  appearance?: 'default' | 'studio'
  title?: string
  items: ImageContextMenuItem[]
  onClose: () => void
}) {
  const { state, appearance = 'default', title, items, onClose } = input
  const ref = useRef<HTMLDivElement>(null)

  useLayoutEffect(() => {
    if (!state.open) {
      return
    }

    const width = ref.current?.offsetWidth ?? 220
    const height = ref.current?.offsetHeight ?? 120
    const margin = 12
    const left = Math.max(margin, Math.min(state.x, window.innerWidth - width - margin))
    const top = Math.max(margin, Math.min(state.y, window.innerHeight - height - margin))
    if (ref.current) {
      ref.current.style.left = `${left}px`
      ref.current.style.top = `${top}px`
    }
  }, [items.length, state.open, state.x, state.y, title])

  useEffect(() => {
    if (!state.open) {
      return undefined
    }

    const handlePointerDown = (event: PointerEvent) => {
      const target = event.target as Node | null
      if (ref.current?.contains(target)) {
        return
      }
      onClose()
    }

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose()
      }
    }

    window.addEventListener('pointerdown', handlePointerDown, true)
    window.addEventListener('keydown', handleEscape, true)
    return () => {
      window.removeEventListener('pointerdown', handlePointerDown, true)
      window.removeEventListener('keydown', handleEscape, true)
    }
  }, [onClose, state.open])

  if (!state.open) {
    return null
  }

  const shellClassName = appearance === 'studio'
    ? 'fixed z-[220] w-56 overflow-hidden rounded-[1.6rem] border border-border/10 bg-bg-secondary/92 text-text-primary shadow-2xl backdrop-blur-xl dark:border-white/10 dark:bg-bg-secondary/92 dark:text-text-primary'
    : 'fixed z-[220] w-56 overflow-hidden rounded-[1.25rem] border border-border/10 bg-bg-secondary/92 text-text-primary shadow-2xl backdrop-blur-xl dark:border-white/10 dark:bg-bg-secondary/92 dark:text-text-primary'

  const titleClassName = 'border-border/10 text-text-secondary/55 dark:border-white/10 dark:text-text-secondary/70'

  const buttonClassName = appearance === 'studio'
    ? 'w-full rounded-[1.1rem] px-4 py-3 text-left text-sm text-text-primary transition hover:bg-bg-primary/60 disabled:opacity-60 dark:text-text-primary dark:hover:bg-bg-primary/70'
    : 'w-full rounded-xl px-4 py-3 text-left text-sm text-text-primary transition hover:bg-bg-primary/60 disabled:opacity-60 dark:text-text-primary dark:hover:bg-bg-primary/70'

  return createPortal(
    <div
      ref={ref}
      className={shellClassName}
      style={{ left: state.x, top: state.y }}
      onContextMenu={(event) => event.preventDefault()}
    >
      {title ? (
        <div className={`border-b px-4 py-3 ${titleClassName}`}>
          <div className="text-[10px] uppercase tracking-[0.24em]">
            {title}
          </div>
        </div>
      ) : null}
      <div className="p-2">
        {items.map((item) => (
          <button
            key={item.key}
            type="button"
            className={buttonClassName}
            disabled={item.disabled || item.busy}
            onClick={item.onClick}
          >
            {item.label}
          </button>
        ))}
      </div>
    </div>,
    document.body,
  )
}
