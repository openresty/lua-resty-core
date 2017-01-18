local ffi = require "ffi"
local base = require "resty.core.base"
local FFI_OK = base.FFI_OK
local C = ffi.C

local _M = {
    _VERSION = base.version
}

ffi.cdef[[
        int ngx_http_lua_ffi_write(ngx_http_request_t *r,
                const char* str,
                size_t offset,
                size_t len);
]]

function output.ffi_write(lua_string, offset, len)
    local r = getfenv(0).__ngx_req

    if not r then       
       return false
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
