import type { StudioRuntimeTurnPlan } from '../../domain/types'
import type { StudioToolRegistry } from '../../tools/registry'
import type { StudioTurnPlanResolver } from './turn-plan-resolver'
import { insertStudioReminders } from './insert-reminders'
import { resolveStudioTurnPolicy } from './turn-plan-policy'
import { buildAgentAssistantText } from './turn-plan-text'

const DEFAULT_ENABLED_TOOL_NAMES = ['skill', 'read', 'glob', 'grep', 'ls', 'question', 'static-check', 'render']

interface CreateStudioDefaultTurnPlanResolverOptions {
  registry: StudioToolRegistry
  enabledToolNames?: string[]
}

export function createStudioDefaultTurnPlanResolver(
  options: CreateStudioDefaultTurnPlanResolverOptions
): StudioTurnPlanResolver {
  const enabledToolNames = new Set(options.enabledToolNames ?? DEFAULT_ENABLED_TOOL_NAMES)

  return async (input) => {
    const studioKind = input.session.studioKind ?? 'manim'
    const agentToolNames = new Set(options.registry.listForAgent(input.session.agentType, studioKind).map((tool) => tool.name))
    const supportedToolNames = new Set(
      [...agentToolNames].filter((toolName) => enabledToolNames.has(toolName))
    )

    const policyDecision = resolveStudioTurnPolicy({
      agentType: input.session.agentType,
      studioKind,
      inputText: input.inputText,
      supportedToolNames,
      workContext: input.workContext
    })

    const assistantText = insertStudioReminders({
      assistantText: buildAgentAssistantText({
        agentType: input.session.agentType,
        studioKind,
        inputText: input.inputText,
        policyDecision
      }),
      agentType: input.session.agentType,
      studioKind,
      unsupportedRequestedTools: [],
      workContext: input.workContext,
      policyDecision
    })

    const plan: StudioRuntimeTurnPlan = {
      assistantText,
      toolCalls: policyDecision.toolCalls.length ? policyDecision.toolCalls : undefined
    }

    return plan
  }
}
