# tkz-fn — 使用 LuaLaTeX 绘制函数图像

_当前版本：**[2026/10/19 version 1.00c]**_


`tkz-fn` 使用 TikZ 绘制函数图像；所有计算均由 Lua 完成。
它是 `tkz-fct` 的继任者：不再需要 gnuplot、`fp.sty`、`tkz-base` 和
`--shell-escape`。

## 功能特性

- 曲线 y = f(x)、参数曲线和极坐标曲线；在函数无定义处以及垂直渐近线处，曲线会中断。
- 切线及单侧切线、曲线下方面积或两条曲线之间的面积、黎曼和（左、右、中点、下确界、上确界）。
- 曲线上的点、坐标、文本、垂直线和水平线、数据。
- 由 Lua 计算并写入文本的结果：函数值、导数、积分、黎曼和。
- 两种坐标空间：计算在坐标系的单位（`xstep`、`ystep`）中进行，绘制以厘米为单位进行。
- 数字可采用美式（`3.14`、`(a, b)`）或法式（`3,14`、`]a ; b[`）格式书写。
- 坐标轴可如学校教科书那样（一端或两端带箭头），也可如 pgfplots 那样使用“盒式”坐标轴，通过选项选择（无需环境）。
- 可选连接到 `tkz-elements`：由 `tkz-fn` 定义的点可在表 `z` 中使用。

## 要求

- LuaLaTeX
- TikZ（由宏包加载，含 `plotmarks` 库）

`tkz-fn` 不需要 `tkz-base` 或 `tkz-euclide`。其所有宏均以
`\tkzFn` 开头，因此可与 `tkz-fct` 一起使用。

## 安装

该宏包由两个文件组成：`tkz-fn.sty` 和 `tkz_fn.lua`。
将它们放入 TeX 可识别的文件夹，例如 `texmf/tex/latex/tkz-fn`，
或放入文档所在文件夹。

## 快速开始

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

表达式为 Lua 表达式：`x^2`、`sin(x)`、`ln(x)`、`exp(x)`、
`sqrt(x)`、`pi`、`e`。

## 文档


- `doc/tkz-fn-en.pdf`：美式英语文档
- `doc/tkz-fn-fr.pdf`：法语文档
- `doc/tkz-fn-cn.pdf`：中文文档

源文件位于 `doc/latex-en` 和 `doc/latex-fr`和`doc/latex-cn`（文档类为 `tkz-doc`，LuaLaTeX，
makeindex）。

- `doc/tkz-fn-en.pdf`: documentation in American English
- `doc/tkz-fn-fr.pdf`: documentation in French
- `doc/tkz-fn-cn.pdf`: documentation in Chinese
 
The sources are in `doc/latex-en` and `doc/latex-fr` and `doc/latex-cn` (class `tkz-doc`, LuaLaTeX,
makeindex).


## 许可证

本作品可在 LaTeX Project Public License 的条款下分发和/或修改，
版本 1.3c 或（按您的选择）任何更高版本。参见 `LICENSE` 和 `lppl-1-3c.txt`。

本作品的 LPPL 维护状态为“maintained”。
本作品的当前维护者为 Alain Matthes。

# tkz-fn-cn
tkz-fn-cn 中文文档

