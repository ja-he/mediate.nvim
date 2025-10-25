-- core plugin logic

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

local match_conflict_base = function(s)
  local marker = "|||||||"
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

  -- split into sections (by markers)
  -- first pass: detect conflict style and find all markers
  local start_line_nr = vim.api.nvim_win_get_cursor(original_win)[1]
  local base_line_nr = -1
  local sep_line_nr = -1
  local end_line_nr = -1

  for line_ofs, line in ipairs(vim.api.nvim_buf_get_lines(original_buf, start_line_nr - 1, -1, false)) do
    if match_conflict_start(line) then
      -- Nothing to do for now...
    elseif match_conflict_base(line) then
      if base_line_nr ~= -1 then
        print("ILLEGAL: found multiple base markers (|||||||)")
        do return end
      end
      base_line_nr = start_line_nr + line_ofs - 1
      is_diff3_style = true
    elseif match_conflict_sep(line) then
      if sep_line_nr ~= -1 then
        print("ILLEGAL: seem to have found a second sep (octopus merges are not supported)")
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
    else
      -- Nothing to do for now...
    end
  end

  -- extract content based on conflict style
  local ours_lines, base_lines, theirs_lines

  if is_diff3_style then
    -- diff3/zdiff3 style: <<<<<<< ours ||||||| base ======= theirs >>>>>>>
    if base_line_nr == -1 then
      print("ILLEGAL: expected base marker but didn't find one")
      do return end
    end
    ours_lines = vim.api.nvim_buf_get_lines(original_buf, start_line_nr, base_line_nr - 1, true)
    base_lines = vim.api.nvim_buf_get_lines(original_buf, base_line_nr, sep_line_nr - 1, true)
    theirs_lines = vim.api.nvim_buf_get_lines(original_buf, sep_line_nr, end_line_nr - 1, true)
  else
    -- standard diff2 style: <<<<<<< ours ======= theirs >>>>>>>
    ours_lines = vim.api.nvim_buf_get_lines(original_buf, start_line_nr, sep_line_nr - 1, true)
    theirs_lines = vim.api.nvim_buf_get_lines(original_buf, sep_line_nr, end_line_nr - 1, true)
  end

  original_line_start = start_line_nr
  original_line_end = end_line_nr

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
