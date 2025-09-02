-- Process ID: NHS0P0kc_Y-zJRYAmWScgavHPff-gTCLC7CcQX2hqvI
-- Spawned by: aos ASTRO_Relay --module=Do_Uc2Sju_ffp6Ev0AnLVdPtot15rvMjP-a9VVaA5fM
local json = require("json")

PROVIDER = "MTGWOso92fDit9lRQ376cE5TlhX45OUQ79ogPeZWYGA"

-- Here we store the latest data from the fetcher
LATEST_DATA = "{}"

function GetTimestamp(msg)
    local timestamp_ms = msg["Timestamp"]
    local timestamp_seconds = math.floor(timestamp_ms / 1000)
    local timestamp = timestamp_seconds
    return timestamp
end

Handlers.add("SetData", "set-data", function (msg) 
    
    -- Make sure the data is from a trusted process
    if msg.From ~= PROVIDER and msg.From ~= ao.id then
        print("Error: Data from untrusted process")
        return
    end

    local raw_json = msg.Data
    if type(raw_json) == "string" then
        raw_json = raw_json:gsub('^"', ''):gsub('"$', '')
    end

    local data = json.decode(raw_json)
    if data then
        LATEST_DATA = raw_json
        local outcome = "Latest data set: " .. LATEST_DATA
        print("Latest data set: " .. LATEST_DATA)
        ao.send({
            Target = msg.From,
            Action = "Set-Data-Response",
            Data = outcome
        })
        return true
    else
        print("Error: Failed to decode JSON data")
        ao.send({
            Target = msg.From,
            Action = "Set-Data-Response",
            Data = "Error: Failed to decode JSON data"
        })
    end
end)


Handlers.add("GetLatestData", "get-latest-data", function (msg) 
    print("--GetLatestData Handler Called--")
    -- Does process hold token? If not, return error

    if LATEST_DATA then
        ao.send({
            Target = msg.From,
            Action = "Latest-Data-Response",
            Data = LATEST_DATA
        })
    else
        print("Error: Failed to get latest data")
        ao.send({
            Target = msg.From,
            Action = "Latest-Data-Response",
            Data = "Error: Failed to get latest data"
        })
    end
end)

Handlers.add("IsActive", "is-active", function (msg)
    ao.send({ Target = msg.From, Action = "Is-Active-Response", Data = "true" })
end)

Handlers.add("Info", "Info", function (msg)

    ao.send({ Target = msg.From, Action = "Info-Response", 
        ["Name"] = "ASTRO-Relay", 
        ["Data"] = LATEST_DATA, 
        ["Version"] = "0.0.1a",
        ["Author"] = "FUDBear",
    })
end)