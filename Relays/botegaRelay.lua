-- Process ID: rjwvEeBi3-4KIoQbDfZoaH-YZFXK8dueWcPpDEAhRKY
-- Spawned by: aos botega_relay --module=GYrbbe0VbHim_7Hi6zrOpHQXrSQz07XNtwCnfbFo2I0
local json = require("json")
local sqlite3 = require("lsqlite3")

db = db or sqlite3.open_memory()
dbAdmin = require('DbAdmin').new(db)

PROVIDER = "MTGWOso92fDit9lRQ376cE5TlhX45OUQ79ogPeZWYGA"

-- Here we store the latest Botega pool overview data from the fetcher
LATEST_POOL_OVERVIEW = "{}"
-- Here we store the latest Botega volume data from the fetcher
LATEST_VOLUME = "{}"

SCHEMA = [[
  CREATE TABLE IF NOT EXISTS HISTORY (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Data TEXT NOT NULL,
    CreatedAt INTEGER DEFAULT (strftime('%s', 'now'))
  );
]]

function InitDb()
    print("--InitDb--")
    db:exec("DROP TABLE IF EXISTS HISTORY;")
    local result = db:exec(SCHEMA)
    if result ~= sqlite3.OK then
      print("Error initializing database: " .. db:errmsg())
      return
    end
    print("SCHEMA initialized successfully.")
  end

function GetTimestamp(msg)
    local timestamp_ms = msg["Timestamp"]
    local timestamp_seconds = math.floor(timestamp_ms / 1000)
    local timestamp = timestamp_seconds
    return timestamp
end

Handlers.add("InitDBs", "init-db", function (msg)  
    if msg.From ~= ao.id then
        return
    end

    InitDb()
end)

-- Set Botega Latest Pool Data
Handlers.add("SetLatestData", "set-latest-data", function (msg) 
    
    -- Make sure the data is from a trusted process
    if msg.From ~= PROVIDER and msg.From ~= ao.id then
        print("Error: Data from untrusted process")
        return
    end

    print(" ------- SetLatestData Handler Called ------- ")

    local raw_json = msg.Data
    if type(raw_json) == "string" then
        raw_json = raw_json:gsub('^"', ''):gsub('"$', '')
    end

    local data = json.decode(raw_json)
    if data then
        -- Store the decoded data, not the JSON string
        LATEST_POOL_OVERVIEW = data
        -- print("Latest data set: " .. json.encode(data))
        ao.send({
            Target = msg.From,
            Action = "Latest-Data-Response",
            Data = "Latest data set"
        })
        StoreLatestData(raw_json)
        return true
    else
        print("Error: Failed to decode JSON data")
        ao.send({
            Target = msg.From,
            Action = "Latest-Data-Response",
            Data = "Error: Failed to decode JSON data"
        })
    end
end)

-- Set Botega Volume
Handlers.add("SetVolume", "set-volume", function (msg) 
    
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
      -- Store the decoded data, not the JSON string
      LATEST_VOLUME = data
      ao.send({ Target = msg.From, Action = "Volume-Response", Data = "Volume data set" })
      return true
  else
      print("Error: Failed to decode JSON data")
      ao.send({ Target = msg.From, Action = "Volume-Response", Data = "Error: Failed to decode JSON data" })
  end
end)

function StoreLatestData(data)
    local insertQuery = string.format([[
        INSERT INTO HISTORY (Data) VALUES ('%s')
    ]], data)
    local result = db:exec(insertQuery)
    if result ~= sqlite3.OK then
        print("Error storing latest data: " .. db:errmsg())
        return false
    else
        print("Latest data stored successfully")
        return true
    end
end

Handlers.add("GetLatestData", "get-latest-data", function (msg) 
    print("--GetLatestData Handler Called--")
    -- Does process hold token? If not, return error

    if LATEST_POOL_OVERVIEW then
        -- Encode the data as JSON when sending it back
        -- local jsonData = json.encode(LATEST_POOL_OVERVIEW)
        print("Latest data: " .. jsonData)
        ao.send({ Target = msg.From, Action = "Latest-Data-Response", Data = jsonData })
    else
        print("Error: Failed to get latest data") 
        ao.send({ Target = msg.From, Action = "Latest-Data-Response", Data = "Error: Failed to get latest data" })
    end
end)

-- Get Botega Volume
Handlers.add("GetVolume", "get-volume", function (msg) 
    print("--GetVolume Handler Called--")
    -- Encode the data as JSON when sending it back
    local jsonData = json.encode(LATEST_VOLUME)
    ao.send({ Target = msg.From, Action = "Volume-Response", Data = jsonData })
end)

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
        -- Store the entire JSON data as a single record
        local insertQuery = string.format([[
            INSERT INTO HISTORY (Data) VALUES ('%s')
        ]], raw_json)
        
        local result = db:exec(insertQuery)
        if result ~= sqlite3.OK then
            print("Error storing data: " .. db:errmsg())
            return false
        else
            print("Stored complete data snapshot")
        end
        return true

    else
        print("Error: Failed to decode JSON data")
    end
end)

Handlers.add("ListHistory", "list-history", function (msg)
    print("--ListHistory Handler Called--")
    print("Message From: " .. (msg.From or "Unknown"))
    print("Message Action: " .. (msg.Action or "Unknown"))
    print("ao.id: " .. (ao.id or "Unknown"))
    
    print("--ListHistory--")
    print("=== HISTORY DATABASE CONTENTS ===")
    
    -- Get all data entries
    local query = [[
        SELECT 
            ID,
            Data,
            datetime(CreatedAt, 'unixepoch') as readable_time
        FROM HISTORY
        ORDER BY CreatedAt DESC
    ]]
    
    print("Executing query: " .. query)
    
    -- Use direct SQLite methods
    local result = {}
    local stmt = db:prepare(query)
    if stmt then
        for row in stmt:nrows() do
            table.insert(result, row)
        end
        stmt:finalize()
    else
        print("Error preparing statement: " .. db:errmsg())
        return
    end
    
    print("Query result: " .. (result and #result or "nil"))
    
    if result and #result > 0 then
        print(string.format("Found %d price entries:", #result))
        print("")
        
        for i, row in ipairs(result) do
            print(string.format("=== ENTRY %d ===", i))
            print(string.format("ID: %d", row.ID or 0))
            print(string.format("Created: %s", row.readable_time or "Unknown"))
            print("Data:")
            
            -- Parse and display the JSON data
            local data = json.decode(row.Data or "{}")
            if data then
                for asset, assetData in pairs(data) do
                    if type(assetData) == "table" and assetData.price then
                        print(string.format("  %s: $%.8f (conf: %d, expo: %d, t: %d)", 
                            asset, 
                            assetData.price or 0, 
                            assetData.conf or 0, 
                            assetData.expo or 0, 
                            assetData.t or 0))
                    end
                end
            else
                print("  (Invalid JSON data)")
            end
            
            print("")
        end
        
        -- Print summary statistics
        local statsQuery = [[
            SELECT 
                COUNT(*) as total_entries,
                MIN(CreatedAt) as earliest_timestamp,
                MAX(CreatedAt) as latest_timestamp
            FROM HISTORY
        ]]
        
        local stats = {}
        local statsStmt = db:prepare(statsQuery)
        if statsStmt then
            for row in statsStmt:nrows() do
                table.insert(stats, row)
            end
            statsStmt:finalize()
        end
        
        if stats and #stats > 0 then
            local stat = stats[1]
            print("=== SUMMARY STATISTICS ===")
            print(string.format("Total Entries: %d", stat.total_entries or 0))
            print(string.format("Earliest Entry: %s", os.date("%Y-%m-%d %H:%M:%S", stat.earliest_timestamp or 0)))
            print(string.format("Latest Entry: %s", os.date("%Y-%m-%d %H:%M:%S", stat.latest_timestamp or 0)))
        end

        ao.send({
            Target = msg.From,
            Action = "List-History-Response",
            Data = string.format("Found %d price entries", #result)
        })
        
    else
        print("No price entries found in database.")
        print("Try adding some entries first using 'set-data'")
        ao.send({
            Target = msg.From,
            Action = "List-History-Response",
            Data = "No price entries found in database."
        })
    end
    
    print("=== END HISTORY DATABASE CONTENTS ===")
end)

Handlers.add("IsActive", "is-active", function (msg)
  ao.send({ Target = msg.From, Action = "Is-Active-Response", Data = "true" })
end)

Handlers.add("Info", "Info", function (msg)

  ao.send({ Target = msg.From, Action = "Info-Response", 
  ["Name"] = "Botega-Relay", 
  ["Volume"] = LATEST_VOLUME, 
  ["Overview"] = LATEST_POOL_OVERVIEW,
  ["Version"] = "0.0.1a",
  ["Author"] = "FUDBear",
  })
end)