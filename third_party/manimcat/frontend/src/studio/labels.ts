import type { I18nContextValue } from '../i18n/context'

type Translate = I18nContextValue['t']

export function translateRunStatus(status: string, t: Translate) {
  switch (status) {
    case 'running':
      return t('studio.runStatus.running')
    case 'completed':
      return t('studio.runStatus.completed')
    case 'failed':
      return t('studio.runStatus.failed')
    case 'cancelled':
      return t('studio.runStatus.cancelled')
    case 'pending':
      return t('studio.runStatus.pending')
    default:
      return status
  }
}

export function translateWorkStatus(status: string, t: Translate) {
  switch (status) {
    case 'queued':
      return t('studio.workStatus.queued')
    case 'running':
      return t('studio.workStatus.running')
    case 'completed':
      return t('studio.workStatus.completed')
    case 'failed':
      return t('studio.workStatus.failed')
    case 'cancelled':
      return t('studio.workStatus.cancelled')
    case 'proposed':
      return t('studio.workStatus.proposed')
    default:
      return status
  }
}

export function translateWorkType(type: string, t: Translate) {
  switch (type) {
    case 'video':
      return t('studio.workType.video')
    case 'plot':
      return t('studio.workType.plot')
    case 'edit':
      return t('studio.workType.edit')
    case 'render-fix':
      return t('studio.workType.renderFix')
    default:
      return type
  }
}

export function translateTaskStatus(status: string, t: Translate) {
  switch (status) {
    case 'proposed':
      return t('studio.taskStatus.proposed')
    case 'pending_confirmation':
      return t('studio.taskStatus.pendingConfirmation')
    case 'queued':
      return t('studio.taskStatus.queued')
    case 'running':
      return t('studio.taskStatus.running')
    case 'completed':
      return t('studio.taskStatus.completed')
    case 'failed':
      return t('studio.taskStatus.failed')
    case 'cancelled':
      return t('studio.taskStatus.cancelled')
    default:
      return status
  }
}

export function translateTaskType(type: string, t: Translate) {
  switch (type) {
    case 'tool-execution':
      return t('studio.taskType.toolExecution')
    case 'static-check':
      return t('studio.taskType.staticCheck')
    case 'render':
      return t('studio.taskType.render')
    default:
      return type
  }
}

export function translateEventStatus(status: string, t: Translate) {
  switch (status) {
    case 'connecting':
      return t('studio.event.connecting')
    case 'connected':
      return t('studio.event.connected')
    case 'reconnecting':
      return t('studio.event.reconnecting')
    case 'disconnected':
      return t('studio.event.disconnected')
    default:
      return t('studio.idle')
  }
}

export function translateSnapshotStatus(status: string, t: Translate) {
  switch (status) {
    case 'loading':
      return t('studio.event.snapshotLoading')
    case 'ready':
      return t('studio.event.snapshotReady')
    case 'error':
      return t('studio.workStatus.failed')
    default:
      return t('studio.idle')
  }
}

export function translateResultKind(kind: string, t: Translate) {
  switch (kind) {
    case 'render-output':
      return t('studio.resultKind.renderOutput')
    case 'edit-result':
      return t('studio.resultKind.editResult')
    case 'failure-report':
      return t('studio.resultKind.failureReport')
    default:
      return kind
  }
}

export function translateSeverity(severity: string, t: Translate) {
  switch (severity) {
    case 'high':
      return t('studio.severity.high')
    case 'medium':
      return t('studio.severity.medium')
    case 'low':
      return t('studio.severity.low')
    default:
      return severity
  }
}
