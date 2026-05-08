import type { StudioToolRegistry } from '../tools/registry'
import { createStudioRenderTool } from '../tools/render-tool'

export function registerManimStudioTools(registry: StudioToolRegistry): void {
  registry.register(createStudioRenderTool())
}
