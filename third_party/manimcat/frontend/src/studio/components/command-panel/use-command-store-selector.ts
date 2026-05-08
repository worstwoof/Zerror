import { useEffect, useRef, useState } from 'react'
import type { StudioCommandPanelStore } from './store'

export function useCommandStoreSelector<T>(
  store: StudioCommandPanelStore,
  selector: (snapshot: ReturnType<StudioCommandPanelStore['getSnapshot']>) => T,
  isEqual: (left: T, right: T) => boolean = Object.is,
) {
  const selectorRef = useRef(selector)
  const isEqualRef = useRef(isEqual)
  selectorRef.current = selector
  isEqualRef.current = isEqual

  const [selected, setSelected] = useState(() => selector(store.getSnapshot()))
  const selectedRef = useRef(selected)

  useEffect(() => {
    selectedRef.current = selected
  }, [selected])

  useEffect(() => {
    const unsubscribe = store.subscribe(() => {
      const nextSelected = selectorRef.current(store.getSnapshot())
      if (isEqualRef.current(selectedRef.current, nextSelected)) {
        return
      }
      selectedRef.current = nextSelected
      setSelected(nextSelected)
    })

    const nextSelected = selectorRef.current(store.getSnapshot())
    if (!isEqualRef.current(selectedRef.current, nextSelected)) {
      selectedRef.current = nextSelected
      setSelected(nextSelected)
    }

    return unsubscribe
  }, [store])

  return selected
}
