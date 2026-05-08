import { useEffect } from 'react'
import { debugStudioMessages } from '../../agent-response/debug'
import { shouldRedirectKeyToInput } from './studio-command-typing'

interface UseStudioCommandPanelShortcutsOptions {
  composer: {
    input: string
    focusInput: () => void
    handleInputChange: (value: string) => void
    handleDocumentPaste: (event: ClipboardEvent) => Promise<void>
  }
  disabled: boolean
  onEscapePress?: () => void
}

export function useStudioCommandPanelShortcuts({
  composer,
  disabled,
  onEscapePress,
}: UseStudioCommandPanelShortcutsOptions) {
  useEffect(() => {
    const handleWindowKeyDown = (event: KeyboardEvent) => {
      if (event.defaultPrevented || event.metaKey || event.ctrlKey || event.altKey) {
        return
      }

      if (event.key === 'Escape' && onEscapePress) {
        event.preventDefault()
        onEscapePress()
        return
      }

      if (disabled) {
        return
      }

      const target = event.target as HTMLElement | null
      if (
        target instanceof HTMLInputElement
        || target instanceof HTMLTextAreaElement
        || target?.isContentEditable
      ) {
        return
      }

      if (!shouldRedirectKeyToInput(event)) {
        return
      }

      composer.focusInput()
      if (event.key === 'Backspace') {
        composer.handleInputChange(composer.input.slice(0, -1))
        event.preventDefault()
        return
      }

      if (event.key.length === 1) {
        composer.handleInputChange(`${composer.input}${event.key}`)
        event.preventDefault()
      }
    }

    window.addEventListener('keydown', handleWindowKeyDown)
    return () => window.removeEventListener('keydown', handleWindowKeyDown)
  }, [composer, disabled, onEscapePress])

  useEffect(() => {
    const handleDocumentPaste = (event: ClipboardEvent) => {
      if (disabled) {
        return
      }

      const target = event.target as HTMLElement | null
      const isInputTarget =
        target instanceof HTMLInputElement
        || target instanceof HTMLTextAreaElement
        || target?.isContentEditable

      if (isInputTarget) {
        return
      }

      const imageCount = Array.from(event.clipboardData?.items ?? []).filter((item) => (
        item.kind === 'file' && item.type.startsWith('image/')
      )).length

      debugStudioMessages('command-panel-document-paste', {
        imageCount,
        targetTag: target?.tagName ?? null,
      })

      if (imageCount === 0) {
        return
      }

      event.preventDefault()
      void composer.handleDocumentPaste(event)
    }

    document.addEventListener('paste', handleDocumentPaste)
    return () => document.removeEventListener('paste', handleDocumentPaste)
  }, [composer, disabled])
}
