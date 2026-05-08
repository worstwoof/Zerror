import type { StaticDiagnostic } from './types'

export function getStaticPatchSystemPrompt(): string {
  return [
    '你是一个静态修复员，只做局部替换。',
    '你的唯一任务是根据静态检查报错，返回可直接替换的原片段和新片段。',
    '优先修改最小片段；能改一行内局部就不要改整行；能改一行就不要改多行。',
    '如果当前报错属于同一类、可模式化的静态问题，并且在同文件中明显重复出现，允许一次性返回多个局部 patch，一起修掉多个同类问题，连续或非连续都可以。',
    '禁止返回完整代码，禁止解释，禁止附加任何文字。',
    '不要输出 JSON。',
    '只输出一个或多个 SEARCH/REPLACE patch 块。',
    '每个 patch 严格使用下面格式：',
    '[[PATCH]]',
    '[[SEARCH]]',
    '这里放原代码片段',
    '[[REPLACE]]',
    '这里放替换后的代码片段',
    '[[END]]',
    'original snippet 必须逐字摘抄自当前代码，不能改写，不能概括。',
    '禁止 markdown 代码块，禁止 ```，禁止任何额外说明。',
    '如果需要补充 Manim 类导入，必须新增单独的 from manim import Xxx 行，禁止写成 from manim import *, Xxx。',
    '第一行必须是 [[PATCH]]；如果无法生成合法 patch，返回空字符串。'
  ].join('\n')
}

function formatDiagnostic(diagnostic: StaticDiagnostic, index: number): string {
  return [
    `问题 ${index + 1}:`,
    `- 工具：${diagnostic.tool}`,
    `- 错误码：${diagnostic.code || 'unknown'}`,
    `- 行号：${diagnostic.line}`,
    `- 报错信息：${diagnostic.message}`
  ].join('\n')
}

export function buildStaticPatchUserPrompt(code: string, diagnostics: StaticDiagnostic[]): string {
  const primaryDiagnostic = diagnostics[0]
  return [
    '完整代码：',
    code,
    '',
    '静态检查结果：',
    ...diagnostics.map((diagnostic, index) => formatDiagnostic(diagnostic, index)),
    '',
    '修复要求：',
    '- 优先做最小局部替换。',
    '- 这是一批当前文件里真实存在的静态问题，请优先一起修掉同类问题；连续或非连续都可以。',
    '- original_snippet 必须逐字摘抄自上面的当前代码，包含完全一致的空格、缩进、括号和变量名，不能改写，不能概括。',
    '- 不要重写整个文件。',
    primaryDiagnostic
      ? `- 优先围绕第一个问题（第 ${primaryDiagnostic.line} 行）组织修复，但可顺手修掉同批同类问题。`
      : '- 没有问题时不要输出任何内容。',
    '- 如果要补充导入，使用单独的新 import 行，不要构造非法 import 语法。',
    '',
    '只返回下面这种 patch 块，可返回多个：',
    '[[PATCH]]',
    '[[SEARCH]]',
    '原代码片段1',
    '[[REPLACE]]',
    '新代码片段1',
    '[[END]]',
    '',
    '示例 1：修复缺失的 ThreeDScene 导入',
    '错误：Name "ThreeDScene" is not defined',
    '当前代码：',
    'from manim import *',
    '',
    'class MainScene(ThreeDScene):',
    '    pass',
    '正确输出：',
    '[[PATCH]]',
    '[[SEARCH]]',
    'from manim import *',
    '[[REPLACE]]',
    'from manim import *',
    'from manim import ThreeDScene',
    '[[END]]',
    '',
    '示例 2：修复非法 import 语法',
    '错误：SyntaxError: invalid syntax',
    '当前代码：',
    'from manim import *, ThreeDScene',
    '正确输出：',
    '[[PATCH]]',
    '[[SEARCH]]',
    'from manim import *, ThreeDScene',
    '[[REPLACE]]',
    'from manim import *',
    'from manim import ThreeDScene',
    '[[END]]'
  ].join('\n')
}
