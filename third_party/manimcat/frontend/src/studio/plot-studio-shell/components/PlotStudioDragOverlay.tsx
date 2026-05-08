export function PlotStudioDragOverlay() {
  return (
    <div className="pointer-events-none fixed inset-0 z-[160] border border-dashed border-black/15 bg-bg-primary/86 backdrop-blur-[2px] dark:border-white/15">
      <div className="flex h-full items-center justify-center p-6">
        <div className="rounded-[2rem] border border-black/8 bg-white/72 px-6 py-4 text-center shadow-[0_24px_80px_rgba(15,23,42,0.08)] backdrop-blur-xl dark:border-white/10 dark:bg-bg-secondary/78">
          <div className="font-mono text-[10px] uppercase tracking-[0.36em] text-text-secondary/60">
            DROP IMAGES
          </div>
          <div className="mt-2 text-sm text-text-primary/86">
            拖拽图片到此以上传为参考图
          </div>
        </div>
      </div>
    </div>
  )
}
