-- lua/mediate/conflict.lua
local M = {}

-- Simple pattern matchers
local function match_conflict_start(line)
  return line:sub(1, 7) == "<<<<<<<"
end

local function match_conflict_end(line)
  return line:sub(1, 7) == ">>>>>>>"
end

local function match_conflict_sep(line)
  return line:sub(1, 7) == "======="
end

local function match_conflict_base(line)
  return line:sub(1, 7) == "|||||||"
end

-- Parse conflict starting at given position in buffer
-- @param bufnr: buffer number
-- @param line_nr: 1-based line number where conflict should start
-- @return: table with conflict info or nil + error message
function M.parse_conflict(bufnr, line_nr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if line_nr < 1 or line_nr > line_count then
    return nil, "line number out of bounds"
  end

  -- Check if we're at a conflict start
  local start_line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
  if not match_conflict_start(start_line) then
    return nil, "line is not a conflict start marker"
  end

  local base_line_nr = nil
  local sep_line_nr = nil
  local end_line_nr = nil
  local is_diff3 = false

  -- Scan forward from start to find all markers
  for i = line_nr + 1, line_count do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]

    if match_conflict_base(line) then
      if base_line_nr then
        return nil, "found multiple base markers (|||||||)"
      end
      base_line_nr = i
      is_diff3 = true
    elseif match_conflict_sep(line) then
      if sep_line_nr then
        return nil, "found multiple separator markers (octopus merges not supported)"
      end
      sep_line_nr = i
    elseif match_conflict_end(line) then
      if not sep_line_nr then
        return nil, "found end marker before separator marker"
      end
      end_line_nr = i
      break
    end
  end

  if not end_line_nr then
    return nil, "could not find conflict end marker"
  end

  -- Build result structure
  local result = {
    start_line = line_nr,
    end_line = end_line_nr,
    sep_line = sep_line_nr,
    is_diff3 = is_diff3,
  }

  if is_diff3 then
    if not base_line_nr then
      return nil, "expected base marker for diff3 style conflict"
    end
    result.base_line = base_line_nr
    result.ours_range = { line_nr + 1, base_line_nr - 1 }
    result.base_range = { base_line_nr + 1, sep_line_nr - 1 }
    result.theirs_range = { sep_line_nr + 1, end_line_nr - 1 }
  else
    result.ours_range = { line_nr + 1, sep_line_nr - 1 }
    result.theirs_range = { sep_line_nr + 1, end_line_nr - 1 }
  end

  return result
end

-- Extract lines for a given range from a buffer
-- @param bufnr: buffer number
-- @param range: {start_line, end_line} (inclusive, 1-based)
-- @return: table of lines in that range
function M.extract_range(bufnr, range)
  -- Handle empty range
  if range[1] > range[2] then
    return {}
  end

  return vim.api.nvim_buf_get_lines(bufnr, range[1] - 1, range[2], false)
end

return M
