local uv        = require "lluv"
local ut        = require "lluv.utils"
local socket    = require "lluv.ssl.luasocket"
local ssl       = require "lluv.ssl"
local sendmail_ = require "sendmail"
local Args      = require "spylog.args"
local log       = require "spylog.log"

local SSL_CONTEXT = {}

local function CTX(opt)
  if not opt then return end

  local ctx = SSL_CONTEXT[opt]
  if not ctx then
    ctx = ssl.context(opt)
    SSL_CONTEXT[opt] = ctx
  end

  return ctx
end

return function(action, cb)
  local options = action.options

  local args, tail = Args.split(action.args)

  if not args then
    log.error("[%s] Can not parse argument string: %q", action.jail, action.args)
    return uv.defer(cb, info, nil)
  end

  if tail then
    log.warning("[%s] Unused command arguments: %q", action.jail, tail)
  end

  ut.corun(function()
    local ok, err = sendmail_{
      server = {
        address  = options.server.address;
        user     = options.server.user;
        password = options.server.password;
        ssl      = CTX(options.server.ssl);
        create   = options.server.ssl and socket.ssl;
      },

      from = {
        title   = options.from.title;
        address = options.from.address;
      },

      to = {
        title   = options.to.title;
        address = options.to.address;
      },

      message = { args[1], args[2] }
    }

    uv.defer(cb, action, ok, err)
  end)
end
