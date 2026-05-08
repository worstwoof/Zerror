import type { ReactNode } from 'react'
import { act, renderHook } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { I18nProvider } from '../../i18n'
import { useStudioSession } from './use-studio-session'
import { createStudioSession, getStudioSessionSnapshot } from '../api/studio-agent-api'
import type { StudioSession, StudioSessionSnapshot } from '../protocol/studio-agent-types'

vi.mock('../api/studio-agent-api', () => ({
  createStudioSession: vi.fn(),
  getStudioSessionSnapshot: vi.fn(),
}))

vi.mock('./use-studio-events', () => ({
  useStudioEvents: vi.fn(),
}))

vi.mock('./use-studio-run', () => ({
  useStudioRun: vi.fn(() => vi.fn()),
}))

const mockedCreateStudioSession = vi.mocked(createStudioSession)
const mockedGetStudioSessionSnapshot = vi.mocked(getStudioSessionSnapshot)

function wrapper({ children }: { children: ReactNode }) {
  return <I18nProvider>{children}</I18nProvider>
}

function createSession(id = 'session-1'): StudioSession {
  const now = '2026-03-22T00:00:00.000Z'
  return {
    id,
    projectId: 'manimcat-studio',
    agentType: 'builder',
    title: 'ManimCat Studio',
    directory: 'D:/projects/ManimCat',
    permissionLevel: 'L2',
    permissionRules: [],
    createdAt: now,
    updatedAt: now,
  }
}

function createSnapshot(session: StudioSession, taskStatus?: 'queued' | 'running' | 'pending_confirmation'): StudioSessionSnapshot {
  const now = '2026-03-22T00:00:00.000Z'
  return {
    session,
    messages: [],
    runs: [],
    tasks: taskStatus ? [{
      id: 'task-1',
      sessionId: session.id,
      type: 'render',
      status: taskStatus,
      title: 'Render scene',
      createdAt: now,
      updatedAt: now,
    }] : [],
    works: [],
    workResults: [],
  }
}

describe('useStudioSession', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('bootstraps a session and polls quietly only while a render task is active', async () => {
    const session = createSession()
    mockedCreateStudioSession.mockResolvedValue(session)
    mockedGetStudioSessionSnapshot.mockResolvedValue(createSnapshot(session, 'running'))

    const { result } = renderHook(() => useStudioSession(), { wrapper })

    await act(async () => {
      await Promise.resolve()
      await Promise.resolve()
      await Promise.resolve()
    })

    expect(result.current.session?.id).toBe(session.id)
    expect(mockedGetStudioSessionSnapshot).toHaveBeenCalledTimes(2)

    await act(async () => {
      await vi.advanceTimersByTimeAsync(4000)
    })

    expect(mockedGetStudioSessionSnapshot).toHaveBeenCalledTimes(3)
  })

  it('does not start background polling when there is no active render task', async () => {
    const session = createSession()
    mockedCreateStudioSession.mockResolvedValue(session)
    mockedGetStudioSessionSnapshot.mockResolvedValue(createSnapshot(session))

    const { result } = renderHook(() => useStudioSession(), { wrapper })

    await act(async () => {
      await Promise.resolve()
      await Promise.resolve()
      await Promise.resolve()
    })

    expect(result.current.session?.id).toBe(session.id)
    expect(mockedGetStudioSessionSnapshot).toHaveBeenCalledTimes(1)

    await act(async () => {
      await vi.advanceTimersByTimeAsync(8000)
    })

    expect(mockedGetStudioSessionSnapshot).toHaveBeenCalledTimes(1)
  })
})
