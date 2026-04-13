-- TextDraw Logger + TextDraw ID Detector
script_name("TextDraw Logger")
script_author("YourName")
script_version("1.1")

local encoding = require "encoding"
encoding.default = "CP1251"
local u8 = encoding.UTF8

local os = require "os"

local folder_path = "/storage/emulated/0/Android/media/com.newgamersrp.game/monetloader/"
local file_name = ""
local isLoggerActive = false
local renderTextDrawID = {}

function createFolderIfNotExists(path)
    local command = 'mkdir -p "' .. path .. '"'
    os.execute(command)
end

function generateFileName()
    local time = os.date("%Y%m%d_%H%M%S")
    file_name = folder_path .. "textdraw_" .. time .. ".txt"
end

function saveTextDrawToFile(data)
    if file_name == "" then
        generateFileName()
        print("File baru dibuat: " .. file_name)
    end
    local file, err = io.open(file_name, "a")
    if file then
        file:write(data .. "\n")
        file:close()
    else
        print("Gagal menyimpan file! Error: " .. tostring(err))
    end
end

function onReceiveRpc(id, bs)
    if not isLoggerActive then return end
    if id == 134 then
        local wTextDrawID = raknetBitStreamReadInt16(bs)
        local Flags = raknetBitStreamReadInt8(bs)
        local fLetterWidth = raknetBitStreamReadFloat(bs)
        local fLetterHeight = raknetBitStreamReadFloat(bs)
        local dLetterColor = raknetBitStreamReadInt32(bs)
        local fLineWidth = raknetBitStreamReadFloat(bs)
        local fLineHeight = raknetBitStreamReadFloat(bs)
        local dBoxColor = raknetBitStreamReadInt32(bs)
        local Shadow = raknetBitStreamReadInt8(bs)
        local Outline = raknetBitStreamReadInt8(bs)
        local dBackgroundColor = raknetBitStreamReadInt32(bs)
        local Style = raknetBitStreamReadInt8(bs)
        local Selectable = raknetBitStreamReadInt8(bs)
        local fX = raknetBitStreamReadFloat(bs)
        local fY = raknetBitStreamReadFloat(bs)
        local wModelID = raknetBitStreamReadInt16(bs)
        local fRotX = raknetBitStreamReadFloat(bs)
        local fRotY = raknetBitStreamReadFloat(bs)
        local fRotZ = raknetBitStreamReadFloat(bs)
        local fZoom = raknetBitStreamReadFloat(bs)
        local wColor1 = raknetBitStreamReadInt16(bs)
        local wColor2 = raknetBitStreamReadInt16(bs)
        local szTextLen = raknetBitStreamReadInt16(bs)
        local szText = raknetBitStreamReadString(bs, szTextLen)

        if Selectable == 1 then
            renderTextDrawID[wTextDrawID] = {x = fX, y = fY}
            sampAddChatMessage(string.format(
                "[TextDraw] ID: %d, Selectable: %d, X: %.2f, Y: %.2f, Text: %s",
                wTextDrawID, Selectable, fX, fY, szText
            ), -1)
        end

        local logData = string.format([[--------------------------------
TextDraw ID: %d
Flags: %d
Letter Width: %.3f
Letter Height: %.3f
Letter Color: %d
Line Width: %.3f
Line Height: %.3f
Box Color: %d
Shadow: %d
Outline: %d
Background Color: %d
Style: %d
Selectable: %d
X: %.3f
Y: %.3f
Model ID: %d
Rotation X: %.3f
Rotation Y: %.3f
Rotation Z: %.3f
Zoom: %.3f
Color 1: %d
Color 2: %d
Text: %s
        ]],
        wTextDrawID, Flags, fLetterWidth, fLetterHeight, dLetterColor,
        fLineWidth, fLineHeight, dBoxColor, Shadow, Outline,
        dBackgroundColor, Style, Selectable, fX, fY, wModelID,
        fRotX, fRotY, fRotZ, fZoom, wColor1, wColor2, szText
        )
        saveTextDrawToFile(logData)
    end
end

function initializeRender()
    font = renderCreateFont("Arial", 17, 4)
    if not font then
        print("Failed to create font! Using default.")
        font = renderCreateFont("default", 17, 4)
    end

    lua_thread.create(function()
        while true do
            wait(0)
            if isLoggerActive then
                local displayWidth, displayHeight = 1280, 720
                for id, pos in pairs(renderTextDrawID) do
                    local intermediateX = (pos.x / 640) * 1920
                    local intermediateY = (pos.y / 480) * 1080
                    local drawX = (intermediateX * displayWidth) / 1920 + 20
                    local drawY = (intermediateY * displayHeight) / 1080 - 40
                    renderFontDrawText(font, string.format("ID: %d", id), drawX, drawY, 0xFFFFFFFF)
                end
            end
        end
    end)
end

function toggleLogger()
    isLoggerActive = not isLoggerActive
    if isLoggerActive then
        sampAddChatMessage("[TextDraw Logger]: Aktif! Semua TextDraw akan dicatat.", -1)
    else
        sampAddChatMessage("[TextDraw Logger]: Nonaktif! Tidak ada TextDraw yang akan dicatat.", -1)
        renderTextDrawID = {}
    end
end

function clickTextDrawById(id)
    if tonumber(id) then
        local tdId = tonumber(id)
        sampSendClickTextdraw(tdId)
        sampAddChatMessage(string.format("[ClickTD]: Klik dikirim untuk TextDraw ID %d", tdId), 0xFF8000FF)
    else
        sampAddChatMessage("[ClickTD]: Gunakan format /clicktd <textdraw_id>", 0xFF0000FF)
    end
end

function detectExistingTextdraws()
    for i = 0, 2047 do
        if sampTextdrawIsExists(i) then
            local text = sampTextdrawGetString(i)
            sampAddChatMessage(string.format("[TextDraw Exists] ID: %d, Text: %s", i, text), -1)
        end
    end
end

function main()
    while not isSampAvailable() do wait(0) end
    createFolderIfNotExists(folder_path)
    sampRegisterChatCommand("td", toggleLogger)
    sampRegisterChatCommand("clicktd", clickTextDrawById)
    sampRegisterChatCommand("tdcek", detectExistingTextdraws)
    initializeRender()
    sampAddChatMessage("[TextDraw Logger]: Gunakan /td untuk aktif/nonaktif. Gunakan /tdcek untuk cek textdraw yang aktif.", -1)
end