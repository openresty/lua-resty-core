local base = require "resty.core.base"
local get_request = base.get_request
local ffi = require "ffi"
local C = ffi.C
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local FFI_OK = base.FFI_OK
local FFI_ERROR = base.FFI_ERROR
local FFI_DONE = base.FFI_DONE
local co_yield = coroutine._yield

local BUF_SIZE = 256
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr

base.allows_subsystem("http")

ffi.cdef [[
typedef intptr_t                         ngx_int_t;
typedef unsigned char                    u_char;
typedef struct ngx_http_lua_co_ctx_t    *curcoctx_ptr;
typedef struct ngx_http_resolver_ctx_t  *rctx_ptr;

typedef struct {
    ngx_http_request_t              *request;
    u_char                          *buf;
    size_t                          *buf_size;
    curcoctx_ptr                     curr_co_ctx;
    rctx_ptr                         rctx;
    ngx_int_t                        rc;
    unsigned                         ipv4:1;
    unsigned                         ipv6:1;
} ngx_http_lua_resolver_ctx_t;

int ngx_http_lua_ffi_resolve(ngx_http_lua_resolver_ctx_t *ctx,
    const char *hostname);

void ngx_http_lua_ffi_resolver_destroy(ngx_http_lua_resolver_ctx_t *ctx);
]]

local _M = { version = base.version }

local mt = {
    __gc = C.ngx_http_lua_ffi_resolver_destroy
}

local Ctx = ffi.metatype("ngx_http_lua_resolver_ctx_t", mt)

function _M.resolve(hostname, ipv4, ipv6)
    local buf = get_string_buf(BUF_SIZE)
    local buf_size = get_size_ptr()
    buf_size[0] = BUF_SIZE

    local ctx = Ctx()
    ctx.request = get_request()
    ctx.buf = buf
    ctx.buf_size = buf_size

    if ipv4 == nil or ipv4 then
        ctx.ipv4 = 1
    end

    if ipv6 then
        ctx.ipv6 = 1
    end

    local rc = C.ngx_http_lua_ffi_resolve(ctx, hostname)

    local res, err
    if (rc == FFI_OK) then
        res, err = ffi_str(buf, buf_size[0]), nil
    elseif (rc == FFI_DONE) then
        res, err = co_yield()
    elseif (rc == FFI_ERROR) then
        res, err = nil, ffi_str(buf, buf_size[0])
    else
        res, err = nil, "unknown error"
    end

    C.ngx_http_lua_ffi_resolver_destroy(ffi_gc(ctx, nil))

    if err ~= nil then
        return res, err
    end

    return res
end

return _M