-- basic plugin infrastructure
vim.api.nvim_create_user_command(
  "Mediate",
  require('mediate').mediate_start,
  {
  }
)
