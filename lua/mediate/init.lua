local conflict = require('mediate.conflict')

-- TODO: probably encapsulate this into a table?
local mediation_active = false
local mediate_win_left = -1
local mediate_buf_left = -1
local mediate_win_middle = -1
local mediate_buf_middle = -1
local mediate_win_right = -1
local mediate_buf_right = -1
local original_win = -1
local original_buf = -1
local original_line_start = -1
local original_line_end = -1
local is_diff3_style = false

local reset = function()
  mediation_active = false
  mediate_win_left = -1
  mediate_buf_left = -1
  mediate_win_middle = -1
  mediate_buf_middle = -1
  mediate_win_right = -1
  mediate_buf_right = -1
  original_win = -1
  original_buf = -1
  original_line_start = -1
  original_line_end = -1
  is_diff3_style = false
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

  local cursor_line_nr = vim.api.nvim_win_get_cursor(original_win)[1]
  local conflict_info, err = conflict.parse_conflict(original_buf, cursor_line_nr)
  if not conflict_info then
    print("ILLEGAL: " .. err)
    return
  end

  is_diff3_style = conflict_info.is_diff3
  original_line_start = conflict_info.start_line
  original_line_end = conflict_info.end_line

  -- Extract content using helper function
  local ours_lines = conflict.extract_range(original_buf, conflict_info.ours_range)
  local theirs_lines = conflict.extract_range(original_buf, conflict_info.theirs_range)
  local base_lines = nil
  if is_diff3_style then
    base_lines = conflict.extract_range(original_buf, conflict_info.base_range)
  end

  -- open new tab and create splits
  vim.cmd('tabnew')

  if is_diff3_style then
    -- three-way diff layout: left (ours) | middle (base) | right (theirs)
    mediate_win_right = vim.api.nvim_get_current_win()
    mediate_buf_right = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(mediate_win_right, mediate_buf_right)
    vim.api.nvim_buf_set_name(mediate_buf_right, "mediate-theirs")

    vim.cmd('vnew')
    mediate_win_middle = vim.api.nvim_get_current_win()
    mediate_buf_middle = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(mediate_win_middle, mediate_buf_middle)
    vim.api.nvim_buf_set_name(mediate_buf_middle, "mediate-base")

    vim.cmd('vnew')
    mediate_win_left = vim.api.nvim_get_current_win()
    mediate_buf_left = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(mediate_win_left, mediate_buf_left)
    vim.api.nvim_buf_set_name(mediate_buf_left, "mediate-ours")

    -- populate buffers with content
    vim.api.nvim_buf_set_lines(mediate_buf_left, 0, 1, false, ours_lines)
    vim.api.nvim_buf_set_lines(mediate_buf_middle, 0, 1, false, base_lines)
    vim.api.nvim_buf_set_lines(mediate_buf_right, 0, 1, false, theirs_lines)
  else
    -- two-way diff layout: left (ours) | right (theirs)
    mediate_win_right = vim.api.nvim_get_current_win()
    mediate_buf_right = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(mediate_win_right, mediate_buf_right)
    vim.api.nvim_buf_set_name(mediate_buf_right, "mediate-theirs")

    vim.cmd('vnew')
    mediate_win_left = vim.api.nvim_get_current_win()
    mediate_buf_left = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(mediate_win_left, mediate_buf_left)
    vim.api.nvim_buf_set_name(mediate_buf_left, "mediate-ours")

    -- populate buffers with content
    vim.api.nvim_buf_set_lines(mediate_buf_left, 0, 1, false, ours_lines)
    vim.api.nvim_buf_set_lines(mediate_buf_right, 0, 1, false, theirs_lines)
  end

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

  -- get mediation result from buffers
  local lines_left = vim.api.nvim_buf_get_lines(mediate_buf_left, 0, -1, false)
  local lines_right = vim.api.nvim_buf_get_lines(mediate_buf_right, 0, -1, false)

  -- verify result based on conflict style
  if is_diff3_style then
    local lines_middle = vim.api.nvim_buf_get_lines(mediate_buf_middle, 0, -1, false)

    -- all three buffers should match
    if table.concat(lines_left) ~= table.concat(lines_middle) or
        table.concat(lines_left) ~= table.concat(lines_right) then
      print("ILLEGAL: buffer contents do not match, conflict has not been mediated fully")
      do return end
    end
  else
    -- two-way: left and right should match
    if table.concat(lines_left) ~= table.concat(lines_right) then
      print("ILLEGAL: buffer contents do not match, conflict has not been mediated fully")
      do return end
    end
  end

  -- close temporary windows and delete buffers
  vim.api.nvim_win_close(mediate_win_left, true)
  vim.api.nvim_buf_delete(mediate_buf_left, { force = true })

  if is_diff3_style then
    vim.api.nvim_win_close(mediate_win_middle, true)
    vim.api.nvim_buf_delete(mediate_buf_middle, { force = true })
  end

  vim.api.nvim_win_close(mediate_win_right, true)
  vim.api.nvim_buf_delete(mediate_buf_right, { force = true })

  -- put result back to original buffer's range
  vim.api.nvim_buf_set_lines(original_buf, original_line_start - 1, original_line_end, true, lines_left)

  print("SUCCESS: mediation concluded")

  reset()
end

return {
  mediate_start = mediate_start,
  mediate_finish = mediate_finish,
}
