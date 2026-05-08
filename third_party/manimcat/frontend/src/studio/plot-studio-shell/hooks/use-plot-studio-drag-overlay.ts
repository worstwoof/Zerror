import { useEffect, useRef, useState } from 'react'
import type { RefObject } from 'react'
import type { StudioCommandPanelHandle } from '../../components/StudioCommandPanel'
import { countImageItems, extractImageFilesFromDataTransfer } from '../utils/drag-transfer'

interface UsePlotStudioDragOverlayOptions {
  commandPanelRef: RefObject<StudioCommandPanelHandle | null>
}

export function usePlotStudioDragOverlay({ commandPanelRef }: UsePlotStudioDragOverlayOptions) {
  const [isDraggingImages, setIsDraggingImages] = useState(false)
  const dragDepthRef = useRef(0)

  const handleShellDragEnter = (event: React.DragEvent<HTMLDivElement>) => {
    if (countImageItems(event.dataTransfer) === 0) {
      return
    }

    event.preventDefault()
    dragDepthRef.current += 1
    setIsDraggingImages(true)
  }

  const handleShellDragOver = (event: React.DragEvent<HTMLDivElement>) => {
    if (countImageItems(event.dataTransfer) === 0) {
      return
    }

    event.preventDefault()
    if (!isDraggingImages) {
      setIsDraggingImages(true)
    }
  }

  const handleShellDragLeave = (event: React.DragEvent<HTMLDivElement>) => {
    event.preventDefault()
    if (event.currentTarget.contains(event.relatedTarget as Node | null)) {
      return
    }

    dragDepthRef.current = Math.max(0, dragDepthRef.current - 1)
    if (dragDepthRef.current === 0) {
      setIsDraggingImages(false)
    }
  }

  const handleShellDrop = async (event: React.DragEvent<HTMLDivElement>) => {
    const imageFiles = extractImageFilesFromDataTransfer(event.dataTransfer)
    dragDepthRef.current = 0

    if (imageFiles.length === 0) {
      setIsDraggingImages(false)
      return
    }

    event.preventDefault()
    setIsDraggingImages(false)
    await commandPanelRef.current?.ingestImageFiles(imageFiles)
  }

  useEffect(() => {
    const syncWindowDragState = (event: DragEvent) => {
      const imageCount = countImageItems(event.dataTransfer)
      if (imageCount === 0) {
        return
      }

      if (event.type === 'dragenter' || event.type === 'dragover') {
        if (event.type === 'dragenter') {
          dragDepthRef.current += 1
        }
        setIsDraggingImages(true)
        return
      }

      if (event.type === 'dragleave') {
        dragDepthRef.current = Math.max(0, dragDepthRef.current - 1)
        if (dragDepthRef.current === 0) {
          setIsDraggingImages(false)
        }
        return
      }

      if (event.type === 'drop') {
        dragDepthRef.current = 0
        setIsDraggingImages(false)
      }
    }

    window.addEventListener('dragenter', syncWindowDragState)
    window.addEventListener('dragover', syncWindowDragState)
    window.addEventListener('dragleave', syncWindowDragState)
    window.addEventListener('drop', syncWindowDragState)

    return () => {
      window.removeEventListener('dragenter', syncWindowDragState)
      window.removeEventListener('dragover', syncWindowDragState)
      window.removeEventListener('dragleave', syncWindowDragState)
      window.removeEventListener('drop', syncWindowDragState)
    }
  }, [])

  return {
    isDraggingImages,
    shellDragBindings: {
      onDragEnter: handleShellDragEnter,
      onDragOver: handleShellDragOver,
      onDragLeave: handleShellDragLeave,
      onDrop: (event: React.DragEvent<HTMLDivElement>) => { void handleShellDrop(event) },
    },
  }
}
