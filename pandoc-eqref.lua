-- Pandoc Lua filter for equation numbering and cross-referencing.
-- Detects display math paragraphs tagged with {#eq:id} and numbers them.
-- For LaTeX output, wraps the equation in an equation environment with \label.
-- For HTML output, lays out the equation in a 3-column CSS grid with the number right-aligned.
-- For docx and other formats, appends the equation number inline.
-- Equations are referenced by citing their identifier (e.g. @eq:myeq),
-- which gets replaced with the equation's sequence number.

-- Ordered list of equation identifiers, used to map IDs to sequence numbers.
local ids = {}

-- Process each paragraph looking for display math tagged with {#id}.
-- A qualifying paragraph contains a DisplayMath element and a Str matching {#some-id}.
local function process_equations(para)
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

    if not (math_el and id_tag) then
        return nil
    end

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
