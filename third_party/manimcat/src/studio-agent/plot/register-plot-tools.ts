import type { StudioToolRegistry } from '../tools/registry'
import { createPlotStudioRenderTool } from './tools/plot-render-tool'

export function registerPlotStudioTools(registry: StudioToolRegistry): void {
  registry.register(createPlotStudioRenderTool())
}
