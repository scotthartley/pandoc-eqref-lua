-- Pandoc Lua filter for equation numbering and cross-referencing.
-- Detects display math paragraphs tagged with {#eq:id} and numbers them.
-- Also detects standalone chemical equation lines using pandoc-chem-sub.lua syntax:
--   [formula]{.chem} {#eq:id}
-- and numbers them in the same sequence as display math.
-- NOTE: This filter must run BEFORE pandoc-chem-sub.lua so it can detect the
--   [formula]{.chem} span before chem-sub converts it to Unicode inlines.
-- For LaTeX output, wraps the equation in an equation environment with \label.
-- For HTML output, lays out the equation in a 3-column CSS grid with the number right-aligned.
-- For docx and other formats, appends the equation number inline.
-- Equations are referenced by citing their identifier (e.g. @eq:myeq),
-- which gets replaced with the equation's sequence number.

-- Ordered list of equation identifiers, used to map IDs to sequence numbers.
local ids = {}
-- Reverse map: id_tag -> sequence number, for O(1) reference lookup.
local id_to_num = {}

-- Detect a standalone chemical equation of the form:
--   [formula]{.chem} {#id}
-- Returns formula, id_tag if found; nil otherwise.
-- Only matches when the Para starts with a .chem Span (optional leading whitespace),
-- and a {#id} label immediately follows with no other non-whitespace text.
local function detect_chem_equation(inlines)
    -- Find the leading .chem Span; reject if any non-whitespace precedes it
    local span_idx = nil
    for i, el in ipairs(inlines) do
        if el.t == "Space" or el.t == "SoftBreak" then
            -- leading whitespace is fine
        elseif el.t == "Span" and el.classes:includes("chem") then
            span_idx = i
            break
        else
            return nil
        end
    end
    if not span_idx then return nil end

    local formula = pandoc.utils.stringify(inlines[span_idx].content)

    -- Gather remaining inlines as a string; reject any non-Str/Space element
    local rest = ""
    for i = span_idx + 1, #inlines do
        local el = inlines[i]
        if     el.t == "Str"                           then rest = rest .. el.text
        elseif el.t == "Space" or el.t == "SoftBreak"  then rest = rest .. " "
        else   return nil
        end
    end

    -- Require {#id} with no other non-whitespace in rest
    local label_s, label_e, id_tag = rest:find("{#([^}]+)}")
    if not id_tag then return nil end
    if rest:sub(1, label_s - 1):find("%S") then return nil end  -- text before label
    if rest:sub(label_e + 1):find("%S")    then return nil end  -- text after label

    return formula, id_tag
end

-- Process each paragraph looking for display math tagged with {#id},
-- or a standalone chemical equation line ([formula]{.chem} {#id}).
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
        if math_el and id_tag then break end
    end

    if math_el and id_tag then
        table.insert(ids, id_tag)
        id_to_num[id_tag] = #ids
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

    -- Phase 2: chemical equation  [formula]{.chem} {#id}
    local formula
    formula, id_tag = detect_chem_equation(para.content)
    if formula and id_tag then
        table.insert(ids, id_tag)
        id_to_num[id_tag] = #ids
        local label_num = #ids
        local chem_span = pandoc.Span(
            {pandoc.Str(formula)},
            pandoc.Attr('', {'chem'}, {}))

        if FORMAT == "latex" then
            local latex = "\n\\begin{equation}\n\\ce{" .. formula
                          .. "}\n\\label{" .. id_tag .. "}\n\\end{equation}\n"
            return pandoc.RawBlock('latex', latex)

        elseif FORMAT:match("html") then
            local num_str = "(" .. tostring(label_num) .. ")"
            local outer_style = "display:grid;grid-template-columns:1fr auto 1fr;align-items:center;"
            local left_div  = pandoc.Div({})
            local chem_div  = pandoc.Div(
                {pandoc.Plain({chem_span})},
                pandoc.Attr('', {}, {{'style', 'text-align:center;'}}))
            local right_div = pandoc.Div(
                {pandoc.Plain({pandoc.Str(num_str)})},
                pandoc.Attr('', {}, {{'style', 'text-align:right;'}}))
            return pandoc.Div({left_div, chem_div, right_div},
                pandoc.Attr('', {}, {{'style', outer_style}}))

        elseif FORMAT == "docx" then
            local num_str = "\u{00A0}\u{00A0}\u{00A0}\u{00A0}(" .. tostring(label_num) .. ")"
            return pandoc.Para({chem_span, pandoc.Str(num_str)})

        else
            local num_str = "\u{00A0}\u{00A0}(" .. tostring(label_num) .. ")"
            return pandoc.Para({chem_span, pandoc.Str(num_str)})
        end
    end
end

-- Replace citation references (e.g. @eq:myeq) with the equation's
-- sequence number. Unmatched citations are left unchanged.
local function process_references(cite)
    if #cite.citations == 1 then
        local id = cite.citations[1].id
        local index = id_to_num[id]
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
