-- basic plugin infrastructure
vim.api.nvim_create_user_command(
  "MediateStart",
  require('mediate').mediate_start,
  {
  }
)
vim.api.nvim_create_user_command(
  "MediateFinish",
  require('mediate').mediate_finish,
  {
  }
)
