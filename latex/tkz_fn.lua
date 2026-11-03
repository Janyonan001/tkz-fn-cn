-- File: tkz_fn.lua
-- Copyright (c) 2026 Alain Matthes
-- SPDX-License-Identifier: LPPL-1.3c
-- Maintainer: Alain Matthes
--
-- tkz-fn : graphs of functions with LuaLaTeX.
--
-- Two coordinate spaces:
--   * frame (user units: xstep, ystep) -> every computation
--   * page  (cm, TikZ and tkz-elements) -> drawing only
-- X = (x - xorigin) / xstep,  Y = (y - yorigin) / ystep

tkzfn = tkzfn or {}
local M = tkzfn
M.version = "1.00c"   -- 2026/10/19

-- user functions, accessible from Lua: FN.f(2)
FN = FN or {}

local floor, ceil, abs, max, min = math.floor, math.ceil, math.abs, math.max, math.min
local huge, pi = math.huge, math.pi

-- ====================================================================
-- output
-- ====================================================================
-- tex.print with the LaTeX catcode table: independent of babel
local cct
local function catcodetable()
  if cct == nil then
    cct = false
    if luatexbase and luatexbase.registernumber then
      local n = luatexbase.registernumber("catcodetable@latex")
      if n then cct = n end
    end
  end
  return cct
end

local function out(s)
  local c = catcodetable()
  if c then tex.print(c, s) else tex.print(s) end
end

local function sout(s)
  local c = catcodetable()
  if c then tex.sprint(c, s) else tex.sprint(s) end
end
M.out, M.sout = out, sout

local function err(msg, level)
  error("tkz-fn: " .. msg, level or 2)
end

local function warn(msg)
  texio.write_nl("term and log", "Package tkz-fn Warning: " .. msg)
end

local function is_finite(v)
  return type(v) == "number" and v == v and v ~= huge and v ~= -huge
end
M.is_finite = is_finite

local function empty(s)
  return s == nil or tostring(s):match("^%s*$") ~= nil
end

local function trim(s)
  return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function bool(s, default)
  if empty(s) then return default end
  s = trim(s):lower()
  return not (s == "false" or s == "no" or s == "0")
end

-- ====================================================================
-- environment of the expressions
-- ====================================================================
local env = {}
for k, v in pairs(math) do env[k] = v end
env.e     = math.exp(1)
env.ln    = math.log
env.log   = math.log              -- natural logarithm (Lua convention)
env.log10 = function(x) return math.log(x, 10) end
env.sinh  = function(x) return (math.exp(x) - math.exp(-x)) / 2 end
env.cosh  = function(x) return (math.exp(x) + math.exp(-x)) / 2 end
env.tanh  = function(x) local a, b = math.exp(x), math.exp(-x) return (a - b) / (a + b) end
env.sign  = function(x) if x > 0 then return 1 elseif x < 0 then return -1 else return 0 end end
env.cbrt  = function(x) if x >= 0 then return x ^ (1 / 3) else return -((-x) ^ (1 / 3)) end end
env.root  = function(x, n)          -- n-th root, odd n accepts x < 0
  if x < 0 and n % 2 == 1 then return -((-x) ^ (1 / n)) end
  return x ^ (1 / n)
end
env.mod   = function(a, b) return a % b end
env.frac  = function(x) return x - floor(x) end
env.round = function(x, n)
  local p = 10 ^ (n or 0)
  return floor(x * p + 0.5) / p
end
env.diff      = function(f, x) return M.derivative(f, x) end
env.integral  = function(f, a, b, n) return M.integral(f, a, b, n) end
env.riemann   = function(f, a, b, n, m) return M.riemann_sum(f, a, b, n, m) end
-- user functions (FN) and Lua globals (parameters) are visible
setmetatable(env, {
  __index = function(_, k)
    local f = FN[k]
    if f ~= nil then return f end
    return _G[k]
  end
})
M.env = env

local function compile(code, what)
  local loader, msg = load(code, "tkz-fn", "t", env)
  if not loader then
    err("invalid " .. what .. ": " .. tostring(msg), 4)
  end
  local ok, res = pcall(loader)
  if not ok then
    err("invalid " .. what .. ": " .. tostring(res), 4)
  end
  return res
end

-- numeric expression ("2*pi", "-3", "a+1")
function M.num(s, default)
  if s == nil then return default end
  if type(s) == "number" then return s end
  s = trim(s)
  if s == "" then return default end
  local v = compile("return (" .. s .. ")", "expression '" .. s .. "'")
  v = tonumber(v)
  if v == nil then err("'" .. s .. "' is not a number", 3) end
  return v
end

-- list "a,b,c" or "a,b,...,c" (as with \foreach)
function M.list(s)
  local items = {}
  for item in tostring(s):gmatch("[^,]+") do
    item = trim(item)
    if item ~= "" then items[#items + 1] = item end
  end
  local res = {}
  local i = 1
  while i <= #items do
    if items[i] == "..." then
      local last = M.num(items[i + 1])
      local n = #res
      local step = (n >= 2) and (res[n] - res[n - 1]) or 1
      if step == 0 then err("list: step is zero", 2) end
      local v = res[n]
      local k = 1
      while true do
        local w = v + k * step
        if (step > 0 and w > last + 1e-9 * abs(step)) or (step < 0 and w < last - 1e-9 * abs(step)) then
          break
        end
        res[#res + 1] = w
        k = k + 1
      end
      if abs(res[#res] - last) > 1e-9 * abs(step) then res[#res + 1] = last end
      i = i + 2
    else
      res[#res + 1] = M.num(items[i])
      i = i + 1
    end
  end
  return res
end

-- ====================================================================
-- class fn : a function of one variable (frame units)
-- ====================================================================
local fn = {}
fn.__index = fn
fn.__call = function(self, x) return self:eval(x) end
M.fn = fn

function M.newfn(expr_or_function, var)
  local o = setmetatable({}, fn)
  if type(expr_or_function) == "function" then
    o.f = expr_or_function
  elseif type(expr_or_function) == "table" and getmetatable(expr_or_function) == fn then
    return expr_or_function
  else
    o.expr = trim(tostring(expr_or_function))
    o.f = compile("return function(" .. (var or "x") .. ") return (" .. o.expr .. ") end",
                  "expression '" .. o.expr .. "'")
  end
  return o
end
M.fct = M.newfn

-- nan if f is not defined at x
function fn:eval(x)
  local ok, y = pcall(self.f, x)
  if not ok then return 0 / 0 end
  return tonumber(y) or 0 / 0
end

function M.get(name)
  local f = FN[name]
  if f == nil then err("unknown function '" .. tostring(name) .. "'", 3) end
  if type(f) == "function" then f = M.newfn(f); FN[name] = f end
  return f
end

-- a name of FN, else an expression in x ("0", "12", "x/2")
function M.resolve(s)
  if type(s) == "table" then return s end
  s = trim(s)
  local f = FN[s]
  if f ~= nil then
    if type(f) == "function" then f = M.newfn(f); FN[s] = f end
    return f
  end
  return M.newfn(s)
end

local function check_name(name)
  if not name:match("^[%a_][%w_]*$") then
    err("invalid function name '" .. name .. "'", 3)
  end
end

-- \tkzFnDef{name}{expression}
function M.def(name, expr)
  name = trim(name)
  check_name(name)
  FN[name] = M.newfn(expr)
  M.last = FN[name]
end

-- derivatives: mean, left, right, value
function M.derivatives(f, x)
  f = M.resolve(f)
  local h = 1e-5 * (1 + abs(x))
  local y0 = f:eval(x)
  local yl, yr = f:eval(x - h), f:eval(x + h)
  local ml, mr = (y0 - yl) / h, (yr - y0) / h
  local m = (yr - yl) / (2 * h)
  if not is_finite(m) then
    if is_finite(mr) then m = mr elseif is_finite(ml) then m = ml end
  end
  return m, ml, mr, y0
end

function M.derivative(f, x)
  local m = M.derivatives(f, x)
  return m
end

-- Simpson's rule
function M.integral(f, a, b, n)
  f = M.resolve(f)
  n = n or 1000
  if n % 2 == 1 then n = n + 1 end
  local h = (b - a) / n
  local s = f:eval(a) + f:eval(b)
  for i = 1, n - 1 do
    s = s + ((i % 2 == 1) and 4 or 2) * f:eval(a + i * h)
  end
  return s * h / 3
end

-- ====================================================================
-- the frame
-- ====================================================================
M.R = { xmin = -5, xmax = 5, xstep = 1, ymin = -5, ymax = 5, ystep = 1,
        xorigin = 0, yorigin = 0 }

function M.init(t)
  local R = {}
  R.xmin    = M.num(t.xmin, -5)
  R.xmax    = M.num(t.xmax, 5)
  R.xstep   = M.num(t.xstep, 1)
  R.ymin    = M.num(t.ymin, -5)
  R.ymax    = M.num(t.ymax, 5)
  R.ystep   = M.num(t.ystep, 1)
  R.xorigin = M.num(t.xorigin, 0)
  R.yorigin = M.num(t.yorigin, 0)
  if R.xmin >= R.xmax then err("xmin must be less than xmax", 2) end
  if R.ymin >= R.ymax then err("ymin must be less than ymax", 2) end
  if R.xstep <= 0 or R.ystep <= 0 then err("xstep and ystep must be positive", 2) end
  -- data limits (default domain) and window (enlarged with enlarge = k)
  R.dxmin, R.dxmax = R.xmin, R.xmax
  local ex = M.num(t.enlargex, M.num(t.enlarge, 0))
  local ey = M.num(t.enlargey, M.num(t.enlarge, 0))
  local wx, wy = R.xmax - R.xmin, R.ymax - R.ymin
  R.xmin, R.xmax = R.xmin - ex * wx, R.xmax + ex * wx
  R.ymin, R.ymax = R.ymin - ey * wy, R.ymax + ey * wy
  M.R = R
end

function M.X(x) return (x - M.R.xorigin) / M.R.xstep end
function M.Y(y) return (y - M.R.yorigin) / M.R.ystep end
function M.to_page(x, y) return M.X(x), M.Y(y) end
function M.to_user(X, Y)
  return X * M.R.xstep + M.R.xorigin, Y * M.R.ystep + M.R.yorigin
end

-- number written in a TikZ coordinate
local function cnum(v)
  local s = string.format("%.5f", v):gsub("0+$", ""):gsub("%.$", "")
  if s == "-0" then s = "0" end
  return s
end
M.cnum = cnum

local function pt(x, y)
  return "(" .. cnum(M.X(x)) .. "," .. cnum(M.Y(y)) .. ")"
end
M.pt = pt

local function opt(...)
  local t = {}
  for _, s in ipairs({ ... }) do
    if not empty(s) then t[#t + 1] = s end
  end
  if #t == 0 then return "" end
  return "[" .. table.concat(t, ",") .. "]"
end

-- the y value used for the band: no huge numbers for TeX
local function band()
  local R = M.R
  local H = R.ymax - R.ymin
  return R.ymin - H, R.ymax + H
end

local function clamp_y(y)
  local lo, hi = band()
  if y < lo then return lo elseif y > hi then return hi end
  return y
end

-- margin in pt (marks are not cut at the border of the window)
local function window_clip(margin)
  local R = M.R
  local m = (margin or 0) / 28.45274
  return "\\clip (" .. cnum(M.X(R.xmin) - m) .. "," .. cnum(M.Y(R.ymin) - m) .. ") rectangle ("
         .. cnum(M.X(R.xmax) + m) .. "," .. cnum(M.Y(R.ymax) + m) .. ");"
end

-- emits a command inside a scope clipped to the window if clip is true
local function emit(cmd, clip, margin)
  if clip then
    out("\\begin{scope}" .. window_clip(margin))
    out(cmd)
    out("\\end{scope}")
  else
    out(cmd)
  end
end

local function domain(s, a0, b0)
  if empty(s) then return a0, b0 end
  local a, b = tostring(s):match("^(.-):(.*)$")
  if not a then err("domain must be written a:b, got '" .. tostring(s) .. "'", 3) end
  return M.num(a), M.num(b)
end

-- ====================================================================
-- formatting of the results : fr / us
-- ====================================================================
M.format   = "us"
M.decimals = 2
M.format_explicit = false

function M.set_format(f)
  f = trim(f):lower()
  if f == "fr" or f == "french" or f == "francais" then
    M.format = "fr"
  elseif f == "us" or f == "en" or f == "american" or f == "english" then
    M.format = "us"
  else
    err("unknown format '" .. f .. "' (fr or us expected)", 2)
  end
  M.format_explicit = true
end

-- called at \begin{document}
function M.auto_format(lang)
  if M.format_explicit then return end
  lang = tostring(lang or ""):lower()
  if lang:match("french") or lang:match("francais") or lang:match("acadian") then
    M.format = "fr"
  end
end

function M.set_decimals(n)
  n = M.num(n, 2)
  if n < 0 or n ~= floor(n) then err("decimals must be a non-negative integer", 2) end
  M.decimals = n
end

local function group(int, sep, minlen)
  if #int < minlen then return int end
  local r = int:reverse():gsub("(%d%d%d)", "%1\0"):reverse()
  r = r:gsub("^%z", "")
  return (r:gsub("%z", sep))
end

-- number -> math-mode string (without $)
function M.format_number(x, dec)
  dec = dec or M.decimals
  if not is_finite(x) then return "\\text{--}" end
  local s = string.format("%." .. dec .. "f", x)
  local sign, int, frac = s:match("^(%-?)(%d+)%.?(%d*)$")
  frac = frac:gsub("0+$", "")
  if int:match("^0*$") and frac == "" then sign = "" end
  if M.format == "fr" then
    int = group(int, "\\,", 5)
    return sign .. int .. (frac ~= "" and ("{,}" .. frac) or "")
  else
    int = group(int, "{,}", 5)
    return sign .. int .. (frac ~= "" and ("." .. frac) or "")
  end
end

local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return abs(a)
end

-- k*pi/n as a fraction of pi
function M.format_pi(k, n)
  if k == 0 then return "0" end
  local g = gcd(k, n)
  k, n = k // g, n // g
  local sign = k < 0 and "-" or ""
  k = abs(k)
  local num = (k == 1) and "\\pi" or (k .. "\\pi")
  if n == 1 then return sign .. num end
  return sign .. "\\frac{" .. num .. "}{" .. n .. "}"
end

local function sep_list()
  if M.format == "fr" then return "\\,;\\," else return ",\\," end
end

function M.format_pair(x, y, dec)
  return "\\left(" .. M.format_number(x, dec) .. sep_list() .. M.format_number(y, dec) .. "\\right)"
end

-- kind: cc, oo, co, oc (c = closed, o = open)
function M.format_interval(a, b, kind, dec)
  kind = empty(kind) and "cc" or trim(kind)
  local l, r = kind:sub(1, 1), kind:sub(2, 2)
  local A = type(a) == "number" and M.format_number(a, dec) or a
  local B = type(b) == "number" and M.format_number(b, dec) or b
  local L, Rb
  if M.format == "fr" then
    L  = (l == "o") and "\\mathopen{]}" or "\\mathopen{[}"
    Rb = (r == "o") and "\\mathclose{[}" or "\\mathclose{]}"
  else
    L  = (l == "o") and "\\mathopen{(}" or "\\mathopen{[}"
    Rb = (r == "o") and "\\mathclose{)}" or "\\mathclose{]}"
  end
  return L .. A .. sep_list() .. B .. Rb
end

-- an interval bound may be a number expression or TeX (\infty)
local function bound(s)
  local t = trim(s)
  if t:match("\\") then return t end
  local ok, v = pcall(M.num, t)
  if ok and v then
    if v == huge then return "+\\infty" end
    if v == -huge then return "-\\infty" end
    return v
  end
  return t
end

function M.print_number(expr, dec)
  sout("\\ensuremath{" .. M.format_number(M.num(expr), M.num(dec)) .. "}")
end

function M.print_interval(a, b, kind, dec)
  sout("\\ensuremath{" .. M.format_interval(bound(a), bound(b), kind, M.num(dec)) .. "}")
end

-- ====================================================================
-- points
-- ====================================================================
M.points = {}   -- frame coordinates of the points

-- bridge to tkz-elements: z.name = point(X, Y) (page space, cm)
local function export_z(name, X, Y)
  local Z, P = rawget(_G, "z"), rawget(_G, "point")
  if type(Z) == "table" and P ~= nil then
    local ok, p = pcall(P, X, Y)
    if ok and p then Z[name] = p end
  end
end

function M.set_point(name, x, y)
  name = trim(name)
  if not (is_finite(x) and is_finite(y)) then
    err("point '" .. name .. "' is not defined", 3)
  end
  M.points[name] = { x = x, y = y }
  local X, Y = M.to_page(x, y)
  export_z(name, X, Y)
  out("\\coordinate (" .. name .. ") at (" .. cnum(X) .. "," .. cnum(Y) .. ");")
end

-- point of tkz-elements -> frame coordinates
function M.from_z(name)
  local Z = rawget(_G, "z")
  if type(Z) ~= "table" or Z[name] == nil then
    err("z." .. tostring(name) .. " does not exist", 2)
  end
  return M.to_user(Z[name].re, Z[name].im)
end

-- stores the frame coordinates of z.name (no output)
function M.point_from_z(name)
  local x, y = M.from_z(name)
  M.points[name] = { x = x, y = y }
  return x, y
end

-- \tkzFnDefPoint(f,x){M}
function M.def_point(t)
  local f = M.resolve(t.f)
  local x = M.num(t.x)
  local y = f:eval(x)
  if not is_finite(y) then
    err(trim(t.f) .. " is not defined at x = " .. tostring(x), 2)
  end
  M.set_point(t.name, x, y)
  if bool(t.draw, false) then M.draw_points{ list = t.name, opts = t.opts, size = t.size } end
end

-- \tkzFnDefPointXY(x,y){M}
function M.def_point_xy(t)
  M.set_point(t.name, M.num(t.x), M.num(t.y))
  if bool(t.draw, false) then M.draw_points{ list = t.name, opts = t.opts, size = t.size } end
end

function M.print_coord(name, dec)
  name = trim(name)
  local p = M.points[name]
  if not p then err("unknown point '" .. name .. "'", 2) end
  sout("\\ensuremath{" .. M.format_pair(p.x, p.y, M.num(dec)) .. "}")
end

-- \tkzFnDrawPoints[size,opts](A,B,...)
function M.draw_points(t)
  local size = empty(t.size) and "1.5pt" or trim(t.size)
  for name in tostring(t.list):gmatch("[^,%s]+") do
    out("\\path" .. opt("tkzfn point", t.opts) .. " (" .. name .. ") circle [radius=" .. size .. "];")
  end
end

-- \tkzFnMarkPoints[size,opts](f){list} : points of the curve, no name
function M.mark_points(t)
  local f = M.resolve(t.f)
  local size = empty(t.size) and "1.5pt" or trim(t.size)
  local s = {}
  for _, x in ipairs(M.list(t.list)) do
    local y = f:eval(x)
    if is_finite(y) then
      s[#s + 1] = pt(x, y) .. " circle [radius=" .. size .. "]"
    end
  end
  if #s > 0 then out("\\path" .. opt("tkzfn point", t.opts) .. " " .. table.concat(s, " ") .. ";") end
end

-- \tkzFnShowCoord[xlabel,ylabel,opts](M)
function M.show_coord(t)
  local name = trim(t.name)
  local p = M.points[name]
  if not p then err("unknown point '" .. name .. "'", 2) end
  local x0, y0 = M.crossing()
  local s = "\\draw" .. opt("tkzfn show coord", t.opts) .. " (" .. name .. ") -- " .. pt(p.x, y0)
      .. " (" .. name .. ") -- " .. pt(x0, p.y) .. ";"
  out(s)
  local dec = M.num(t.decimals, M.decimals)
  local function label(v, default)
    if empty(v) then return default end
    if trim(v) == "false" then return nil end
    return v
  end
  local xl = label(t.xlabel, "$" .. M.format_number(p.x, dec) .. "$")
  local yl = label(t.ylabel, "$" .. M.format_number(p.y, dec) .. "$")
  if xl then out("\\node[below,tkzfn tick label] at " .. pt(p.x, y0) .. " {" .. xl .. "};") end
  if yl then out("\\node[left,tkzfn tick label] at " .. pt(x0, p.y) .. " {" .. yl .. "};") end
end

-- position of a text: (x,y) in frame units or (A)
function M.position(s)
  s = trim(s)
  local a, b = s:match("^(.-),(.*)$")
  local res
  if a then
    res = pt(M.num(a), M.num(b))
  else
    res = "(" .. s .. ")"
  end
  token.set_macro("tkzfnpos", res, "global")
end

-- ====================================================================
-- sampling of a curve
-- The curve is cut where f is not defined, where it jumps from one side
-- of the window to the other (asymptote), and segments are clipped to a
-- band of height 3*(ymax-ymin) so that TikZ never sees huge numbers.
-- ====================================================================
function M.pieces(f, a, b, n)
  local R = M.R
  local lo, hi = band()
  local pieces, cur = {}, nil
  local function flush()
    if cur and #cur >= 2 then pieces[#pieces + 1] = cur end
    cur = nil
  end
  local function add(x, y)
    if not cur then cur = {} end
    cur[#cur + 1] = { x, y }
  end
  local prev
  for i = 0, n do
    local x = (i == n) and b or (a + (b - a) * i / n)
    local y = f:eval(x)
    if not is_finite(y) then
      flush()
      prev = nil
    else
      if prev then
        local x0, y0 = prev[1], prev[2]
        if (y0 > R.ymax and y < R.ymin) or (y0 < R.ymin and y > R.ymax) then
          flush()
        else
          local t0, t1 = 0, 1
          local dy = y - y0
          if dy == 0 then
            if y0 < lo or y0 > hi then t0, t1 = 1, 0 end
          else
            local ta, tb = (lo - y0) / dy, (hi - y0) / dy
            if ta > tb then ta, tb = tb, ta end
            if ta > t0 then t0 = ta end
            if tb < t1 then t1 = tb end
          end
          if t0 > t1 then
            flush()
          else
            local dx = x - x0
            if t0 > 0 or not cur then
              flush()
              add(x0 + t0 * dx, y0 + t0 * dy)
            end
            add(x0 + t1 * dx, y0 + t1 * dy)
            if t1 < 1 then flush() end
          end
        end
      end
      prev = { x, y }
    end
  end
  flush()
  return pieces
end

-- with plot = true each piece is written "plot coordinates {...}" so
-- that the TikZ options mark=..., only marks, smooth can be used
local function pieces_to_path(pieces, plot)
  local t = {}
  for _, p in ipairs(pieces) do
    local s = {}
    for i, q in ipairs(p) do s[i] = pt(q[1], q[2]) end
    if plot then
      t[#t + 1] = "plot coordinates {" .. table.concat(s, " ") .. "}"
    else
      t[#t + 1] = table.concat(s, "--")
    end
  end
  return table.concat(t, " ")
end

local function wants_plot(opts)
  opts = tostring(opts or "")
  return opts:match("mark") ~= nil or opts:match("smooth") ~= nil
end

-- samples = number of points (as with TikZ) -> number of intervals
function M.intervals(s)
  local n = floor(M.num(s, 200)) - 1
  if n < 1 then n = 1 end
  return n
end

-- \tkzFnDraw
function M.draw_curve(t)
  local f
  if t.kind == "name" then
    f = M.resolve(t.f)
  else
    f = M.newfn(t.f)
    if not empty(t.name) then
      local name = trim(t.name)
      check_name(name)
      FN[name] = f
    end
  end
  M.last = f
  local a, b = domain(t.domain, M.R.dxmin, M.R.dxmax)
  local n = M.intervals(t.samples)
  local path = pieces_to_path(M.pieces(f, a, b, n), wants_plot(t.opts))
  if path == "" then
    warn("nothing to draw for '" .. tostring(t.f) .. "'")
    return
  end
  local margin = tostring(t.opts or ""):match("mark") and 5 or 0
  emit("\\draw" .. opt("tkzfn curve", t.opts) .. " " .. path .. ";", bool(t.clip, true), margin)
end

-- \tkzFnParam : x(t), y(t)
local function draw_param(fx, fy, a, b, n, opts, clip)
  local pieces, cur = {}, nil
  for i = 0, n do
    local s = (i == n) and b or (a + (b - a) * i / n)
    local x, y = fx:eval(s), fy:eval(s)
    if is_finite(x) and is_finite(y) then
      cur = cur or {}
      cur[#cur + 1] = { x, clamp_y(y) }
    else
      if cur and #cur >= 2 then pieces[#pieces + 1] = cur end
      cur = nil
    end
  end
  if cur and #cur >= 2 then pieces[#pieces + 1] = cur end
  local path = pieces_to_path(pieces, wants_plot(opts))
  if path == "" then warn("nothing to draw") return end
  emit("\\draw" .. opt("tkzfn curve", opts) .. " " .. path .. ";", clip)
end

function M.param(t)
  local fx = M.newfn(t.x, "t")
  local fy = M.newfn(t.y, "t")
  local a, b = domain(t.domain, 0, 2 * pi)
  draw_param(fx, fy, a, b, M.intervals(t.samples), t.opts, bool(t.clip, false))
end

function M.polar(t)
  local rho = M.newfn(t.rho, "t")
  local fx = M.newfn(function(s) return rho:eval(s) * math.cos(s) end)
  local fy = M.newfn(function(s) return rho:eval(s) * math.sin(s) end)
  local a, b = domain(t.domain, 0, 2 * pi)
  draw_param(fx, fy, a, b, M.intervals(t.samples), t.opts, bool(t.clip, false))
end

-- ====================================================================
-- tangent : \tkzFnTangent[kl,kr,draw](f,x)
-- ====================================================================
function M.tangent(t)
  local f = M.resolve(t.f)
  local x0 = M.num(t.x)
  local kl, kr = M.num(t.kl, 1), M.num(t.kr, 1)
  local m, ml, mr, y0 = M.derivatives(f, x0)
  if not is_finite(y0) then
    err("no tangent: f is not defined at x = " .. tostring(x0), 2)
  end
  if is_finite(ml) and is_finite(mr) and abs(ml - mr) <= 1e-3 * (1 + abs(m)) then
    ml, mr = m, m
  end
  M.last_slope = { m = m, ml = ml, mr = mr }
  local P = pt(x0, y0)
  local o = opt("tkzfn tangent", t.opts)
  local cmd = {}
  if kl ~= 0 then
    if not is_finite(ml) then err("no left half-tangent at x = " .. tostring(x0), 2) end
    cmd[#cmd + 1] = "\\draw" .. o .. " " .. P .. "--" .. pt(x0 - kl, y0 - ml * kl) .. ";"
  end
  if kr ~= 0 then
    if not is_finite(mr) then err("no right half-tangent at x = " .. tostring(x0), 2) end
    cmd[#cmd + 1] = "\\draw" .. o .. " " .. P .. "--" .. pt(x0 + kr, y0 + mr * kr) .. ";"
  end
  if #cmd > 0 then emit(table.concat(cmd, " "), bool(t.clip, true)) end
  if bool(t.draw, false) then
    out("\\path[tkzfn point] " .. P .. " circle [radius=1.5pt];")
  end
end

-- ====================================================================
-- areas : \tkzFnArea[domain,where](f) or (f,g)
-- ====================================================================
function M.area(t)
  local f = M.resolve(t.f)
  local g = M.resolve(empty(t.g) and "0" or t.g)
  local a, b = domain(t.domain, M.R.dxmin, M.R.dxmax)
  local n = M.intervals(t.samples)
  local where = empty(t.where) and "both" or trim(t.where)
  local up, down = {}, {}
  for i = 0, n do
    local x = (i == n) and b or (a + (b - a) * i / n)
    local y1, y2 = f:eval(x), g:eval(x)
    if is_finite(y1) and is_finite(y2) then
      if where == "above" then y2 = min(y1, y2)
      elseif where == "below" then y2 = max(y1, y2) end
      up[#up + 1] = pt(x, clamp_y(y1))
      down[#down + 1] = pt(x, clamp_y(y2))
    end
  end
  if #up < 2 then warn("empty area") return end
  local s = {}
  for i = 1, #up do s[#s + 1] = up[i] end
  for i = #down, 1, -1 do s[#s + 1] = down[i] end
  emit("\\path" .. opt("tkzfn area", t.opts) .. " " .. table.concat(s, "--") .. "--cycle;",
       bool(t.clip, true))
end

-- ====================================================================
-- Riemann sums : method = left | right | mid | inf | sup
-- ====================================================================
local function riemann_heights(f, a, b, n, method)
  local h = (b - a) / n
  local res = {}
  for i = 0, n - 1 do
    local x0, x1 = a + i * h, a + (i + 1) * h
    local y0, y1 = f:eval(x0), f:eval(x1)
    local y
    if method == "left" then y = y0
    elseif method == "right" then y = y1
    elseif method == "mid" then y = f:eval((x0 + x1) / 2)
    elseif method == "inf" then y = min(y0, y1)
    elseif method == "sup" then y = max(y0, y1)
    else err("unknown method '" .. method .. "' (left, right, mid, inf, sup)", 4) end
    res[#res + 1] = { x0, x1, y }
  end
  return res
end

function M.riemann_sum(f, a, b, n, method)
  f = M.resolve(f)
  local s = 0
  for _, r in ipairs(riemann_heights(f, a, b, n or 10, method or "left")) do
    s = s + (r[2] - r[1]) * r[3]
  end
  return s
end

function M.riemann(t)
  local f = M.resolve(t.f)
  local a, b = domain(t.interval, M.R.dxmin, M.R.dxmax)
  local n = floor(M.num(t.number, 10))
  local method = empty(t.method) and "left" or trim(t.method)
  local s = {}
  local sum = 0
  for _, r in ipairs(riemann_heights(f, a, b, n, method)) do
    if is_finite(r[3]) then
      s[#s + 1] = pt(r[1], 0) .. " rectangle " .. pt(r[2], clamp_y(r[3]))
      sum = sum + (r[2] - r[1]) * r[3]
    end
  end
  M.last_sum = sum
  if #s > 0 then
    emit("\\path" .. opt("tkzfn riemann", t.opts) .. " " .. table.concat(s, " ") .. ";",
         bool(t.clip, false))
  end
end

-- ====================================================================
-- lines x = a, y = b
-- ====================================================================
function M.vlines(t)
  local R = M.R
  local s = {}
  for _, x in ipairs(M.list(t.list)) do
    s[#s + 1] = pt(x, R.ymin) .. "--" .. pt(x, R.ymax)
  end
  if #s > 0 then out("\\draw" .. opt("tkzfn line", t.opts) .. " " .. table.concat(s, " ") .. ";") end
end

function M.hlines(t)
  local R = M.R
  local s = {}
  for _, y in ipairs(M.list(t.list)) do
    s[#s + 1] = pt(R.xmin, y) .. "--" .. pt(R.xmax, y)
  end
  if #s > 0 then out("\\draw" .. opt("tkzfn line", t.opts) .. " " .. table.concat(s, " ") .. ";") end
end

-- \tkzFnDrawData[opts]{x1/y1,x2/y2,...}
function M.data(t)
  local s = {}
  for item in tostring(t.list):gmatch("[^,]+") do
    local a, b = item:match("^%s*(.-)%s*/%s*(.-)%s*$")
    if a then s[#s + 1] = pt(M.num(a), M.num(b)) end
  end
  if #s > 0 then
    out("\\draw" .. opt("only marks", "mark=*", t.opts) .. " plot coordinates {" .. table.concat(s, " ") .. "};")
  end
end

-- ====================================================================
-- grid, axes, clip, frame vectors
-- ====================================================================
local function ticks(lo, hi, d)
  local list = {}
  local k0, k1 = ceil(lo / d - 1e-9), floor(hi / d + 1e-9)
  for k = k0, k1 do list[#list + 1] = { k * d, k } end
  return list
end

local function region(t)
  local R = M.R
  if empty(t.region) then return R.xmin, R.ymin, R.xmax, R.ymax end
  local v = {}
  for item in tostring(t.region):gmatch("[^,]+") do v[#v + 1] = M.num(item) end
  if #v ~= 4 then err("grid: (x1,y1)(x2,y2) expected", 3) end
  return v[1], v[2], v[3], v[4]
end

local function grid_lines(x1, y1, x2, y2, dx, dy)
  local s = {}
  for _, x in ipairs(ticks(x1, x2, dx)) do s[#s + 1] = pt(x[1], y1) .. "--" .. pt(x[1], y2) end
  for _, y in ipairs(ticks(y1, y2, dy)) do s[#s + 1] = pt(x1, y[1]) .. "--" .. pt(x2, y[1]) end
  return table.concat(s, " ")
end

function M.grid(t)
  local R = M.R
  local x1, y1, x2, y2 = region(t)
  local dx, dy = M.num(t.dx, R.xstep), M.num(t.dy, R.ystep)
  if bool(t.sub, false) then
    local sdx = M.num(t.subdx, dx / 5)
    local sdy = M.num(t.subdy, dy / 5)
    out("\\draw" .. opt("tkzfn grid", t.opts, "tkzfn subgrid") .. " " .. grid_lines(x1, y1, x2, y2, sdx, sdy) .. ";")
  end
  out("\\draw" .. opt("tkzfn grid", t.opts) .. " " .. grid_lines(x1, y1, x2, y2, dx, dy) .. ";")
end

function M.clip(t)
  local R = M.R
  local m = M.num(t.margin, 0) / 28.45274   -- pt -> cm
  out("\\clip (" .. cnum(M.X(R.xmin) - m) .. "," .. cnum(M.Y(R.ymin) - m) .. ") rectangle ("
      .. cnum(M.X(R.xmax) + m) .. "," .. cnum(M.Y(R.ymax) + m) .. ");")
end

-- where the axes cross
function M.crossing()
  local R = M.R
  local x0 = (R.xmin <= 0 and R.xmax >= 0) and 0 or R.xmin
  local y0 = (R.ymin <= 0 and R.ymax >= 0) and 0 or R.ymin
  return x0, y0
end

-- one axis: which = "x" or "y"
function M.axis(which, t)
  local R = M.R
  local x0, y0 = M.crossing()
  local both = (x0 == 0 and y0 == 0)
  local lab = bool(t.labels, true)
  local tick = bool(t.ticks, true)
  local line = bool(t.line, true)
  local dec = M.num(t.decimals, 4)
  local trig = M.num(t.trig, 0)
  -- arrows: end (school), both (American), none
  local arrows = empty(t.arrows) and M.arrows or trim(t.arrows)
  local tip = ({ ["end"] = "", both = "<->", none = "-" })[arrows] or ""
  if arrows ~= "end" and arrows ~= "both" and arrows ~= "none" then
    err("arrows = end, both or none expected, got '" .. arrows .. "'", 2)
  end
  local o = opt("tkzfn axis", tip, t.opts)
  local name = t.label or ""
  if empty(name) then name = (which == "x") and "$x$" or "$y$" end
  if trim(name) == "none" or trim(name) == "false" then name = "" end
  local s = {}
  if which == "x" then
    if line then
      out("\\draw" .. o .. " " .. pt(R.xmin, y0) .. "--" .. pt(R.xmax, y0)
          .. " node" .. opt(empty(t.labelstyle) and "right" or t.labelstyle) .. "{" .. name .. "};")
    end
    if not tick then return end
    local list
    if trig > 0 then
      list = ticks(R.xmin, R.xmax, pi / trig)
    else
      list = ticks(R.xmin, R.xmax, M.num(t.step, R.xstep))
    end
    for _, v in ipairs(list) do
      local x = v[1]
      local zero = abs(x) < 1e-12 and (x0 == 0)
      if x < R.xmax - 1e-9 * R.xstep and not zero then
        local text = (trig > 0) and M.format_pi(v[2], trig) or M.format_number(x, dec)
        local node = lab and (" node[below,tkzfn tick label]{$" .. text .. "$}") or ""
        s[#s + 1] = pt(x, y0) .. " +(0,2pt) -- +(0,-2pt)" .. node
      end
    end
    if both and lab and bool(t.origin, true) then
      local origin = (not empty(t.origin) and t.origin ~= "true") and t.origin
                     or (M.format == "fr" and "$O$" or "$0$")
      s[#s + 1] = pt(0, 0) .. " node[below left,tkzfn tick label]{" .. origin .. "}"
    end
  else
    if line then
      out("\\draw" .. o .. " " .. pt(x0, R.ymin) .. "--" .. pt(x0, R.ymax)
          .. " node" .. opt(empty(t.labelstyle) and "above" or t.labelstyle) .. "{" .. name .. "};")
    end
    if not tick then return end
    for _, v in ipairs(ticks(R.ymin, R.ymax, M.num(t.step, R.ystep))) do
      local y = v[1]
      local zero = abs(y) < 1e-12 and (y0 == 0)
      if y < R.ymax - 1e-9 * R.ystep and not zero then
        local node = lab and (" node[left,tkzfn tick label]{$" .. M.format_number(y, dec) .. "$}") or ""
        s[#s + 1] = pt(x0, y) .. " +(2pt,0) -- +(-2pt,0)" .. node
      end
    end
  end
  if #s > 0 then
    out("\\draw[tkzfn ticks] " .. table.concat(s, " ") .. ";")
  end
end

M.axes_style = "school"
M.arrows = "end"

function M.set_arrows(s)
  s = trim(s)
  if s ~= "end" and s ~= "both" and s ~= "none" then
    err("arrows = end, both or none expected, got '" .. s .. "'", 2)
  end
  M.arrows = s
end

function M.set_axes_style(s)
  s = trim(s)
  if s ~= "box" and s ~= "school" then err("axes = box or school expected, got '" .. s .. "'", 2) end
  M.axes_style = s
end

-- presentation "box" (as pgfplots): frame, inner ticks on the four sides,
-- every value written outside the frame, names below and on the left
function M.box(t)
  local R = M.R
  local dx = M.num(t.dx, R.xstep)
  local dy = M.num(t.dy, R.ystep)
  local dec = M.num(t.decimals, 4)
  local trig = M.num(t.trig, 0)
  local lab = bool(t.labels, true)
  local tick = bool(t.ticks, true)
  local len = empty(t.ticklength) and "3pt" or trim(t.ticklength)
  out("\\draw" .. opt("tkzfn box", t.opts) .. " " .. pt(R.xmin, R.ymin) .. " rectangle " .. pt(R.xmax, R.ymax) .. ";")
  local s, nodes = {}, {}
  local xl = (trig > 0) and ticks(R.xmin, R.xmax, pi / trig) or ticks(R.xmin, R.xmax, dx)
  for _, v in ipairs(xl) do
    local x = v[1]
    if tick then
      s[#s + 1] = pt(x, R.ymin) .. " -- +(0," .. len .. ") " .. pt(x, R.ymax) .. " -- +(0,-" .. len .. ")"
    end
    if lab then
      local text = (trig > 0) and M.format_pi(v[2], trig) or M.format_number(x, dec)
      nodes[#nodes + 1] = "\\node[below,tkzfn tick label] at " .. pt(x, R.ymin) .. " {$" .. text .. "$};"
    end
  end
  local width = 0
  for _, v in ipairs(ticks(R.ymin, R.ymax, dy)) do
    local y = v[1]
    if tick then
      s[#s + 1] = pt(R.xmin, y) .. " -- +(" .. len .. ",0) " .. pt(R.xmax, y) .. " -- +(-" .. len .. ",0)"
    end
    if lab then
      local text = M.format_number(y, dec)
      local w = #(text:gsub("\\,", " "):gsub("[{}]", ""))
      if w > width then width = w end
      nodes[#nodes + 1] = "\\node[left,tkzfn tick label] at " .. pt(R.xmin, y) .. " {$" .. text .. "$};"
    end
  end
  if #s > 0 then out("\\draw[tkzfn ticks] " .. table.concat(s, " ") .. ";") end
  for _, n in ipairs(nodes) do out(n) end
  -- names of the axes: only if given
  if not empty(t.xlabel) and trim(t.xlabel) ~= "none" then
    out("\\node[below=" .. (lab and "1.6em" or "0.4em") .. "] at " .. pt((R.xmin + R.xmax) / 2, R.ymin)
        .. " {" .. t.xlabel .. "};")
  end
  if not empty(t.ylabel) and trim(t.ylabel) ~= "none" then
    local shift = lab and (0.55 * width + 0.9) or 0.4
    out("\\node[xshift=-" .. string.format("%.2f", shift) .. "em,rotate=90,anchor=south] at "
        .. pt(R.xmin, (R.ymin + R.ymax) / 2) .. " {" .. t.ylabel .. "};")
  end
end

function M.axes(t)
  local style = empty(t.style) and M.axes_style or trim(t.style)
  if bool(t.box, false) then style = "box" end
  if style == "box" then return M.box(t) end
  local tx = {}
  for k, v in pairs(t) do tx[k] = v end
  tx.label = empty(t.xlabel) and "$x$" or t.xlabel
  tx.trig = t.trig
  tx.step = t.dx
  M.axis("x", tx)
  local ty = {}
  for k, v in pairs(t) do ty[k] = v end
  ty.label = empty(t.ylabel) and "$y$" or t.ylabel
  ty.trig = nil
  ty.step = t.dy
  M.axis("y", ty)
end

-- \tkzFnRep : O, vec i, vec j
function M.rep(t)
  local R = M.R
  local o = opt("tkzfn rep", t.opts)
  out("\\draw" .. o .. " " .. pt(0, 0) .. "--" .. pt(R.xstep, 0)
      .. " node[midway,below]{$\\vec{\\imath}$};")
  out("\\draw" .. o .. " " .. pt(0, 0) .. "--" .. pt(0, R.ystep)
      .. " node[midway,left]{$\\vec{\\jmath}$};")
end

return M
