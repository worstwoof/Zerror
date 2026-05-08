import fs from 'node:fs'
import path from 'node:path'
import type { StudioAgentType, StudioKind } from '../domain/types'

const TEMPLATE_ROOT = path.join(process.cwd(), 'src', 'studio-agent', 'prompts', 'templates')
const templateCache = new Map<string, string>()

function readTemplate(filePath: string): string {
  const cached = templateCache.get(filePath)
  if (cached) {
    return cached
  }

  const content = fs.readFileSync(filePath, 'utf8')
  templateCache.set(filePath, content)
  return content
}

export function clearStudioAgentPromptCache(): void {
  templateCache.clear()
}

export function getStudioAgentSystemPrompt(
  agentType: StudioAgentType,
  studioKind: StudioKind = 'manim'
): string {
  const studioSpecificPath = path.join(TEMPLATE_ROOT, 'studios', studioKind, 'roles', `${agentType}.system.md`)
  if (fs.existsSync(studioSpecificPath)) {
    return readTemplate(studioSpecificPath).trim()
  }

  const fallbackPath = path.join(TEMPLATE_ROOT, 'roles', `${agentType}.system.md`)
  return readTemplate(fallbackPath).trim()
}

