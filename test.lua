local mongol = require "resty.mongol"
ngx.header['Content-Type'] = 'text/html' 
local monl = mongol:new()
monl:set_timeout(30000)  --30 sec

local ok, err = monl:connect('10.0.200.15', 30030)
if err then
    error('connect mongodb failed! : ' .. err)
    return
end

-- auth mongoDB2.8
local db = monl:new_db_handle('admin')
ok, err = db:auth_scram_sha1('chivox', 'chisheng')
if err then
    error('authorize failed! : ' .. err)
    monl:close()
    return
end

local device_col = monl:new_db_handle('authorize'):get_col('device')

-- local cursorid, r, t = device_col:query({appKey="1440647545000006"}, { _id = 0 }, 0, 100)

-- ngx.say('cursorid-----' .. cursorid)

-- if t then
--     ngx.say(cjson.encode(t))
-- end
-- local x = 1
-- if r then
--     for i,v in ipairs(r) do
--         ngx.log(ngx.ERR, cjson.encode(v))
--         x = x + 1
--     end
-- end

local device_cursor = device_col:find({appKey="14255202120000cf"})
local devices = {}
for index, item in device_cursor:pairs() do
    for k,v in pairs(item) do
        if k == "_id" then
            local oid =  v.tostring(v)
            ngx.log(ngx.ERR, oid)
            table.insert(devices, oid)
        else
            ngx.log(ngx.ERR, k .. " : " .. v)
        end
    end

end
ngx.log(ngx.ERR, "xxxxx---------------------" .. #devices)
ngx.say(cjson.encode(devices))