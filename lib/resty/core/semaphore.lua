
local ffi = require 'ffi'
local base = require "resty.core.base"

local ffi_new = ffi.new
local ffi_str = ffi.string
local C = ffi.C
local type = type
local getfenv = getfenv
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local error = error
local tostring = tostring
local getmetatable = getmetatable
local setmetatable = setmetatable
local ngx = ngx
ngx.semaphore = {}
local semaphore = ngx.semaphore
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


local mt

local errmsg = base.get_errmsg_ptr()

local function new(n)
    if ngx.worker.exiting() == 1 then
        return nil,"exiting"
    end

    local psem = ffi_new("ngx_http_lua_semaphore_t *[1]")
    local ret = ffi.C.ngx_http_lua_ffi_sem_new(psem,n,errmsg)

    if ret == ngx.ERROR then
        return nil,ffi_str(errmsg[0])
    end

    ffi.gc(psem[0],ffi.C.ngx_http_lua_ffi_sem_gc)
    local sem = {sem = psem[0] }
    setmetatable(sem,mt)

    return sem
end

local function wait(sem,time)
    if sem == nil then
        return nil,"param is nil"
    end

    if ngx.worker.exiting() == 1 then
        return nil,"exiting"
    end

    time = time or 0

    local cdata_sem  = sem.sem
    if time < 0 then
        return nil, "time must not less than 0"
    end

    local r = getfenv(0).__ngx_req
    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE

    local ret = ffi.C.ngx_http_lua_ffi_sem_wait(r,cdata_sem,time,err,errlen)

    if ret == ngx.ERROR then
        return nil, ffi_str(err, errlen[0])
    elseif ret == ngx.OK then
        return true
    else
        if time == 0 then
            -- ret == ngx.DECLINE
            return nil,"busy"
        else
            --ret == ngx.AGAIN
            return coroutine._yield()
        end
    end
end


local function post(sem)
    if sem == nil then
        return nil,"param is nil"
    end

    if ngx.worker.exiting() == 1 then
        return nil,"exiting"
    end

    local cdata_sem = sem.sem
    local ret = ffi.C.ngx_http_lua_ffi_sem_post(cdata_sem,1,errmsg)

    if ret == ngx.ERROR then
        return nil,ffi_str(errmsg[0])
    end

    return true
end

mt = {
    wait = wait,
    post = post,
    post_all = post_all,
}

semaphore.new = new
for k,v in pairs(mt) do
    semaphore[k] = v
end

mt.__index = mt

return {
    version = base.version
}
