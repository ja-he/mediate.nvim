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

local mediate_start = function()
  -- get text from cursor
  -- verify that at conflict (by marker)
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
