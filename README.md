# pandoc-eqref

A Pandoc Lua filter that numbers display math equations and resolves cross-references to them.

## Features

- Tags display math blocks with `{#eq:id}` to assign a sequence number
- Replaces `@eq:id` citations with the corresponding number
- Output adapts to the target format:
  - **LaTeX / PDF** — wraps the equation in an `equation` environment with `\label`, uses `\ref` for citations
  - **HTML** — lays out each equation in a CSS grid with the number right-aligned
  - **docx** — renders inline math followed by the number
  - **Other formats** — same as docx

## Usage

```bash
pandoc input.md --lua-filter pandoc-eqref.lua -o output.pdf
pandoc input.md --lua-filter pandoc-eqref.lua -o output.html
pandoc input.md --lua-filter pandoc-eqref.lua -o output.docx
```

## Syntax

Place the equation tag on the **same line** as the display math, separated by a space:

```markdown
$$x = y + z$$ {#eq:first}

$$E = mc^2$$ {#eq:energy}

See @eq:first and @eq:energy for details.
```

The tag must follow the pattern `{#<id>}`. Any identifier works; the `eq:` prefix is a convention.

## Output examples

### LaTeX / PDF

```latex
\begin{equation}
x = y + z
\label{eq:first}
\end{equation}

See \ref{eq:first} for details.
```

### HTML

Each equation is rendered in a three-column CSS grid so the number floats to the right margin while the equation stays centred:

```html
<div style="display:grid;grid-template-columns:1fr auto 1fr;align-items:center;">
  <div></div>
  <div style="text-align:center;"><span class="math inline">x = y + z</span></div>
  <div style="text-align:right;">(1)</div>
</div>
```

### docx

Inline math followed by non-breaking spaces and the equation number in parentheses: `x = y + z    (1)`.

## Requirements

- [Pandoc](https://pandoc.org/) 2.11 or later (Lua 5.4 filter support)
- A LaTeX distribution (e.g. TeX Live or MiKTeX) for PDF output

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
