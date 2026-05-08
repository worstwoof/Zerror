import type { StudioWorkResult } from '../protocol/studio-agent-types'
import type { StudioReviewViewModel } from '../store/studio-selectors'
import { studioPanelClass } from '../theme'
import { StudioReviewFindingList } from './StudioReviewFindingList'
import { useI18n } from '../../i18n'

interface StudioReviewPanelProps {
  result: StudioWorkResult | null
  review: StudioReviewViewModel | null
}

export function StudioReviewPanel({ result, review }: StudioReviewPanelProps) {
  const { t } = useI18n()
  if (!result || !review) {
    return (
      <section className={studioPanelClass('p-4')}>
        <div className="text-xs uppercase tracking-[0.28em] text-text-secondary">{t('studio.review.title')}</div>
        <div className="mt-3 text-sm text-text-secondary">{t('studio.review.empty')}</div>
      </section>
    )
  }

  return (
    <section className={studioPanelClass('p-4')}>
      <div className="text-xs uppercase tracking-[0.28em] text-text-secondary">{t('studio.review.title')}</div>
      <h3 className="mt-2 text-lg font-semibold text-text-primary">{result.summary}</h3>
      {(review.sourceLabel || review.path) && (
        <div className="mt-2 text-xs text-text-secondary">
          {review.sourceLabel ?? review.path}
        </div>
      )}

      <div className="mt-4 grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
        <div>
          <div className="mb-2 text-sm font-medium text-text-primary">{t('studio.review.findings')}</div>
          <StudioReviewFindingList findings={review.findings} />
        </div>

        <div className="space-y-4">
          <div className="rounded-2xl border border-black/10 bg-black/5 p-3 dark:border-white/10 dark:bg-white/5">
            <div className="text-sm font-medium text-text-primary">{t('studio.review.summary')}</div>
            <div className="mt-2 text-sm text-text-secondary">{review.summary ?? t('studio.review.noSummary')}</div>
          </div>

          {review.changeSet && (
            <div className="rounded-2xl border border-black/10 bg-black/5 p-3 dark:border-white/10 dark:bg-white/5">
              <div className="text-sm font-medium text-text-primary">{t('studio.review.changeSet')}</div>
              <div className="mt-2 space-y-3 text-xs text-text-secondary">
                {review.changeSet.before && <CodeBlock title={t('studio.review.before')} content={review.changeSet.before} />}
                {review.changeSet.after && <CodeBlock title={t('studio.review.after')} content={review.changeSet.after} />}
                {review.changeSet.diff && <CodeBlock title={t('studio.review.diff')} content={review.changeSet.diff} />}
              </div>
            </div>
          )}

          {review.report && <CodeBlock title={t('studio.review.rawReport')} content={review.report} />}
        </div>
      </div>
    </section>
  )
}

function CodeBlock({ title, content }: { title: string; content: string }) {
  return (
    <div>
      <div className="mb-1 text-xs uppercase tracking-[0.2em] text-text-secondary">{title}</div>
      <pre className="overflow-auto rounded-2xl bg-white/70 p-3 text-xs leading-6 text-text-primary dark:bg-black/20">{content}</pre>
    </div>
  )
}
