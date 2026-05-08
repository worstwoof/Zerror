export function debugImageLightbox(event: string, payload: Record<string, unknown>): void {
  if (typeof window === 'undefined') {
    return
  }

  const debugFlag = window.localStorage.getItem('manimcat:debug:image-lightbox')
  const globalDebug = (window as typeof window & { __MANIMCAT_DEBUG_IMAGE_LIGHTBOX__?: boolean }).__MANIMCAT_DEBUG_IMAGE_LIGHTBOX__
  if (debugFlag !== '1' && globalDebug !== true) {
    return
  }

  console.debug(`[image-lightbox] ${event}`, payload)
}
