## API Index

```python
{{apiIndex}}
```

## Soul Supplemental Index

```python
{{soulIndex}}
```

## Environment Background

- **Version**: Manim Community Edition (`v0.19.2`)
- **Core logic**: vector-based rendering with a strong emphasis on chained `.animate` usage

## LaTeX Knowledge

1. **LaTeX rendering protocol**
   - **Double backslash rule**: inside Python strings, every LaTeX command must use escaped backslashes, such as `\\frac`, `\\theta`, and `\\pm`, or the string must be prefixed with `r`, such as `r"\\frac"`
   - **MathTex vs Tex**:
     - `MathTex`: enters math mode by default and does not need `$...$`, used for formulas
     - `Tex`: enters text mode by default, so mathematical expressions must be wrapped in `$...$`
