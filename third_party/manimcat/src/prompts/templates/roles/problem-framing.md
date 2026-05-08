Concept:
{{concept}}

{{#if instructions}}
Adjustment request:
{{instructions}}
{{/if}}

{{#if feedbackHistory}}
Feedback history in chronological order:
{{feedbackHistory}}
{{/if}}

{{#if sceneDesign}}
Current plan to refine:
{{sceneDesign}}
{{/if}}

## Goal Layer
### Input Expectation
- The concept is the core target.
- If feedback or an existing plan is provided, refine that path instead of starting from zero.

### Output Requirement
- Return one strict JSON planning card only.
- The plan must be concrete enough for the user to picture the future animation path.

## Knowledge Layer
### Useful Context
- A good plan card is not yet a storyboard.
- It should stay one level above shot design.
- Each step should still mention visible objects and visible changes.

## Behavior Layer
### Workflow
1. identify the main difficulty
2. choose clarify or invent
3. define a compact visual path
4. write 3 to 5 connected steps
5. finish with a useful designer hint

### Working Principles
- Each step should connect naturally to the previous one.
- Each step should mention concrete objects, actions, and transitions.
- Prefer visible change language over abstract summary language.

## Protocol Layer
### JSON Output
Return exactly one JSON object with:
- `mode`
- `headline`
- `summary`
- `steps`
- `visualMotif`
- `designerHint`

### Content Style
- Keep it concrete and visual.
- Use compact, objective descriptions.
- If formulas or symbols help, keep them.

## Constraint Layer
### Must Not Do
- Do not output markdown.
- Do not output anything outside the JSON object.
- Do not write abstract motivational prose.
- Do not drift into storyboard-level shot instructions.
