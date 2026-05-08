import { advancedStudioCommands } from './advanced-commands'
import { basicStudioCommands } from './basic-commands'
import { featureStudioCommands } from './feature-commands'
import type { StudioCommandDefinition } from './types'

export const allStudioCommands: StudioCommandDefinition[] = [
  ...basicStudioCommands,
  ...featureStudioCommands,
  ...advancedStudioCommands,
]

