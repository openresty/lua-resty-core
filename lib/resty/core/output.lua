local ffi = require "ffi"
local base = require "resty.core.base"
local FFI_OK = base.FFI_OK
local FFI_ERROR = base.FFI_ERROR
local C = ffi.C

local _M = {
    version = base.version
}

ffi.cdef[[
        int ngx_http_lua_ffi_write(ngx_http_request_t *r,
                const char* str,
                size_t offset,
                size_t len);
]]

function _M.ffi_write(lua_string, offset, len)
    local r = getfenv(0).__ngx_req
    if not r then
        return false, FFI_ERROR
    end

    local rc = C.ngx_http_lua_ffi_write(r,
                                        lua_string,
                                        offset,
                                        len)

    if rc == FFI_OK then
        return true
    else
        return false, rc
    end
end


return _M
