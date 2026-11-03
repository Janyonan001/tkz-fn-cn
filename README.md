# tkz-fn — Graphs of functions with  LuaLaTeX

_Current release: **[2026/10/19 version 1.00c]**_

`tkz-fn` draws graphs of functions with TikZ; every computation is done by Lua.
It is the successor of `tkz-fct`: gnuplot, `fp.sty`, `tkz-base` and
`--shell-escape` are no longer needed.

## Features

- Curves y = f(x), parametric and polar curves; the curve is interrupted where
  the function is not defined and at vertical asymptotes.
- Tangent lines and one-sided tangent lines, areas under a curve or between two
  curves, Riemann sums (left, right, mid, inf, sup).
- Points on a curve, coordinates, texts, vertical and horizontal lines, data.
- Results computed by Lua and written in the text: values, derivatives,
  integrals, Riemann sums.
- Two coordinate spaces: computations are done in the units of the coordinate
  system (`xstep`, `ystep`), drawing is done in centimeters.
- Numbers written in the American (`3.14`, `(a, b)`) or the French
  (`3,14`, `]a ; b[`) format.
- Axes as in school textbooks (arrow at one or both ends) or "box" axes as
  with pgfplots, chosen with an option (no environment).
- Optional bridge to `tkz-elements`: the points defined by `tkz-fn` are
  available in the table `z`.

## Requirements

- LuaLaTeX
- TikZ (loaded by the package, with the library `plotmarks`)

`tkz-fn` does not need `tkz-base` or `tkz-euclide`. All its macros begin with
`\tkzFn`, so it can be used together with `tkz-fct`.

## Installation

The package consists of two files: `tkz-fn.sty` and `tkz_fn.lua`.
Put them in a folder known to TeX, for example `texmf/tex/latex/tkz-fn`,
or in the folder of your document.

## Quick start

```latex
% !TEX TS-program = lualatex
\documentclass{article}
\usepackage{tkz-fn}
\begin{document}
\begin{tikzpicture}
  \tkzFnInit[xmin=-2,xmax=4,ymin=-3,ymax=6]
  \tkzFnGrid
  \tkzFnAxes
  \tkzFnDef{f}{x^2 - 2*x - 1}
  \tkzFnDraw[thick,red](f)
  \tkzFnTangent[blue,kl=1.5,kr=1.5](f,3)
\end{tikzpicture}

$f'(3) = \tkzFnPrint{diff(f,3)}$
\end{document}
```

Expressions are Lua expressions: `x^2`, `sin(x)`, `ln(x)`, `exp(x)`,
`sqrt(x)`, `pi`, `e`.

## Documentation

- `doc/tkz-fn-en.pdf`: documentation in American English
- `doc/tkz-fn-fr.pdf`: documentation in French

The sources are in `doc/latex-en` and `doc/latex-fr` (class `tkz-doc`, LuaLaTeX,
makeindex).

## License

This work may be distributed and/or modified under the conditions of the
LaTeX Project Public License, either version 1.3c of this license or (at your
option) any later version. See `LICENSE` and `lppl-1-3c.txt`.

This work has the LPPL maintenance status "maintained".
The Current Maintainer of this work is Alain Matthes.
