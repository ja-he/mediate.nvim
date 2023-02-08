-- core plugin logic

-- TODO: probably encapsulate this into a table?
local mediation_active = false
local active_win_left = -1
local active_buf_left = -1
local active_win_right = -1
local active_buf_right = -1
local original_win = -1
local original_buf = -1
local original_line_start = -1
local original_line_end = -1

local match_conflict_start = function(s)
  local start_marker = "<<<<<<<"
  local starts_with_marker = string.sub(s, 1, string.len(start_marker)) == start_marker
  return starts_with_marker
end

local mediate_start = function()
  -- ensure not already started
  if mediation_active then
    print("ILLEGAL: mediation already active")
    do return end
  end

  -- get text from cursor
  local current_line_contents = vim.api.nvim_get_current_line()
  -- verify that at conflict (by marker)
  if not match_conflict_start(current_line_contents) then
    print("ILLEGAL: current line not a conflict start")
    do return end
  end
  -- split into party A and B (by markers)

  -- open new tab
  -- create two splits
  -- put buffers in

  -- populate buffers with content
  -- start diff mode

  -- set state to await mediate_finish
  mediation_active = true

  print("TODO")
end

local mediate_finish = function()
  -- ensure mediation is active
  if not mediation_active then
    print("ILLEGAL: no mediation active")
    do return end
  end

  -- get mediation result from buffer
  -- verify result (no conflict markers left, ...)

  -- close temporary buffers, windows, tab, ...

  -- put result back to original buffer's range

  mediation_active = false
  print("SUCCESS: mediation concluded")
end

return {
  mediate_start = mediate_start,
  mediate_finish = mediate_finish,
}
