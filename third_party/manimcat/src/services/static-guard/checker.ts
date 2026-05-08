import fs from 'fs'
import os from 'os'
import path from 'path'
import { spawn } from 'child_process'
import { createLogger } from '../../utils/logger'
import type { OutputMode } from '../../types'
import type { StaticCheckBatch, StaticDiagnostic } from './types'

const logger = createLogger('StaticGuardChecker')

interface CommandResult {
  exitCode: number | null
  stdout: string
  stderr: string
}

interface CodeUnit {
  code: string
  lineOffset: number
}

interface CodeLine {
  lineNumber: number
  text: string
}

interface ResolvedCommand {
  command: string
  argsPrefix: string[]
  displayName: string
}

function runCommand(command: string, args: string[], cwd: string): Promise<CommandResult> {
  return new Promise((resolve, reject) => {
    logger.info('Running static guard command', {
      command,
      args,
      cwd
    })
    const proc = spawn(command, args, { cwd, windowsHide: true })
    let stdout = ''
    let stderr = ''

    proc.stdout.on('data', (chunk) => {
      stdout += chunk.toString()
    })

    proc.stderr.on('data', (chunk) => {
      stderr += chunk.toString()
    })

    proc.on('error', (error) => {
      const suffix = args.length > 0 ? ` ${args.join(' ')}` : ''
      reject(new Error(`Failed to spawn command: ${command}${suffix} (${String(error)})`))
    })
    proc.on('close', (exitCode) => {
      logger.info('Static guard command finished', {
        command,
        args,
        cwd,
        exitCode,
        stdoutPreview: stdout.trim().slice(0, 300),
        stderrPreview: stderr.trim().slice(0, 300)
      })
      resolve({ exitCode, stdout, stderr })
    })
  })
}

function resolveMypyCommand(): ResolvedCommand | null {
  const pythonExecutable = process.env.PYTHON_EXECUTABLE || 'python'
  return {
    command: pythonExecutable,
    argsPrefix: ['-m', 'mypy'],
    displayName: `${pythonExecutable} -m mypy`
  }
}

function resolveMypyConfigPath(): string | null {
  const explicitPath = process.env.STATIC_GUARD_MYPY_CONFIG?.trim()
  if (explicitPath) {
    const resolved = path.isAbsolute(explicitPath) ? explicitPath : path.join(process.cwd(), explicitPath)
    if (fs.existsSync(resolved)) {
      return resolved
    }
    logger.warn('Configured mypy config file not found, fallback to built-in mypy args', {
      configuredPath: explicitPath,
      resolvedPath: resolved
    })
  }

  const candidates = ['mypy.ini', '.mypy.ini', 'pyproject.toml', 'setup.cfg']
  for (const candidate of candidates) {
    const resolved = path.join(process.cwd(), candidate)
    if (fs.existsSync(resolved)) {
      return resolved
    }
  }

  return null
}

function buildMypyArgs(codeFile: string): string[] {
  const configPath = resolveMypyConfigPath()
  const args = [
    '--show-column-numbers',
    '--show-error-codes',
    '--hide-error-context',
    '--no-color-output',
    '--no-error-summary'
  ]

  if (configPath) {
    args.push('--config-file', configPath)
  } else {
    args.push(
      '--follow-imports',
      'skip',
      '--ignore-missing-imports',
      '--allow-untyped-globals',
      '--allow-redefinition'
    )
  }

  args.push(codeFile)
  return args
}

function parseMypyDiagnostics(stdout: string, stderr: string, lineOffset: number): StaticDiagnostic[] {
  const output = [stdout, stderr].filter(Boolean).join('\n').replace(/\r\n/g, '\n')
  if (!output.trim()) {
    return []
  }

  const diagnostics: StaticDiagnostic[] = []
  for (const rawLine of output.split('\n')) {
    const line = rawLine.trim()
    if (!line) {
      continue
    }

    const match =
      line.match(/^[^:]+:(\d+):(\d+):\s*error:\s*(.+?)(?:\s+\[([a-z0-9\-]+)\])?$/i) ||
      line.match(/^[^:]+:(\d+):\s*error:\s*(.+?)(?:\s+\[([a-z0-9\-]+)\])?$/i)
    if (!match) {
      continue
    }

    const hasColumn = match.length >= 5
    const lineNumber = Number.parseInt(match[1], 10)
    const column = hasColumn ? Number.parseInt(match[2], 10) : undefined
    const message = hasColumn ? match[3] : match[2]
    const code = hasColumn ? match[4] : match[3]

    diagnostics.push({
      tool: 'mypy',
      line: lineNumber + lineOffset,
      column,
      code,
      message: message || 'mypy reported an error'
    })
  }

  return diagnostics
}

function parseImageCodeUnits(code: string): CodeUnit[] {
  const units: CodeUnit[] = []
  const blockRegex = /###\s*YON_IMAGE_(\d+)_START\s*###([\s\S]*?)###\s*YON_IMAGE_\1_END\s*###/g

  let match: RegExpExecArray | null
  while ((match = blockRegex.exec(code)) !== null) {
    const fullMatch = match[0]
    const blockCode = match[2].trim()
    if (!blockCode) {
      continue
    }

    const prefix = code.slice(0, match.index)
    const startMarker = fullMatch.indexOf(match[2])
    const beforeCode = fullMatch.slice(0, startMarker)
    const lineOffset = prefix.split('\n').length - 1 + beforeCode.split('\n').length - 1
    units.push({ code: blockCode, lineOffset })
  }

  if (units.length === 0) {
    units.push({ code, lineOffset: 0 })
  }

  return units
}

function getCodeUnits(code: string, outputMode: OutputMode): CodeUnit[] {
  if (outputMode === 'image') {
    return parseImageCodeUnits(code)
  }
  return [{ code, lineOffset: 0 }]
}

function parsePyCompileDiagnostic(stderr: string, lineOffset: number): StaticDiagnostic | null {
  const normalized = stderr.replace(/\r\n/g, '\n').trim()
  if (!normalized) {
    return null
  }

  const lineMatch = normalized.match(/line\s+(\d+)/i)
  const line = lineMatch ? Number.parseInt(lineMatch[1], 10) + lineOffset : 1 + lineOffset
  const lines = normalized.split('\n').map((item) => item.trim()).filter(Boolean)
  const message = lines[lines.length - 1] || normalized

  return {
    tool: 'py_compile',
    line,
    message
  }
}

function previewDiagnostics(diagnostics: StaticDiagnostic[], limit = 3): Array<Record<string, unknown>> {
  return diagnostics.slice(0, limit).map((diagnostic) => ({
    line: diagnostic.line,
    column: diagnostic.column,
    code: diagnostic.code,
    messagePreview: diagnostic.message.replace(/\s+/g, ' ').trim().slice(0, 180)
  }))
}

function getCodeLine(code: string, oneBasedLineNumber: number): CodeLine | null {
  if (oneBasedLineNumber < 1) {
    return null
  }

  const lines = code.split('\n')
  const text = lines[oneBasedLineNumber - 1]
  if (typeof text !== 'string') {
    return null
  }

  return {
    lineNumber: oneBasedLineNumber,
    text
  }
}

function shouldIgnoreMypyDiagnostic(diagnostic: StaticDiagnostic, code: string, lineOffset: number): boolean {
  if (diagnostic.tool !== 'mypy') {
    return false
  }

  const message = diagnostic.message.toLowerCase()
  const codeLine = getCodeLine(code, diagnostic.line - lineOffset)
  const normalizedLine = codeLine?.text.toLowerCase() || ''
  const isCameraFrameAccess =
    normalizedLine.includes('camera.frame') ||
    normalizedLine.includes('camera.frame.animate') ||
    normalizedLine.includes('camera.frame.save_state') ||
    normalizedLine.includes('camera.frame.restore') ||
    normalizedLine.includes('camera.frame.move_to') ||
    normalizedLine.includes('camera.frame.set_width') ||
    normalizedLine.includes('camera.frame.scale')

  if (
    diagnostic.code === 'attr-defined' &&
    message.includes('"frame"') &&
    message.includes('camera') &&
    isCameraFrameAccess
  ) {
    logger.info('Ignoring known mypy false positive for Manim camera.frame', {
      line: diagnostic.line,
      column: diagnostic.column,
      code: diagnostic.code,
      lineText: codeLine?.text.trim() || ''
    })
    return true
  }

  return false
}

async function checkUnit(code: string, lineOffset: number): Promise<StaticDiagnostic[]> {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'manim-static-'))
  const codeFile = path.join(tempDir, 'scene.py')

  try {
    fs.writeFileSync(codeFile, code, 'utf-8')
    logger.info('Static guard checking code unit', {
      tempDir,
      codeFile,
      lineOffset,
      codeLength: code.length
    })

    const pyCompileResult = await runCommand('python', ['-m', 'py_compile', codeFile], tempDir)
    if (pyCompileResult.exitCode !== 0) {
      logger.warn('py_compile reported diagnostic', {
        codeFile,
        lineOffset,
        stderrPreview: pyCompileResult.stderr.trim().slice(0, 300)
      })
      const diagnostic = parsePyCompileDiagnostic(pyCompileResult.stderr, lineOffset)
      return diagnostic ? [diagnostic] : []
    }

    const mypyCommand = resolveMypyCommand()
    if (!mypyCommand) {
      logger.warn('mypy command not found, skip mypy static checks')
      return []
    }

    const mypyResult = await runCommand(
      mypyCommand.command,
      [...mypyCommand.argsPrefix, ...buildMypyArgs(codeFile)],
      tempDir
    )
    const mypyDiagnostics = parseMypyDiagnostics(mypyResult.stdout, mypyResult.stderr, lineOffset)
      .filter((diagnostic) => !shouldIgnoreMypyDiagnostic(diagnostic, code, lineOffset))

    logger.info('mypy check summarized', {
      codeFile,
      lineOffset,
      errorCount: mypyDiagnostics.length
    })
    if (mypyDiagnostics.length > 0) {
      logger.warn('mypy reported errors', {
        codeFile,
        lineOffset,
        errorCount: mypyDiagnostics.length,
        errorsPreview: previewDiagnostics(mypyDiagnostics)
      })
      return mypyDiagnostics
    }

    if (mypyResult.exitCode !== 0 && mypyDiagnostics.length === 0) {
      throw new Error(
        mypyResult.stderr.trim() ||
          mypyResult.stdout.trim() ||
          `${mypyCommand.displayName} check failed`
      )
    }

    return []
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true })
  }
}

export async function runStaticChecks(code: string, outputMode: OutputMode): Promise<StaticCheckBatch> {
  const units = getCodeUnits(code, outputMode)
  const diagnostics: StaticDiagnostic[] = []
  for (const unit of units) {
    diagnostics.push(...(await checkUnit(unit.code, unit.lineOffset)))
  }
  diagnostics.sort((left, right) => left.line - right.line || (left.column || 0) - (right.column || 0))
  return { diagnostics }
}
