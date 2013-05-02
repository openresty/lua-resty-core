-- Copyright (C) 2013 Yichun Zhang (agentzh)


local ffi = require 'ffi'
local ffi_new = ffi.new
local error = error
local setmetatable = setmetatable
local floor = math.floor


module(...)


local str_buf_size = 4096
local str_buf
local size_ptr


function set_string_buf_size(size)
    if size <= 0 then
        return
    end
    if str_buf then
        str_buf = nil
    end
    str_buf_size = floor(size)
end


function get_size_ptr()
    if not size_ptr then
        size_ptr = ffi_new("size_t[1]")
    end

    return size_ptr
end

function get_string_buf(size)
    if size > str_buf_size then
        return ffi_new("unsigned char[?]", size)
    end

    if not str_buf then
        str_buf = ffi_new("unsigned char[4096]")
    end

    return str_buf
end


local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
        error('attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)
