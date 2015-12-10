
local ffi = require 'ffi'
local base = require "resty.core.base"


local FFI_OK = base.FFI_OK
local FFI_ERROR = base.FFI_ERROR
local FFI_DECLINED = base.FFI_DECLINED
local ffi_new = ffi.new
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local C = ffi.C
local type = type
local error = error
local tonumber = tonumber
local getfenv = getfenv
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local setmetatable = setmetatable
local co_yield = coroutine._yield
local ERR_BUF_SIZE = 128


local errmsg = base.get_errmsg_ptr()


if not pcall(ffi.typeof, "ngx_http_lua_semaphore_t") then
    ffi.cdef[[
        struct ngx_http_lua_semaphore_s;
        typedef struct ngx_http_lua_semaphore_s ngx_http_lua_semaphore_t;
    ]]
end

ffi.cdef[[
int ngx_http_lua_ffi_semaphore_new(ngx_http_request_t *r,
    ngx_http_lua_semaphore_t **psem, int n, char *errstr, size_t *errlen);

int ngx_http_lua_ffi_semaphore_post(ngx_http_lua_semaphore_t *sem,
    int n, char **errstr);

int ngx_http_lua_ffi_semaphore_count(ngx_http_lua_semaphore_t *sem);

int ngx_http_lua_ffi_semaphore_wait(ngx_http_request_t *r,
    ngx_http_lua_semaphore_t *sem, int wait_ms, char *errstr, size_t *errlen);

void ngx_http_lua_ffi_semaphore_gc(ngx_http_lua_semaphore_t *sem);
]]


local psem = ffi_new("ngx_http_lua_semaphore_t *[1]")


local _M = {}
local mt = { __index = _M }


function _M.new(n)
    local r = getfenv(0).__ngx_req
    if not r then
        return nil, "no request found"
    end

    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE

    local ret = C.ngx_http_lua_ffi_semaphore_new(r, psem, n, err, errlen)

    if ret == FFI_ERROR then
        return nil, ffi_str(err, errlen[0])
    end

    local sem = psem[0]

    ffi_gc(sem, C.ngx_http_lua_ffi_semaphore_gc)

    return setmetatable({ sem = sem }, mt)
end


function _M.wait(self, time)
    if type(self) ~= "table" or type(self.sem) ~= "cdata" then
        return nil, "semaphore not inited"
    end

    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    time = time and tonumber(time) or 0
    if time < 0 then
        time = 0
    end

    local cdata_sem = self.sem

    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE

    local ret = C.ngx_http_lua_ffi_semaphore_wait(r, cdata_sem,
                                                  time * 1000, err, errlen)

    if ret == FFI_ERROR then
        return nil, ffi_str(err, errlen[0])
    end

    if ret == FFI_OK then
        return true
    end

    if ret == FFI_DECLINED then
        return nil, "busy"
    end

    return co_yield()
end


function _M.post(self, n)
    if type(self) ~= "table" or type(self.sem) ~= "cdata" then
        return nil, "semaphore not inited"
    end

    local cdata_sem = self.sem

    local num = tonumber(n) or 1
    if num < 1 then
        num = 1
    end

    local ret = C.ngx_http_lua_ffi_semaphore_post(cdata_sem, num, errmsg)

    if ret == FFI_ERROR then
        return nil, ffi_str(errmsg[0])
    end

    return true
end


function _M.count(self)
    if type(self) ~= "table" or type(self.sem) ~= "cdata" then
        return nil, "semaphore not inited"
    end

    local cdata_sem = self.sem
    local ret = C.ngx_http_lua_ffi_semaphore_count(cdata_sem)

    return ret
end


return _M
