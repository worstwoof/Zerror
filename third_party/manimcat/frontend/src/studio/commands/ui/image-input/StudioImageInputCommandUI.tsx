import { useRef } from 'react'
import { CanvasWorkspaceModal } from '../../../../components/canvas/CanvasWorkspaceModal'
import { ImageInputModeModal } from '../../../../components/ImageInputModeModal'
import type { ReferenceImage } from '../../../../types/api'

interface StudioImageInputCommandUIProps {
  isImageModeOpen: boolean
  isCanvasOpen: boolean
  onCloseImageMode: () => void
  onCloseCanvas: () => void
  onImportFiles: (files: FileList | File[]) => Promise<void> | void
  onStartImport: () => void
  onStartDraw: () => void
  onCanvasComplete: (images: ReferenceImage[]) => void
}

export function StudioImageInputCommandUI({
  isImageModeOpen,
  isCanvasOpen,
  onCloseImageMode,
  onCloseCanvas,
  onImportFiles,
  onStartImport,
  onStartDraw,
  onCanvasComplete,
}: StudioImageInputCommandUIProps) {
  const fileInputRef = useRef<HTMLInputElement>(null)

  return (
    <>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        multiple
        className="hidden"
        onChange={(event) => {
          const files = event.target.files
          if (files && files.length > 0) {
            void onImportFiles(files)
          }
          event.currentTarget.value = ''
        }}
      />

      <ImageInputModeModal
        isOpen={isImageModeOpen}
        onClose={onCloseImageMode}
        onImport={() => {
          onStartImport()
          fileInputRef.current?.click()
        }}
        onDraw={onStartDraw}
      />

      <CanvasWorkspaceModal
        isOpen={isCanvasOpen}
        onClose={onCloseCanvas}
        onComplete={onCanvasComplete}
      />
    </>
  )
}
