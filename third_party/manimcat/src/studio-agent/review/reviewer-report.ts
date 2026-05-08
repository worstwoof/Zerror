export interface ReviewerLineRange {
  start: number
  end: number
}

export interface ReviewerFinding {
  code: string
  severity: 'high' | 'medium' | 'low'
  title: string
  rationale: string
  recommendation: string
  path?: string
  line?: number
  range?: ReviewerLineRange
}

export interface ReviewerTarget {
  path?: string
  content: string
}

export interface ReviewerReport {
  summary: string
  findings: ReviewerFinding[]
}

const REVIEW_TARGET_PATTERN = /<review_target>\s*([\s\S]*?)\s*<\/review_target>/i
const FILE_LINE_PATTERN = /Review the file "([^"]+)"\./i

export function extractReviewerTarget(inputText: string): ReviewerTarget | null {
  const content = inputText.match(REVIEW_TARGET_PATTERN)?.[1]?.trim()
  if (!content) {
    return null
  }

  const path = inputText.match(FILE_LINE_PATTERN)?.[1]
  return {
    path,
    content
  }
}

export function buildReviewerStructuredReport(inputText: string): ReviewerReport | null {
  const target = extractReviewerTarget(inputText)
  if (!target) {
    return null
  }

  const findings = collectReviewerFindings(target)
  const summary = findings.length
    ? `发现 ${findings.length} 个需要关注的问题`
    : '当前没有发现足够确定的高风险问题'

  return {
    summary,
    findings
  }
}

export function buildReviewerReport(inputText: string): string | null {
  const target = extractReviewerTarget(inputText)
  const report = buildReviewerStructuredReport(inputText)
  if (!target || !report) {
    return null
  }

  return renderReviewerReport(target, report)
}

export function renderReviewerReport(target: ReviewerTarget, report: ReviewerReport): string {
  const heading = target.path ? `审查对象：${target.path}` : '审查对象：内联文本'

  if (!report.findings.length) {
    return [
      heading,
      `结论：${report.summary}。`,
      '建议：如果这段代码来自实际变更，仍应结合调用方和渲染路径继续做上下文复核。'
    ].join('\n')
  }

  return [
    heading,
    `结论：${report.summary}。`,
    '',
    ...report.findings.map((finding, index) => {
      const location = formatFindingLocation(finding)
      return [
        `${index + 1}. [${finding.severity}] ${finding.title}${location}`,
        `原因：${finding.rationale}`,
        `建议：${finding.recommendation}`
      ].join('\n')
    })
  ].join('\n')
}

export function collectReviewerFindings(target: ReviewerTarget): ReviewerFinding[] {
  const findings: ReviewerFinding[] = []
  const lines = target.content.split(/\r?\n/)

  pushFindingIfMatched({
    findings,
    target,
    code: 'manim.wildcard-import',
    severity: 'medium',
    title: '使用了通配符 Manim 导入',
    rationale: '通配符导入会降低审查可读性，也更容易把名称冲突和错误 API 使用藏起来。随着场景代码增长，这会让后续维护和 review 明显变差。',
    recommendation: '改成显式导入当前场景真正使用的 Manim 符号。',
    lineMatcher: (line) => /from\s+manim\s+import\s+\*/.test(line)
  })

  pushFindingIfMatched({
    findings,
    target,
    code: 'python.bare-except',
    severity: 'high',
    title: '存在 bare except',
    rationale: '裸捕获会把真实渲染错误、LaTeX 错误或文件路径错误全部吞掉，调用方也无法区分失败类型。',
    recommendation: '改为捕获明确异常类型，并把错误信息向上抛出或写入结构化日志。',
    lineMatcher: (line) => /except\s*:/.test(line)
  })

  pushFindingIfMatched({
    findings,
    target,
    code: 'python.broad-exception',
    severity: 'medium',
    title: '异常捕获过宽',
    rationale: '直接捕获 Exception 很容易把本应暴露的行为回归和环境错误一起吞掉，尤其是在渲染链路里会降低定位效率。',
    recommendation: '只捕获当前代码确实能处理的异常类型，并保留兜底日志。',
    lineMatcher: (line) => /except\s+Exception\s*:/.test(line)
  })

  pushFindingIfMatched({
    findings,
    target,
    code: 'logging.debug-print',
    severity: 'low',
    title: '使用了 print 调试输出',
    rationale: '长期保留的 print 会让长任务输出变得嘈杂，也不利于后续把渲染、审查和任务结果统一写回。',
    recommendation: '改为结构化日志，或在提交前移除临时调试输出。',
    lineMatcher: (line) => /print\(/.test(line)
  })

  pushFindingIfMatched({
    findings,
    target,
    code: 'workflow.todo-marker',
    severity: 'low',
    title: '存在未完成标记',
    rationale: 'TODO/FIXME 说明这段逻辑可能还没有收口，如果它位于生成、审查或渲染链路中，后续行为容易出现不一致。',
    recommendation: '确认这些标记是否仍代表真实缺口；如果是，补齐或至少把风险写进任务结论。',
    lineMatcher: (line) => /TODO|FIXME/.test(line)
  })

  const longLineIndex = lines.findIndex((line) => line.length > 140)
  if (longLineIndex >= 0) {
    findings.push(buildFinding(target, {
      code: 'style.long-line',
      severity: 'low',
      title: '存在过长代码行',
      rationale: '超长行会让 diff、自动补丁和 review 都更难定位真实行为变化。',
      recommendation: '把长表达式拆开，尤其是复杂动画参数和嵌套调用。',
      line: longLineIndex + 1
    }))
  }

  return findings
}

function pushFindingIfMatched(input: {
  findings: ReviewerFinding[]
  target: ReviewerTarget
  code: string
  severity: ReviewerFinding['severity']
  title: string
  rationale: string
  recommendation: string
  lineMatcher: (line: string) => boolean
}): void {
  const line = findFirstMatchingLine(input.target.content, input.lineMatcher)
  if (!line) {
    return
  }

  input.findings.push(buildFinding(input.target, {
    code: input.code,
    severity: input.severity,
    title: input.title,
    rationale: input.rationale,
    recommendation: input.recommendation,
    line
  }))
}

function buildFinding(
  target: ReviewerTarget,
  input: Omit<ReviewerFinding, 'path' | 'range'> & { line?: number }
): ReviewerFinding {
  return {
    ...input,
    path: target.path,
    range: input.line ? { start: input.line, end: input.line } : undefined
  }
}

function findFirstMatchingLine(content: string, matcher: (line: string) => boolean): number | undefined {
  const lines = content.split(/\r?\n/)
  const index = lines.findIndex((line) => matcher(line))
  return index >= 0 ? index + 1 : undefined
}

function formatFindingLocation(finding: ReviewerFinding): string {
  if (!finding.path && !finding.line) {
    return ''
  }

  if (finding.path && finding.line) {
    return ` (${finding.path}:${finding.line})`
  }

  if (finding.path) {
    return ` (${finding.path})`
  }

  return ` (line ${finding.line})`
}
