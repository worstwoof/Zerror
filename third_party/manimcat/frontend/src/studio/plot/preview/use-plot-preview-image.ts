import { useEffect, useState } from 'react'

const PREVIEW_MAX_EDGE = 2400

interface PlotPreviewImageState {
  previewSrc?: string
  isPreviewReady: boolean
}

export function usePlotPreviewImage(source?: string): PlotPreviewImageState {
  const [previewSrc, setPreviewSrc] = useState<string | undefined>(source)
  const [isPreviewReady, setIsPreviewReady] = useState(false)

  useEffect(() => {
    if (!source) {
      setPreviewSrc(undefined)
      setIsPreviewReady(false)
      return undefined
    }

    if (looksLikeSvg(source)) {
      setPreviewSrc(source)
      setIsPreviewReady(true)
      return undefined
    }

    let cancelled = false
    let objectUrl: string | undefined

    setPreviewSrc(source)
    setIsPreviewReady(false)

    void createPreviewBitmap(source, PREVIEW_MAX_EDGE).then((nextPreviewSrc) => {
      if (cancelled) {
        if (nextPreviewSrc?.startsWith('blob:')) {
          URL.revokeObjectURL(nextPreviewSrc)
        }
        return
      }

      objectUrl = nextPreviewSrc?.startsWith('blob:') ? nextPreviewSrc : undefined
      setPreviewSrc(nextPreviewSrc ?? source)
      setIsPreviewReady(true)
    }).catch(() => {
      if (!cancelled) {
        setPreviewSrc(source)
        setIsPreviewReady(true)
      }
    })

    return () => {
      cancelled = true
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl)
      }
    }
  }, [source])

  return {
    previewSrc,
    isPreviewReady,
  }
}

async function createPreviewBitmap(source: string, maxEdge: number) {
  const image = await loadImage(source)
  const width = Math.max(1, image.naturalWidth || image.width || 1)
  const height = Math.max(1, image.naturalHeight || image.height || 1)
  const longestEdge = Math.max(width, height)

  if (longestEdge <= maxEdge) {
    return source
  }

  const scale = maxEdge / longestEdge
  const targetWidth = Math.max(1, Math.round(width * scale))
  const targetHeight = Math.max(1, Math.round(height * scale))
  const canvas = document.createElement('canvas')
  canvas.width = targetWidth
  canvas.height = targetHeight

  const context = canvas.getContext('2d', { alpha: false })
  if (!context) {
    return source
  }

  context.imageSmoothingEnabled = true
  context.imageSmoothingQuality = 'high'
  context.drawImage(image, 0, 0, targetWidth, targetHeight)

  const blob = await new Promise<Blob | null>((resolve) => {
    canvas.toBlob(resolve, 'image/webp', 0.88)
  })
  if (!blob) {
    return source
  }

  return URL.createObjectURL(blob)
}

async function loadImage(source: string) {
  return await new Promise<HTMLImageElement>((resolve, reject) => {
    const image = new Image()
    image.decoding = 'async'
    image.onload = () => resolve(image)
    image.onerror = () => reject(new Error('Failed to load preview source'))
    if (!source.startsWith('data:')) {
      image.crossOrigin = 'anonymous'
    }
    image.src = source
  })
}

function looksLikeSvg(source: string) {
  return source.startsWith('data:image/svg+xml') || /\.svg(?:[?#]|$)/i.test(source)
}
