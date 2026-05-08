import { z } from 'zod'

export const qualitySchema = z.enum(['low', 'medium', 'high'])

export const customApiConfigSchema = z.object({
  apiUrl: z.string(),
  apiKey: z.string(),
  model: z.string()
})

export const promptOverridesSchema = z.object({
  locale: z.enum(['zh-CN', 'en-US']).optional(),
  roles: z
    .object({
      problemFraming: z
        .object({
          system: z.string().max(20000).optional(),
          user: z.string().max(20000).optional()
        })
        .optional(),
      conceptDesigner: z
        .object({
          system: z.string().max(20000).optional(),
          user: z.string().max(20000).optional()
        })
        .optional(),
      codeGeneration: z
        .object({
          system: z.string().max(20000).optional(),
          user: z.string().max(20000).optional()
        })
        .optional(),
      codeRetry: z
        .object({
          system: z.string().max(20000).optional(),
          user: z.string().max(20000).optional()
        })
        .optional(),
      codeEdit: z
        .object({
          system: z.string().max(20000).optional(),
          user: z.string().max(20000).optional()
        })
        .optional()
    })
    .optional(),
  shared: z
    .object({
      apiIndex: z.string().max(40000).optional(),
      specification: z.string().max(40000).optional()
    })
    .optional()
})

export const videoConfigSchema = z.object({
  quality: qualitySchema.optional(),
  frameRate: z.number().int().min(1).max(120).optional(),
  timeout: z.number().optional(),
  bgm: z.boolean().optional()
})
