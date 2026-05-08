/**
 * OpenAI 客户端服务
 * 处理基于 AI 的 Manim 代码生成
 */

import OpenAI from 'openai'
import { createLogger } from '../utils/logger'
import type { CustomApiConfig } from '../types'
import { createCustomOpenAIClient } from './openai-client-factory'
import { createChatCompletionText } from './openai-stream'
import {
  extractCodeFromResponse,
  generateManimPrompt,
  generateUniqueSeed,
  OPENAI_MANIM_SYSTEM_PROMPT
} from './openai-client-utils'
import { buildTokenParams } from '../utils/reasoning-model'

const logger = createLogger('OpenAIClient')

const AI_TEMPERATURE = parseFloat(process.env.AI_TEMPERATURE || '0.7')
const MAX_TOKENS = parseInt(process.env.AI_MAX_TOKENS || '12000', 10)
const THINKING_TOKENS = parseInt(process.env.AI_THINKING_TOKENS || '20000', 10)

export interface BackendTestResult {
  model: string
  content: string
}

function normalizeConfig(config: CustomApiConfig): CustomApiConfig {
  return {
    apiUrl: config.apiUrl.trim(),
    apiKey: config.apiKey.trim(),
    model: (config.model || '').trim()
  }
}

function createClient(config: CustomApiConfig): OpenAI {
  const normalized = normalizeConfig(config)
  if (!normalized.apiUrl || !normalized.apiKey) {
    throw new Error('Upstream apiUrl/apiKey is missing')
  }
  return createCustomOpenAIClient(normalized)
}

function requireModel(config: CustomApiConfig): string {
  const model = normalizeConfig(config).model
  if (!model) {
    throw new Error('No model available')
  }
  return model
}

export async function listBackendAIModels(config: CustomApiConfig): Promise<string[]> {
  const client = createClient(config)

  const response = await client.models.list()
  const models = response.data
    .map((model) => model.id)
    .filter((id) => typeof id === 'string' && id.trim().length > 0)

  return Array.from(new Set(models)).sort((a, b) => a.localeCompare(b))
}

/**
 * 创建自定义 OpenAI 客户端
 */
// (moved into createClient/normalizeConfig helpers)

/**
 * 使用 OpenAI 生成 Manim 代码
 * 使用较高的温度以获得多样化的输出，并为每次请求使用唯一种子
 */
export async function generateAIManimCode(concept: string, customApiConfig: CustomApiConfig): Promise<string> {
  const client = createClient(customApiConfig)

  try {
    const seed = generateUniqueSeed(concept)

    const systemPrompt = OPENAI_MANIM_SYSTEM_PROMPT

    const userPrompt = generateManimPrompt(concept, seed)

    const model = requireModel(customApiConfig)

    const { content, mode } = await createChatCompletionText(
      client,
      {
        model,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        temperature: AI_TEMPERATURE,
        ...buildTokenParams(THINKING_TOKENS, MAX_TOKENS)
      },
      { fallbackToNonStream: true, usageLabel: 'single-stage-generation' }
    )

    if (!content) {
      logger.warn('AI 返回空内容')
      return ''
    }

    // 记录完整的 AI 响应
    logger.info('AI 代码生成成功', {
      concept,
      seed,
      mode,
      responseLength: content.length,
      response: content
    })

    const extractedCode = extractCodeFromResponse(content)
    logger.info('代码提取完成', {
      extractedLength: extractedCode.length,
      code: extractedCode
    })

    return extractedCode
  } catch (error) {
    if (error instanceof OpenAI.APIError) {
      logger.error('OpenAI API 错误', {
        concept,
        status: error.status,
        code: error.code,
        type: error.type,
        message: error.message,
        headers: JSON.stringify(error.headers),
        cause: error.cause
      })
    } else if (error instanceof Error) {
      logger.error('AI 生成失败', {
        concept,
        errorName: error.name,
        errorMessage: error.message,
        stack: error.stack
      })
    } else {
      logger.error('AI 生成失败（未知错误）', { concept, error: String(error) })
    }
    return ''
  }
}

export async function testBackendAIConnection(customApiConfig: CustomApiConfig): Promise<BackendTestResult> {
  const client = createClient(customApiConfig)
  const model = requireModel(customApiConfig)

  const response = await client.chat.completions.create({
    model,
    messages: [{ role: 'user', content: 'hello' }],
    temperature: 0,
    max_tokens: 8
  })

  return {
    model,
    content: response.choices[0]?.message?.content || ''
  }
}
