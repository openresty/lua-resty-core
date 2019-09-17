-- Copyright (C) Yichun Zhang (agentzh)


local base = require "resty.core.base"
base.allows_subsystem('http', 'stream')
require "resty.core.hash"


local ffi = require "ffi"
local C = ffi.C
local ffi_str = ffi.string
local errmsg = base.get_errmsg_ptr()
local FFI_OK = base.FFI_OK
local FFI_ERROR = base.FFI_ERROR
local int_out = ffi.new("int[1]")
local get_request = base.get_request
local error = error
local type = type
local tonumber = tonumber
local max = math.max
local ngx_crc32_long = ngx.crc32_long
local subsystem = ngx.config.subsystem
local ngx_lua_ffi_balancer_set_current_peer
local ngx_lua_ffi_balancer_enable_keepalive
local ngx_lua_ffi_balancer_set_more_tries
local ngx_lua_ffi_balancer_get_last_failure
local ngx_lua_ffi_balancer_set_timeouts -- used by both stream and http


if subsystem == 'http' then
    ffi.cdef[[
    int ngx_http_lua_ffi_balancer_set_current_peer(ngx_http_request_t *r,
        const unsigned char *addr, size_t addr_len, int port,
        unsigned int cpool_crc32, unsigned int cpool_size, char **err);

    int ngx_http_lua_ffi_balancer_enable_keepalive(ngx_http_request_t *r,
        unsigned long timeout, unsigned int max_requests, char **err);

    int ngx_http_lua_ffi_balancer_set_more_tries(ngx_http_request_t *r,
        int count, char **err);

    int ngx_http_lua_ffi_balancer_get_last_failure(ngx_http_request_t *r,
        int *status, char **err);

    int ngx_http_lua_ffi_balancer_set_timeouts(ngx_http_request_t *r,
        long connect_timeout, long send_timeout,
        long read_timeout, char **err);
    ]]

    ngx_lua_ffi_balancer_set_current_peer =
        C.ngx_http_lua_ffi_balancer_set_current_peer

    ngx_lua_ffi_balancer_enable_keepalive =
        C.ngx_http_lua_ffi_balancer_enable_keepalive

    ngx_lua_ffi_balancer_set_more_tries =
        C.ngx_http_lua_ffi_balancer_set_more_tries

    ngx_lua_ffi_balancer_get_last_failure =
        C.ngx_http_lua_ffi_balancer_get_last_failure

    ngx_lua_ffi_balancer_set_timeouts =
        C.ngx_http_lua_ffi_balancer_set_timeouts

elseif subsystem == 'stream' then
    ffi.cdef[[
    int ngx_stream_lua_ffi_balancer_set_current_peer(
        ngx_stream_lua_request_t *r,
        const unsigned char *addr, size_t addr_len, int port, char **err);

    int ngx_stream_lua_ffi_balancer_set_more_tries(ngx_stream_lua_request_t *r,
        int count, char **err);

    int ngx_stream_lua_ffi_balancer_get_last_failure(
        ngx_stream_lua_request_t *r, int *status, char **err);

    int ngx_stream_lua_ffi_balancer_set_timeouts(ngx_stream_lua_request_t *r,
        long connect_timeout, long timeout, char **err);
    ]]

    ngx_lua_ffi_balancer_set_current_peer =
        C.ngx_stream_lua_ffi_balancer_set_current_peer

    ngx_lua_ffi_balancer_set_more_tries =
        C.ngx_stream_lua_ffi_balancer_set_more_tries

    ngx_lua_ffi_balancer_get_last_failure =
        C.ngx_stream_lua_ffi_balancer_get_last_failure

    local ngx_stream_lua_ffi_balancer_set_timeouts =
        C.ngx_stream_lua_ffi_balancer_set_timeouts

    ngx_lua_ffi_balancer_set_timeouts =
        function(r, connect_timeout, send_timeout, read_timeout, err)
            local timeout = max(send_timeout, read_timeout)

            return ngx_stream_lua_ffi_balancer_set_timeouts(r, connect_timeout,
                                                            timeout, err)
        end

else
    error("unknown subsystem: " .. subsystem)
end


local DEFAULT_KEEPALIVE_POOL_SIZE = 30
local DEFAULT_KEEPALIVE_IDLE_TIMEOUT = 60000
local DEFAULT_KEEPALIVE_MAX_REQUESTS = 100


local peer_state_names = {
    [1] = "keepalive",
    [2] = "next",
    [4] = "failed",
}


local _M = { version = base.version }


if subsystem == "http" then
    function _M.set_current_peer(addr, port, opts)
        local r = get_request()
        if not r then
            error("no request found")
        end

        local pool_crc32
        local pool_size

        if opts then
            if type(opts) ~= "table" then
                error("bad argument #3 to 'set_current_peer' " ..
                      "(table expected, got " .. type(opts) .. ")", 2)
            end

            local pool = opts.pool
            pool_size = opts.pool_size

            if pool then
                if type(pool) ~= "string" then
                    error("bad option 'pool' to 'set_current_peer' " ..
                          "(string expected, got " .. type(pool) .. ")", 2)
                end

                pool_crc32 = ngx_crc32_long(pool)
            end

            if pool_size then
                if type(pool_size) ~= "number" then
                    error("bad option 'pool_size' to 'set_current_peer' " ..
                          "(number expected, got " .. type(pool_size) .. ")", 2)

                elseif pool_size < 1 then
                    error("bad option 'pool_size' to 'set_current_peer' " ..
                          "(expected > 0)", 2)
                end
            end
        end

        if not port then
            port = 0

        elseif type(port) ~= "number" then
            port = tonumber(port)
        end

        if not pool_crc32 then
            pool_crc32 = 0
        end

        if not pool_size then
            pool_size = DEFAULT_KEEPALIVE_POOL_SIZE
        end

        local rc = ngx_lua_ffi_balancer_set_current_peer(r, addr, #addr, port,
                                                         pool_crc32, pool_size,
                                                         errmsg)
        if rc == FFI_OK then
            return true
        end

        return nil, ffi_str(errmsg[0])
    end

else
    function _M.set_current_peer(addr, port, opts)
        local r = get_request()
        if not r then
            error("no request found")
        end

        if opts then
            error("bad argument #3 to 'set_current_peer' ('opts' not yet " ..
                  "implemented in " .. subsystem .. " subsystem)", 2)
        end

        if not port then
            port = 0

        elseif type(port) ~= "number" then
            port = tonumber(port)
        end

        local rc = ngx_lua_ffi_balancer_set_current_peer(r, addr, #addr,
                                                         port, errmsg)
        if rc == FFI_OK then
            return true
        end

        return nil, ffi_str(errmsg[0])
    end
end


if subsystem == "http" then
    function _M.enable_keepalive(idle_timeout, max_requests)
        local r = get_request()
        if not r then
            error("no request found")
        end

        if not idle_timeout then
            idle_timeout = DEFAULT_KEEPALIVE_IDLE_TIMEOUT

        elseif type(idle_timeout) ~= "number" then
            error("bad argument #1 to 'enable_keepalive' " ..
                  "(number expected, got " .. type(idle_timeout) .. ")", 2)

        elseif idle_timeout < 0 then
            error("bad argument #1 to 'enable_keepalive' (expected >= 0)", 2)

        else
            idle_timeout = idle_timeout * 1000
        end

        if not max_requests then
            max_requests = DEFAULT_KEEPALIVE_MAX_REQUESTS

        elseif type(max_requests) ~= "number" then
            error("bad argument #2 to 'enable_keepalive' " ..
                  "(number expected, got " .. type(max_requests) .. ")", 2)

        elseif max_requests < 0 then
            error("bad argument #2 to 'enable_keepalive' (expected >= 0)", 2)
        end

        local rc = ngx_lua_ffi_balancer_enable_keepalive(r, idle_timeout,
                                                         max_requests, errmsg)
        if rc == FFI_OK then
            return true
        end

        return nil, ffi_str(errmsg[0])
    end

else
    function _M.enable_keepalive()
        error("'enable_keepalive' not yet implemented in " .. subsystem ..
              " subsystem", 2)
    end
end


function _M.set_more_tries(count)
    local r = get_request()
    if not r then
        error("no request found")
    end

    local rc = ngx_lua_ffi_balancer_set_more_tries(r, count, errmsg)
    if rc == FFI_OK then
        if errmsg[0] == nil then
            return true
        end
        return true, ffi_str(errmsg[0])  -- return the warning
    end

    return nil, ffi_str(errmsg[0])
end


function _M.get_last_failure()
    local r = get_request()
    if not r then
        error("no request found")
    end

    local state = ngx_lua_ffi_balancer_get_last_failure(r, int_out, errmsg)

    if state == 0 then
        return nil
    end

    if state == FFI_ERROR then
        return nil, nil, ffi_str(errmsg[0])
    end

    return peer_state_names[state] or "unknown", int_out[0]
end


function _M.set_timeouts(connect_timeout, send_timeout, read_timeout)
    local r = get_request()
    if not r then
        error("no request found")
    end

    if not connect_timeout then
        connect_timeout = 0
    elseif type(connect_timeout) ~= "number" or connect_timeout <= 0 then
        error("bad connect timeout", 2)
    else
        connect_timeout = connect_timeout * 1000
    end

    if not send_timeout then
        send_timeout = 0
    elseif type(send_timeout) ~= "number" or send_timeout <= 0 then
        error("bad send timeout", 2)
    else
        send_timeout = send_timeout * 1000
    end

    if not read_timeout then
        read_timeout = 0
    elseif type(read_timeout) ~= "number" or read_timeout <= 0 then
        error("bad read timeout", 2)
    else
        read_timeout = read_timeout * 1000
    end

    local rc

    rc = ngx_lua_ffi_balancer_set_timeouts(r, connect_timeout,
                                           send_timeout, read_timeout,
                                           errmsg)

    if rc == FFI_OK then
        return true
    end

    return false, ffi_str(errmsg[0])
end


return _M
