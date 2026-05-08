/** Default to broad OpenAI-compatible providers; opt into reasoning tokens when needed. */
export function buildTokenParams(
  thinkingTokens: number,
  outputTokens: number
): { max_completion_tokens: number } | { max_tokens: number } {
  if (process.env.MANIMCAT_USE_MAX_COMPLETION_TOKENS === 'true') {
    return { max_completion_tokens: thinkingTokens + outputTokens }
  }
  return { max_tokens: outputTokens }
}
