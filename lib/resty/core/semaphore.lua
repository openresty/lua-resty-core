
local ffi = require 'ffi'
local base = require "resty.core.base"

local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local C = ffi.C
local type = type
local getfenv = getfenv
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local setmetatable = setmetatable
local ngx = ngx
local ERR_BUF_SIZE = 128

if not pcall(ffi.typeof,"ngx_http_lua_semaphore_t") then
    ffi.cdef[[
        struct ngx_http_lua_semaphore_s;
        typedef struct ngx_http_lua_semaphore_s ngx_http_lua_semaphore_t;
    ]]
end

ffi.cdef[[
    int ngx_http_lua_ffi_sem_new(ngx_http_lua_semaphore_t **psem,
                                 int n,char **errstr);
    int ngx_http_lua_ffi_sem_wait(ngx_http_request_t *r,
    	                          ngx_http_lua_semaphore_t *sem,
                                  int time,char *errstr,
                                  size_t *errlen);
    int ngx_http_lua_ffi_sem_post(ngx_http_lua_semaphore_t *sem,
                                  int time, char **errstr);
    void ngx_http_lua_ffi_sem_gc(ngx_http_lua_semaphore_t *sem);
]]


local _M = {}

ngx.semaphore = _M

local errmsg = base.get_errmsg_ptr()

function _M.new(n)
    local psem = ffi_new("ngx_http_lua_semaphore_t *[1]")
    local ret = C.ngx_http_lua_ffi_sem_new(psem, n, errmsg)

    if ret == ngx.ERROR then
        return nil, ffi_str(errmsg[0])
    end

    ffi_gc(psem[0], C.ngx_http_lua_ffi_sem_gc)

    return setmetatable({ sem = psem[0] }, _M)
end


function _M.wait(sem, time)
    if sem == nil then
        return nil, "param is nil"
    end

    time = tonumber(time) or 0

    local cdata_sem  = sem.sem
    if time < 0 then
        return nil, "time must not less than 0"
    end

    local r = getfenv(0).__ngx_req
    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE

    local ret = C.ngx_http_lua_ffi_sem_wait(r,cdata_sem,time,err,errlen)

    if ret == ngx.ERROR then
        return nil, ffi_str(err, errlen[0])

    elseif ret == ngx.OK then
        return true

    else
        if time == 0 then
            -- ret == ngx.DECLINE
            return nil, "busy"

        else
            --ret == ngx.AGAIN
            return coroutine._yield()
        end
    end
end


function _M.post(sem)
    if type(sem) ~= "table" or type(sem.sem) ~= "cdata" then
        return nil, "semaphore not inited"
    end

    local cdata_sem = sem.sem
    local ret = C.ngx_http_lua_ffi_sem_post(cdata_sem, 1, errmsg)

    if ret == ngx.ERROR then
        return nil,ffi_str(errmsg[0])
    end

    return true
end


_M.__index = _M


return {
    version = base.version
}
