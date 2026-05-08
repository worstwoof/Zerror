import type { RefObject } from 'react'
import { StudioCommandPanel, type StudioCommandPanelHandle } from '../components/StudioCommandPanel'
import { PlotPreviewPanel } from '../plot/PlotPreviewPanel'
import type { usePlotStudioShell } from './hooks/use-plot-studio-shell'
import { PlotStudioHistoryAside } from './components/PlotStudioHistoryAside'

interface PlotStudioWorkspaceProps {
  commandPanelRef: RefObject<StudioCommandPanelHandle | null>
  shell: ReturnType<typeof usePlotStudioShell>
  onExit: () => void
  interruptPlaceholder: string | undefined
}

export function PlotStudioWorkspace({
  commandPanelRef,
  shell,
  onExit,
  interruptPlaceholder,
}: PlotStudioWorkspaceProps) {
  return (
    <>
      <main className="relative mb-10 flex min-h-[36vh] flex-1 items-center justify-center md:mb-12 md:min-h-0">
        <div className="h-full w-full">
          <PlotPreviewPanel
            session={shell.studio.session}
            works={shell.orderedWorkSummaries}
            selectedWorkId={shell.effectiveSelectedWorkId}
            work={shell.selected.work}
            result={shell.selected.result}
            latestRun={shell.studio.latestRun}
            tasks={shell.selected.tasks}
            latestAssistantText={shell.studio.latestAssistantText}
            errorMessage={shell.studio.state.error ?? shell.studio.state.connection.eventError}
            onSelectWork={shell.setSelectedWorkId}
            onReorderWorks={shell.handleReorderWorks}
            onSendPreviewToComposer={(attachment) => commandPanelRef.current?.appendPreviewAttachment(attachment)}
            variant="pure-minimal-top"
          />
        </div>
      </main>

      <section className="flex shrink-0 min-h-0 flex-col gap-5 md:h-72 md:flex-row md:gap-12 lg:gap-16">
        <div className="relative flex min-h-[15rem] min-w-0 flex-1 flex-col md:pl-5 md:pr-5 lg:pl-8 lg:pr-10">
          <StudioCommandPanel
            ref={commandPanelRef}
            session={shell.studio.session}
            messages={shell.studio.messages}
            latestAssistantText={shell.studio.latestAssistantText}
            isBusy={shell.studio.isBusy}
            disabled={shell.studio.isBusy || shell.studio.state.connection.snapshotStatus !== 'ready'}
            onRun={shell.studio.runCommand}
            onExit={onExit}
            variant="pure-minimal-bottom"
            onEscapePress={shell.handleEscapePress}
            inputPlaceholderOverride={interruptPlaceholder}
          />
        </div>

        <PlotStudioHistoryAside
          works={shell.orderedWorkSummaries}
          selectedWorkId={shell.effectiveSelectedWorkId}
          historyCountLabel={shell.historyCountLabel}
          maxHistorySlots={shell.maxHistorySlots}
          onSelectWork={shell.setSelectedWorkId}
        />
      </section>
    </>
  )
}
