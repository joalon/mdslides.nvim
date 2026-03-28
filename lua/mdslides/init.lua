-- lua/mdslides/init.lua
local M = {}

--- Parse Marp markdown lines into a list of slides.
--- Each slide is a list of strings (lines).
---@param lines string[]
---@return string[][]
function M.parse_slides(lines)
  local body_start = 1

  -- Strip YAML frontmatter: if line 1 is "---", skip to the next "---"
  if lines[1] and lines[1]:match("^%s*---%s*$") then
    for i = 2, #lines do
      if lines[i]:match("^%s*---%s*$") then
        body_start = i + 1
        break
      end
    end
  end

  -- Split on "---" delimiters
  local slides = {}
  local current = {}
  for i = body_start, #lines do
    if lines[i]:match("^%s*---%s*$") then
      slides[#slides + 1] = current
      current = {}
    else
      current[#current + 1] = lines[i]
    end
  end
  if #current > 0 then
    slides[#slides + 1] = current
  end

  -- Trim leading/trailing blank lines per slide
  for i, slide in ipairs(slides) do
    local first, last = 1, #slide
    while first <= last and slide[first]:match("^%s*$") do
      first = first + 1
    end
    while last >= first and slide[last]:match("^%s*$") do
      last = last - 1
    end
    local trimmed = {}
    for j = first, last do
      trimmed[#trimmed + 1] = slide[j]
    end
    slides[i] = trimmed
  end

  return slides
end

return M
