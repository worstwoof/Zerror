import type { StudioSession } from '../protocol/studio-agent-types'

export type StudioCommandGroup = 'basic' | 'feature' | 'advanced'
export type StudioCommandScope = 'global' | 'local'

export interface StudioCommandPresentation {
  trigger: string
  titleKey: string
  descriptionKey: string
  aliases?: string[]
  keywords?: string[]
}

export interface StudioCommandContext {
  session: StudioSession | null
  openHistory: () => void
  createSession: () => Promise<void>
  openImageInputMode?: () => void
  runCommandInput: (inputText: string) => Promise<void>
}

export interface StudioParsedCommandBase {
  id: string
  group: StudioCommandGroup
  raw: string
}

export interface StudioHistoryCommand extends StudioParsedCommandBase {
  id: 'history'
  group: 'basic'
}

export interface StudioNewSessionCommand extends StudioParsedCommandBase {
  id: 'new-session'
  group: 'basic'
}

export interface StudioImageInputCommand extends StudioParsedCommandBase {
  id: 'image-input'
  group: 'feature'
}

export interface StudioSkillCommand extends StudioParsedCommandBase {
  id: 'skill'
  group: 'feature'
}

export type StudioParsedCommand =
  | StudioHistoryCommand
  | StudioNewSessionCommand
  | StudioImageInputCommand
  | StudioSkillCommand

export interface StudioCommandDefinition<TCommand extends StudioParsedCommand = any> {
  id: TCommand['id']
  group: StudioCommandGroup
  scope: StudioCommandScope
  presentation: StudioCommandPresentation
  matches: (input: string) => TCommand | null
  execute: {
    bivarianceHack: (command: TCommand, context: StudioCommandContext) => Promise<void> | void
  }['bivarianceHack']
}
