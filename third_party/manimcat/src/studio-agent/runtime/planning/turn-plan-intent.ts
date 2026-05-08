import { randomUUID } from 'node:crypto'

export interface StudioParsedDirectToolIntent {
  toolName: 'read' | 'glob' | 'grep' | 'ls' | 'skill'
  input: Record<string, unknown>
}

export interface StudioParsedTurnIntent {
  skillName?: string
  directTool?: StudioParsedDirectToolIntent
  requestedToolNames: string[]
  explicitCommand: boolean
  cleanedInput: string
}

const SLASH_COMMAND_PATTERN = /^\/(skill|read|glob|grep|ls)\b.*$/gim
const FILE_REFERENCE_PATTERN = /@([^\s,;]+?\.[A-Za-z0-9_]+)/g
const SKILL_PATTERN = /(?:^\/skill\s+|(?:use|load)\s+skill\s+|技能\s*[:：]\s*|skill\s*[:：]\s*)([A-Za-z0-9._-]+)/im

export function parseStudioTurnIntent(inputText: string): StudioParsedTurnIntent {
  const normalized = inputText.trim()
  const requestedToolNames = collectRequestedTools(normalized)
  const skillName = extractSkillName(normalized)
  const cleanedInput = stripCommandLines(normalized) || normalized
  const directTool = parseDirectToolIntent(normalized, cleanedInput, skillName)

  return {
    skillName,
    directTool,
    requestedToolNames,
    explicitCommand: /^\//m.test(normalized),
    cleanedInput
  }
}

export function createPlannedCallId(toolName: string): string {
  return `${toolName}_${randomUUID()}`
}

function parseDirectToolIntent(
  originalInput: string,
  cleanedInput: string,
  skillName?: string
): StudioParsedDirectToolIntent | undefined {
  const readMatch = originalInput.match(/^\/read\s+(.+)$/im)
  if (readMatch) {
    return {
      toolName: 'read',
      input: { path: stripWrappingQuotes(readMatch[1].trim()) }
    }
  }

  const globMatch = originalInput.match(/^\/glob\s+(.+)$/im)
  if (globMatch) {
    return {
      toolName: 'glob',
      input: { pattern: stripWrappingQuotes(globMatch[1].trim()) }
    }
  }

  const grepMatch = originalInput.match(/^\/grep\s+(.+)$/im)
  if (grepMatch) {
    const [query, scope] = splitDescriptionAndBody(grepMatch[1].trim())
    return {
      toolName: 'grep',
      input: {
        query: stripWrappingQuotes(query),
        path: scope ? stripWrappingQuotes(scope) : '.'
      }
    }
  }

  const lsMatch = originalInput.match(/^\/ls(?:\s+(.+))?$/im)
  if (lsMatch) {
    return {
      toolName: 'ls',
      input: { path: stripWrappingQuotes(lsMatch[1]?.trim() || '.') }
    }
  }

  if (skillName) {
    return {
      toolName: 'skill',
      input: { name: skillName }
    }
  }

  const fileReferences = extractFileReferences(cleanedInput)
  if (fileReferences?.length === 1 && /\b(read|读取|看看|打开)\b/i.test(cleanedInput)) {
    return {
      toolName: 'read',
      input: { path: fileReferences[0] }
    }
  }

  if (/\b(ls|list)\b/i.test(cleanedInput) || cleanedInput.includes('列出')) {
    return {
      toolName: 'ls',
      input: { path: '.' }
    }
  }

  return undefined
}

function splitDescriptionAndBody(value: string): [string, string] {
  const [description, ...rest] = value.split(/\s*::\s*/)
  return [description.trim(), rest.join(' :: ').trim()]
}

function extractSkillName(inputText: string): string | undefined {
  return inputText.match(SKILL_PATTERN)?.[1]
}

function stripCommandLines(inputText: string): string {
  return inputText.replace(SLASH_COMMAND_PATTERN, '').trim()
}

function collectRequestedTools(inputText: string): string[] {
  const tools = new Set<string>()
  const lower = inputText.toLowerCase()

  if (/\b(read|读取|打开|看看)\b/i.test(inputText)) tools.add('read')
  if (/\bglob\b/i.test(lower) || inputText.includes('通配')) tools.add('glob')
  if (/\b(grep|search|搜索)\b/i.test(lower)) tools.add('grep')
  if (/\b(ls|list)\b/i.test(lower) || inputText.includes('列出')) tools.add('ls')
  if (/\b(question|clarify)\b/i.test(lower) || inputText.includes('问我')) tools.add('question')
  if (/\b(static-check|lint|check)\b/i.test(lower) || inputText.includes('静态检查')) tools.add('static-check')
  if (/\b(render)\b/i.test(lower) || inputText.includes('渲染')) tools.add('render')
  if (/\b(skill)\b/i.test(lower) || inputText.includes('技能')) tools.add('skill')
  return [...tools]
}

function extractFileReferences(inputText: string): string[] | undefined {
  const matches = [...inputText.matchAll(FILE_REFERENCE_PATTERN)].map((match) => match[1])
  return matches.length ? [...new Set(matches)] : undefined
}

function stripWrappingQuotes(value: string): string {
  return value.replace(/^['"]|['"]$/g, '')
}
