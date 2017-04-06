local strbuf = {}
local strbuf_mt = {
    __index = strbuf,
    __tostring = function(self) 
        return table.concat(self)
    end,
    __concat = function(v1, v2)
        return type(v1) == 'table' and (table.concat(v1) .. v2) or (v1 .. table.concat(v2))
    end
}

function strbuf.new()
    return setmetatable({}, strbuf_mt)
end

function strbuf.append(self, ...)
    for i, v in ipairs({...}) do
        if type(v) == 'string' then
            if #v > 0 then
                table.insert(self, v)
            end
        elseif type(v) == 'table' then
            local mt = getmetatable(v)
            if mt == strbuf_mt then
                for ii, vv in ipairs(v) do
                    table.insert(self, vv)
                end
            else
                error('invalid value (table) at index ' .. i .. ' in strbuf for \'append\'')
            end
        else
            table.insert(self, tostring(v))
        end
    end
end

function strbuf.length(self)
    local l = 0
    for i, v in ipairs(self) do
        l = l + #v
    end
    return l
end
function strbuf.reset(self)
    local n = self:length()
    while n > 0 do
        table.remove(self)
        n = n - 1
    end
end

function strbuf.delete(self)
    self:reset()
end

return strbuf
