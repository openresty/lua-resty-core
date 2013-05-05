-- Copyright (C) 2013 Yichun Zhang (agentzh)


local ffi = require 'ffi'
local ffi_new = ffi.new
local error = error
local setmetatable = setmetatable
local floor = math.floor


local str_buf_size = 4096
local str_buf
local size_ptr


local M = {
    version = "0.0.1"
}


if not ngx then
    return error("no existing ngx. table found")
end


function M.set_string_buf_size(size)
    if size <= 0 then
        return
    end
    if str_buf then
        str_buf = nil
    end
    str_buf_size = floor(size)
end


function M.get_size_ptr()
    if not size_ptr then
        size_ptr = ffi_new("size_t[1]")
    end

    return size_ptr
end


function M.get_string_buf(size)
    if size > str_buf_size then
        return ffi_new("unsigned char[?]", size)
    end

    if not str_buf then
        str_buf = ffi_new("unsigned char[4096]")
    end

    return str_buf
end


return M
