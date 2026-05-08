export function nextTypeDelay(target: string, currentLength: number, streamRate: number) {
  const nextChar = target[currentLength] ?? ''
  const backlog = target.length - currentLength
  const targetCharsPerSecond = resolveTypingCharsPerSecond(backlog, streamRate)
  if (!nextChar) {
    return 18
  }

  if (nextChar === '\n') {
    return 1000 / Math.max(targetCharsPerSecond * 1.4, 1)
  }

  if (/[，。！？；：,.!?;:]/.test(nextChar)) {
    return Math.max(24, 1000 / Math.max(targetCharsPerSecond * 0.55, 1))
  }

  if (/\s/.test(nextChar)) {
    return Math.max(10, 1000 / Math.max(targetCharsPerSecond * 1.25, 1))
  }

  return Math.max(12, 1000 / Math.max(targetCharsPerSecond, 1))
}

export function nextTypeStep(backlog: number) {
  if (backlog >= 28) {
    return 3
  }

  if (backlog >= 16) {
    return 2
  }

  return 1
}

function resolveTypingCharsPerSecond(backlog: number, streamRate: number) {
  const minCharsPerSecond = 10
  const maxCharsPerSecond = 26
  const adaptiveBase = streamRate > 0 ? streamRate * 0.55 + 6 : minCharsPerSecond

  if (backlog >= 10) {
    return clamp(adaptiveBase, 12, maxCharsPerSecond)
  }

  return clamp(adaptiveBase, minCharsPerSecond, 18)
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value))
}

export function shouldRedirectKeyToInput(event: KeyboardEvent): boolean {
  return event.key.length === 1 || event.key === 'Backspace'
}
