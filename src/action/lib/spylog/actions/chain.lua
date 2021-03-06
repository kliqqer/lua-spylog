local uv      = require "lluv"
local spawn   = require "spylog.spawn"
local Args    = require "spylog.args"
local var     = require "spylog.var"
local log     = require "spylog.log"

return function(task, cb)
  local action, options = task.action, task.options
  local context, command = action, action.cmd[2]
  local parameters = action.parameters or command.parameters

  if action.parameters then context = var.combine{action, action.parameters, command.parameters}
  elseif command.parameters then context = var.combine{action, command.parameters} end

  local log_header = string.format("[%s][%s][%s]", action.jail, action.action, task.type)

  local commands = command
  if type(commands) == 'string' then commands = {commands} end

  if type(commands) ~= 'table' or #commands == 0 then
    log.warning('%s no commands to execute', log_header)
    return uv.defer(cb, task, 0)
  end

  for i = 1, #commands do
    if type(commands[i]) == 'string' then
      commands[i] = {commands[i]}
    end

    local command = commands[i]

    local cmd, args, tail = Args.decode_command(command, context)

    if not cmd then
      log.error("%s Can not parse argument string: %s", log_header, args)
      return uv.defer(cb, task, false, args)
    end

    if tail then
      log.warning("%s Unused command arguments: %q", log_header, tail)
    end

    command[1], command[2] = cmd, args

    log.debug("%s[%d] prepare to execute: %s %s", log_header, i, cmd, Args.build(args))
  end

  local last_error, last_command
  spawn.chain(commands, options.timeout, function(i, typ, err, status, signal)
    if typ == 'done' then
      return uv.defer(cb, task, not last_error, last_error)
    end

    if typ == 'exit' then
      last_command, last_error, last_status = i, err, status
      log.debug("%s[%d] chain command exit: %s", log_header, i, tostring(err or status))
      return
    end

    return log.trace("%s[%d] chain command output: [%s] %s", log_header, i, typ, tostring(err or status))
  end)
end
