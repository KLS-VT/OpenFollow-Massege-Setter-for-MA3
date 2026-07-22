-- ============================================================
-- OpenFollow OSC Cue Command Plugin
-- ============================================================

local OPENFOLLOW_PART_OFFSET = 9000  -- Offset für OpenFollow-Parts, um Kollisionen mit anderen Parts zu vermeiden

------------------------------------------------------------
-- HELPERS: STRINGS
------------------------------------------------------------

local function escape_quotes(str)
    str = tostring(str or "")
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    return str
end

local function trim(str)
    str = tostring(str or "")
    return str:match("^%s*(.-)%s*$")
end

local function get_input(result, name)
    if not result or not result.inputs then
        return ""
    end

    local input = result.inputs[name]

    if type(input) == "table" then
        return trim(input.value or "")
    end

    return trim(input or "")
end

------------------------------------------------------------
-- HELPERS: VALIDATION
------------------------------------------------------------

local function is_only_numbers(str)
    str = tostring(str or "")
    return str:match("^%d+$") ~= nil
end

local function is_cue_number(str)
    str = tostring(str or "")
    return str:match("^%d+%.?%d*$") ~= nil
end

local function is_valid_seconds(str)
    str = tostring(str or "")
    if str == "" then
        return true -- optional field
    end
    return str:match("^%d+%.?%d*$") ~= nil
end

local function is_valid_ip(str)
    str = tostring(str or "")

    local a, b, c, d = str:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")

    if not a then
        return false
    end

    a = tonumber(a)
    b = tonumber(b)
    c = tonumber(c)
    d = tonumber(d)

    return
        a >= 0 and a <= 255 and
        b >= 0 and b <= 255 and
        c >= 0 and c <= 255 and
        d >= 0 and d <= 255
end

local function is_valid_port(str)
    str = tostring(str or "")

    if not str:match("^%d+$") then
        return false
    end

    local port = tonumber(str)

    return port >= 1 and port <= 65535
end

local function contains_comma(str)
    return tostring(str or ""):find(",") ~= nil
end

------------------------------------------------------------
-- HELPERS: UI
------------------------------------------------------------

local function show_message(title, message)
    MessageBox({
        title = title,
        message = message,
        commands = {
            { value = 1, name = "OK" }
        }
    })
end

------------------------------------------------------------
-- HELPERS: HANDLE PROPERTIES
------------------------------------------------------------

local function set_handle_property(handle, property_names, value)
    if not handle then
        return false
    end

    for _, property_name in ipairs(property_names) do
        local success = pcall(function()
            handle[property_name] = value
        end)

        if success then
            return true
        end
    end

    return false
end

local function get_handle_property(handle, property_names)
    if not handle then
        return nil
    end

    for _, property_name in ipairs(property_names) do
        local success, value = pcall(function()
            return handle[property_name]
        end)

        if success and value ~= nil then
            return value
        end
    end

    return nil
end

local function set_handle_properties(handle, properties)
    for _, prop in ipairs(properties) do
        set_handle_property(handle, prop[1], prop[2])
    end
end

local function value_is_enabled(value)
    if value == true then
        return true
    end

    if value == 1 then
        return true
    end

    value = tostring(value or ""):lower()

    return value == "1" or value == "true" or value == "yes" or value == "on" or value == "enabled"
end

------------------------------------------------------------
-- OSC BASE / ENABLE OUTPUT
------------------------------------------------------------

local function get_osc_base()
    local root = Root()

    if not root then
        return nil
    end

    if root.ShowData and root.ShowData.OSCBase then
        return root.ShowData.OSCBase
    end

    return nil
end

local function ensure_osc_enable_output()
    local osc_base = get_osc_base()

    if not osc_base then
        show_message("OSC Error", "OSCBase konnte nicht gefunden werden.")
        return false
    end

    local enable_output_properties = {
        "EnableOutput",
        "Enable Output",
        "Output",
        "OSCOutput",
        "OSC Output"
    }

    local current_value = get_handle_property(osc_base, enable_output_properties)

    if value_is_enabled(current_value) then
        Printf("OSC Enable Output is already enabled.")
        return true
    end

    set_handle_property(osc_base, enable_output_properties, 1)

    Cmd("CD ShowData.OSCBase")
    Cmd('Set Root "EnableOutput" 1')
    Cmd('Set Root "Enable Output" 1')
    Cmd("CD Root")

    local new_value = get_handle_property(osc_base, enable_output_properties)

    if value_is_enabled(new_value) then
        Printf("OSC Enable Output was enabled.")
        return true
    end

    show_message(
        "OSC Enable Output",
        "Enable Output konnte nicht automatisch geprüft oder eingeschaltet werden.\n\nBitte prüfe Menü > In & Out > OSC > Enable Output manuell."
    )

    return false
end

------------------------------------------------------------
-- OSC DATA LINE LOOKUP / CREATION
------------------------------------------------------------

local function get_osc_line_count(osc_base)
    local count = 0

    local success, amount = pcall(function()
        return osc_base:Count()
    end)

    if success and amount then
        count = amount
    end

    return count
end

local function get_osc_line_by_index(osc_base, index)
    local handle = nil

    pcall(function()
        handle = osc_base[index]
    end)

    return handle
end

local function get_osc_line_name(handle)
    if not handle then
        return ""
    end

    local name = ""

    pcall(function()
        name = handle.Name or ""
    end)

    return tostring(name or "")
end

local function find_openfollow_osc_line()
    local osc_base = get_osc_base()

    if not osc_base then
        return nil, nil, nil
    end

    local count = get_osc_line_count(osc_base)

    for i = 1, count do
        local line = get_osc_line_by_index(osc_base, i)

        if line and get_osc_line_name(line) == "OpenFollow" then
            return osc_base, line, i
        end
    end

    return osc_base, nil, count + 1
end

local function create_osc_line(osc_base, index)
    if not osc_base then
        return nil
    end

    local line = nil

    pcall(function()
        osc_base:Create(index)
    end)

    line = get_osc_line_by_index(osc_base, index)

    if not line then
        Cmd("CD ShowData.OSCBase")
        Cmd("Store " .. index .. " /NC")
        Cmd("CD Root")
        line = get_osc_line_by_index(osc_base, index)
    end

    return line
end

------------------------------------------------------------
-- CONFIGURE OPENFOLLOW OSC LINE
------------------------------------------------------------

local function configure_openfollow_osc(ip_address, port)
    ------------------------------------------------------------
    -- CHECK / ENABLE GLOBAL OSC OUTPUT
    ------------------------------------------------------------

    if not ensure_osc_enable_output() then
        return false
    end

    ------------------------------------------------------------
    -- FIND OR CREATE OSC DATA LINE
    ------------------------------------------------------------

    local osc_base, osc_line, osc_index = find_openfollow_osc_line()

    if not osc_base then
        show_message("OSC Error", "OSCBase konnte nicht gefunden werden.")
        return false
    end

    if not osc_line then
        osc_line = create_osc_line(osc_base, osc_index)
    end

    if not osc_line then
        show_message("OSC Error", "OSC Data Line konnte nicht erstellt werden.")
        return false
    end

    ------------------------------------------------------------
    -- SET OSC DATA LINE (via API, tabellengetrieben)
    ------------------------------------------------------------

    set_handle_properties(osc_line, {
        { { "Name" }, "OpenFollow" },
        { { "DestinationIP", "DestinationIp", "Destination IP", "IP", "IPAddress", "IP Address" }, ip_address },
        { { "Port", "DestinationPort", "Destination Port" }, tonumber(port) },
        { { "Mode" }, "UDP" },
        { { "SendCmd", "SendCommand", "Send Commands", "SendCommands" }, 1 },
        { { "EnableOutput", "Enable Output", "Output" }, 1 },
    })

    ------------------------------------------------------------
    -- COMMAND LINE FALLBACK
    ------------------------------------------------------------

    Cmd("CD ShowData.OSCBase")
    Cmd('Set ' .. osc_index .. ' Name "OpenFollow"')
    Cmd('Set ' .. osc_index .. ' DestinationIP "' .. escape_quotes(ip_address) .. '"')
    Cmd('Set ' .. osc_index .. ' Port ' .. port)
    Cmd('Set ' .. osc_index .. ' Mode "UDP"')
    Cmd('Set ' .. osc_index .. ' SendCmd 1')
    Cmd('Set ' .. osc_index .. ' "Send Commands" 1')
    Cmd('Set ' .. osc_index .. ' EnableOutput 1')
    Cmd('Set ' .. osc_index .. ' "Enable Output" 1')
    Cmd("CD Root")

    show_message(
        "OpenFollow Settings",
        "OSC Data Line gespeichert:\n\n" ..
        "Name: OpenFollow\n" ..
        "IP: " .. ip_address .. "\n" ..
        "Port: " .. port .. "\n\n" ..
        "Enable Output wurde geprüft."
    )

    Printf("OpenFollow OSC Data Line configured.")
    Printf("OSC IP: " .. ip_address)
    Printf("OSC Port: " .. port)
    Printf("OSC Send Commands enabled")

    return true
end

------------------------------------------------------------
-- SETTINGS DIALOG
------------------------------------------------------------

local function open_settings()
    local popup = MessageBox({
        title = "OpenFollow Settings",

        commands = {
            { value = 1, name = "Save" },
            { value = 0, name = "Cancel" }
        },

        inputs = {
            { name = "IP Address", value = "127.0.0.1", order = 1 },
            { name = "Port", value = "8765", order = 2 }
        }
    })

    if not popup.success then return end
    if popup.result ~= 1 then return end

    local ip_address = get_input(popup, "IP Address")
    local port = get_input(popup, "Port")

    if not is_valid_ip(ip_address) then
        show_message("Invalid IP Address", "Bitte eine gültige IP-Adresse eingeben, z.B. 127.0.0.1.")
        return
    end

    if not is_valid_port(port) then
        show_message("Invalid Port", "Bitte einen gültigen Port zwischen 1 und 65535 eingeben.")
        return
    end

    configure_openfollow_osc(ip_address, port)
end

------------------------------------------------------------
-- MAIN: CREATE OPENFOLLOW CUE COMMAND
------------------------------------------------------------

local function create_openfollow_cue_command()
    local popup = MessageBox({
        title = "OpenFollow Message Setter",

        commands = {
            { value = 1, name = "Save" },
            { value = 2, name = "⚙ Settings" },
            { value = 0, name = "Cancel" }
        },

        inputs = {
            { name = "Sequence", value = "", order = 1 },
            { name = "Cue", value = "", order = 2 },
            { name = "Marker ID", value = "0", order = 3 },
            { name = "Message", value = "", order = 4 },
            { name = "Info", value = "", order = 5 },
            { name = "Dismiss-Time", value = "", order = 6 }
        }
    })

    if not popup.success then return end

    if popup.result == 2 then
        open_settings()
        return
    end

    if popup.result ~= 1 then return end

    local sequence_number = get_input(popup, "Sequence")
    local cue_number = get_input(popup, "Cue")
    local marker_id = get_input(popup, "Marker ID")
    local message = get_input(popup, "Message")
    local info = get_input(popup, "Info")
    local seconds = get_input(popup, "Dismiss-Time")

    ------------------------------------------------------------
    -- VALIDATION
    ------------------------------------------------------------

    if sequence_number == "" then
        show_message("Invalid Sequence", "Sequence darf nicht leer sein.")
        return
    end

    if cue_number == "" then
        show_message("Invalid Cue", "Cue darf nicht leer sein.")
        return
    end

    if not is_only_numbers(sequence_number) then
        show_message("Invalid Sequence", "Sequence darf nur Zahlen enthalten.")
        return
    end

    if not is_cue_number(cue_number) then
        show_message("Invalid Cue", "Cue darf nur eine Zahl sein, z.B. 1 oder 1.5.")
        return
    end

    if not is_only_numbers(marker_id) then
        show_message("Invalid Marker ID", "Marker ID darf nur Zahlen enthalten.")
        return
    end

    if not is_valid_seconds(seconds) then
        show_message("Invalid Dismiss-Time", "Dismiss-Time muss eine Zahl sein (z.B. 3 oder 3.5).")
        return
    end

    if contains_comma(message) or contains_comma(info) then
        show_message("Invalid Input", "Message und Info dürfen kein Komma (,) enthalten, da dies das OSC-Payload zerstört.")
        return
    end

    ------------------------------------------------------------
    -- BUILD CUE COMMAND
    ------------------------------------------------------------

    local part_number = OPENFOLLOW_PART_OFFSET + tonumber(marker_id)

    -- Message/Info werden escaped, um Anführungszeichen im Cmd-String abzusichern
    local osc_payload =
        "/message,ssif," ..
        escape_quotes(message) .. "," ..
        escape_quotes(info) .. "," ..
        marker_id .. "," ..
        seconds

    local cue_command =
        'SendOSC "OpenFollow" "' ..
        osc_payload ..
        '"'

    local part_target =
        "Sequence " .. sequence_number ..
        " Cue " .. cue_number ..
        " Part " .. part_number

    Cmd("Store " .. part_target .. " /Merge")

    local part_list = ObjectList(part_target)
    local part_handle = part_list and part_list[1]

    if not part_handle then
        show_message("Error", "Part konnte nicht gefunden werden: " .. part_target)
        return
    end

    local command_set_ok = pcall(function()
        part_handle.Command = cue_command
    end)

    if not command_set_ok then
        show_message("Error", "Command konnte nicht auf dem Part gesetzt werden: " .. part_target)
        return
    end

    local part_label = "OpenFollow ID " .. marker_id

    Cmd(
        'Label ' ..
        part_target ..
        ' "' ..
        escape_quotes(part_label) ..
        '"'
    )

    Printf("Used Sequence: " .. sequence_number)
    Printf("Used Cue: " .. cue_number)
    Printf("Used Part: " .. part_number)
    Printf("Stored Cue Command: " .. cue_command)
    Printf("Labeled Part: " .. part_label)
end

return create_openfollow_cue_command
