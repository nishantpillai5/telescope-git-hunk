local has_telescope, telescope = pcall(require, 'telescope')

if not has_telescope then
  return
end

local gh_config = require 'telescope._extensions.git_hunk.config'
local gh_picker = require 'telescope._extensions.git_hunk.picker'

local git_hunk = function(opts)
  opts = opts or {}
  local defaults = (function()
    if gh_config.values.theme then
      return require('telescope.themes')['get_' .. gh_config.values.theme](gh_config.values)
    end
    return vim.deepcopy(gh_config.values)
  end)()

  if gh_config.values.mappings then
    defaults.attach_mappings = function(prompt_bufnr, map)
      if gh_config.values.attach_mappings then
        gh_config.values.attach_mappings(prompt_bufnr, map)
      end
      for mode, tbl in pairs(gh_config.values.mappings) do
        for key, action in pairs(tbl) do
          map(mode, key, action)
        end
      end
      return true
    end
  end

  if opts.attach_mappings then
    local opts_attach = opts.attach_mappings
    opts.attach_mappings = function(prompt_bufnr, map)
      defaults.attach_mappings(prompt_bufnr, map)
      return opts_attach(prompt_bufnr, map)
    end
  end
  local popts = vim.tbl_deep_extend('force', defaults, opts)
  gh_picker(popts)
end

return require('telescope').register_extension {
  setup = gh_config.setup,
  exports = {
    git_hunk = git_hunk,
  },
}
