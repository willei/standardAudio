local strbuf = require('ginger.strbuf')
local client = {}

-- protocol://host[:port]/path/[?query]#fragment
local function parse_url(url)

    local parsed = {
        protocol = 'http',
        hostname = '',
        port = 80,
        path = '/',
        query = '',
        fragment = ''
    }

    local si, ei = string.find(url, '://')
    if si then
        parsed.protocol = string.sub(url, 1, si - 1) 
        url = string.sub(url, ei + 1)
    end

    local si, ei = string.find(url, '#')
    if si then
        parsed.fragment = string.sub(url, ei + 1)
        url = string.sub(url, 1, si - 1)
    end

    local si, ei = string.find(url, '?')
    if si then
        parsed.query = string.sub(url, ei + 1)
        url = string.sub(url, 1, si - 1)
    end

    local si, ei = string.find(url, '/')
    if si then
        parsed.path = string.sub(url, ei)
        url = string.sub(url, 1, si - 1)
    end

    local si, ei = string.find(url, ':')
    if si then
        parsed.port = string.sub(url, ei + 1)
        url = string.sub(url, 1, si - 1)
    end

    parsed.host = url

    return parsed
end


local methods = {}
methods[ngx.HTTP_GET]    = 'GET'
methods[ngx.HTTP_POST]   = 'POST'
methods[ngx.HTTP_PUT]    = 'PUT'
methods[ngx.HTTP_DELETE] = 'DELETE'

function client.request(url, options, chunk_handler)

    local starttime = ngx.now()

    options = type(options) == 'table' and options or {}
    options.method = options.method == nil and 'GET' or (type(options.method == 'number') and methods[options.method] or options.method)
    options.args = (not options.args) and '' or (type(options.args) == 'table' and ngx.encode_args(options.args) or options.args)
    options.header = type(options.header) == 'table' and options.header or {} -- only support Content-Type
    options.body = (not options.body) and '' or options.body
    options.keepalive = type(options.keepalive) == 'number' and options.keepalive or nil
    options.timeout = type(options.timeout) == 'number' and options.timeout or nil

    local parsed = parse_url(url)

    local query = strbuf.new()
    query:append(parsed.query, (#parsed.query > 0 and #options.args > 0) and '&' or '', options.args)

    local data = strbuf.new()
    if options.method == 'GET' or options.method == 'DELETE' then
        data:append(options.method, ' ', parsed.path, #query > 0 and '?' or '', query, ' HTTP/1.1\r\n',
                    'Host: ', parsed.host, '\r\n',
                    '\r\n')
    elseif options.method == 'POST' or options.method == 'PUT' then
        local multipart = false
        if type(options.body) == 'table' then
            for k, v in pairs(options.body) do
                if type(v) == 'table' then
                    multipart = true
                    break
                end
            end
        end

        local body = strbuf.new()
        if not multipart then
            body:append(type(options.body) == 'table' and cjson.encode(options.body) or options.body)
            data:append(options.method, ' ', parsed.path, #query > 0 and '?' or '', query, ' HTTP/1.1\r\n',
                        'Host: ', parsed.host, '\r\n',
                        'Content-Type: ', options.header['Content_Type'] and options.header['Content_Type'] or 'application/x-www-form-urlencoded', '\r\n',
                        'Content-Length: ', body:length(), '\r\n',
                        '\r\n',
                        body)
        else
            local boundary = 'shun' .. os.time()
            for k, v in pairs(options.body) do
                if type(v) == 'table' then
                    body:append('--', boundary, '\r\nContent-Disposition: form-data; name="', k, '"; filename="', v.filename, '"\r\nContent-Type: application/octet-stream\r\n\r\n', v.data, '\r\n')
                elseif v ~= nil then
                    body:append('--', boundary, '\r\nContent-Disposition: form-data; name="', k, '"\r\n\r\n', v, '\r\n')
                end
            end
            body:append('--', boundary, '--\r\n')
            data:append(options.method, ' ', parsed.path, #query > 0 and '?' or '', query, ' HTTP/1.1\r\n',
                        'Host: ', parsed.host, '\r\n',
                        'Content-Type: multipart/form-data; boundary=', boundary, '\r\n',
                        'Content-Length: ', body:length(), '\r\n',
                        '\r\n',
                        body)
        end
    end

    local tcpsock = ngx.socket.tcp()
    if options.timeout then
        tcpsock:settimeout(options.timeout)
    end

    local ok, err = tcpsock:connect(parsed.host, parsed.port)
    if err then return nil, err end

    local _, err = tcpsock:send(data)
    
    if err then return nil, err end 

    local response = {status = ngx.HTTP_OK, info = 'OK', header = {}, body = ''}

    local line, err = tcpsock:receive("*l")
    if err then return nil, err end
    _, _, response.status, response.info = string.find(line, '^HTTP/1.[01]%s(%d+)%s(.*)$', 1, false)
    response.status = tonumber(response.status)

    while true do
        local line, err = tcpsock:receive('*l')
        if err then return nil, err end
        if #line == 0 then break end

        local _, _, k, v = string.find(line, '^([^:]+):%s+(.*)$')
        if k and v then
            response.header[string.lower(k)] = v
        end
    end

    if response.header['content-length'] then
        if response.header['content-length'] ~= '0' then
            response.body, err = tcpsock:receive(tonumber(response.header['content-length']))
            if err then return nil, err end
        else
            response.body = ''
        end
    elseif response.header['connection'] == 'close' then
        response.body, err = tcpsock:receive('*a')
        if err then return nil, err end
    elseif response.header['transfer-encoding'] == 'chunked' then
        -- https://en.wikipedia.org/wiki/Chunked_encoding
        local body = strbuf.new()
        while true do
            local chunk_size, err = tcpsock:receive('*l')
            if err then return nil, err end

            local chunk_data, err = tcpsock:receive(tonumber(chunk_size, 16))
            if err then return nil, err end

            if chunk_handler then
                local ok = chunk_handler(chunk_data)
                if not ok then
                    break
                end
            else
                body:append(chunk_data)
            end

            local _, err = tcpsock:receive('*l') -- discard empty line CRLF
            if err then return nil, err end

            if tonumber(chunk_size, 16) == 0 then
                break
            end
        end

        response.body = tostring(body)
    end

    if options.keepalive then
        tcpsock:setkeepalive(options.keepalive)
    else
        tcpsock:close()
    end

    response.request_time = ngx.now() - starttime

    return response

end


return client
