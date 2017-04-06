local nettle     = require "resty.nettle"
local ffi        = require "ffi"
local ffi_new    = ffi.new
local ffi_typeof = ffi.typeof
local ffi_cdef   = ffi.cdef
local ffi_str    = ffi.string

ffi_cdef[[
typedef struct gosthash94_ctx {
  uint32_t hash[8];
  uint32_t sum[8];
  uint8_t message[32];
  uint64_t length;
} GOSTHASH94_CTX;
void nettle_gosthash94_init(struct gosthash94_ctx *ctx);
void nettle_gosthash94_update(struct gosthash94_ctx *ctx, size_t length, const uint8_t *data);
void nettle_gosthash94_digest(struct gosthash94_ctx *ctx, size_t length, uint8_t *digest);
]]

local ctx = ffi_typeof("GOSTHASH94_CTX[1]")
local buf = ffi_new("uint8_t[?]", 32)
local gosthash94 = setmetatable({}, {
    __call = function(_, data)
        local context = ffi_new(ctx)
        nettle.nettle_gosthash94_init(context)
        nettle.nettle_gosthash94_update(context, #data, data)
        nettle.nettle_gosthash94_digest(context, 32, buf)
        return ffi_str(buf, 32)
    end
})
gosthash94.__index = gosthash94

function gosthash94.new()
    local self = setmetatable({ context = ffi_new(ctx) }, gosthash94)
    nettle.nettle_gosthash94_init(self.context)
    return self
end

function gosthash94:update(data)
    return nettle.nettle_gosthash94_update(self.context, #data, data)
end

function gosthash94:digest()
    nettle.nettle_gosthash94_digest(self.context, 32, buf)
    return ffi_str(buf, 32)
end

return gosthash94