-- core plugin logic

-- TODO: probably encapsulate this into a table?
local mediation_active = false
local mediate_win_left = -1
local mediate_buf_left = -1
local mediate_win_right = -1
local mediate_buf_right = -1
local original_win = -1
local original_buf = -1
local original_line_start = -1
local original_line_end = -1

local reset = function()
  mediation_active = false
  mediate_win_left = -1
  mediate_buf_left = -1
  mediate_win_right = -1
  mediate_buf_right = -1
  original_win = -1
  original_buf = -1
  original_line_start = -1
  original_line_end = -1
end

local match_conflict_start = function(s)
  local marker = "<<<<<<<"
  local starts_with_marker = string.sub(s, 1, string.len(marker)) == marker
  return starts_with_marker
end

local match_conflict_end = function(s)
  local marker = ">>>>>>>"
  local starts_with_marker = string.sub(s, 1, string.len(marker)) == marker
  return starts_with_marker
end

local match_conflict_sep = function(s)
  local marker = "======="
  local starts_with_marker = string.sub(s, 1, string.len(marker)) == marker
  return starts_with_marker
end

local mediate_start = function()
  -- ensure not already started
  if mediation_active then
    print("ILLEGAL: mediation already active")
    do return end
  end

  -- get the current win and buf
  original_win = vim.api.nvim_get_current_win()
  original_buf = vim.api.nvim_get_current_buf()

  -- get text from cursor
  local current_line_contents = vim.api.nvim_get_current_line()
  -- verify that at conflict (by marker)
  if not match_conflict_start(current_line_contents) then
    print("ILLEGAL: current line not a conflict start")
    do return end
  end
  -- split into party A and B (by markers)
  local start_line_nr = vim.api.nvim_win_get_cursor(original_win)[1]
  local sep_line_nr = -1
  local end_line_nr = -1
  for line_ofs, line in ipairs(vim.api.nvim_buf_get_lines(original_buf, start_line_nr - 1, -1, false)) do
    if match_conflict_sep(line) then
      if sep_line_nr ~= -1 then
        print("ILLEGAL: seem to have found a second sep (octopus merges are not supported, I wouldn't even know what they look like with conflict markers tbh)")
        do return end
      end
      sep_line_nr = start_line_nr + line_ofs - 1
    elseif match_conflict_end(line) then
      if sep_line_nr == -1 then
        print("ILLEGAL: seem to have found end of conflict before finding sep (line:", (start_line_nr + line_ofs - 1),
          ")")
        do return end
      end
      end_line_nr = start_line_nr + line_ofs - 1
      break
    end
  end
  local a_lines = vim.api.nvim_buf_get_lines(original_buf, start_line_nr, sep_line_nr - 1, true)
  local b_lines = vim.api.nvim_buf_get_lines(original_buf, sep_line_nr, end_line_nr - 1, true)
  original_line_start = start_line_nr
  original_line_end = end_line_nr

  -- open new tab and create two splits, keep the windows and the buffers
  vim.cmd('tabnew')
  mediate_win_right = vim.api.nvim_get_current_win()
  mediate_buf_right = vim.api.nvim_create_buf('mediate-right', true)
  vim.api.nvim_win_set_buf(mediate_win_right, mediate_buf_right)
  vim.api.nvim_buf_set_name(mediate_buf_right, "mediate-right")
  vim.cmd('vnew')
  mediate_win_left = vim.api.nvim_get_current_win()
  mediate_buf_left = vim.api.nvim_create_buf('mediate-left', true)
  vim.api.nvim_win_set_buf(mediate_win_left, mediate_buf_left)
  vim.api.nvim_buf_set_name(mediate_buf_left, "mediate-left")
  -- populate buffers with content
  vim.api.nvim_buf_set_lines(mediate_buf_left, 0, 1, false, a_lines)
  vim.api.nvim_buf_set_lines(mediate_buf_right, 0, 1, false, b_lines)
  -- start diff mode
  vim.cmd('windo diffthis')

  -- set state to await mediate_finish
  mediation_active = true
end

local mediate_finish = function()
  -- ensure mediation is active
  if not mediation_active then
    print("ILLEGAL: no mediation active")
    do return end
  end

  -- get mediation result from buffer
  local lines_left = vim.api.nvim_buf_get_lines(mediate_buf_left, 0, -1, false)
  local lines_right = vim.api.nvim_buf_get_lines(mediate_buf_right, 0, -1, false)
  -- verify result (no conflict markers left, ...)
  if table.concat(lines_left) ~= table.concat(lines_right) then
    print("ILLEGAL: buffer contents don't match, conflict has not been mediated fully")
    do return end
  end

  -- close temporary buffers, windows, tab, ...
  vim.api.nvim_win_close(mediate_win_left, true)
  vim.api.nvim_win_close(mediate_win_right, true)

  -- put result back to original buffer's range
  vim.api.nvim_buf_set_lines(original_buf, original_line_start-1, original_line_end, true, lines_left)

  mediation_active = false
  print("SUCCESS: mediation concluded")

  reset()
end

local mediate_context_activate = function()
  local mediate_augrp = vim.api.nvim_create_augroup("mediate", {
    clear = true,
  })
  vim.api.nvim_create_autocmd()
end

return {
  mediate_start = mediate_start,
  mediate_finish = mediate_finish,
  mediate_context_activate = mediate_context_activate,
}
