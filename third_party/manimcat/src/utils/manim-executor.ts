import { spawn } from 'child_process'
import { createLogger } from './logger'
import {
  registerManimProcess,
  unregisterManimProcess,
  wasManimProcessCancelled
} from './manim-process-registry'
import {
  buildManimArgs,
  buildResult,
  createExecutionState,
  elapsedSeconds,
  handleStderrData,
  handleStdoutData,
  normalizeExecuteOptions,
  startMemoryMonitor
} from './manim-executor-runtime'

const logger = createLogger('ManimExecutor')

export interface ManimExecutionResult {
  success: boolean
  stdout: string
  stderr: string
  peakMemoryMB: number
  exitCode?: number
}

export interface ManimExecuteOptions {
  jobId: string
  quality: string
  frameRate?: number
  format?: 'mp4' | 'png'
  sceneName?: string
  tempDir: string
  mediaDir: string
  timeoutMs?: number
}

export function executeManimCommand(
  codeFile: string,
  options: ManimExecuteOptions
): Promise<ManimExecutionResult> {
  const normalizedOptions = normalizeExecuteOptions(options)
  const args = buildManimArgs(codeFile, normalizedOptions)

  const manimExecutable = process.env.MANIM_EXECUTABLE || 'manim'

  logger.info(`Job ${normalizedOptions.jobId}: starting manim process`, {
    command: `${manimExecutable} ${args.join(' ')}`,
    cwd: normalizedOptions.tempDir
  })

  return new Promise((resolve) => {
    const startTime = Date.now()
    const state = createExecutionState()
    const proc = spawn(manimExecutable, args, { cwd: normalizedOptions.tempDir })

    registerManimProcess(normalizedOptions.jobId, proc)

    const memoryMonitor = startMemoryMonitor(proc, normalizedOptions, state)
    let timeoutTimer: NodeJS.Timeout | null = null
    let settled = false

    const settle = (result: ManimExecutionResult): void => {
      if (settled) {
        return
      }
      settled = true

      if (timeoutTimer) {
        clearTimeout(timeoutTimer)
      }
      clearInterval(memoryMonitor)
      unregisterManimProcess(normalizedOptions.jobId)
      resolve(result)
    }

    proc.stdout.on('data', (data) => {
      handleStdoutData(state, normalizedOptions.jobId, data.toString())
    })

    proc.stderr.on('data', (data) => {
      handleStderrData(state, normalizedOptions.jobId, data.toString())
    })

    timeoutTimer = setTimeout(() => {
      const elapsed = elapsedSeconds(startTime)

      logger.warn(`Job ${normalizedOptions.jobId}: manim render timeout (${elapsed}s), killing process`, {
        peakMemoryMB: state.peakMemoryMB
      })

      proc.kill('SIGKILL')

      settle(
        buildResult(
          false,
          state,
          state.stderr || `Manim render timeout (${Math.round(normalizedOptions.timeoutMs / 1000)} seconds)`
        )
      )
    }, normalizedOptions.timeoutMs)

    proc.on('close', (code) => {
      const elapsed = elapsedSeconds(startTime)
      const cancelled = wasManimProcessCancelled(normalizedOptions.jobId)

      if (cancelled) {
        logger.warn(`Job ${normalizedOptions.jobId}: Manim cancelled`, { elapsed: `${elapsed}s` })
        settle(buildResult(false, state, 'Job cancelled', code ?? undefined))
        return
      }

      if (code === 0) {
        logger.info(`Job ${normalizedOptions.jobId}: manim completed`, {
          elapsed: `${elapsed}s`,
          exitCode: code,
          stdoutLength: state.stdout.length,
          stderrLength: state.stderr.length,
          peakMemoryMB: state.peakMemoryMB
        })
        settle(buildResult(true, state, undefined, code ?? undefined))
        return
      }

      logger.error(`Job ${normalizedOptions.jobId}: manim exited with error`, {
        elapsed: `${elapsed}s`,
        exitCode: code,
        stdoutLength: state.stdout.length,
        stderrLength: state.stderr.length,
        stderrPreview: state.stderr.slice(-500),
        peakMemoryMB: state.peakMemoryMB
      })
      settle(buildResult(false, state, undefined, code ?? undefined))
    })

    proc.on('error', (error) => {
      const elapsed = elapsedSeconds(startTime)
      const cancelled = wasManimProcessCancelled(normalizedOptions.jobId)

      if (cancelled) {
        logger.warn(`Job ${normalizedOptions.jobId}: Manim cancelled`, { elapsed: `${elapsed}s` })
        settle(buildResult(false, state, 'Job cancelled'))
        return
      }

      logger.error(`Job ${normalizedOptions.jobId}: manim process start failed`, {
        elapsed: `${elapsed}s`,
        errorMessage: error.message,
        errorStack: error.stack
      })
      settle(buildResult(false, state, error.message))
    })
  })
}
