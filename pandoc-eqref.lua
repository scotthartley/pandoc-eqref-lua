-- Pandoc Lua filter for equation numbering and cross-referencing.
-- Detects display math paragraphs tagged with {#eq:id} and numbers them.
-- Also detects standalone chemical equation lines using pandoc-chem-sub.lua syntax:
--   s:{formula} {#eq:id}
-- and numbers them in the same sequence as display math.
-- NOTE: This filter must run BEFORE pandoc-chem-sub.lua so it can detect the raw
--   s:{...} syntax before chem-sub converts it to Unicode inlines.
-- For LaTeX output, wraps the equation in an equation environment with \label.
-- For HTML output, lays out the equation in a 3-column CSS grid with the number right-aligned.
-- For docx and other formats, appends the equation number inline.
-- Equations are referenced by citing their identifier (e.g. @eq:myeq),
-- which gets replaced with the equation's sequence number.

-- Ordered list of equation identifiers, used to map IDs to sequence numbers.
local ids = {}

-- Find the matching closing brace for the open brace at open_pos in string s.
-- Returns the position of the closing brace, or nil if unmatched.
local function find_closing_brace(s, open_pos)
    local depth = 1
    local i = open_pos + 1
    while i <= #s do
        local c = s:sub(i, i)
        if     c == '{' then depth = depth + 1
        elseif c == '}' then
            depth = depth - 1
            if depth == 0 then return i end
        end
        i = i + 1
    end
    return nil
end

-- Detect a standalone chemical equation of the form:
--   s:{formula} {#id}
-- Returns formula, id_tag if found; nil otherwise.
-- Only matches when the Para consists entirely of Str/Space/SoftBreak tokens,
-- the s:{...} starts at the beginning (no non-whitespace before it),
-- and a {#id} label immediately follows with no other non-whitespace text.
local function detect_chem_equation(inlines)
    -- Only process Paras made entirely of Str/Space/SoftBreak
    for _, el in ipairs(inlines) do
        if el.t ~= "Str" and el.t ~= "Space" and el.t ~= "SoftBreak" then
            return nil
        end
    end
    -- Concatenate to a flat string
    local combined = ""
    for _, el in ipairs(inlines) do
        if     el.t == "Str"                          then combined = combined .. el.text
        elseif el.t == "Space" or el.t == "SoftBreak" then combined = combined .. " "
        end
    end
    -- Find s:{ with brace matching
    local marker_pos = combined:find("s:{")
    if not marker_pos then return nil end
    if combined:sub(1, marker_pos - 1):find("%S") then return nil end  -- text before s:{
    local brace_open  = marker_pos + 2
    local brace_close = find_closing_brace(combined, brace_open)
    if not brace_close then return nil end
    local formula = combined:sub(brace_open + 1, brace_close - 1)
    local rest = combined:sub(brace_close + 1)
    -- Find {#id} and verify nothing else is in rest
    local label_s, label_e, id_tag = rest:find("{#([^}]+)}")
    if not id_tag then return nil end
    if rest:sub(1, label_s - 1):find("%S") then return nil end  -- text before label
    if rest:sub(label_e + 1):find("%S")    then return nil end  -- text after label
    return formula, id_tag
end

-- Process each paragraph looking for display math tagged with {#id},
-- or a standalone chemical equation line (s:{formula} {#id}).
local function process_equations(para)
    -- Phase 1: display math  $$...$$ {#id}
    local math_el = nil
    local id_tag = nil

    for _, el in ipairs(para.content) do
        if el.t == "Math" and el.mathtype == pandoc.DisplayMath then
            math_el = el
        elseif el.t == "Str" and math_el then
            local m = el.text:match("^{#(.+)}$")
            if m then
                id_tag = m
            end
        end
    end

    if math_el and id_tag then
        table.insert(ids, id_tag)
        local label_num = #ids
        local code = math_el.text

        if FORMAT == "latex" then
            local latex = "\n\\begin{equation}\n" .. code .. "\n\\label{" .. id_tag .. "}\n\\end{equation}\n"
            return pandoc.RawBlock('latex', latex)
        elseif FORMAT:match("html") then
            local inline_math = pandoc.Math(pandoc.InlineMath, code)
            local num_str = "(" .. tostring(label_num) .. ")"
            local outer_style = "display:grid;grid-template-columns:1fr auto 1fr;align-items:center;"
            local left_div  = pandoc.Div({})
            local math_div  = pandoc.Div(
                {pandoc.Plain({inline_math})},
                pandoc.Attr('', {}, {{'style', 'text-align:center;'}})
            )
            local right_div = pandoc.Div(
                {pandoc.Plain({pandoc.Str(num_str)})},
                pandoc.Attr('', {}, {{'style', 'text-align:right;'}})
            )
            return pandoc.Div(
                {left_div, math_div, right_div},
                pandoc.Attr('', {}, {{'style', outer_style}})
            )
        elseif FORMAT == "docx" then
            local inline_math = pandoc.Math(pandoc.InlineMath, code)
            local num_str = "\u{00A0}\u{00A0}\u{00A0}\u{00A0}(" .. tostring(label_num) .. ")"
            return pandoc.Para({inline_math, pandoc.Str(num_str)})
        else
            local inline_math = pandoc.Math(pandoc.InlineMath, code)
            local num_str = "\u{00A0}\u{00A0}(" .. tostring(label_num) .. ")"
            return pandoc.Para({inline_math, pandoc.Str(num_str)})
        end
    end

    -- Phase 2: chemical equation  s:{formula} {#id}
    local formula, chem_id = detect_chem_equation(para.content)
    if formula and chem_id then
        table.insert(ids, chem_id)
        local label_num = #ids

        if FORMAT == "latex" then
            local latex = "\n\\begin{equation}\n\\ce{" .. formula
                          .. "}\n\\label{" .. chem_id .. "}\n\\end{equation}\n"
            return pandoc.RawBlock('latex', latex)

        elseif FORMAT:match("html") then
            local chem_str   = "s:{" .. formula .. "}"
            local num_str    = "(" .. tostring(label_num) .. ")"
            local outer_style = "display:grid;grid-template-columns:1fr auto 1fr;align-items:center;"
            local left_div  = pandoc.Div({})
            local chem_div  = pandoc.Div(
                {pandoc.Plain({pandoc.Str(chem_str)})},
                pandoc.Attr('', {}, {{'style', 'text-align:center;'}}))
            local right_div = pandoc.Div(
                {pandoc.Plain({pandoc.Str(num_str)})},
                pandoc.Attr('', {}, {{'style', 'text-align:right;'}}))
            return pandoc.Div({left_div, chem_div, right_div},
                pandoc.Attr('', {}, {{'style', outer_style}}))

        elseif FORMAT == "docx" then
            local chem_str = "s:{" .. formula .. "}"
            local num_str  = "\u{00A0}\u{00A0}\u{00A0}\u{00A0}(" .. tostring(label_num) .. ")"
            return pandoc.Para({pandoc.Str(chem_str), pandoc.Str(num_str)})

        else
            local chem_str = "s:{" .. formula .. "}"
            local num_str  = "\u{00A0}\u{00A0}(" .. tostring(label_num) .. ")"
            return pandoc.Para({pandoc.Str(chem_str), pandoc.Str(num_str)})
        end
    end
end

-- Replace citation references (e.g. @eq:myeq) with the equation's
-- sequence number. Unmatched citations are left unchanged.
local function process_references(cite)

    -- Look up an identifier in the ids list and return its index.
    local function get_ids_index(value)
        for k, v in pairs(ids) do
            if v == value then
                return k
            end
        end
        return nil
    end

    if #cite.citations == 1 then
        local id = cite.citations[1].id
        local index = get_ids_index(id)
        if index then
            if FORMAT == "latex" then
                return pandoc.RawInline('latex', "\\ref{" .. id .. "}")
            else
                return pandoc.Str(tostring(index))
            end
        end
    end
    return nil
end

-- Entry point: process equations first so IDs are collected before resolving references.
function Pandoc(doc)
    return doc:walk { Para = process_equations } : walk { Cite = process_references }
end
