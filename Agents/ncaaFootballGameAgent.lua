-- Spawn: aos NCAAGameAgent --module=Do_Uc2Sju_ffp6Ev0AnLVdPtot15rvMjP-a9VVaA5fM --cron 30-seconds
-- NOTE: This version of the agent is spawned from a process not aoconnect, some features or data might be slightly diffrent from the game agent spawned from Weavepoint
local json = require("json")

NCAA_RELAY = "ruKqeINStWIE0YK0gxJkgXWFJci6irA07JxbJJLOcBE"
LATEST_RELAY_DATA = "{}" -- All the data from teh ncaa relay
LATEST_GAME_DATA = "{}" -- The data for the game we are tracking
STOP_FLAG = "false" -- "true" to stop the agent
TICKS = 0 -- Just keeps track of # of cron ticks

GAME_INITIALIZED = false
SPORT = ""
ORGANIZATION = ""
HOME_TEAM = ""
AWAY_TEAM = ""
GAME_ID = "" -- temp id -- id of the game to track
GAME_STATUS = "" -- Status of the game [Final, In Progress, Scheduled]
GAME_NAME = "" -- Name of the game


VOTING_DATA = "{}" -- Data for the voting

-- APUS
APUS_PREDICTION_AGENT = "n0fNFdVjMSXzFH_nQVyhb5UG6MA4kC00lKz7A3UyzXM" -- old "AJFWbK51AsqRLaWfI-xdmFB1ZZcLeuLD3g5QftO1LFw"
APUS_PREDICTION_INITIALIZED = false
APUS_AI_COMMENT = ""; -- AI Comment of the game
APUS_PREDICTION = ""; -- The prediction APUS AI Makes
SENT_APUS_PREDICTION = false; -- The flag to check if the prompt was sent to APUS


Handlers.add("Info", "Info", function (msg)
    ao.send({ Target = msg.From, Action = "Info-Response", 
        ["Name"] = "TEST GAME AGENT", 
        ["GAME_ID"] = GAME_ID,
        ["SPORT"] = SPORT,
        ["ORGANIZATION"] = ORGANIZATION,
        ["HOME_TEAM"] = HOME_TEAM,
        ["AWAY_TEAM"] = AWAY_TEAM,
        ["GAME_STATUS"] = GAME_STATUS,
        ["APUS_AI_COMMENT"] = APUS_AI_COMMENT,
        ["APUS_AI_PREDICTION"] = APUS_PREDICTION,
        ["VOTING_DATA"] = VOTING_DATA,
        ["LATEST_GAME_DATA"] = LATEST_GAME_DATA,
        ["Version"] = "0.0.1a",
        ["TICKS"] = TICKS,
        ["STOP_FLAG"] = STOP_FLAG,
        ["SENT_APUS_PREDICTION"] = SENT_APUS_PREDICTION,
    })
end)

Handlers.add("CheckRelayData", "check-relay-data", function (msg)
    print( " ----- Checking relay data ----- " )
    print( LATEST_RELAY_DATA )
end)

Handlers.add("GetApusPrediction", "get-apus-prediction", function (msg)
    print( " ----- Getting Apus prediction ----- " )
    Send({ Target = APUS_ROUTER, Action = "Infer", Data = msg.Data })
end)

-- Handle cron messages for autonomous operation
Handlers.add(
"CronTick",
  Handlers.utils.hasMatchingTag("Action", "Cron"), -- Pattern to identify cron message
  function () -- Handler task to execute on cron message

    if STOP_FLAG == "true" then -- If the stop flag is true, stop the agent
        print( "Agent Stopped" )
        return
    end

    TICKS = TICKS + 1 -- Increment the ticks counter

    local timestamp_ms = os.time()
    local timestamp_seconds = math.floor(timestamp_ms / 1000)
    local readable_date = os.date("%Y-%m-%d %H:%M:%S", timestamp_seconds)
    print("Ticks: " .. TICKS .. " Timestamp: " .. timestamp_seconds .. " Date: " .. readable_date) -- Print the ticks, timestamp, and date
   
   -- Get latest data from the ESPN relay
    GetLatestData()
    
    -- Get prediction once we have a game id
    if APUS_PREDICTION == "" or APUS_PREDICTION == "No prediction text available" then
        GetPrediction()
    end
    
  end
)

function GetPrediction()
    print( "----- Getting prediction ----- " )
    SENT_APUS_PREDICTION = true
    ao.send({ Target = APUS_PREDICTION_AGENT, 
        Action = "get-prediction", 
        GameID = GAME_ID })
    -- Note: The prediction agent will send back the result directly, no Receive needed
    print("Prediction request sent for game ID: " .. GAME_ID)
end

-- Handler to receive prediction response
Handlers.add("PredictionResponse", Handlers.utils.hasMatchingTag("Action", "Prediction-Response"), function(msg)
    APUS_PREDICTION = msg.Data or "" -- Set the APUS prediction
    print("APUS Prediction: " .. APUS_PREDICTION)
end)

function GetLatestData()
    print( "----- Getting latest data ----- " )
    ao.send({ Target = NCAA_RELAY, Action = "get-latest-data" })
    local res = Receive({Action = "Latest-Data-Response"})
    if res then
        -- print( res.Data )
        LATEST_RELAY_DATA = res.Data
        ExtractLatestGameData()
    end
end

Handlers.add(
    "LatestDataResponse",
    Handlers.utils.hasMatchingTag("Action", "Latest-Data-Response"),
    function(msg)
    end
)

function GetTimestamp(msg)
    -- Convert the timestamp to seconds
    local timestamp_ms = msg["Timestamp"]
    local timestamp_seconds = math.floor(timestamp_ms / 1000)
    -- local readable = os.date("%Y-%m-%d %H:%M:%S", timestamp_seconds)
    return timestamp_seconds
end

function ExtractLatestGameData()
    print( "Extracting latest game data" )
    
    -- Check if we have relay data and a game ID to search for
    if LATEST_RELAY_DATA == "{}" or GAME_ID == "" then
        print("No relay data or game ID available")
        return
    end
    
    -- Decode the JSON from LATEST_RELAY_DATA
    local success, relay_data = pcall(json.decode, LATEST_RELAY_DATA)
    if not success then
        print("Failed to decode relay data JSON: " .. tostring(relay_data))
        return
    end
    
    -- Search for the game with matching GAME_ID
    local found_game = nil
    
    -- Check the nested structure: sports -> [sport] -> events
    if relay_data.sports then
        for sport_name, sport_data in pairs(relay_data.sports) do
            if sport_data.events then
                for _, game in ipairs(sport_data.events) do
                    if game.id == GAME_ID or game.game_id == GAME_ID then
                        found_game = game
                        print("Found game in " .. sport_name .. " events")
                        break
                    end
                end
                if found_game then break end
            end
        end
    -- Fallback: Check if relay_data has a games array or is structured differently
    elseif relay_data.games then
        for _, game in ipairs(relay_data.games) do
            if game.id == GAME_ID or game.game_id == GAME_ID then
                found_game = game
                break
            end
        end
    elseif type(relay_data) == "table" then
        -- If it's a direct array of games
        for _, game in ipairs(relay_data) do
            if game.id == GAME_ID or game.game_id == GAME_ID then
                found_game = game
                break
            end
        end
    end
    
    -- Store the found game data
    if found_game then
        LATEST_GAME_DATA = json.encode(found_game)
        print("Found and stored game data for ID: " .. GAME_ID)
        CheckGameStatus()

        if GAME_INITIALIZED == false then
            InitGameData()
        end

        if APUS_PREDICTION_INITIALIZED == false and GAME_INITIALIZED == true then
            InitGamePrediction()
        end

    else
        print("Game with ID " .. GAME_ID .. " not found in relay data")
    end
end

function InitGameData()
    print( " ---- Initializing Game Data  ---- " )
    
    -- Check if we have game data
    if LATEST_GAME_DATA == "{}" then
        print("No game data available")
        return
    end
    
    -- Decode the game data
    local success, game_data = pcall(json.decode, LATEST_GAME_DATA)
    if not success then
        print("Failed to decode game data")
        return
    end
    
    -- Extract and set game variables
    GAME_NAME = game_data.name or game_data.shortName or GAME_NAME
    GAME_STATUS = game_data.status.detail or GAME_STATUS
    
    -- Extract sport and organization info
    SPORT = "Football" -- Default for NCAA football
    ORGANIZATION = "NCAA" -- Default organization
    
    -- Extract team information
    if game_data.teams and #game_data.teams >= 2 then
        for _, team in ipairs(game_data.teams) do
            if team.homeAway == "home" then
                HOME_TEAM = team.name or team.shortName or ""
            elseif team.homeAway == "away" then
                AWAY_TEAM = team.name or team.shortName or ""
            end
        end
    end

    GAME_INITIALIZED = true
    
    -- Print initialized data
    print("Game initialized:")
    print("  Game ID: " .. GAME_ID)
    print("  Game Name: " .. GAME_NAME)
    print("  Status: " .. GAME_STATUS)
    print("  Sport: " .. SPORT)
    print("  Organization: " .. ORGANIZATION)
    print("  Home Team: " .. HOME_TEAM)
    print("  Away Team: " .. AWAY_TEAM)
    
end

function InitGamePrediction()
    print( " ---- Initializing APUS game prediction ---- " )
    Send({ Target = APUS_PREDICTION_AGENT, 
        Action = "Infer", 
        Sport = SPORT, 
        Organization = ORGANIZATION, 
        Home = HOME_TEAM, 
        Away = AWAY_TEAM, 
        GameID = GAME_ID })

    APUS_PREDICTION_INITIALIZED = true
end

function CheckGameStatus()
    print( " ---- Checking game status ---- " )
    
    -- Check if we have game data
    if LATEST_GAME_DATA == "{}" then
        print("No game data available")
        return
    end
    
    -- Decode the game data
    local success, game_data = pcall(json.decode, LATEST_GAME_DATA)
    if not success then
        print("Failed to decode game data")
        return
    end
    
    -- Print team names and scores
    if game_data.teams then
        print("=== GAME SCORES ===")
        for i, team in ipairs(game_data.teams) do
            local home_away = team.homeAway or "unknown"
            local winner_status = ""
            if team.winner == true then
                winner_status = " (WINNER)"
            elseif team.winner == false then
                winner_status = " (LOSER)"
            end
            print(home_away:upper() .. ": " .. team.name .. " - Score: " .. (team.score or "0") .. winner_status)
        end
        print("Game Status: " .. (game_data.status.detail or "Unknown"))
        print("===================")
    end
    
    -- Check specific game status
    local status = game_data.status.detail or ""
    GAME_STATUS = status -- Update the game status
    if status == "Final" then
        print( "Game is final" )
    elseif status:find("In Progress") or status == "1st Quarter" or status == "2nd Quarter" or status == "3rd Quarter" or status == "4th Quarter" or status == "Halftime" then
        print( "Game is in progress" )
    elseif status:find("TBD") or status:find("EST") or status:find("CST") or status:find("MST") or status:find("PST") then
        print( "Game is scheduled" )
    else
        print( "Game status: " .. status )
    end

end


-- Add user voting for the game outcome Note: Add a % under each team to signify the oods
