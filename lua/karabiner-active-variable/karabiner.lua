local M = {}

local state = {
  config = nil,
  notified_missing_cli = false,
  notified_job_failure = false,
}

local function notify_once(key, msg, level)
  if state[key] then
    return
  end

  state[key] = true

  vim.schedule(function()
    vim.notify(msg, level)
  end)
end

local function executable(path)
  return vim.fn.executable(path) == 1
end

function M.configure(config)
  state.config = vim.deepcopy(config)
  state.notified_missing_cli = false
  state.notified_job_failure = false
end

function M.apply(value, opts)
  opts = opts or {}

  local cli_path = state.config.karabiner_cli_path
  if not executable(cli_path) then
    notify_once(
      "notified_missing_cli",
      string.format("karabiner-active-variable.nvim: karabiner_cli was not found at %s", cli_path),
      vim.log.levels.WARN
    )
    return
  end

  local payload = vim.json.encode({
    [state.config.karabiner_variable_name] = value,
  })

  if opts.sync then
    vim.fn.system({ cli_path, "--set-variables", payload })

    if vim.v.shell_error == 0 then
      return
    end

    notify_once(
      "notified_job_failure",
      string.format("karabiner-active-variable.nvim: failed to update Karabiner variable (exit code %d)", vim.v.shell_error),
      vim.log.levels.WARN
    )
    return
  end

  local job_id = vim.fn.jobstart({ cli_path, "--set-variables", payload }, {
    on_exit = function(_, code)
      if code == 0 then
        return
      end

      notify_once(
        "notified_job_failure",
        string.format("karabiner-active-variable.nvim: failed to update Karabiner variable (exit code %d)", code),
        vim.log.levels.WARN
      )
    end,
  })

  if job_id <= 0 then
    notify_once(
      "notified_job_failure",
      "karabiner-active-variable.nvim: failed to start karabiner_cli",
      vim.log.levels.WARN
    )
  end
end

return M
