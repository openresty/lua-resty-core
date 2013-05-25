-- Copyright (C) 2013 Yichun Zhang (agentzh)


local ffi = require 'ffi'
local ffi_string = ffi.string
local ffi_new = ffi.new
local ffi_gc = ffi.gc
local C = ffi.C
local bit = require "bit"
local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local strlen = string.len
local substr = string.sub
local byte = string.byte
local setmetatable = setmetatable
local concat = table.concat
local ngx = ngx
local type = type
local tostring = tostring
local error = error
local base = require "resty.core.base"
local get_string_buf = base.get_string_buf
local get_size_ptr = base.get_size_ptr
local floor = math.floor
local print = print
local tonumber = tonumber


if not ngx.re then
    ngx.re = {}
end


local MAX_ERR_MSG_LEN = 128


local FLAG_COMPILE_ONCE  = 0x01
local FLAG_DFA           = 0x02
local FLAG_JIT           = 0x04
local FLAG_DUPNAMES      = 0x08
local FLAG_NO_UTF8_CHECK = 0x10


local PCRE_CASELESS          = 0x0000001
local PCRE_MULTILINE         = 0x0000002
local PCRE_DOTALL            = 0x0000004
local PCRE_EXTENDED          = 0x0000008
local PCRE_ANCHORED          = 0x0000010
local PCRE_UTF8              = 0x0000800
local PCRE_DUPNAMES          = 0x0080000
local PCRE_JAVASCRIPT_COMPAT = 0x2000000


local PCRE_ERROR_NOMATCH = -1


local regex_cache = {}
local regex_cache_size = 0
local script_engine


ffi.cdef[[
    typedef struct {
        ngx_str_t                   value;
        void                       *lengths;
        void                       *values;
    } ngx_http_lua_complex_value_t;

    typedef struct {
        void                         *pool;
        unsigned char                *name_table;
        int                           name_count;
        int                           name_entry_size;

        int                           ncaptures;
        int                          *captures;

        void                         *regex;
        void                         *regex_sd;

        ngx_http_lua_complex_value_t *replace;
    } ngx_http_lua_regex_t;

    ngx_http_lua_regex_t *
        ngx_http_lua_ffi_compile_regex(const unsigned char *pat,
            size_t pat_len, int flags,
            int pcre_opts, unsigned char *errstr,
            size_t errstr_size);

    int ngx_http_lua_ffi_exec_regex(ngx_http_lua_regex_t *re, int flags,
        const unsigned char *s, size_t len, int pos);

    void ngx_http_lua_ffi_destroy_regex(ngx_http_lua_regex_t *re);

    int ngx_http_lua_ffi_compile_replace_template(ngx_http_lua_regex_t *re,
                                                  const unsigned char
                                                  *replace_data,
                                                  size_t replace_len);

    struct ngx_http_lua_script_engine_s;
    typedef struct ngx_http_lua_script_engine_s  *ngx_http_lua_script_engine_t;

    ngx_http_lua_script_engine_t *ngx_http_lua_ffi_create_script_engine(void);

    void ngx_http_lua_ffi_init_script_engine(ngx_http_lua_script_engine_t *e,
                                             const unsigned char *subj,
                                             ngx_http_lua_regex_t *compiled,
                                             int count);

    void ngx_http_lua_ffi_destroy_script_engine(
        ngx_http_lua_script_engine_t *e);

    size_t ngx_http_lua_ffi_script_eval_len(ngx_http_lua_script_engine_t *e,
                                            ngx_http_lua_complex_value_t *cv);

    size_t ngx_http_lua_ffi_script_eval_data(ngx_http_lua_script_engine_t *e,
                                             ngx_http_lua_complex_value_t *cv,
                                             unsigned char *dst, size_t len);
]]


local function parse_regex_opts(opts)
    local flags = 0
    local pcre_opts = 0
    local len = strlen(opts)

    for i = 1, len do
        local opt = byte(opts, i)
        if opt == byte("o") then
            flags = bor(flags, FLAG_COMPILE_ONCE)

        elseif opt == byte("j") then
            flags = bor(flags, FLAG_JIT)

        elseif opt == byte("i") then
            pcre_opts = bor(pcre_opts, PCRE_CASELESS)

        elseif opt == byte("s") then
            pcre_opts = bor(pcre_opts, PCRE_DOTALL)

        elseif opt == byte("m") then
            pcre_opts = bor(pcre_opts, PCRE_MULTILINE)

        elseif opt == byte("u") then
            pcre_opts = bor(pcre_opts, PCRE_UTF8)

        elseif opt == byte("U") then
            pcre_opts = bor(pcre_opts, PCRE_UTF8)
            flags = bor(flags, FLAG_NO_UTF8_CHECK)

        elseif opt == byte("x") then
            pcre_opts = bor(pcre_opts, PCRE_EXTENDED)

        elseif opt == byte("d") then
            flags = bor(flags, FLAG_DFA)

        elseif opt == byte("a") then
            pcre_opts = bor(pcre_opts, PCRE_ANCHORED)

        elseif opt == byte("D") then
            pcre_opts = bor(pcre_opts, PCRE_DUPNAMES)
            flags = bor(flags, FLAG_DUPNAMES)

        elseif opt == byte("J") then
            pcre_opts = bor(pcre_opts, PCRE_JAVASCRIPT_COMPAT)

        else
            return error("unknown flag \"" .. substr(opts, i, i) .. "\"")
        end
    end

    return flags, pcre_opts
end


local function collect_captures(compiled, rc, subj)
    local cap = compiled.captures

    if rc == 1 then
        local from = cap[0]
        if from >= 0 then
            return {[0] = substr(subj, from + 1, cap[1])}
        end
        return nil
    end

    local m = {}
    local i = 0
    local n = 0
    while i < rc do
        local from = cap[n]
        if from >= 0 then
            local to = cap[n + 1]
            m[i] = substr(subj, from + 1, to)
        end
        i = i + 1
        n = n + 2
    end

    return m
end


local function destroy_compiled_regex(compiled)
    C.ngx_http_lua_ffi_destroy_regex(ffi_gc(compiled, nil))
end


local function collect_named_captures(compiled, flags, res)
    local name_count = compiled.name_count
    local name_table = compiled.name_table
    local entry_size = compiled.name_entry_size

    local ind = 0
    local dup_names = (band(flags, FLAG_DUPNAMES) ~= 0)
    for i = 1, name_count do
        local n = bor(lshift(name_table[ind], 8), name_table[ind + 1])
        -- ngx.say("n = ", n)
        local name = ffi_string(name_table + ind + 2)
        local cap = res[n]
        if cap then
            if dup_names then
                local old = res[name]
                if old then
                    old[#old + 1] = cap
                else
                    res[name] = {cap}
                end
            else
                res[name] = cap
            end
        end

        ind = ind + entry_size
    end
end


local function re_match(subj, regex, opts, ctx)
    local flags = 0
    local pcre_opts = 0
    local pos

    if opts then
        flags, pcre_opts = parse_regex_opts(opts)
    else
        opts = ""
    end

    if ctx then
        pos = ctx.pos or 0
    else
        pos = 0
    end

    local key, compiled
    local compile_once = (band(flags, FLAG_COMPILE_ONCE) == 1)
    if compile_once then
        key = regex .. "\0" .. pcre_opts
        -- print("key: ", key)
        compiled = regex_cache[key]
    end

    -- compile the regex

    if compiled == nil then
        -- print("compiled regex not found, compiling regex...")
        local errbuf = get_string_buf(MAX_ERR_MSG_LEN)

        compiled = C.ngx_http_lua_ffi_compile_regex(regex, strlen(regex),
                                                    flags, pcre_opts,
                                                    errbuf, MAX_ERR_MSG_LEN)

        if compiled == nil then
            return nil, ffi_string(errbuf)
        end

        ffi_gc(compiled, C.ngx_http_lua_ffi_destroy_regex)

        -- print("ncaptures: ", compiled.ncaptures)

        if compile_once then
            -- TODO: add support for lua_regex_cache_max_entries.
            if regex_cache_size < 1024 then
                -- print("inserting compiled regex into cache")
                regex_cache[key] = compiled
                regex_cache_size = regex_cache_size + 1
            else
                compile_once = false
            end
        end
    end

    -- exec the compiled regex

    local rc = C.ngx_http_lua_ffi_exec_regex(compiled, flags, subj,
                                             strlen(subj), pos)
    if rc == PCRE_ERROR_NOMATCH then
        if not compile_once then
            destroy_compiled_regex(compiled)
        end
        return nil
    end

    if rc < 0 then
        if not compile_once then
            destroy_compiled_regex(compiled)
        end
        return nil, "pcre_exec() failed: " .. rc
    end

    if rc == 0 then
        if band(flags, FLAG_DFA) == 0 then
            return nil, "capture size too small"
        end

        rc = 1
    end

    -- print("cap 0: ", compiled.captures[0])
    -- print("cap 1: ", compiled.captures[1])

    local res = collect_captures(compiled, rc, subj)

    local name_count = compiled.name_count
    if name_count > 0 then
        collect_named_captures(compiled, flags, res)
    end

    if ctx then
        ctx.pos = compiled.captures[1]
    end

    if not compile_once then
        destroy_compiled_regex(compiled)
    end

    return res
end


local function new_script_engine(subj, compiled, count)
    if not script_engine then
        script_engine = C.ngx_http_lua_ffi_create_script_engine()
        if script_engine == nil then
            return nil
        end
        ffi_gc(script_engine, C.ngx_http_lua_ffi_destroy_script_engine)
    end

    C.ngx_http_lua_ffi_init_script_engine(script_engine, subj, compiled,
                                          count)
    return script_engine
end


local function re_sub_helper(subj, regex, replace, opts, global)
    local flags = 0
    local pcre_opts = 0
    local pos

    if opts then
        flags, pcre_opts = parse_regex_opts(opts)
    else
        opts = ""
    end

    local func
    local repl_type = type(replace)
    if repl_type == "function" then
        func = replace

    elseif repl_type ~= "string" then
        replace = tostring(replace)
    end

    local key, compiled
    local compile_once = (band(flags, FLAG_COMPILE_ONCE) == 1)
    if compile_once then
        if func then
            key = regex .. "\0" .. pcre_opts
        else
            key = regex .. "\0" .. pcre_opts .. "\0" .. replace
        end
        -- print("key: ", key)
        compiled = regex_cache[key]
    end

    -- compile the regex

    if compiled == nil then
        -- print("compiled regex not found, compiling regex...")
        local errbuf = get_string_buf(MAX_ERR_MSG_LEN)

        compiled = C.ngx_http_lua_ffi_compile_regex(regex, strlen(regex),
                                                    flags, pcre_opts,
                                                    errbuf, MAX_ERR_MSG_LEN)

        if compiled == nil then
            return nil, nil, ffi_string(errbuf)
        end

        ffi_gc(compiled, C.ngx_http_lua_ffi_destroy_regex)

        if func == nil then
            local rc =
                C.ngx_http_lua_ffi_compile_replace_template(compiled, replace,
                                                            strlen(replace))
            if rc ~= 0 then
                if not compile_once then
                    destroy_compiled_regex(compiled)
                end
                return nil, nil, "failed to compile the replacement template"
            end
        end

        -- print("ncaptures: ", compiled.ncaptures)

        if compile_once then
            -- TODO: add support for lua_regex_cache_max_entries.
            if regex_cache_size < 1024 then
                -- print("inserting compiled regex into cache")
                regex_cache[key] = compiled
                regex_cache_size = regex_cache_size + 1
            else
                compile_once = false
            end
        end
    end

    -- exec the compiled regex

    local name_count = compiled.name_count
    local new_bits = {}
    local n = 0

    local subj_len = strlen(subj)
    local count = 0
    local pos = 0
    local cp_pos = 0

    local replace_literal

    while true do
        local rc = C.ngx_http_lua_ffi_exec_regex(compiled, flags, subj,
                                                 subj_len, pos)
        if rc == PCRE_ERROR_NOMATCH then
            break
        end

        if rc < 0 then
            if not compile_once then
                destroy_compiled_regex(compiled)
            end
            return nil, nil, "pcre_exec() failed: " .. rc
        end

        if rc == 0 then
            if band(flags, FLAG_DFA) == 0 then
                return nil, nil, "capture size too small"
            end

            rc = 1
        end

        count = count + 1

        if func ~= nil then
            local res = collect_captures(compiled, rc, subj)

            if name_count > 0 then
                collect_named_captures(compiled, flags, res)
            end

            local bit = func(res)
            new_bits[n + 1] = substr(subj, cp_pos + 1, compiled.captures[0])
            new_bits[n + 2] = bit
            n = n + 2

        else
            local cv = compiled.replace
            if cv.lengths ~= nil then
                local e = new_script_engine(subj, compiled, rc)
                if e == nil then
                    return nil, nil, "failed to create script engine"
                end

                local len = C.ngx_http_lua_ffi_script_eval_len(e, cv)
                local dst = get_string_buf(len)
                C.ngx_http_lua_ffi_script_eval_data(e, cv, dst, len)

                new_bits[n + 1] = substr(subj, cp_pos + 1, compiled.captures[0])
                new_bits[n + 2] = ffi_string(dst, len)
                n = n + 2

            else
                -- compiled.replace.lengths == nil
                new_bits[n + 1] = substr(subj, cp_pos + 1, compiled.captures[0])

                if replace_literal == nil then
                    replace_literal = ffi_string(cv.value.data, cv.value.len)
                end
                new_bits[n + 2] = replace_literal
                n = n + 2
            end
        end

        cp_pos = compiled.captures[1]
        pos = cp_pos
        if pos == compiled.captures[0] then
            pos = pos + 1
            if pos > subj_len then
                break
            end
        end

        if not global then
            break
        end
    end

    if not compile_once then
        destroy_compiled_regex(compiled)
    end

    if count > 0 then
        if pos < subj_len then
            new_bits[n + 1] = substr(subj, cp_pos + 1)
        end
        return concat(new_bits), count
    end

    return subj, 0
end


local function re_sub(subj, regex, replace, opts)
    return re_sub_helper(subj, regex, replace, opts, false)
end


local function re_gsub(subj, regex, replace, opts)
    return re_sub_helper(subj, regex, replace, opts, true)
end


ngx.re.match = re_match
ngx.re.sub = re_sub
ngx.re.gsub = re_gsub


return {
    version = base.version
}
