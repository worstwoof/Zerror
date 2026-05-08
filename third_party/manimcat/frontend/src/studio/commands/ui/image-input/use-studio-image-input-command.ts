import { useCallback, useState } from 'react'
import type { ReferenceImage } from '../../../../types/api'
import type { StudioComposerAttachment } from '../../../composer/types'

interface UseStudioImageInputCommandInput {
  addImageFiles: (files: FileList | File[]) => Promise<StudioComposerAttachment[]>
  appendReferenceImages: (images: ReferenceImage[]) => StudioComposerAttachment[]
  onAttachmentsAdded: (attachments: StudioComposerAttachment[]) => void
  onFocusComposer: () => void
}

export function useStudioImageInputCommand({
  addImageFiles,
  appendReferenceImages,
  onAttachmentsAdded,
  onFocusComposer,
}: UseStudioImageInputCommandInput) {
  const [isImageModeOpen, setIsImageModeOpen] = useState(false)
  const [isCanvasOpen, setIsCanvasOpen] = useState(false)

  const openImageInputMode = useCallback(() => {
    setIsImageModeOpen(true)
  }, [])

  const closeImageInputMode = useCallback(() => {
    setIsImageModeOpen(false)
  }, [])

  const closeCanvas = useCallback(() => {
    setIsCanvasOpen(false)
  }, [])

  const handleImportFiles = useCallback(async (files: FileList | File[]) => {
    const nextAttachments = await addImageFiles(files)
    onAttachmentsAdded(nextAttachments)
    onFocusComposer()
  }, [addImageFiles, onAttachmentsAdded, onFocusComposer])

  const handleCanvasComplete = useCallback((nextImages: ReferenceImage[]) => {
    const nextAttachments = appendReferenceImages(nextImages)
    onAttachmentsAdded(nextAttachments)
    setIsCanvasOpen(false)
    onFocusComposer()
  }, [appendReferenceImages, onAttachmentsAdded, onFocusComposer])

  const startImport = useCallback(() => {
    setIsImageModeOpen(false)
  }, [])

  const startDraw = useCallback(() => {
    setIsImageModeOpen(false)
    setIsCanvasOpen(true)
  }, [])

  return {
    isImageModeOpen,
    isCanvasOpen,
    openImageInputMode,
    closeImageInputMode,
    closeCanvas,
    handleImportFiles,
    handleCanvasComplete,
    startImport,
    startDraw,
  }
}
