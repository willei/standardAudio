require "resty.nettle.types.chacha"

local ffi        = require "ffi"
local ffi_new    = ffi.new
local ffi_typeof = ffi.typeof
local ffi_cdef   = ffi.cdef
local ffi_str    = ffi.string
local nettle     = require "resty.nettle"

ffi_cdef[[
void nettle_chacha_set_key(struct chacha_ctx *ctx, const uint8_t *key);
void nettle_chacha_set_nonce(struct chacha_ctx *ctx, const uint8_t *nonce);
void nettle_chacha_crypt(struct chacha_ctx *ctx, size_t length, uint8_t *dst, const uint8_t *src);
]]

local uint8t = ffi_typeof("uint8_t[?]")

local chacha = {}
chacha.__index = chacha

local context  = ffi_typeof("CHACHA_CTX[1]")
local setkey   = nettle.nettle_chacha_set_key
local setnonce = nettle.nettle_chacha_set_nonce
local crypt    = nettle.nettle_chacha_crypt

function chacha.new(key, nonce)
    local kl = #key
    assert(kl == 32, "The ChaCha supported key size is 256 bits.")
    local nl = #nonce
    assert(nl == 8, "The ChaCha supported nonce size is 64 bits.")
    local ct = ffi_new(context)
    setkey(ct, key)
    setnonce(ct, nonce)
    return setmetatable({ context = ct }, chacha)
end

function chacha:encrypt(src)
    local len = #src
    local dst = ffi_new(uint8t, len)
    crypt(self.context, len, dst, src)
    return ffi_str(dst, len)
end

function chacha:decrypt(src)
    local len = #src
    local dst = ffi_new(uint8t, len)
    crypt(self.context, len, dst, src)
    return ffi_str(dst, len)
end

return chacha
