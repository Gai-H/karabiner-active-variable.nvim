local M = {}

local defaults = {
  karabiner_variable_name = "neovim_active",
  karabiner_cli_path = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli",
}

local state = {
  notified_shared_state_failure = false,
}

local function notify_shared_state_failure_once(msg)
  if state.notified_shared_state_failure then
    return
  end

  state.notified_shared_state_failure = true

  vim.schedule(function()
    vim.notify(msg, vim.log.levels.WARN)
  end)
end

local karabiner = require("karabiner-active-variable.karabiner")
local shared_state = require("karabiner-active-variable.state")

local function sync_state(active, opts)
  local ok, result = pcall(shared_state.update_instance, active)
  if not ok then
    notify_shared_state_failure_once(string.format("karabiner-active-variable.nvim: failed to update shared state: %s", result))
    return
  end

  karabiner.apply(result.any_active, opts)
end

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  state.notified_shared_state_failure = false
  karabiner.configure(config)

  local group = vim.api.nvim_create_augroup("karabiner-active-variable", { clear = true })

  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "VimResume" }, {
    group = group,
    callback = function()
      sync_state(true)
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend", "VimLeavePre" }, {
    group = group,
    callback = function(event)
      if event.event == "VimLeavePre" then
        sync_state(false, { sync = true })
        return
      end

      sync_state(false)
    end,
  })

  sync_state(true)
end

return M
