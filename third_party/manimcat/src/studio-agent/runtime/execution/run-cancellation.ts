export class StudioRunCancelledError extends Error {
  readonly reason: string

  constructor(reason: string = 'Run cancelled') {
    super(reason)
    this.name = 'StudioRunCancelledError'
    this.reason = reason
  }
}

export function isStudioRunCancelledError(error: unknown): error is StudioRunCancelledError {
  return error instanceof StudioRunCancelledError
}

export function throwIfStudioRunCancelled(signal?: AbortSignal | null): void {
  if (signal?.aborted) {
    throw new StudioRunCancelledError(readAbortReason(signal))
  }
}

export function readAbortReason(signal?: AbortSignal | null): string {
  const reason = signal?.reason
  return typeof reason === 'string' && reason.trim() ? reason : 'Run cancelled'
}
