export interface ImageContextMenuState {
  open: boolean
  x: number
  y: number
}

export const CLOSED_IMAGE_CONTEXT_MENU: ImageContextMenuState = { open: false, x: 0, y: 0 }
