local ffi = require "ffi"
local base = require "resty.core.base"


local C = ffi.C
local ngx = ngx
local error = error
local tonumber = tonumber
local math_randomseed = math.randomseed


ffi.cdef [[
    long random(void);
]]


local function random()
    return tonumber(C.random())
end


local function fnop() end


local _M = { version = base.version }


function _M.randomseed(nop)
    if ngx.get_phase() == "init" then
        return error("API disabled in the current context")
    end

    local r = random()

    math_randomseed(r)

    if nop then
        -- luacheck: globals = math.randomseed
        math.randomseed = fnop
    end

    return r
end


return _M
