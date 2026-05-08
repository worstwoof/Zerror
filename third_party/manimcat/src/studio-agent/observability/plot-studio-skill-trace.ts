import { createLogger } from '../../utils/logger'

const logger = createLogger('PlotStudioSkillTrace')

const PLOT_STUDIO_SKILL_EVENT_LABELS: Record<string, string> = {
  'skill.prompt.catalog': '绘图工作室：技能目录已注入提示词',
  'skill.prompt.state': '绘图工作室：技能状态已注入提示词',
  'skill.discovery.requested': '绘图工作室：开始发现技能',
  'skill.discovery.completed': '绘图工作室：技能发现完成',
  'skill.summary.requested': '绘图工作室：开始读取技能摘要',
  'skill.summary.completed': '绘图工作室：技能摘要读取完成',
  'skill.resolve.requested': '绘图工作室：开始解析技能',
  'skill.resolve.completed': '绘图工作室：技能解析完成',
  'skill.usage.recorded': '绘图工作室：技能使用已记录',
  'skill.registry.list': '绘图工作室：技能注册表列举完成',
  'skill.registry.match': '绘图工作室：技能注册表命中',
  'skill.source.scan': '绘图工作室：技能源扫描完成',
  'skill.tool.called': '绘图工作室：skill 工具开始执行',
  'skill.tool.completed': '绘图工作室：skill 工具执行完成',
  'skill.task.requested': '绘图工作室：旧任务式 skill 请求',
  'skill.subagent.requested': '绘图工作室：旧多阶段 skill 注入开始',
  'skill.subagent.resolved': '绘图工作室：旧多阶段 skill 注入完成',
}

export function logPlotStudioSkillTrace(
  studioKind: string | null | undefined,
  event: string,
  data: Record<string, unknown>,
  level: 'info' | 'warn' = 'info',
): void {
  if (studioKind !== 'plot') {
    return
  }

  logger[level](PLOT_STUDIO_SKILL_EVENT_LABELS[event] ?? `绘图工作室：${event}`, {
    事件代码: event,
    ...data,
  })
}
