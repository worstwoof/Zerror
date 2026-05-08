import type { StudioAgentType, StudioKind, StudioToolDefinition } from '../domain/types'

export class StudioToolRegistry {
  private readonly tools = new Map<string, StudioToolDefinition<any>[]>()

  register(tool: StudioToolDefinition<any>): void {
    const existing = this.tools.get(tool.name) ?? []
    this.tools.set(tool.name, [...existing, tool])
  }

  get(toolName: string, studioKind?: StudioKind): StudioToolDefinition<any> | null {
    const candidates = this.tools.get(toolName) ?? []
    if (!candidates.length) {
      return null
    }

    if (!studioKind) {
      return candidates[0] ?? null
    }

    return candidates.find((tool) => this.matchesStudioKind(tool, studioKind)) ?? candidates[0] ?? null
  }

  list(): StudioToolDefinition<any>[] {
    return [...this.tools.values()].flat()
  }

  listForAgent(agentType: StudioAgentType, studioKind?: StudioKind): StudioToolDefinition<any>[] {
    return this.list().filter((tool) => (
      tool.allowedAgents.includes(agentType)
      && this.matchesStudioKind(tool, studioKind)
    ))
  }

  private matchesStudioKind(tool: StudioToolDefinition<any>, studioKind?: StudioKind): boolean {
    if (!studioKind || !tool.allowedStudioKinds?.length) {
      return true
    }

    return tool.allowedStudioKinds.includes(studioKind)
  }
}
