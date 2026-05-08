import type { CustomApiConfig, OutputMode, PromptOverrides } from '../../types'

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export interface CodeRetryContext {
  concept: string
  sceneDesign: string
  outputMode: OutputMode
  promptOverrides?: PromptOverrides
}

export interface CodePatch {
  originalSnippet: string
  replacementSnippet: string
}

export interface CodePatchSet {
  patches: CodePatch[]
}

export interface CodeRetryOptions {
  context: CodeRetryContext
  customApiConfig?: CustomApiConfig
}

export interface CodeRetryResult {
  success: boolean
  code: string
  attempt: number
  reason?: string
}

export interface RenderResult {
  success: boolean
  stderr: string
  stdout: string
  peakMemoryMB: number
  exitCode?: number
  codeSnippet?: string
}

export interface RetryManagerResult {
  code: string
  success: boolean
  attempts: number
  generationTimeMs?: number
  lastError?: string
}

export type RetryCheckpoint = () => Promise<void>
