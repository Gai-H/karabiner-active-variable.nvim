local M = {}

local STATE_PATH = "/tmp/karabiner-active-variable.nvim.json"
local LOCK_PATH = "/tmp/karabiner-active-variable.nvim.lock"
local LOCK_OWNER_PATH = LOCK_PATH .. "/owner_pid"
local LOCK_RETRY_COUNT = 5
local LOCK_RETRY_DELAY_MS = 20

local function current_pid()
  return tostring(vim.fn.getpid())
end

local function sleep_ms(ms)
  vim.wait(ms)
end

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end

  return table.concat(lines, "\n")
end

local function write_file(path, content)
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)
end

local function path_exists(path)
  return vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1
end

local function remove_path(path)
  if path_exists(path) then
    vim.fn.delete(path, "rf")
  end
end

local function pid_is_alive(pid)
  local numeric_pid = tonumber(pid)
  if not numeric_pid then
    return false
  end

  vim.fn.system({ "kill", "-0", tostring(numeric_pid) })
  return vim.v.shell_error == 0
end

local function read_state()
  if vim.fn.filereadable(STATE_PATH) ~= 1 then
    return { instances = {} }
  end

  local raw = read_file(STATE_PATH)
  if not raw or raw == "" then
    return { instances = {} }
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    return { instances = {} }
  end

  if type(decoded.instances) ~= "table" then
    decoded.instances = {}
  end

  return decoded
end

local function write_state(state)
  if vim.tbl_isempty(state.instances) then
    remove_path(STATE_PATH)
    return
  end

  write_file(STATE_PATH, vim.json.encode(state))
end

local function cleanup_stale_entries(state)
  for pid, instance in pairs(state.instances) do
    if type(instance) ~= "table" or not pid_is_alive(pid) then
      state.instances[pid] = nil
    end
  end
end

local function any_active(state)
  for _, instance in pairs(state.instances) do
    if instance.active == true then
      return true
    end
  end

  return false
end

local function read_lock_owner_pid()
  local content = read_file(LOCK_OWNER_PATH)
  if not content or content == "" then
    return nil
  end

  return vim.trim(content)
end

local function write_lock_owner_pid()
  write_file(LOCK_OWNER_PATH, current_pid())
end

local function clear_stale_lock_if_needed()
  if vim.fn.isdirectory(LOCK_PATH) ~= 1 then
    return false
  end

  local owner_pid = read_lock_owner_pid()
  if owner_pid and pid_is_alive(owner_pid) then
    return false
  end

  remove_path(LOCK_PATH)
  return true
end

local function acquire_lock()
  for _ = 1, LOCK_RETRY_COUNT do
    local ok = vim.fn.mkdir(LOCK_PATH) == 1
    if ok then
      write_lock_owner_pid()
      return true
    end

    clear_stale_lock_if_needed()
    sleep_ms(LOCK_RETRY_DELAY_MS)
  end

  return false
end

local function release_lock()
  remove_path(LOCK_PATH)
end

function M.update_instance(active)
  if not acquire_lock() then
    error("failed to acquire shared state lock")
  end

  local ok, result = pcall(function()
    local state = read_state()
    cleanup_stale_entries(state)

    state.instances[current_pid()] = {
      active = active,
    }

    local desired_value = any_active(state)
    write_state(state)

    return {
      any_active = desired_value,
    }
  end)

  release_lock()

  if not ok then
    error(result)
  end

  return result
end

return M
