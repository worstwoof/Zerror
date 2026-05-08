import type { Dispatch, SetStateAction } from 'react'
import {
  addAttachmentTokenToInput,
  createComposerImageAttachment,
  filterAttachmentsPresentInInput,
  removeAttachmentTokenFromInput,
} from '../../composer/attachments'
import { useStudioComposerAttachments } from '../../composer/use-studio-composer-attachments'
import { useStudioImageInputCommand } from '../../commands/ui/image-input/use-studio-image-input-command'
import { debugStudioMessages } from '../../agent-response/debug'

interface UseStudioCommandComposerAttachmentsControllerOptions {
  disabled: boolean
  focusInput: () => void
  setInput: Dispatch<SetStateAction<string>>
}

export function useStudioCommandComposerAttachmentsController({
  disabled,
  focusInput,
  setInput,
}: UseStudioCommandComposerAttachmentsControllerOptions) {
  const attachmentsState = useStudioComposerAttachments()

  const appendAttachmentTokens = (nextInput: string, nextAttachments: typeof attachmentsState.attachments) => {
    return nextAttachments.reduce((current, attachment) => addAttachmentTokenToInput(current, attachment), nextInput)
  }

  const addAttachmentsToComposer = (nextAttachments: typeof attachmentsState.attachments) => {
    if (nextAttachments.length === 0) {
      return
    }
    setInput((current) => appendAttachmentTokens(current, nextAttachments))
    focusInput()
  }

  const imageInputCommand = useStudioImageInputCommand({
    addImageFiles: attachmentsState.addImageFiles,
    appendReferenceImages: attachmentsState.appendReferenceImages,
    onAttachmentsAdded: addAttachmentsToComposer,
    onFocusComposer: focusInput,
  })

  const addImageFilesToComposer = async (files: FileList | File[]) => {
    if (disabled) {
      debugStudioMessages('composer-image-ingest-skipped', {
        reason: 'disabled',
      })
      return
    }

    debugStudioMessages('composer-image-ingest-start', {
      count: Array.from(files).length,
    })
    const nextAttachments = await attachmentsState.addImageFiles(files)
    addAttachmentsToComposer(nextAttachments)
    debugStudioMessages('composer-image-ingest-finish', {
      attachmentCount: nextAttachments.length,
      names: nextAttachments.map((attachment) => attachment.name),
    })
  }

  const handleInputChange = (nextValue: string) => {
    setInput(nextValue)
    const retained = filterAttachmentsPresentInInput(nextValue, attachmentsState.attachments)
    if (retained.length !== attachmentsState.attachments.length) {
      attachmentsState.retainAttachments(retained)
    }
  }

  const handleRemoveAttachment = (attachmentId: string) => {
    const target = attachmentsState.attachments.find((attachment) => attachment.id === attachmentId)
    if (!target) {
      return
    }

    attachmentsState.removeAttachment(attachmentId)
    setInput((current) => removeAttachmentTokenFromInput(current, target))
  }

  const appendPreviewAttachment = (attachment: { url: string; name: string; mimeType?: string }) => {
    const nextAttachment = createComposerImageAttachment({
      url: attachment.url,
      name: attachment.name,
      mimeType: attachment.mimeType,
      detail: 'low',
    })
    attachmentsState.appendUploadedAttachment(nextAttachment)
    setInput((current) => addAttachmentTokenToInput(current, nextAttachment))
    focusInput()
  }

  return {
    attachmentsState,
    imageInputCommand,
    addImageFilesToComposer,
    handleInputChange,
    handleRemoveAttachment,
    appendPreviewAttachment,
  }
}
