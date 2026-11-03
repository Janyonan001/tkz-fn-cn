# Changelog — tkz-fn

All notable changes to `tkz-fn` are listed here, most recent first.

## [2026/10/19 — version 1.00c]

   First release. `tkz-fn` is the successor of `tkz-fct`: every computation is
   done by Lua (LuaLaTeX); gnuplot, `fp.sty`, `tkz-base` and `--shell-escape`
   are no longer needed. All macros begin with `\tkzFn`, so `tkz-fn` and
   `tkz-fct` can be loaded together.

   ### Added
   - **Coordinate system**: `\tkzFnInit` (`xstep`, `ystep`, `enlarge`),
     `\tkzFnGrid` (subgrid, region), `\tkzFnAxes`, `\tkzFnAxisX`,
     `\tkzFnAxisY` (ticks at multiples of pi with `trig`), `\tkzFnClip`,
     `\tkzFnRep`, `\tkzFnText`.
   - **Functions**: `\tkzFnDef`, `\tkzFnDraw` (named function or expression,
     `mark`, `smooth`), `\tkzFnParam`, `\tkzFnPolar`. Curves are clipped to
     the window and interrupted where the function is not defined and at
     vertical asymptotes.
   - **Points**: `\tkzFnDefPoint`, `\tkzFnDefPointXY`, `\tkzFnDrawPoints`,
     `\tkzFnMarkPoints`, `\tkzFnLabelPoint(s)`, `\tkzFnShowCoord`,
     `\tkzFnDrawData`.
   - **Tangent lines**: `\tkzFnTangent`, with one-sided tangent lines computed
     separately where the function is not differentiable.
   - **Areas and sums**: `\tkzFnArea` (under a curve, between two curves,
     option `where`), `\tkzFnRiemann` (methods `left`, `right`, `mid`, `inf`,
     `sup`).
   - **Lines**: `\tkzFnVLines`, `\tkzFnHLines`.
   - **Results**: `\tkzFnPrint`, `\tkzFnPrintCoord`, `\tkzFnPrintInterval`;
     Lua functions `diff`, `integral`, `riemann` usable in expressions.
   - **Presentation**: American or French format of the numbers (options
     `us`/`fr`, `\tkzFnSetup{format=...}`); arrows at one or both ends of the
     axes (`arrows`); "box" axes as with pgfplots (`box`,
     `\tkzFnSetup{axes=box}`).
   - **tkz-elements**: points defined by `tkz-fn` are exported to the table
     `z` (in cm); `tkzfn.point_from_z` brings a point back to the coordinate
     system.
   - **Documentation** in American English (`tkz-fn-en.pdf`) and in French
     (`tkz-fn-fr.pdf`), with the examples of `tkz-fct` rewritten for `tkz-fn`.
