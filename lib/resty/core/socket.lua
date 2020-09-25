local base = require "resty.core.base"
local debug = require 'debug'
local ffi = require 'ffi'


local error = error
local tonumber = tonumber
local registry = debug.getregistry()
local ffi_new = ffi.new
local ffi_string = ffi.string
local C = ffi.C


local option_index = {
    ["keepalive"]   = 1,
    ["reuseaddr"]   = 2,
    ["tcp-nodelay"] = 3,
    ["sndbuf"]      = 4,
    ["rcvbuf"]      = 5,
}


ffi.cdef[[
typedef struct ngx_http_lua_socket_tcp_upstream_s
    ngx_http_lua_socket_tcp_upstream_t;

int
ngx_http_lua_ffi_socket_tcp_getoption(ngx_http_lua_socket_tcp_upstream_t *u,
    int opt, int *val, char **err_msg);

int
ngx_http_lua_ffi_socket_tcp_setoption(ngx_http_lua_socket_tcp_upstream_t *u,
    int opt, int val, char **err_msg);
]]


local output_value_buf = ffi_new("int[1]")
local err_msg = base.get_errmsg_ptr()
local FFI_OK = base.FFI_OK
local SOCKET_CTX_INDEX = 1


local function get_tcp_socket(cosocket)
    local tcp_socket = cosocket[SOCKET_CTX_INDEX]
    if not tcp_socket then
        error("bad tcp socket")
    end

    return tcp_socket
end


local function getoption(cosocket, option)
    local tcp_socket = get_tcp_socket(cosocket)

    if option == nil then
        return nil, 'missing the "option" argument'
    end

    if option_index[option] == nil then
        return nil, "unsupported option " .. tostring(option)
    end

    local rc = C.ngx_http_lua_ffi_socket_tcp_getoption(tcp_socket,
                                                       option_index[option],
                                                       output_value_buf,
                                                       err_msg)
    if rc ~= FFI_OK then
        return nil, ffi_string(err_msg[0])
    end

    return tonumber(output_value_buf[0])
end


local function setoption(cosocket, option, value)
    local tcp_socket = get_tcp_socket(cosocket)

    if option == nil then
        return nil, 'missing the "option" argument'
    end

    if value == nil then
        return nil, 'missing the "value" argument'
    end

    if option_index[option] == nil then
        return nil, "unsupported option " .. tostring(option)
    end

    local rc = C.ngx_http_lua_ffi_socket_tcp_setoption(tcp_socket,
                                                       option_index[option],
                                                       value,
                                                       err_msg)
    if rc ~= FFI_OK then
        return nil, ffi_string(err_msg[0])
    end

    return true
end


do
    local method_table = registry.__tcp_cosocket_mt
    method_table.getoption = getoption
    method_table.setoption = setoption
end


return { version = base.version }
