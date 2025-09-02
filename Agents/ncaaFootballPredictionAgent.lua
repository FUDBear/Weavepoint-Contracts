-- RawDogAgentTwo: ytRJJcWZ9umI8N0jQaI5pRQ5mKvVUBePUpHDh5TDQz8
-- RawDogAgentThree: inPYe3CzvBjT7q7ZJM5uqA2F-WE9XXyMipM8xh-8HC8
local json = require("json")

NCAA_RELAY = "ruKqeINStWIE0YK0gxJkgXWFJci6irA07JxbJJLOcBE"
LATEST_RELAY_DATA = "{}" -- All the data from teh ncaa relay
LATEST_GAME_DATA = "{}" -- The data for the game we are tracking
STOP_FLAG = "false" -- "true" to stop the agent
TICKS = 0 -- Just keeps track of # of cron ticks
GAME_ID = "401762522" -- temp id -- id of the game to track
GAME_STATUS = "" -- Status of the game [Final, In Progress, Scheduled]

GAME_NAME = "" -- Name of the game
VOTING_DATA = "{}" -- Data for the voting

-- APUS
APUS_ROUTER = "Bf6JJR2tl2Wr38O2-H6VctqtduxHgKF-NzRB9HhTRzo"
APUS_AI_COMMENT = ""; -- AI Comment of the game
APUS_PREDICTION = ""; -- The prediction APUS AI Makes
SENT_APUS_PREDICTION = false; -- The flag to check if the prompt was sent to APUS

CurrentReference = CurrentReference or 0 -- Initialize or use existing reference counter
Tasks = Tasks or {}                      -- Your process's state where results are stored
Balances = Balances or "0"               -- Store balance information for each reference

USDA = ""; -- USDA Token
USDA_AMOUNT = "" -- Amount of USDA to pay to the winner
RANDO_WINNER_INDEX = ""; -- Index of the winner in the random number generator

Handlers.add("Info", "Info", function (msg)
    ao.send({ Target = msg.From, Action = "Info-Response", 
        ["Name"] = "TEST GAME AGENT", 
        ["GAME_ID"] = GAME_ID,
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

    -- ao.send({ Target = ao.id, Action = "Infer", Data = msg.Data })
    
    -- local res = Receive({Action = "Infer-Response"})
    -- if res then
    --     -- APUS_AI_PREDICTION = res.Data
    --     -- print( "Apus prediction: " .. APUS_AI_PREDICTION )
    --     print( "Apus prediction: " .. res.Data )
    -- end

end)

-- Handlers.add("GetApusPrediction", "get-apus-prediction", function (msg)
--     print( " ----- Getting Apus prediction ----- " )
--     ao.send({ Target = APUS_ROUTER, Action = "Infer", Data = "What is the prediction a college football between South Florida Bulls and Boise State Broncos?" })
--     local res = Receive({Action = "Infer-Response"})
--     if res then
--         APUS_AI_PREDICTION = res.Data
--     end


-- end)

-- Handle cron messages for autonomous operation
Handlers.add(
"CronTick",
  Handlers.utils.hasMatchingTag("Action", "Cron"), -- Pattern to identify cron message
  function () -- Handler task to execute on cron message
    TICKS = TICKS + 1

    local timestamp_ms = os.time()
    local timestamp_seconds = math.floor(timestamp_ms / 1000)
    local readable_date = os.date("%Y-%m-%d %H:%M:%S", timestamp_seconds)

    -- print("Ticks: " .. TICKS .. " Timestamp: " .. timestamp_seconds .. " Date: " .. readable_date)
    -- GetLatestData()
    -- GetInfoResponse()

    -- Get prediction
    if SENT_APUS_PREDICTION == false then
        GetPrediction()
    end
    
  end
)

function GetPrediction()
    print( "----- Getting prediction ----- " )
    SENT_APUS_PREDICTION = true
    ao.send({ Target = "AJFWbK51AsqRLaWfI-xdmFB1ZZcLeuLD3g5QftO1LFw", 
        Action = "get-prediction", 
        GameID = GAME_ID })
    -- Note: The prediction agent will send back the result directly, no Receive needed
    print("Prediction request sent for game ID: " .. GAME_ID)
end

-- Handler to receive prediction response
Handlers.add("PredictionResponse", Handlers.utils.hasMatchingTag("Action", "prediction-response"), function(msg)
    print("Received prediction response!")
    APUS_PREDICTION = msg.Data or ""
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

-- function GetInfoResponse()
--     print( "----- Getting info response ----- " )
--     ao.send({ Target = "TOzrYdLxB2o_EOfp0uKmiSxh6REl4ClRhqpDuTIiRwk", Action = "Info" })
--     local res = Receive({Action = "Info-Response"})
--     if res then
--         print( res.Data )
--     end
-- end

Handlers.add(
    "LatestDataResponse",
    Handlers.utils.hasMatchingTag("Action", "Latest-Data-Response"),
    function(msg)

        

        -- if msg.Data then
        --     LATEST_RELAY_DATA = msg.Data
        --     print( "Latest relay data received" )
        --     print( LATEST_RELAY_DATA )
        -- else
        --     print( "Latest relay data not received" )
        -- end
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
    else
        print("Game with ID " .. GAME_ID .. " not found in relay data")
    end
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

-- 

-- Apus
-- Handler to listen for prompts from your frontend
Handlers.add(
    "SendInfer",
    Handlers.utils.hasMatchingTag("Action", "Infer"),
    function(msg)
        local reference = msg["X-Reference"] or msg.Reference
        local requestReference = reference
        local request = {
            Target = APUS_ROUTER,
            Action = "Infer",
            ["X-Prompt"] = msg.Data,
            ["X-Reference"] = reference
        }
        if msg["X-Session"] then
            request["X-Session"] = msg["X-Session"]
        end
        if msg["X-Options"] then
            request["X-Options"] = msg["X-Options"]
        end
        Tasks[requestReference] = {
            prompt = request["X-Prompt"],
            options = request["X-Options"],
            session = request["X-Session"],
            reference = reference,
            status = "processing",
            starttime = os.time(),
        }
        Send({
            device = 'patch@1.0',
            cache = {
                tasks = Tasks
            }
        })
        print( "Sending request to Apus: " .. request.Data )
        ao.send(request)
    end
)

Handlers.add(
    "AcceptResponse",
    Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
    function(msg)
        local reference = msg.Tags["X-Reference"] or ""
        print("Received Infer-Response for reference: " .. reference)

        if msg.Tags["Code"] then
            -- Update task status to failed
            if Tasks[reference] then
                local error_message = msg.Tags["Message"] or "Unknown error"
                Tasks[reference].status = "failed"
                Tasks[reference].error_message = error_message
                Tasks[reference].error_code = msg.Tags["Code"]
                Tasks[reference].endtime = os.time()
            end
            Send({
                device = 'patch@1.0',
                cache = {
                    tasks = {
                        [reference] = Tasks[reference] }
                }
            })
            return
        end
        Tasks[reference].response = msg.Data or ""
        Tasks[reference].status = "success"
        Tasks[reference].endtime = os.time()
        
        -- Store the AI prediction if this was a game prediction request
        if Tasks[reference].prompt and Tasks[reference].prompt:find("prediction") then
            APUS_PREDICTION = msg.Data or ""
            print("APUS AI Prediction received: " .. APUS_AI_PREDICTION)
        end

        Send({
            device = 'patch@1.0',
            cache = {
                tasks = {
                    [reference] = Tasks[reference] }
            }
        })
    end
)

Handlers.add(
    "GetInferResponse",
    Handlers.utils.hasMatchingTag("Action", "GetInferResponse"),
    function(msg)
        local reference = msg.Tags["X-Reference"] or ""
        if Tasks[reference] then
            APUS_PREDICTION = Tasks[reference].response
            print("Found task for reference: " .. reference .. " - Status: " .. (Tasks[reference].status or "unknown"))
            -- msg.reply({Data = json.encode(Tasks[reference])})
        else
            print("Task not found for reference: " .. reference)
            msg.reply({Data = "Task not found"}) -- if task not found, return error
        end
    end
)