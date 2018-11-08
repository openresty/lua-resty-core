-- Copyright (C) Yichun Zhang (agentzh)

local subsystem = ngx.config.subsystem


-- regex module should be loaded first to inject ngx.re for other modules
require "resty.core.regex"

require "resty.core.shdict"
require "resty.core.time"


if subsystem == 'http' then
    require "resty.core.base64"
    require "resty.core.ctx"
    require "resty.core.exit"
    require "resty.core.hash"
    require "resty.core.misc"
    require "resty.core.ndk"
    require "resty.core.phase"
    require "resty.core.request"
    require "resty.core.response"
    require "resty.core.uri"
    require "resty.core.var"
    require "resty.core.worker"
end


local base = require "resty.core.base"


return {
    version = base.version
}
