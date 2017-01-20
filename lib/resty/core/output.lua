local ffi = require "ffi"
local base = require "resty.core.base"


local ffi_str = ffi.string
local errmsg = base.get_errmsg_ptr()
local FFI_OK = base.FFI_OK
local C = ffi.C
local getfenv = getfenv
local error = error


local _M = {
    version = base.version
}


ffi.cdef[[
    int ngx_http_lua_ffi_write(ngx_http_request_t *r,
                               const char* str, size_t offset,
                               size_t len, char **err);
]]


function _M.ffi_write(lua_string, offset, len)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_write(r, lua_string, offset,
                                        len, errmsg)

    if rc == FFI_OK then
        return true
    end

    return false, ffi_str(errmsg[0])
end


return _M
