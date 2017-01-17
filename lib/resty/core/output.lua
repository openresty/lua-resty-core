local ffi = require "ffi"
local base = require "resty.core.base"
local FFI_OK = base.FFI_OK
local ffi_cast = ffi.cast
local const_char_ptr = ffi.typeof("const char *")
local C = ffi.C
--local get_string_buf = base.get_string_buf
--local get_size_ptr = base.get_size_ptr

local output = {}

ffi.cdef[[
        int ngx_http_lua_ffi_write(ngx_http_request_t *r,
                const char* str,
                size_t offset,
                size_t len);
]]

function output.ffi_write(lua_string, offset, len)
    --local ERR_BUF_SIZE = 128
    --local err = get_string_buf(ERR_BUF_SIZE)
    --local errlen = get_size_ptr()
    local buff = ffi_cast(const_char_ptr, lua_string)

    local r = getfenv(0).__ngx_req

    if not r then
       --return false, error("no request found")
       ngx.log(ngx.ERR, "no request found")
       return false
    end

    local rc = C.ngx_http_lua_ffi_write(r,
                           buff,
                           offset,
                           len)

    if rc == FFI_OK then
      ngx.log(ngx.INFO, "ffi_write success: code = "..rc)
      return true
    else
      --errlen[0] = ERR_BUF_SIZE
      --return false, error(ffi_string(err, errlen[0]))
      ngx.log(ngx.INFO, "ffi_write error: code = "..rc)
      return false
    end

 end

return output
