local M = {}

local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local conf = require('telescope.config').values
local finders = require 'telescope.finders'
local pickers = require 'telescope.pickers'
local utils = require 'telescope.utils'
local putils = require 'telescope.previewers.utils'
local git_command = utils.__git_command
local previewers = require 'telescope.previewers'

M.hunk_diff = previewers.defaulter(function()
  return previewers.new_buffer_previewer {
    title = 'Git Hunk Diff Preview',
    get_buffer_by_name = function(_, entry)
      return entry.value
    end,

    define_preview = function(self, entry, _)
      local lines = entry.raw_lines or { 'empty' }
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      putils.regex_highlighter(self.state.bufnr, 'diff')
    end,
  }
end, {})

M.find_hunks = function(opts)
  opts = opts or {}
  if opts.is_bare then
    utils.notify('git_hunk.find_hunks', {
      msg = 'This operation must be run in a work tree',
      level = 'ERROR',
    })
    return
  end
  local args = { 'diff' }
  if opts.additional_args then
    vim.list_extend(args, opts.additional_args)
  end
  local git_cmd = git_command(args, opts)
  local output = vim.fn.systemlist(git_cmd)

  local results = {}
  local filename = nil
  local linenumber = nil
  local hunk_lines = {}

  for _, line in ipairs(output) do
    -- new file
    if vim.startswith(line, 'diff') then
      -- Start of a new hunk
      if hunk_lines[1] ~= nil then
        table.insert(results, { filename = filename, lnum = linenumber, raw_lines = hunk_lines })
      end

      local _, filepath_, _ = line:match '^diff (.*) a/(.*) b/(.*)$'

      filename = filepath_
      linenumber = nil

      hunk_lines = {}
    elseif vim.startswith(line, '@') then
      if filename ~= nil and linenumber ~= nil and #hunk_lines > 0 then
        table.insert(results, { filename = filename, lnum = linenumber, raw_lines = hunk_lines })
        hunk_lines = {}
      end
      -- Hunk header
      -- @example "@@ -157,20 +157,6 @@ some content"
      local _, _, c, _ = string.match(line, '@@ %-(.*),(.*) %+(.*),(.*) @@')
      linenumber = tonumber(c)
      hunk_lines = {}
      table.insert(hunk_lines, line)
    else
      table.insert(hunk_lines, line)
    end
  end
  -- Add the last hunk to the table
  if hunk_lines[1] ~= nil then
    table.insert(results, { filename = filename, lnum = linenumber, raw_lines = hunk_lines })
  end

  local function get_diff_line_idx(lines)
    for i, line in ipairs(lines) do
      if vim.startswith(line, '-') or vim.startswith(line, '+') then
        return i
      end
    end
    return -1
  end

  -- lnum in diff hunks points a few lines off actually changed line
  -- update results to point at changed lines to be precise
  for _, v in ipairs(results) do
    local diff_line_idx = get_diff_line_idx(v.raw_lines)
    diff_line_idx = math.max(
      -- first line is header, next one is already handled
      diff_line_idx - 2,
      0
    )
    v.lnum = v.lnum + diff_line_idx
  end

  pickers
    .new({}, {
      prompt_title = 'Git Hunks',
      finder = finders.new_table {
        results = results,
        entry_maker = function(entry)
          entry.value = entry.filename
          entry.ordinal = entry.filename .. ':' .. entry.lnum
          entry.display = entry.filename .. ':' .. entry.lnum
          return entry
        end,
      },
      previewer = M.hunk_diff.new(opts),
      sorter = conf.file_sorter {},
      on_complete = {
        function(self)
          local lines = self.manager:num_results()
          local prompt = action_state.get_current_line()
          if lines == 0 and prompt == '' then
            utils.notify('git_hunk.find_hunks', {
              msg = 'No changes found',
              level = 'ERROR',
            })
            actions.close(self.prompt_bufnr)
          end
        end,
      },
    })
    :find()
end

return M.find_hunks
