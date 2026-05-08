import type { StudioToolDefinition } from '../domain/types'
import { createSharedStudioTools } from '../shared/register-shared-tools'
import { createStudioRenderTool } from './render-tool'

export function createPlaceholderStudioTools(): StudioToolDefinition[] {
  return [
    ...createSharedStudioTools(),
    createStudioRenderTool() as StudioToolDefinition,
  ]
}
