import type {
  StudioMessagePart,
  StudioToolPart
} from '../../domain/types'

export function getToolInput(part: StudioMessagePart | null): Record<string, unknown> {
  if (!part || part.type !== 'tool') {
    return {}
  }

  return part.state.input
}

export function getToolTimeStart(part: StudioMessagePart | null): number {
  if (!part || part.type !== 'tool' || !('time' in part.state) || !part.state.time?.start) {
    return Date.now()
  }

  return part.state.time.start
}

export function mergeToolMetadata(
  part: StudioMessagePart | null,
  metadata?: Record<string, unknown>
): Record<string, unknown> | undefined {
  if (!metadata || !Object.keys(metadata).length) {
    return part?.type === 'tool' ? part.metadata ?? ('metadata' in part.state ? part.state.metadata : undefined) : undefined
  }

  const current = part?.type === 'tool'
    ? {
        ...(part.metadata ?? {}),
        ...(('metadata' in part.state && part.state.metadata) ? part.state.metadata : {})
      }
    : {}

  return {
    ...current,
    ...metadata
  }
}

export function mergeToolStateMetadata(
  state: StudioToolPart['state'],
  title?: string,
  metadata?: Record<string, unknown>
): StudioToolPart['state'] {
  switch (state.status) {
    case 'pending':
      return state
    case 'running':
      return {
        ...state,
        title: title ?? state.title,
        metadata: {
          ...(state.metadata ?? {}),
          ...(metadata ?? {})
        }
      }
    case 'completed':
      return {
        ...state,
        title: title ?? state.title,
        metadata: {
          ...(state.metadata ?? {}),
          ...(metadata ?? {})
        }
      }
    case 'error':
      return {
        ...state,
        metadata: {
          ...(state.metadata ?? {}),
          ...(metadata ?? {})
        }
      }
  }
}
