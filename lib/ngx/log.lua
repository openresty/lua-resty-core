
local ffi = require 'ffi'
local base = require "resty.core.base"
local ffi_string = ffi.string
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local C = ffi.C
local new_tab = base.new_tab
local ffi_new = ffi.new
local charpp = ffi_new("char *[1]")
local intp = ffi.new("int[1]")


local _M = { version = base.version }


ffi.cdef[[
    int ngx_http_lua_ffi_set_errlog_filter(int level, unsigned char *err,
        size_t *errlen);
    int ngx_http_lua_ffi_get_errlog_data(char **log, size_t *loglen,
        int *loglevel, unsigned char *err, size_t *errlen);
]]


local ERR_BUF_SIZE = 128
local FFI_ERROR = base.FFI_ERROR


function _M.set_errlog_filter(level)
    if not level then
        return nil, [[missing "level" argument]]
    end

    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE
    local rc = C.ngx_http_lua_ffi_set_errlog_filter(level, err, errlen)

    if rc == FFI_ERROR then
        return nil, ffi_string(err, errlen[0])
    end

    return true
end


function _M.get_errlog(max, logs)
    local err = get_string_buf(ERR_BUF_SIZE)
    local errlen = get_size_ptr()
    errlen[0] = ERR_BUF_SIZE

    local log = charpp
    local loglen = get_size_ptr()
    local loglevel = intp

    max = max or 10

    if not logs then
        logs = new_tab(max, 0)
    end

    for i = 1, max do
        local rc = C.ngx_http_lua_ffi_get_errlog_data(log, loglen,
                                                      loglevel, err, errlen)
        if rc == FFI_ERROR then
            return nil, ffi_string(err, errlen[0])
        end

        if rc > 0 then
            logs[i] = {loglevel[0], ffi_string(log[0], loglen[0])}
        end

        if rc <= 1 or i == max then    -- last one
            logs[i + 1] = nil
            break
        end
    end

    return logs
end


return _M
