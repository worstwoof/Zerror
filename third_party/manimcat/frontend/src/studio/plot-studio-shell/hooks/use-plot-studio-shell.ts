import { useMemo, useState } from 'react'
import { useStudioSession } from '../../hooks/use-studio-session'
import { areSameIds, computeMaxHistorySlots, orderWorkSummaries } from '../utils/work-order'

export function usePlotStudioShell() {
  const studio = useStudioSession({
    studioKind: 'plot',
    title: 'Plot Studio'
  })
  const [selectedWorkId, setSelectedWorkId] = useState<string | null>(null)
  const [orderedWorkIds, setOrderedWorkIds] = useState<string[]>([])
  const [confirmExitOpen, setConfirmExitOpen] = useState(false)
  const [interruptArmedUntil, setInterruptArmedUntil] = useState<number | null>(null)

  const orderedWorkSummaries = useMemo(
    () => orderWorkSummaries(studio.workSummaries, orderedWorkIds),
    [orderedWorkIds, studio.workSummaries]
  )

  const effectiveSelectedWorkId =
    selectedWorkId && orderedWorkSummaries.some((entry) => entry.work.id === selectedWorkId)
      ? selectedWorkId
      : orderedWorkSummaries[0]?.work.id ?? null

  const selected = studio.selectWork(effectiveSelectedWorkId)
  const historyCount = orderedWorkSummaries.length
  const historyCountLabel = String(historyCount).padStart(2, '0')
  const maxHistorySlots = computeMaxHistorySlots(historyCount)
  const interruptHintActive = interruptArmedUntil !== null && interruptArmedUntil > Date.now()

  const handleReorderWorks = (nextWorkIds: string[]) => {
    setOrderedWorkIds((current) => (areSameIds(current, nextWorkIds) ? current : nextWorkIds))
  }

  const handleEscapePress = () => {
    const activeRun = studio.latestRun
    const runIsInterruptible = activeRun && (activeRun.status === 'pending' || activeRun.status === 'running')
    if (!runIsInterruptible) {
      setInterruptArmedUntil(null)
      return
    }

    const now = Date.now()
    if (interruptArmedUntil && interruptArmedUntil > now) {
      setInterruptArmedUntil(null)
      void studio.cancelCurrentRun('Cancelled by double-escape in Plot Studio')
      return
    }

    setInterruptArmedUntil(now + 3000)
    window.setTimeout(() => {
      setInterruptArmedUntil((current) => (current && current <= Date.now() ? null : current))
    }, 3100)
  }

  return {
    studio,
    selected,
    orderedWorkSummaries,
    effectiveSelectedWorkId,
    historyCountLabel,
    maxHistorySlots,
    confirmExitOpen,
    setConfirmExitOpen,
    interruptHintActive,
    setSelectedWorkId,
    handleReorderWorks,
    handleEscapePress,
  }
}
