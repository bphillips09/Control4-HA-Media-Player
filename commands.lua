MEDIA_STATUS = {
    STATE = "",
    TITLE = "",
    ALBUM = "",
    ARTIST = "",
    IMAGEURL = "",
}

MEDIA_DURATION = 0
MEDIA_POSITION = 0
VOLUME_LEVEL = 0
HAS_DISCRETE_VOLUME = false
LAST_STATE = ""
LAST_MEDIA_TITLE = ""
LAST_FILE_PATH = ""
LAST_FILE_NAME = ""
HA_URL = ""

function DRV.OnDriverLateInit(init)
    math.randomseed(os.time())
    math.random(); math.random(); math.random()
end

function RFP.DEVICE_SELECTED(idBinding, strCommand, tParams)
    UpdateMediaInfo()
    UpdateProgress()
    UpdateDashboard()
end

function RFP.DEVICE_DESELECTED(idBinding, strCommand, tParams)
    MediaPlayerServiceCall("turn_off", {})
    UpdateMediaInfo()
    UpdateProgress()
    UpdateDashboard()
end

function RFP.GetDashboard(idBinding, strCommand, tParams)
    UpdateDashboard()
    UpdateProgress()
end

function RFP.GetQueue(idBinding, strCommand, tParams)
    UpdateQueue()
    UpdateDashboard()
    UpdateProgress()
end

function RFP.ToggleRepeat(idBinding, strCommand, tParams)
    REPEAT = not (REPEAT)
    UpdateQueue()
end

function RFP.ToggleShuffle(idBinding, strCommand, tParams)
    SHUFFLE = not (SHUFFLE)
    UpdateQueue()
end

function RFP.PLAY(idBinding, strCommand, tParams)
    MediaPlayerServiceCall("media_play", {})
end

function RFP.PAUSE(idBinding, strCommand, tParams)
    MediaPlayerServiceCall("media_pause", {})
end

function RFP.STOP(idBinding, strCommand, tParams)
    UpdateDashboard()
    MediaPlayerServiceCall("media_stop", {})
end

function RFP.SKIP_FWD(idBinding, strCommand, tParams)
    MediaPlayerServiceCall("media_next_track", {})
end

function RFP.SKIP_REV(idBinding, strCommand, tParams)
    MediaPlayerServiceCall("media_previous_track", {})
end

function RFP.OFF(idBinding, strCommand, tParams)
    MediaPlayerServiceCall("media_stop", {})
end

function RFP.PULSE_VOL_UP(idBinding, strCommand, tParams)
    print("--vol up--")
end

function RFP.PULSE_VOL_DOWN(idBinding, strCommand, tParams)
    print("--vol dn--")
end

function RFP.SET_VOLUME_LEVEL(idBinding, strCommand, tParams)
    local volumeLevel = tonumber(tParams.LEVEL) * 0.01
    MediaPlayerServiceCall("volume_set", { volume_level = volumeLevel })
end

function RFP.GET_VOLUME_LEVEL(idBinding, strCommand, tParams)
    return VOLUME_LEVEL
end

function RFP.GET_HAS_DISCRETE_VOLUME(idBinding, strCommand, tParams)
    return HAS_DISCRETE_VOLUME
end

function MediaPlayerServiceCall(service, data)
    local playerServiceCall = {
        domain = "media_player",
        service = service,

        service_data = data,

        target = {
            entity_id = EntityID
        }
    }

    local tParams = {
        JSON = JSON:encode(playerServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

--Common MSP functions
function DataReceivedError(idBinding, navId, seq, msg)
    local tParams = {
        NAVID = navId,
        SEQ = seq,
        DATA = '',
        ERROR = msg,
    }

    C4:SendToProxy(idBinding, 'DATA_RECEIVED', tParams)
end

function DataReceived(idBinding, navId, seq, args)
    -- Returns data to a specific Navigator in response to a specific request made by Navigator.  Can't be triggered asynchronously, each seq request can only get one response.
    local data = ''

    if (type(args) == 'string') then
        data = args
    elseif (type(args) == 'boolean' or type(args) == 'number') then
        data = tostring(args)
    elseif (type(args) == 'table') then
        data = XMLTag(nil, args, false, false)
    end

    local tParams = {
        NAVID = navId,
        SEQ = seq,
        DATA = data,
    }

    C4:SendToProxy(idBinding, 'DATA_RECEIVED', tParams)
end

function SendEvent(idBinding, navId, roomId, name, args)
    local data = ''

    if (type(args) == 'string') then
        data = args
    elseif (type(args) == 'boolean' or type(args) == 'number') then
        data = tostring(args)
    elseif (type(args) == 'table') then
        data = XMLTag(nil, args, false, false)
    end

    local tParams = {
        NAVID = navId,
        ROOMS = roomId,
        NAME = name,
        EVTARGS = data,
    }

    C4:SendToProxy(idBinding, 'SEND_EVENT', tParams, 'COMMAND')
end

function UpdateDashboard()
    local possibleItems = "SkipRev"
    if MEDIA_STATUS.STATE == "playing" then
        possibleItems = possibleItems .. " Pause Stop "
    else
        possibleItems = possibleItems .. " Play "
    end
    possibleItems = possibleItems .. "SkipFwd"

    local dashboardInfo = {
        Items = possibleItems
    }

    SendEvent(5001, nil, nil, 'DashboardChanged', dashboardInfo)
end

function UpdateMediaInfo()
    C4:SendToProxy(5001, 'UPDATE_MEDIA_INFO', MEDIA_STATUS, 'COMMAND', true)
end

function UpdateProgress()
    local duration = MEDIA_DURATION
    local elapsed = MEDIA_POSITION

    local label = ConvertTime(elapsed) .. ' / -' .. ConvertTime(duration - elapsed)

    local progressInfo = {
        length = duration,
        offset = elapsed,
        label = label,
    }

    SendEvent(5001, nil, nil, 'ProgressChanged', progressInfo)
end

function UpdateQueue()
    local tags = {
        can_shuffle = true,
        can_repeat = true,
        shufflemode = (SHUFFLE == true),
        repeatmode = (REPEAT == true),
    }

    local queueInfo = {
        NowPlaying = XMLTag(tags)
    }

    SendEvent(5001, nil, nil, 'QueueChanged', queueInfo)
end

function RFP.RECEIEVE_STATE(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.response)

    local stateData

    if jsonData ~= nil then
        stateData = jsonData
    end

    Parse(stateData)
end

function RFP.RECEIEVE_EVENT(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.data)

    local eventData

    if jsonData ~= nil then
        eventData = jsonData["event"]["data"]["new_state"]
    end

    Parse(eventData)
end

function Parse(data)
    if data == nil then
        return
    end

    if data["entity_id"] ~= EntityID then
        return
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if state ~= nil then
        MEDIA_STATUS.STATE = state

        if LAST_STATE ~= state then
            print("-- STATE CHANGE -- from " .. LAST_STATE .. " to " .. state)
            LAST_STATE = state
            MediaStateChanged()
        end
    end

    if attributes == nil then
        return
    end

    local selectedAttribute = attributes["volume_level"]
    if selectedAttribute ~= nil then
        local volumeLevel = tonumber(selectedAttribute) * 100
        VOLUME_LEVEL = volumeLevel

        HAS_DISCRETE_VOLUME = true

        C4:SendToProxy(5001, 'VOLUME_LEVEL_CHANGED', { LEVEL = volumeLevel, OUTPUT = 7000 })
    else
        HAS_DISCRETE_VOLUME = false
    end

    selectedAttribute = attributes["media_duration"]
    if selectedAttribute ~= nil then
        MEDIA_DURATION = tonumber(selectedAttribute)
    end

    selectedAttribute = attributes["media_position"]
    if selectedAttribute ~= nil then
        MEDIA_POSITION = tonumber(selectedAttribute)
    end

    selectedAttribute = attributes["media_title"]
    if selectedAttribute ~= nil then
        MEDIA_STATUS.TITLE = selectedAttribute
    end

    selectedAttribute = attributes["media_artist"]
    if selectedAttribute ~= nil then
        MEDIA_STATUS.ARTIST = selectedAttribute
    end

    selectedAttribute = attributes["media_album_name"]
    if selectedAttribute ~= nil then
        MEDIA_STATUS.ALBUM = selectedAttribute
    end

    selectedAttribute = attributes["media_artist"]
    if selectedAttribute ~= nil then
        MEDIA_STATUS.ARTIST = selectedAttribute
    end

    selectedAttribute = attributes["app_name"]
    if selectedAttribute ~= nil and MEDIA_STATUS.TITLE == "" or MEDIA_STATUS.TITLE == nil then
        MEDIA_STATUS.TITLE = selectedAttribute
    end

    selectedAttribute = attributes["shuffle"]
    if selectedAttribute ~= nil then
        local shuffleMode = ""
        if selectedAttribute == "false" then
            shuffleMode = "Off"
        elseif selectedAttribute == "true" then
            shuffleMode = "On"
        end

        C4:SendToProxy(5001, 'SHUFFLE_CHANGED', { SHUFFLE_MODE = shuffleMode })
    end

    selectedAttribute = attributes["repeat"]
    if selectedAttribute ~= nil then
        local repeatMode = ""
        if selectedAttribute == "off" then
            repeatMode = "Off"
        elseif selectedAttribute == "one" then
            repeatMode = "One"
        elseif selectedAttribute == "all" then
            repeatMode = "All"
        end

        C4:SendToProxy(5001, 'REPEAT_CHANGED', { REPEAT_MODE = repeatMode })
    end

    selectedAttribute = attributes["entity_picture"]
    if selectedAttribute ~= nil then
        if not (LAST_MEDIA_TITLE == MEDIA_STATUS.TITLE) then
            LAST_MEDIA_TITLE = MEDIA_STATUS.TITLE

            if HA_URL == "" then
                for deviceId, _ in pairs(C4:GetDevicesByC4iName('HA Coordinator.c4z') or {}) do
                    HA_URL = C4:GetVariable(deviceId, 1001) or ""
                end
            end

            GetImageFromURL(HA_URL .. selectedAttribute)
        end
    else
        MEDIA_STATUS.IMAGEURL = ''
    end

    UpdateMediaInfo()
end

function MediaStateChanged()
    if MEDIA_STATUS.STATE == "playing" or MEDIA_STATUS.STATE == "paused" then
        C4:SendToDevice(C4:RoomGetId(), "SELECT_AUDIO_DEVICE", { deviceid = C4:GetProxyDevices() })
    else
        C4:SendToDevice(C4:RoomGetId(), "ROOM_OFF", { deviceid = C4:GetProxyDevices() })
    end
end

function XMLEncode(s)
    if (s == nil) then return end

    s = string.gsub(s, '&', '&amp;')
    s = string.gsub(s, '"', '&quot;')
    s = string.gsub(s, '<', '&lt;')
    s = string.gsub(s, '>', '&gt;')
    s = string.gsub(s, "'", '&apos;')

    return s
end

function XMLTag(strName, tParams, tagSubTables, xmlEncodeElements)
    local retXML = {}
    if (type(strName) == 'table' and tParams == nil) then
        tParams = strName
        strName = nil
    end
    if (strName) then
        table.insert(retXML, '<')
        table.insert(retXML, tostring(strName))
        table.insert(retXML, '>')
    end
    if (type(tParams) == 'table') then
        for k, v in pairs(tParams) do
            if (v == nil) then v = '' end
            if (type(v) == 'table') then
                if (k == 'image_list') then
                    for _, image_list in pairs(v) do
                        table.insert(retXML, image_list)
                    end
                elseif (tagSubTables == true) then
                    table.insert(retXML, XMLTag(k, v))
                end
            else
                if (v == nil) then v = '' end
                table.insert(retXML, '<')
                table.insert(retXML, tostring(k))
                table.insert(retXML, '>')
                if (xmlEncodeElements ~= false) then
                    table.insert(retXML, XMLEncode(tostring(v)))
                else
                    table.insert(retXML, tostring(v))
                end
                table.insert(retXML, '</')
                table.insert(retXML, string.match(tostring(k), '^(%S+)'))
                table.insert(retXML, '>')
            end
        end
    elseif (tParams) then
        if (xmlEncodeElements ~= false) then
            table.insert(retXML, XMLEncode(tostring(tParams)))
        else
            table.insert(retXML, tostring(tParams))
        end
    end
    if (strName) then
        table.insert(retXML, '</')
        table.insert(retXML, string.match(tostring(strName), '^(%S+)'))
        table.insert(retXML, '>')
    end
    return (table.concat(retXML))
end

function ConvertTime(data, incHours)
    -- Converts a string of [HH:]MM:SS to an integer representing the number of seconds
    -- Converts an integer number of seconds to a string of [HH:]MM:SS. If HH is zero, it is omitted unless incHours is true

    if (data == nil) then
        return (0)
    elseif (type(data) == 'number') then
        local strTime = ''
        local minutes = ''
        local seconds = ''
        local hours = string.format('%d', data / 3600)
        data = data - (hours * 3600)

        if (hours ~= '0' or incHours) then
            strTime = hours .. ':'
            minutes = string.format('%02d', data / 60)
        else
            minutes = string.format('%d', data / 60)
        end

        data = data - (minutes * 60)
        seconds = string.format('%02d', data)
        strTime = strTime .. minutes .. ':' .. seconds
        return strTime
    elseif (type(data) == 'string') then
        local hours, minutes, seconds = string.match(data, '^(%d-):(%d-):?(%d-)$')

        if (hours == '') then hours = nil end
        if (minutes == '') then minutes = nil end
        if (seconds == '') then seconds = nil end

        if (hours and not minutes) then
            minutes = hours
            hours = 0
        elseif (minutes and not hours) then
            hours = 0
        elseif (not minutes and not hours) then
            minutes = 0
            hours = 0
            seconds = seconds or 0
        end

        hours, minutes, seconds = tonumber(hours), tonumber(minutes), tonumber(seconds)
        return ((hours * 3600) + (minutes * 60) + seconds)
    end
end

function GetImageFromURL(url)
    print("-- GET IMG FROM URL -- " .. url)

    C4:FileDelete("MEDIA", LAST_FILE_PATH)

    local randomName = tostring(math.random(0, 1000))

    local folder = "/images/album/"
    local fileType = ".jpg"
    local fileName = C4:Base64Encode(randomName) .. fileType
    local filePath = folder .. fileName
    LAST_FILE_NAME = fileName
    LAST_FILE_PATH = filePath

    local t = C4:url()
        :OnDone(function(transfer, responses, errCode, errMsg)
            if (errCode == 0) then
                local lresp = responses[#responses]
                local address = "http://" .. C4:GetControllerNetworkAddress()
                local imageAddress = C4:Base64Encode(address .. filePath)
                MEDIA_STATUS.IMAGEURL = imageAddress
                UpdateMediaInfo()
            else
                if (errCode == -1) then
                    print("Transfer aborted")
                else
                    print("Transfer failed: " ..
                        errCode .. ": " .. errMsg .. " (" .. #responses .. " responses completed)")
                end
            end
        end)
        :DownloadFile(url, "MEDIA", filePath)
end
