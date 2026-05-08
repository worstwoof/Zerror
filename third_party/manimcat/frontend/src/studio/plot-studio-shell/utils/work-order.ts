export function areSameIds(left: string[], right: string[]) {
  if (left.length !== right.length) {
    return false
  }

  for (let index = 0; index < left.length; index += 1) {
    if (left[index] !== right[index]) {
      return false
    }
  }

  return true
}

export function computeMaxHistorySlots(historyCount: number) {
  return historyCount <= 12 ? 12 : Math.ceil(historyCount / 12) * 12 + (historyCount % 12 === 0 ? 0 : 12)
}

export function orderWorkSummaries<T extends { work: { id: string } }>(workSummaries: T[], orderedWorkIds: string[]) {
  const byId = new Map(workSummaries.map((entry) => [entry.work.id, entry]))
  const incomingIds = workSummaries.map((entry) => entry.work.id)
  const preserved = orderedWorkIds.filter((id) => byId.has(id))
  const appended = incomingIds.filter((id) => !preserved.includes(id))

  return [...appended, ...preserved]
    .map((id) => byId.get(id))
    .filter((entry): entry is T => Boolean(entry))
}
