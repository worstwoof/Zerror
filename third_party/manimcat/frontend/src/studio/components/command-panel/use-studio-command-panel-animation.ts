import { useEffect, useRef, useState } from 'react'
import { nextTypeDelay, nextTypeStep } from './studio-command-typing'

export function useStudioCommandPanelAnimation(latestAssistantText: string) {
  const [animatedAssistantText, setAnimatedAssistantText] = useState('')
  const streamRateRef = useRef(0)
  const latestTextMetaRef = useRef<{ text: string; at: number }>({ text: '', at: 0 })

  useEffect(() => {
    if (!latestAssistantText) {
      streamRateRef.current = 0
      latestTextMetaRef.current = { text: '', at: 0 }
      const frame = window.requestAnimationFrame(() => {
        setAnimatedAssistantText('')
      })
      return () => window.cancelAnimationFrame(frame)
    }

    const now = Date.now()
    const prev = latestTextMetaRef.current
    if (prev.text && latestAssistantText.startsWith(prev.text) && latestAssistantText.length > prev.text.length) {
      const deltaChars = latestAssistantText.length - prev.text.length
      const deltaMs = Math.max(1, now - prev.at)
      const charsPerSecond = (deltaChars * 1000) / deltaMs
      streamRateRef.current = streamRateRef.current === 0
        ? charsPerSecond
        : streamRateRef.current * 0.68 + charsPerSecond * 0.32
    } else if (!prev.text) {
      streamRateRef.current = 0
    }
    latestTextMetaRef.current = { text: latestAssistantText, at: now }

    const frame = window.requestAnimationFrame(() => {
      setAnimatedAssistantText((current) => {
        if (!latestAssistantText.startsWith(current)) {
          return latestAssistantText.slice(0, 1)
        }
        return current || latestAssistantText.slice(0, 1)
      })
    })

    return () => window.cancelAnimationFrame(frame)
  }, [latestAssistantText])

  useEffect(() => {
    if (!latestAssistantText) {
      return
    }

    if (animatedAssistantText === latestAssistantText) {
      return
    }

    const timer = window.setTimeout(() => {
      setAnimatedAssistantText((current) => {
        if (!latestAssistantText.startsWith(current)) {
          return latestAssistantText.slice(0, 1)
        }

        const nextLength = current.length + nextTypeStep(latestAssistantText.length - current.length)
        return latestAssistantText.slice(0, nextLength)
      })
    }, nextTypeDelay(latestAssistantText, animatedAssistantText.length, streamRateRef.current))

    return () => window.clearTimeout(timer)
  }, [animatedAssistantText, latestAssistantText])

  return animatedAssistantText
}
