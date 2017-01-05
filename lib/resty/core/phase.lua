local ffi = require 'ffi'
local C = ffi.C
local base = require "resty.core.base"

ffi.cdef[[
int ngx_http_lua_ffi_get_phase(ngx_http_request_t *r, char **err)
]]

local _M = {
	_VERSION = base.version
}

local errmsg = base.get_errmsg_ptr()

function ngx.get_phase()
	local r = getfenv(0).__ngx_req

	-- If we have no request object, assume we are called from the "init" phase
	if not r then
		return "init"
	end

	local context = C.ngx_http_lua_ffi_get_phase(r, errmsg)

	if context == -1 then -- NGX_ERROR
		error(errmsg)
	elseif context == 0x0001 then
		return "set"
	elseif context == 0x0002 then
		return "rewrite"
	elseif context == 0x0004 then
		return "access"
	elseif context == 0x0008 then
		return "content"
	elseif context == 0x0010 then
		return "log"
	elseif context == 0x0020 then
		return "header_filter"
	elseif context == 0x0040 then
		return "body_filter"
	elseif context == 0x0080 then
		return "timer"
	elseif context == 0x0100 then
		return "init_worker"
	elseif context == 0x0200 then
		return "balancer"
	elseif context == 0x0400 then
		return "ssl_cert"
	elseif context == 0x0800 then
		return "ssl_session_store"
	elseif context == 0x1000 then
		return "ssl_session_fetch"
	else
		error("unknown phase: " .. context)
	end
end

return _M
