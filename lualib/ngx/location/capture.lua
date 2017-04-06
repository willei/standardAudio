local capture = ngx.location.capture
local client = require('http.client')

function ngx.location.capture(url, options)
    if string.byte(url) == 47 then -- internal subrequest
        return capture(url, options)
    else
        return client.request(url, options)
    end
end