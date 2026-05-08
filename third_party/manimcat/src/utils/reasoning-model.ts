/** Always returns { max_completion_tokens: thinkingTokens + outputTokens } */
export function buildTokenParams(
  thinkingTokens: number,
  outputTokens: number
): { max_completion_tokens: number } {
  return { max_completion_tokens: thinkingTokens + outputTokens }
}
