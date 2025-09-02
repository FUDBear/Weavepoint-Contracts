-- Process ID: AJFWbK51AsqRLaWfI-xdmFB1ZZcLeuLD3g5QftO1LFw
local json = require("json")

-- Backend AO Process Logic (Core Flow from section 2.5)
PREDICTIONS = "{}" -- { "gameId": "prediction" }

CurrentReference = CurrentReference or 0 -- Initialize or use existing reference counter
Tasks = Tasks or {}                      -- Your process's state where results are stored
Balances = Balances or "0"               -- Store balance information for each reference

APUS_ROUTER = "Bf6JJR2tl2Wr38O2-H6VctqtduxHgKF-NzRB9HhTRzo"

Handlers.add("GetPrediction", "get-prediction", function (msg)
    print( " ----- Getting Prediction ----- " )
    
    -- Debug: Print the entire message structure
    print("Message From: " .. (msg.From or "unknown"))
    print("Message Tags: " .. (msg.Tags and "exists" or "nil"))
    if msg.Tags then
        for k, v in pairs(msg.Tags) do
            print("  Tag " .. k .. ": " .. v)
        end
    end
    print("Message Data: " .. (msg.Data or "nil"))
    
    -- Try multiple ways to get the game ID (case insensitive)
    local gameId = nil
    if msg.Tags then
        gameId = msg.Tags["GameID"] or msg.Tags["Gameid"] or msg.Tags["gameid"] or msg.Tags["ID"] or msg.Tags["Id"] or msg.Tags["id"]
        print("Extracted from Tags: " .. (gameId or "nil"))
    end
    if not gameId then
        gameId = msg["GameID"] or msg["ID"] or msg.Data
        print("Extracted from msg fields: " .. (gameId or "nil"))
    end
    print("Final Game ID: " .. (gameId or "nil"))
    
    -- Safely decode PREDICTIONS JSON
    local predictions_data = {}
    if PREDICTIONS and PREDICTIONS ~= "{}" then
        local success, decoded = pcall(json.decode, PREDICTIONS)
        if success then
            predictions_data = decoded
        else
            print("Failed to decode PREDICTIONS JSON")
            ao.send({Target = msg.From, Data = "Error: Could not decode predictions data"})
            return
        end
    end
    
    -- Look for the prediction
    if gameId and predictions_data[gameId] then
        local prediction_entry = predictions_data[gameId]
        print("Found prediction for game: " .. gameId)
        print("Status: " .. (prediction_entry.status or "unknown"))
        
        -- Send back the prediction data
        ao.send({
            Target = msg.From, 
            Data = prediction_entry.prediction or "No prediction text available",
            Tags = {
                ["GameID"] = gameId,
                ["Status"] = prediction_entry.status or "unknown",
                ["HomeTeam"] = prediction_entry.homeTeam or "",
                ["AwayTeam"] = prediction_entry.awayTeam or "",
                ["Sport"] = prediction_entry.sport or "",
                ["Organization"] = prediction_entry.organization or ""
            }
        })
    else
        print("Prediction not found for game ID: " .. (gameId or "nil"))
        ao.send({Target = msg.From, Data = "Prediction not found for game ID: " .. (gameId or "unknown")})
    end
end)

Handlers.add("ListPredictions", "list-predictions", function (msg)
    print( " ----- Listing All Predictions ----- " )
    
    -- Safely decode PREDICTIONS JSON
    local predictions_data = {}
    if PREDICTIONS and PREDICTIONS ~= "{}" then
        local success, decoded = pcall(json.decode, PREDICTIONS)
        if success then
            predictions_data = decoded
            print("Found " .. (table.getn and table.getn(predictions_data) or "unknown number of") .. " predictions:")
            for gameId, prediction in pairs(predictions_data) do
                print("Game ID: " .. gameId .. " - Status: " .. (prediction.status or "unknown"))
                print("  Teams: " .. (prediction.homeTeam or "?") .. " vs " .. (prediction.awayTeam or "?"))
            end
        else
            print("Failed to decode PREDICTIONS JSON")
        end
    else
        print("No predictions stored yet")
    end
    
    ao.send({Target = msg.From, Data = PREDICTIONS})
end)

-- Handler to listen for prompts from your frontend
Handlers.add(
    "SendInfer",
    Handlers.utils.hasMatchingTag("Action", "Infer"),
    function(msg)

        -- Create new table entry with the game id and the sender

        local sport = msg["Sport"] or "Football"
        local organization = msg["Organization"] or "NCAA"
        local homeTeam = msg["Home"] or "Unknown Home"
        local awayTeam = msg["Away"] or "Unknown Away"
        local prompt = "What is your prediction for a " .. organization .. " " .. sport .. " game between " .. homeTeam .. " and " .. awayTeam .. "?"
        local sender = msg.From
        local gameId = msg.Tags["GameID"] or msg.Tags["Gameid"] or msg.Tags["gameid"] or msg.Tags["ID"] or msg.Tags["Id"] or msg.Tags["id"] or msg["GameID"] or msg["ID"] or ("game_" .. os.time())

        print( "Game ID: " .. (gameId or "nil") )
        print( "Sport: " .. (sport or "nil") )
        print( "Organization: " .. (organization or "nil") )
        print( "Home Team: " .. (homeTeam or "nil") )
        print( "Away Team: " .. (awayTeam or "nil") )
        print( "Prompt: " .. prompt )

        local reference = msg["X-Reference"] or msg.Reference

        -- Create new table entry with the reference, game id, and the sender
        print("Debug - Message structure:")
        print("msg.Data type: " .. type(msg.Data))
        if msg.Data then
            print("msg.Data: " .. tostring(msg.Data))
        end
        print("msg.Tags: " .. (msg.Tags and "exists" or "nil"))
        
        -- Safely decode PREDICTIONS JSON
        local predictions_data = {}
        if PREDICTIONS and PREDICTIONS ~= "{}" then
            local success, decoded = pcall(json.decode, PREDICTIONS)
            if success then
                predictions_data = decoded
            else
                print("Failed to decode PREDICTIONS JSON, starting fresh")
                predictions_data = {}
            end
        end
        predictions_data[gameId] = {
            reference = reference,
            gameId = gameId,
            sender = sender,
            homeTeam = homeTeam,
            awayTeam = awayTeam,
            sport = sport,
            organization = organization,
            prompt = prompt,
            status = "pending",
            timestamp = os.time()
        }
        PREDICTIONS = json.encode(predictions_data)
        print("Added prediction entry for game: " .. gameId .. " with reference: " .. reference)

        local requestReference = reference
        local request = {
            Target = APUS_ROUTER,
            Action = "Infer",
            ["X-Prompt"] = prompt,
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
            gameId = gameId,
        }
        Send({
            device = 'patch@1.0',
            cache = {
                tasks = Tasks
            }
        })
        ao.send(request)
    end
)

Handlers.add(
    "AcceptResponse",
    Handlers.utils.hasMatchingTag("Action", "Infer-Response"),
    function(msg)
        local reference = msg.Tags["X-Reference"] or ""
        print(msg)

        if msg.Tags["Code"] then
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
        
        -- Update PREDICTIONS table with the actual prediction
        local predictions_data = json.decode(PREDICTIONS)
        local gameId = Tasks[reference].gameId
        if gameId and predictions_data[gameId] then
            -- Extract the "result" field from the APUS response JSON
            local prediction_text = ""
            if msg.Data then
                local success, apus_response = pcall(json.decode, msg.Data)
                if success and apus_response.result then
                    prediction_text = apus_response.result
                    print("Extracted prediction result: " .. prediction_text:sub(1, 100) .. "...")
                else
                    -- Fallback to raw data if JSON parsing fails
                    prediction_text = msg.Data
                    print("Using raw response data as prediction")
                end
            end
            
            predictions_data[gameId].prediction = prediction_text
            predictions_data[gameId].status = "completed"
            predictions_data[gameId].completedAt = os.time()
            PREDICTIONS = json.encode(predictions_data)
            print("Updated prediction for game: " .. gameId .. " - Prediction received!")
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
        print(Tasks[reference])
        if Tasks[reference] then
            msg.reply({Data = json.encode(Tasks[reference])})
        else
            msg.reply({Data = "Task not found"})
        end
    end
)