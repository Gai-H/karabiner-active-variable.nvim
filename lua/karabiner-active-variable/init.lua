local M = {}

local defaults = {
  karabiner_variable_name = "neovim_active",
  karabiner_cli_path = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli",
}

local state = {
  config = vim.deepcopy(defaults),
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

local function set_variable(value, opts)
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

function M.setup(opts)
  state.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  state.notified_missing_cli = false
  state.notified_job_failure = false

  local group = vim.api.nvim_create_augroup("karabiner-active-variable", { clear = true })

  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "VimResume" }, {
    group = group,
    callback = function()
      set_variable(true)
    end,
  })

  vim.api.nvim_create_autocmd({ "FocusLost", "VimSuspend", "VimLeavePre" }, {
    group = group,
    callback = function(event)
      if event.event == "VimLeavePre" then
        set_variable(false, { sync = true })
        return
      end

      set_variable(false)
    end,
  })

  set_variable(true)
end

return M
