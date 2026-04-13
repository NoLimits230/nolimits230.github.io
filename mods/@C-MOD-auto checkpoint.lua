local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

require 'lib.sampfuncs'
local sampev = require 'lib.samp.events'
local widgets = require 'widgets'

local WinState = imgui.new.bool(false)
local AutoFakeCp = imgui.new.bool(false)
local AutoFakeMap = imgui.new.bool(false)
local AutoDriveCp = imgui.new.bool(false)
local HidePlayer = imgui.new.bool(false)
local GhostProgress = imgui.new.bool(false)
local AutoCow = imgui.new.bool(false)

local was_pressed_menu = false
local cpX, cpY, cpZ = 0.0,0.0,0.0
local tab = 1

--=========================
-- KOORDINAT BOT SAPI
--=========================
local scanPoints = {
    {-1448.39, 1972.57},
    {-1456.38, 1972.22},
    {-1461.56, 1972.13},
    {-1496.90, 1974.56},
    {-1501.76, 1974.61},
    {-1509.83, 1974.47}
}

local kandangPintu = {
    {-1489.58, 1976.50},
    {-1468.52, 1971.90}
}

local pintuLuar = {-1485.27, 1980.47}

--=========================
-- DETEKSI CHECKPOINT
--=========================
function sampev.onSetCheckpoint(pos)
    cpX,cpY,cpZ = pos.x,pos.y,pos.z
    sampAddChatMessage(string.format("[BOT] Checkpoint: %.2f %.2f %.2f",cpX,cpY,cpZ),-1)
end

function sampev.onSetRaceCheckpoint(_,nextPos)
    cpX,cpY,cpZ = nextPos.x,nextPos.y,nextPos.z
    sampAddChatMessage(string.format("[BOT] Race CP: %.2f %.2f %.2f",cpX,cpY,cpZ),-1)
end

--=========================
-- HITUNG STEP
--=========================
function calculateSteps(x1,y1,z1,x2,y2,z2)
    local dist = getDistanceBetweenCoords3d(x1,y1,z1,x2,y2,z2)
    local steps = math.floor(dist/30)
    if steps < 8 then steps = 8 end
    return steps
end

--=========================
-- TELEPORT CEPAT
--=========================
function fakeTeleportFast(x1,y1,z1,x2,y2,z2)
    local steps = calculateSteps(x1,y1,z1,x2,y2,z2)
    for i=1,steps do
        local t = i/steps
        local nx = x1 + (x2-x1)*t
        local ny = y1 + (y2-y1)*t
        local nz = z1 + (z2-z1)*t
        setCharCoordinates(PLAYER_PED,nx,ny,nz)
        wait(math.random(90,130))
    end
end

--=========================
-- TELEPORT GHOST
--=========================
function fakeTeleportGhost(x1,y1,z1,x2,y2,z2)
    local steps = calculateSteps(x1,y1,z1,x2,y2,z2)
    for i=1,steps do
        sampAddChatMessage(string.format("[BOT] Langkah %d/%d menuju tujuan...",i,steps),-1)
        wait(math.random(90,130))
    end
    setCharCoordinates(PLAYER_PED,x2,y2,z2)
end

--=========================
-- TELEPORT CHECKPOINT
--=========================
function handleFakeTeleportToCheckpoint()
    local x,y,z = getCharCoordinates(PLAYER_PED)
    if cpX ~= 0.0 then
        sampAddChatMessage("[BOT] Menuju checkpoint...",-1)
        if GhostProgress[0] then
            fakeTeleportGhost(x,y,z,cpX,cpY,cpZ)
        else
            fakeTeleportFast(x,y,z,cpX,cpY,cpZ)
        end
        sampAddChatMessage("[BOT] Sampai di checkpoint!",-1)
    else
        sampAddChatMessage("[BOT] Tidak ada checkpoint!",-1)
    end
    AutoFakeCp[0] = false
end

--=========================
-- TELEPORT MARKER
--=========================
function handleFakeTeleportToMapMarker()
    local x,y,z = getCharCoordinates(PLAYER_PED)
    local found,mx,my,mz = getTargetBlipCoordinates()
    if found then
        sampAddChatMessage("[BOT] Menuju marker...",-1)
        if GhostProgress[0] then
            fakeTeleportGhost(x,y,z,mx,my,mz)
        else
            fakeTeleportFast(x,y,z,mx,my,mz)
        end
        sampAddChatMessage("[BOT] Sampai di marker!",-1)
    else
        sampAddChatMessage("[BOT] Marker tidak ditemukan!",-1)
    end
    AutoFakeMap[0] = false
end

--=========================
-- AUTO DRIVE
--=========================
function startAutoDrive()
lua_thread.create(function()
local lastCpX = 0.0
local lastCpY = 0.0

while AutoDriveCp[0] do
wait(0)

if not isCharInAnyCar(PLAYER_PED) then
sampAddChatMessage("[BOT] Harus berada di kendaraan!",-1)
AutoDriveCp[0] = false
break
end

local car = getCarCharIsUsing(PLAYER_PED)

if cpX ~= 0.0 then

if cpX ~= lastCpX or cpY ~= lastCpY then
taskCarDriveToCoord(PLAYER_PED,car,cpX,cpY,cpZ,30.0,1,0,0)
lastCpX = cpX
lastCpY = cpY
end

local cx,cy,cz = getCarCoordinates(car)
local dist = getDistanceBetweenCoords3d(cx,cy,cz,cpX,cpY,cpZ)

if dist < 10 then
setGameKeyState(1,255)
wait(500)
setGameKeyState(1,0)
wait(2000)
end

end

end
end)
end

--=========================
-- LOOP BOT
--=========================
function startAutoLoop()
lua_thread.create(function()
while true do
wait(500)
if AutoFakeCp[0] then handleFakeTeleportToCheckpoint() end
if AutoFakeMap[0] then handleFakeTeleportToMapMarker() end
end
end)
end

--=========================
-- AUTO COW
--=========================
function getNearestCow()
local px,py,pz = getCharCoordinates(PLAYER_PED)
local nearest,dist=nil,9999

for i=0,1000 do
if doesObjectExist(i) and getObjectModel(i)==19833 then
local ox,oy,oz=getObjectCoordinates(i)
local d=getDistanceBetweenCoords3d(px,py,pz,ox,oy,oz)
if d<dist then dist=d nearest={x=ox,y=oy,z=oz} end
end
end

return nearest,dist
end

function safeRun(x,y)
local px,py = getCharCoordinates(PLAYER_PED)
runToPoint(x,y)
wait(1200)
local nx,ny = getCharCoordinates(PLAYER_PED)
if getDistanceBetweenCoords2d(px,py,nx,ny)<1.0 then
runToPoint(x,y)
wait(1200)
end
end

function scanArea()
for _,p in ipairs(scanPoints) do
safeRun(p[1],p[2])
wait(300)
end
end

function goPintuLuar()
safeRun(pintuLuar[1],pintuLuar[2])
wait(800)
end

function enterKandang(cow)
local best,dist=nil,9999
for _,d in ipairs(kandangPintu) do
local d2=getDistanceBetweenCoords3d(cow.x,cow.y,cow.z,d[1],d[2],0)
if d2<dist then dist=d2 best=d end
end
if best then safeRun(best[1],best[2]) end
end

function milkCow(cow)
safeRun(cow.x,cow.y)
wait(800)
SendKey(0x59)
wait(3000)
end

function exitKandang()
for _,d in ipairs(kandangPintu) do
safeRun(d[1],d[2])
wait(300)
end
end

function startAutoCow()
lua_thread.create(function()
while AutoCow[0] do
wait(0)

scanArea()

local cow,dist = getNearestCow()

if cow then
sampAddChatMessage("[BOT] Sapi ditemukan",-1)

if dist < 15 then
goPintuLuar()
end

enterKandang(cow)
milkCow(cow)
exitKandang()
else
sampAddChatMessage("[BOT] Tidak ada sapi",-1)
end

wait(1000)
end
end)
end

--=========================
-- UI
--=========================
imgui.OnFrame(function() return WinState[0] end,function()

imgui.SetNextWindowSize(imgui.ImVec2(500,270),imgui.Cond.FirstUseEver)
imgui.Begin(u8'C-MOD Fake Teleport Bot',WinState,imgui.WindowFlags.NoResize)

for i,name in ipairs({'MENU','BOT','VIP'}) do
if i>1 then imgui.SameLine() end
if imgui.Button(u8(name),imgui.ImVec2(120,35)) then tab=i end
end

imgui.Separator()

if imgui.BeginChild("tabChild",imgui.ImVec2(-1,-1),true) then

if tab==1 then
imgui.Text(u8"Menu Utama")

imgui.Checkbox(u8'Fake Teleport Checkpoint',AutoFakeCp)
imgui.Checkbox(u8'Fake Teleport Marker',AutoFakeMap)
imgui.Checkbox(u8'Ghost Progress Teleport',GhostProgress)

if imgui.Checkbox(u8'Auto Pilot Drive Checkpoint',AutoDriveCp) then
if AutoDriveCp[0] then startAutoDrive() end
end

elseif tab==2 then
imgui.Text(u8"Menu BOT Sapi")

if imgui.Checkbox(u8'Auto Perah Sapi',AutoCow) then
if AutoCow[0] then startAutoCow() end
end

elseif tab==3 then
imgui.Text(u8"Menu VIP")

if imgui.Checkbox(u8'Sembunyikan Semua Player',HidePlayer) then
if HidePlayer[0] then
for i=0,1000 do
if sampIsPlayerConnected(i) then
local bs = raknetNewBitStream()
raknetBitStreamWriteInt16(bs,i)
raknetEmulRpcReceiveBitStream(163,bs)
raknetDeleteBitStream(bs)
end
end
sampAddChatMessage("[VIP] Semua player disembunyikan!",-1)
end
end

end

imgui.EndChild()
end

imgui.End()
end)

--=========================
-- MAIN
--=========================
function main()
repeat wait(0) until isSampAvailable()
startAutoLoop()

while true do
wait(0)
local pressed = isWidgetPressed(WIDGET_PHONE)
if pressed and not was_pressed_menu then
WinState[0] = not WinState[0]
end
was_pressed_menu = pressed
end
end

function SendKey(Key)
local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
local data = allocateMemory(68)
sampStorePlayerOnfootData(myId, data)
setStructElement(data, 36, 1, Key, false)
sampSendOnfootData(data)
freeMemory(data)
end

function runToPoint(tox, toy)
local x, y, z = getCharCoordinates(PLAYER_PED)
local angle = getHeadingFromVector2d(tox - x, toy - y)
local xAngle = math.random(-50, 50)/100
setCameraPositionUnfixed(xAngle, math.rad(angle - 90))
stopRun = false

while getDistanceBetweenCoords2d(x, y, tox, toy) > 0.8 do
setGameKeyState(1, -255)
wait(1)

x, y, z = getCharCoordinates(PLAYER_PED)
angle = getHeadingFromVector2d(tox - x, toy - y)
setCameraPositionUnfixed(xAngle, math.rad(angle - 90))

SendKey(64)

if stopRun then
stopRun = false
break
end
end
end