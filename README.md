# pandoc-eqref

A Pandoc Lua filter that numbers display math equations and chemical equations, and resolves cross-references to them.

## Features

- Tags display math blocks with `{#eq:id}` to assign a sequence number
- Tags standalone chemical equation lines (`[formula]{.chem} {#eq:id}`) in the same numbering sequence
- Replaces `@eq:id` citations with the corresponding number
- Output adapts to the target format:
  - **LaTeX / PDF** — wraps math in an `equation` environment with `\label`; wraps chemical equations in `\begin{equation}\ce{...}\label{}\end{equation}`; uses `\ref` for citations
  - **HTML** — lays out each equation in a CSS grid with the number right-aligned
  - **docx** — renders the equation followed by the number
  - **Other formats** — same as docx

## Usage

### Math equations only

```bash
pandoc input.md --lua-filter pandoc-eqref.lua -o output.pdf
pandoc input.md --lua-filter pandoc-eqref.lua -o output.html
pandoc input.md --lua-filter pandoc-eqref.lua -o output.docx
```

### Math + chemical equations

When using chemical equation syntax (`[...]{.chem}`), this filter must run **before**
`pandoc-chem-sub.lua` so it can detect the `.chem` span before chem-sub converts it
to Unicode inlines:

```bash
pandoc input.md --lua-filter pandoc-eqref.lua --lua-filter pandoc-chem-sub.lua -o output.html
pandoc input.md --lua-filter pandoc-eqref.lua --lua-filter pandoc-chem-sub.lua -o output.pdf
pandoc input.md --lua-filter pandoc-eqref.lua --lua-filter pandoc-chem-sub.lua -o output.docx
```

## Syntax

### Display math

Place the equation tag on the **same line** as the display math, separated by a space:

```markdown
$$x = y + z$$ {#eq:first}

$$E = mc^2$$ {#eq:energy}

See @eq:first and @eq:energy for details.
```

### Chemical equations

Place the equation tag on the **same line** as the chemical formula, with no other text:

```markdown
[CH3CH2OH + HBr -> CH3CH2Br + H2O]{.chem} {#eq:rxn}

$$E = mc^2$$ {#eq:energy}

See @eq:rxn and @eq:energy.
```

Expected output: `eq:rxn` → (1), `eq:energy` → (2); references render as `1` and `2`.

The tag must follow the pattern `{#<id>}`. Any identifier works; the `eq:` prefix is a convention.

**Note:** The chemical equation line must contain *only* `[formula]{.chem} {#id}` — no surrounding
prose. This prevents accidentally numbering inline chemical formulas.

## Output examples

### LaTeX / PDF

```latex
\begin{equation}
x = y + z
\label{eq:first}
\end{equation}

\begin{equation}
\ce{CH3CH2OH + HBr -> CH3CH2Br + H2O}
\label{eq:rxn}
\end{equation}

See \ref{eq:first} and \ref{eq:rxn} for details.
```

PDF output for chemical equations requires the `mhchem` LaTeX package. Add to your
document metadata or a custom header:

```latex
\usepackage[version=4]{mhchem}
```

### HTML

Each equation is rendered in a three-column CSS grid so the number floats to the right
margin while the equation stays centred. For chemical equations, `pandoc-chem-sub.lua`
then converts the `.chem` span inside the grid to properly formatted Unicode:

```html
<div style="display:grid;grid-template-columns:1fr auto 1fr;align-items:center;">
  <div></div>
  <div style="text-align:center;">CH₃CH₂OH + HBr → CH₃CH₂Br + H₂O</div>
  <div style="text-align:right;">(1)</div>
</div>
```

### docx

The equation followed by non-breaking spaces and the equation number in parentheses.

## Requirements

- [Pandoc](https://pandoc.org/) 2.11 or later (Lua 5.4 filter support)
- A LaTeX distribution (e.g. TeX Live or MiKTeX) for PDF output
- `mhchem` LaTeX package for chemical equation PDF output
- [`pandoc-chem-sub.lua`](https://github.com/scotthartley/pandoc-chem-sub-lua) for chemical equation rendering in HTML/docx

## Installation

Copy `pandoc-eqref.lua` to your project directory or to a directory on your Pandoc data path:

```bash
# Per-project
cp pandoc-eqref.lua /your/project/

# System-wide (Linux / macOS)
cp pandoc-eqref.lua ~/.local/share/pandoc/filters/
```

## Acknowledgments

This filter was written by [Claude Code](https://claude.ai/claude-code), Anthropic's AI coding assistant.

## License

MIT
