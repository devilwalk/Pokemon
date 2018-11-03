local EntityWatcher = require("EntityWatcher")
local Globals = require("Globals")
local MiniGameUISystem = InitMiniGameUISystem()
-----------------------------------------------------------------------------------------Common Function--------------------------------------------------------------------------------
local function assert(boolean, message)
    if not boolean then
        echo(
            "devilwalk",
            "devilwalk----------------------------------------------------------------assert failed!!!!:message:" ..
                tostring(message)
        )
    end
end
local function clone(from)
    local ret
    if type(from) == "table" then
        ret = {}
        for key, value in pairs(from) do
            ret[key] = clone(value)
        end
    else
        ret = from
    end
    return ret
end
local function new(class, parameters)
    local new_table = {}
    setmetatable(new_table, {__index = class})
    for key, value in pairs(class) do
        new_table[key] = clone(value)
    end
    local list = {}
    local dst = new_table
    while dst do
        list[#list + 1] = dst
        dst = dst._super
    end
    for i = #list, 1, -1 do
        list[i].construction(new_table, parameters)
    end
    return new_table
end
local function delete(inst)
    if inst then
        local list = {}
        local dst = inst
        while dst do
            list[#list + 1] = dst
            dst = dst._super
        end
        for i = 1, #list do
            list[i].destruction(inst)
        end
    end
end
local function inherit(class)
    local new_table = {}
    setmetatable(new_table, {__index = class})
    for key, value in pairs(class) do
        new_table[key] = clone(value)
    end
    new_table._super = class
    return new_table
end
local function lineStrings(text)
    local ret = {}
    local line = ""
    for i = 1, string.len(text) do
        local char = string.sub(text, i, i)
        if char == "\n" then
            ret[#ret + 1] = line
            line = ""
        elseif char == "\r" then
        else
            line = line .. char
        end
    end
    if line ~= "\n" and line ~= "" then
        ret[#ret + 1] = line
    end
    return ret
end
local function vec2Equal(vec1, vec2)
    return vec1[1] == vec2[1] and vec1[2] == vec2[2]
end
local function vec3Equal(vec1, vec2)
    return vec1[1] == vec2[1] and vec1[2] == vec2[2] and vec1[3] == vec2[3]
end
local function array(t)
    local ret = {}
    for _, value in pairs(t) do
        ret[#ret + 1] = value
    end
    return ret
end
local gOriginBlockIDs = {}
local function setBlock(x, y, z, blockID)
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
    if not gOriginBlockIDs[key] then
        gOriginBlockIDs[key] = {mBlockID = GetBlockId(x, y, z), mPosition = {x, y, z}}
    end
    SetBlock(x, y, z, blockID)
end
local function restoreBlock(x, y, z)
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
    if gOriginBlockIDs[key] then
        SetBlock(x, y, z, gOriginBlockIDs[key].mBlockID)
    end
end
local function restoreAllBlocks()
    for _, block in pairs(gOriginBlockIDs) do
        SetBlock(block.mPosition[1], block.mPosition[2], block.mPosition[3], block.mBlockID)
    end
end
-----------------------------------------------------------------------------------------Library-----------------------------------------------------------------------------------
Command = {}
Command_Callback = inherit(Command)
CommandQueue = {}
Property = {}
PropertyGroup = {}
EntitySyncer = {}
EntitySyncerManager = {}
-----------------------------------------------------------------------------------------Command-----------------------------------------------------------------------------------
Command.EState = {Unstart = 0, Executing = 1, Finish = 2}
function Command:construction(parameter)
    -- echo("devilwalk", "devilwalk--------------------------------------------debug:Command:construction:parameter:")
    -- echo("devilwalk", parameter)
    self.mDebug = parameter.mDebug
    self.mState = Command.EState.Unstart
    self.mTimeOutProcess = parameter.mTimeOutProcess
end

function Command:destruction()
end

function Command:execute()
    self.mState = Command.EState.Executing
    echo("devilwalk", "devilwalk--------------------------------------------debug:Command:execute:self.mDebug:")
    echo("devilwalk", self.mDebug)
end

function Command:frameMove()
    if self.mState == Command.EState.Unstart then
        self:execute()
    elseif self.mState == Command.EState.Executing then
        self:executing()
    elseif self.mState == Command.EState.Finish then
        self:finish()
        return true
    end
end

function Command:executing()
    self.mExecutingTime = self.mExecutingTime or 0
    if self.mExecutingTime > 1000 then
        if self.mTimeOutProcess then
            self:mTimeOutProcess(self)
        else
            echo(
                "devilwalk",
                "devilwalk--------------------------------------------debug:Command:executing time out:self.mDebug:"
            )
            echo("devilwalk", self.mDebug)
        end
    end
    self.mExecutingTime = self.mExecutingTime + 1
end

function Command:finish()
    echo("devilwalk", "devilwalk--------------------------------------------debug:Command:finish:self.mDebug:")
    echo("devilwalk", self.mDebug)
end

function Command:stop()
    -- echo("devilwalk", "devilwalk--------------------------------------------debug:Command:stop:self.mDebug:")
    -- echo("devilwalk",self.mDebug)
end

function Command:restore()
    -- echo("devilwalk", "devilwalk--------------------------------------------debug:Command:restore:self.mDebug:")
    -- echo("devilwalk",self.mDebug)
end
-----------------------------------------------------------------------------------------Command Callback-----------------------------------------------------------------------------------------
function Command_Callback:construction(parameter)
    -- echo(
    --     "devilwalk",
    --     "devilwalk--------------------------------------------debug:Command_Callback:construction:parameter:"
    -- )
    -- echo("devilwalk", parameter)
    self.mExecuteCallback = parameter.mExecuteCallback
    self.mExecutingCallback = parameter.mExecutingCallback
    self.mFinishCallback = parameter.mFinishCallback
end

function Command_Callback:execute()
    Command_Callback._super.execute(self)
    if self.mExecuteCallback then
        self.mExecuteCallback(self)
    end
end

function Command_Callback:executing()
    Command_Callback._super.executing(self)
    if self.mExecutingCallback then
        self.mExecutingCallback(self)
    end
end

function Command_Callback:finish()
    Command_Callback._super.finish(self)
    if self.mFinishCallback then
        self.mFinishCallback(self)
    end
end
-----------------------------------------------------------------------------------------CommandQueue-----------------------------------------------------------------------------------
function CommandQueue:construction()
    self.mCommands = {}
end

function CommandQueue:destruction()
    if self.mCommands and #self.mCommands > 0 then
        for _, command in pairs(self.mCommands) do
            echo(
                "devilwalk",
                "devilwalk--------------------------------------------warning:CommandQueue:delete:command:" ..
                    tostring(command.mDebug)
            )
        end
    end
    self.mCommands = nil
end

function CommandQueue:update()
    if self.mCommands[1] then
        local ret = self.mCommands[1]:frameMove()
        if ret then
            table.remove(self.mCommands, 1)
        end
    end
end

function CommandQueue:post(cmd)
    echo("devilwalk", "CommandQueue:post:")
    echo("devilwalk", cmd.mDebug)
    self.mCommands[#self.mCommands + 1] = cmd
end

function CommandQueue:empty()
    return #self.mCommands == 0
end
-----------------------------------------------------------------------------------------Property-----------------------------------------------------------------------------------------
function Property:construction()
    self.mCommandQueue = new(CommandQueue)
    self.mCache = {}
    self.mCommandRead = {}
    self.mCommandWrite = {}
end

function Property:destruction()
    delete(self.mCommandQueue)
    if self.mPropertyListeners then
        for property, listeners in pairs(self.mPropertyListeners) do
            GlobalProperty.removeListener(self:_getLockKey(property), self)
        end
    end
end

function Property:update()
    self.mCommandQueue:update()
end

function Property:lockRead(property, callback)
    GlobalProperty.lockRead(
        self:_getLockKey(property),
        function(value)
            self.mCache[property] = value
            callback(value)
        end
    )
end

function Property:unlockRead(property)
    GlobalProperty.unlockRead(self:_getLockKey(property))
end

function Property:lockWrite(property, callback)
    GlobalProperty.lockWrite(
        self:_getLockKey(property),
        function(value)
            self.mCache[property] = value
            callback(value)
        end
    )
end

function Property:unlockWrite(property)
    GlobalProperty.unlockWrite(self:_getLockKey(property))
end

function Property:write(property, value, callback)
    self.mCache[property] = value
    GlobalProperty.write(self:_getLockKey(property), value, callback)
end

function Property:safeWrite(property, value, callback)
    self.mCache[property] = value
    GlobalProperty.lockAndWrite(self:_getLockKey(property), value, callback)
end

function Property:safeRead(property, callback)
    self:lockRead(
        property,
        function(value)
            self:unlockRead(property)
            callback(value)
        end
    )
end

function Property:read(property, callback)
    GlobalProperty.read(
        self:_getLockKey(property),
        function(value)
            self.mCache[property] = value
            callback(value)
        end
    )
end

function Property:commandRead(property)
    -- self.mCommandQueue:post(
    --     new(
    --         Command_Callback,
    --         {
    --             mDebug = "Property:commandRead:" .. property,
    --             mExecuteCallback = function(command)
    --                 self:safeRead(
    --                     property,
    --                     function()
    --                         command.mState = Command.EState.Finish
    --                     end
    --                 )
    --             end
    --         }
    --     )
    -- )
    self.mCommandRead[property] = true
    self:safeRead(
        property,
        function()
            self.mCommandRead[property] = nil
        end
    )
end

function Property:commandWrite(property, value)
    -- self.mCommandQueue:post(
    --     new(
    --         Command_Callback,
    --         {
    --             mDebug = "Property:commandWrite:" .. property,
    --             mExecuteCallback = function(command)
    --                 self:safeWrite(
    --                     property,
    --                     value,
    --                     function()
    --                         command.mState = Command.EState.Finish
    --                     end
    --                 )
    --             end
    --         }
    --     )
    -- )
    self.mCommandWrite[property] = true
    self:safeWrite(
        property,
        value,
        function()
            self.mCommandWrite[property] = nil
        end
    )
end

function Property:commandFinish(callback)
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Property:commandFinish",
                mTimeOutProcess = function()
                    echo(
                        "devilwalk",
                        "Property:commandFinish:time out--------------------------------------------------------------"
                    )
                    for property, _ in pairs(self.mCommandRead) do
                        echo("devilwalk", "self.mCommandRead:" .. property)
                    end
                    for property, _ in pairs(self.mCommandRead) do
                        echo("devilwalk", "self.mCommandWrite:" .. property)
                    end
                end,
                mExecutingCallback = function(command)
                    if not next(self.mCommandRead) and not next(self.mCommandWrite) then
                        callback()
                        command.mState = Command.EState.Finish
                    end
                end
            }
        )
    )
end

function Property:cache()
    return self.mCache
end

function Property:addPropertyListener(property, callbackKey, callback, parameter)
    callbackKey = tostring(callbackKey)
    self.mPropertyListeners = self.mPropertyListeners or {}
    if not self.mPropertyListeners[property] then
        GlobalProperty.addListener(
            self:_getLockKey(property),
            self,
            function(_, value, preValue)
                self.mCache[property] = value
                self:notifyProperty(property, value, preValue)
            end
        )
    end
    self.mPropertyListeners[property] = self.mPropertyListeners[property] or {}
    self.mPropertyListeners[property][callbackKey] = {mCallback = callback, mParameter = parameter}

    self:read(
        property,
        function(value)
            if value then
                callback(parameter, value, value)
            end
        end
    )
end

function Property:removePropertyListener(property, callbackKey)
    callbackKey = tostring(callbackKey)
    self.mPropertyListeners[property][callbackKey] = nil
end

function Property:notifyProperty(property, value, preValue)
    -- echo("devilwalk", "Property:notifyProperty:property:" .. property)
    -- echo("devilwalk", value)
    if self.mPropertyListeners and self.mPropertyListeners[property] then
        for _, listener in pairs(self.mPropertyListeners[property]) do
            listener.mCallback(listener.mParameter, value, preValue)
        end
    end
end
-----------------------------------------------------------------------------------------Property Group-----------------------------------------------------------------------------------
function PropertyGroup:construction()
    self.mProperties = {}
end

function PropertyGroup:destruction()
end

function PropertyGroup:commandRead(propertyInstance, propertyName)
    propertyInstance:commandRead(propertyName)
    self.mProperties[tostring(propertyInstance)] = true
end

function PropertyGroup:commandWrite(propertyInstance, propertyName, propertyValue)
    propertyInstance:commandWrite(propertyName, propertyValue)
    self.mProperties[tostring(propertyInstance)] = true
end

function PropertyGroup:commandFinish(callback)
    local function _finish(propertyInstance)
        self.mProperties[tostring(propertyInstance)] = nil
        if not next(self.mProperties) then
            callback()
        end
    end
    for property_instance, _ in pairs(self.mProperties) do
        property_instance:commandFinish(
            function()
                _finish(property_instance)
            end
        )
    end
end
-----------------------------------------------------------------------------------------Entity Syncer----------------------------------------------------------------------------------------
function EntitySyncer:construction(parameter)
    if parameter.mEntityID then
        self.mEntityID = parameter.mEntityID
    else
        self.mEntityID = parameter.mEntity.entityId
    end
    self.mCommandQueue = new(CommandQueue)
end

function EntitySyncer:destruction()
end

function EntitySyncer:getEntity()
    return GetEntityById(self.mEntityID)
end

function EntitySyncer:update()
    self.mCommandQueue:update()
end

function EntitySyncer:setDisplayName(name, colour)
    self:broadcast("DisplayName", {mName = name, mColour = colour})
end

function EntitySyncer:setLocalDisplayNameColour(colour)
    self.mLocalDisplayNameColour = colour
    if self:getEntity() then
        self:getEntity():UpdateDisplayName(nil, self.mLocalDisplayNameColour)
    end
end

function EntitySyncer:broadcast(key, value)
    Host.broadcast(
        {mKey = "EntitySyncer", mEntityID = self:getEntity().entityId, mParameter = {mKey = key, mValue = value}}
    )
end

function EntitySyncer:receive(parameter)
    if not self:getEntity() then
        local parameter_clone = clone(parameter)
        self.mCommandQueue:post(
            new(
                Command_Callback,
                {
                    mDebug = "EntitySyncer:receive:mEntityID:" .. tostring(self.mEntityID),
                    mExecutingCallback = function(command)
                        if self:getEntity() then
                            self:receive(parameter_clone)
                            command.mState = Command.EState.Finish
                        end
                    end
                }
            )
        )
    else
        if parameter.mKey == "DisplayName" then
            -- echo("devilwalk","EntitySyncer:receive:DisplayName:"..parameter.mValue)
            self:getEntity():UpdateDisplayName(
                parameter.mValue.mName,
                self.mLocalDisplayNameColour or parameter.mValue.mColour
            )
        end
    end
end
-----------------------------------------------------------------------------------------Entity Syncer Manager----------------------------------------------------------------------------------------
function EntitySyncerManager.singleton()
    if not EntitySyncerManager.mInstance then
        EntitySyncerManager.mInstance = new(EntitySyncerManager)
    end
    return EntitySyncerManager.mInstance
end
function EntitySyncerManager:construction()
    self.mEntities = {}
    Client.addListener("EntitySyncer", self)
end

function EntitySyncerManager:destruction()
end

function EntitySyncerManager:update()
    for _, entity in pairs(self.mEntities) do
        entity:update()
    end
end

function EntitySyncerManager:receive(parameter)
    local entity = self.mEntities[parameter.mEntityID]
    if not entity then
        entity = new(EntitySyncer, {mEntityID = parameter.mEntityID})
        self.mEntities[parameter.mEntityID] = entity
    end
    entity:receive(parameter.mParameter)
end

function EntitySyncerManager:attach(entity)
    if not self.mEntities[entity.entityId] then
        self.mEntities[entity.entityId] = new(EntitySyncer, {mEntity = entity})
    end
end

function EntitySyncerManager:get(entity)
    self:attach(entity)
    return self.mEntities[entity.entityId]
end

function EntitySyncerManager:getByEntityID(entityID)
    return self.mEntities[entityID]
end
-----------------------------------------------------------------------------------------Table Define-----------------------------------------------------------------------------------
InputManager = {}
Host = {}
Client = {}
GlobalProperty = {}
GlobalOperation = {}

GameUI = {}
GameConfig = {}
GameCompute = {}
TravelHost = {}
TravelClient = {}
FightSceneProperty = inherit(Property)
FightSceneHost = {}
FightSceneClient = {}
FightMonsterProperty = inherit(Property)
FightMonster = {}
Game = {}
GamePlayer = {}
Monster = {}
FightHost = {}
FightClient = {}
FightLogic = {}
-----------------------------------------------------------------------------------------Game UI-----------------------------------------------------------------------------------------
function GameUI.messageBox(text, img)
    if GameUI.mMessageBox then
        GameUI.mMessageBoxMessageQueue = GameUI.mMessageBoxMessageQueue or {}
        GameUI.mMessageBoxMessageQueue[#GameUI.mMessageBoxMessageQueue + 1] = text
        return
    end
    GameUI.mMessageBox = MiniGameUISystem.createWindow("Pokemon/GameUI/MessageBox", "_ct", 0, 0, 600, 400)
    GameUI.mMessageBox:setZOrder(500)
    local background =
        GameUI.mMessageBox:createUI("Picture", "Pokemon/GameUI/MessageBox/Picture", "_lt", 0, 0, 600, 400)
    background:setBackgroundResource(56)
    if img then
        local image =
            GameUI.mMessageBox:createUI(
            "Picture",
            "Pokemon/GameUI/MessageBox/Picture/Image",
            "_lt",
            50,
            100,
            500,
            200,
            background
        )
        image:setBackgroundResource(img)
    end
    local info = GameUI.mMessageBox:createUI("Text", "Pokemon/GameUI/MessageBox/Text", "_lt", 0, 0, 600, 90, background)
    info:setTextFormat(5)
    info:setFontSize(25)
    info:setText(text)
    info:setFontColour("255 255 255")
    local button =
        GameUI.mMessageBox:createUI("Button", "Pokemon/GameUI/MessageBox/Button", "_lt", 250, 300, 100, 100, background)
    button:setBackgroundResource(34, nil, nil, nil, nil, "FtFq7Cxh7NP2JrWjJX2zUPdWFwJ7")
    button:addEventFunction(
        "onclick",
        function()
            MiniGameUISystem.destroyWindow(GameUI.mMessageBox)
            GameUI.mMessageBox = nil
            if GameUI.mMessageBoxMessageQueue and GameUI.mMessageBoxMessageQueue[1] then
                local new_text = GameUI.mMessageBoxMessageQueue[1]
                table.remove(GameUI.mMessageBoxMessageQueue, 1)
                GameUI.messageBox(new_text)
            end
        end
    )
end

function GameUI.yesOrNo(text, yesCallback, noCallback)
    if GameUI.mYesOrNo then
        MiniGameUISystem.destroyWindow(GameUI.mYesOrNo)
    end
    GameUI.mYesOrNo = MiniGameUISystem.createWindow("Pokemon/GameUI/YesOrNo", "_ct", 0, 0, 600, 400)
    GameUI.mYesOrNo:setZOrder(400)
    local background = GameUI.mYesOrNo:createUI("Picture", "Pokemon/GameUI/YesOrNo/Picture", "_lt", 0, 0, 600, 400)
    background:setBackgroundResource(56)
    local info = GameUI.mYesOrNo:createUI("Text", "Pokemon/GameUI/YesOrNo/Text", "_lt", 0, 0, 600, 90, background)
    info:setTextFormat(5)
    info:setFontSize(25)
    info:setText(text)
    info:setFontColour("255 255 255")
    local button_yes =
        GameUI.mYesOrNo:createUI("Button", "Pokemon/GameUI/YesOrNo/Button/Yes", "_lt", 200, 300, 100, 100, background)
    button_yes:setFontSize(25)
    button_yes:setBackgroundResource(160)
    button_yes:addEventFunction(
        "onclick",
        function()
            MiniGameUISystem.destroyWindow(GameUI.mYesOrNo)
            GameUI.mYesOrNo = nil
            if yesCallback then
                yesCallback()
            end
        end
    )
    local button_no =
        GameUI.mYesOrNo:createUI("Button", "Pokemon/GameUI/YesOrNo/Button/No", "_lt", 400, 300, 100, 100, background)
    button_no:setFontSize(25)
    button_no:setBackgroundResource(161)
    button_no:addEventFunction(
        "onclick",
        function()
            MiniGameUISystem.destroyWindow(GameUI.mYesOrNo)
            GameUI.mYesOrNo = nil
            if noCallback then
                noCallback()
            end
        end
    )
end

function GameUI.showBasicTravelWindow(gamePlayer)
    if GameUI.mBasicTravelWindowUp then
        MiniGameUISystem.destroyWindow(GameUI.mBasicTravelWindowUp)
    end
    GameUI.mBasicTravelWindowUp =
        MiniGameUISystem.createWindow("Pokemon/GameUI/BasicTravelWindow/Up", "_lt", 0, 0, 1920, 150)
    GameUI.mBasicTravelWindowUp:setZOrder(100)
    local picture_up_background =
        GameUI.mBasicTravelWindowUp:createUI(
        "Picture",
        "Pokemon/GameUI/BasicTravelWindow/Up/Picture/Background",
        "_lt",
        0,
        0,
        1920,
        150
    )
    local picture_up_head =
        GameUI.mBasicTravelWindowUp:createUI(
        "Picture",
        "Pokemon/GameUI/BasicTravelWindow/Up/Picture/Head",
        "_lt",
        0,
        0,
        150,
        150,
        picture_up_background
    )
    picture_up_head:setBackgroundResource(123, nil, nil, nil, nil, "FneBrULbLfM82KI7NZ-Vw8c_tuST")

    if GameUI.mBasicTravelWindowDown then
        MiniGameUISystem.destroyWindow(GameUI.mBasicTravelWindowDown)
    end
    GameUI.mBasicTravelWindowDown =
        MiniGameUISystem.createWindow("Pokemon/GameUI/BasicTravelWindow/Down", "_lt", 0, 980, 1920, 100)
    GameUI.mBasicTravelWindowDown:setZOrder(100)
    local picture_down_background =
        GameUI.mBasicTravelWindowDown:createUI(
        "Picture",
        "Pokemon/GameUI/BasicTravelWindow/Down/Picture/Background",
        "_lt",
        0,
        0,
        1920,
        100
    )
    local button_down_monsters =
        GameUI.mBasicTravelWindowDown:createUI(
        "Button",
        "Pokemon/GameUI/BasicTravelWindow/Down/Button/Monsters",
        "_lt",
        0,
        0,
        100,
        100,
        picture_down_background
    )
    button_down_monsters:setText("宠物")
    button_down_monsters:setFontSize(50)
    button_down_monsters:addEventFunction(
        "onclick",
        function()
            GameUI.showTravelMonstersWindow(gamePlayer)
        end
    )

    if GameUI.mBasicTravelWindowLeft then
        MiniGameUISystem.destroyWindow(GameUI.mBasicTravelWindowLeft)
    end
    GameUI.mBasicTravelWindowLeft =
        MiniGameUISystem.createWindow("Pokemon/GameUI/BasicTravelWindow/Left", "_lt", 0, 165, 150, 800)
    GameUI.mBasicTravelWindowLeft:setZOrder(100)
    GameUI.mBasicTravelWindowLeft_PlayerListStartIndex = 1
    local picture_left_background =
        GameUI.mBasicTravelWindowLeft:createUI(
        "Picture",
        "Pokemon/GameUI/BasicTravelWindow/Left/Picture/Background",
        "_lt",
        0,
        0,
        150,
        800
    )
    local button_left_player_list_up =
        GameUI.mBasicTravelWindowLeft:createUI(
        "Button",
        "Pokemon/GameUI/BasicTravelWindow/Left/Button/PlayerListUp",
        "_ctt",
        0,
        0,
        25,
        25,
        picture_left_background
    )
    button_left_player_list_up:setBackgroundResource(880, nil, nil, nil, nil, "FuSKsieBX5y4OQQwwlFQt5p8prkV")
    button_left_player_list_up:addEventFunction(
        "onclick",
        function()
            GameUI.mBasicTravelWindowLeft_PlayerListStartIndex =
                math.max(1, GameUI.mBasicTravelWindowLeft_PlayerListStartIndex - 1)
            GameUI.refreshBasicTravelWindow()
        end
    )
    local button_left_player_list_down =
        GameUI.mBasicTravelWindowLeft:createUI(
        "Button",
        "Pokemon/GameUI/BasicTravelWindow/Left/Button/PlayerListDown",
        "_ctb",
        0,
        0,
        25,
        25,
        picture_left_background
    )
    button_left_player_list_down:setBackgroundResource(881, nil, nil, nil, nil, "FnVe_fwd5qoHgSdb06Q7iW6Mj0VU")
    button_left_player_list_down:addEventFunction(
        "onclick",
        function()
            GameUI.mBasicTravelWindowLeft_PlayerListStartIndex = GameUI.mBasicTravelWindowLeft_PlayerListStartIndex + 1
            GameUI.refreshBasicTravelWindow()
        end
    )
    for i = 1, 5 do
        local button_left_player_list =
            GameUI.mBasicTravelWindowLeft:createUI(
            "Button",
            "Pokemon/GameUI/BasicTravelWindow/Left/Button/PlayerList/" .. tostring(i),
            "_lt",
            0,
            25 + (i - 1) * 150,
            150,
            150,
            picture_left_background
        )
        button_left_player_list:addEventFunction(
            "onclick",
            function()
                local players = clone(Game.singleton().mPlayers)
                players[GetPlayerId()] = nil
                players = array(players)
                local player = players[GameUI.mBasicTravelWindowLeft_PlayerListStartIndex + i - 1]
                GameUI.yesOrNo(
                    "挑战" .. GetEntityById(player.mID).nickname .. "吗？",
                    function()
                        Game.singleton().mFightClient:tryBattle(player.mID)
                    end
                )
            end
        )
        button_left_player_list:setFontSize(30)
    end
    GameUI.refreshBasicTravelWindow()
end

function GameUI.refreshBasicTravelWindow()
    if GameUI.mBasicTravelWindowLeft then
        local players = clone(Game.singleton().mPlayers)
        players[GetPlayerId()] = nil
        players = array(players)
        GameUI.mBasicTravelWindowLeft_PlayerListStartIndex =
            math.min(math.max(1, #players - 4), GameUI.mBasicTravelWindowLeft_PlayerListStartIndex)
        if #players > 0 then
            for i = 1, 5 do
                local player = players[GameUI.mBasicTravelWindowLeft_PlayerListStartIndex + i - 1]
                if player then
                    local button_left_player_list =
                        GameUI.mBasicTravelWindowLeft:getUI(
                        "Pokemon/GameUI/BasicTravelWindow/Left/Button/PlayerList/" .. tostring(i)
                    )
                    button_left_player_list:setText(GetEntityById(player.mID).nickname)
                end
            end
        end
    end
end

function GameUI.closeBasicTravelWindow()
    if GameUI.mBasicTravelWindowUp then
        MiniGameUISystem.destroyWindow(GameUI.mBasicTravelWindowUp)
        GameUI.mBasicTravelWindowUp = nil
    end
    if GameUI.mBasicTravelWindowDown then
        MiniGameUISystem.destroyWindow(GameUI.mBasicTravelWindowDown)
        GameUI.mBasicTravelWindowDown = nil
    end
    if GameUI.mBasicTravelWindowLeft then
        MiniGameUISystem.destroyWindow(GameUI.mBasicTravelWindowLeft)
        GameUI.mBasicTravelWindowLeft = nil
    end
end

function GameUI.showTravelMonstersWindow(gamePlayer)
    if GameUI.mTravelMonstersWindow then
        MiniGameUISystem.destroyWindow(GameUI.mTravelMonstersWindow)
    end
    GameUI.mTravelMonstersWindow =
        MiniGameUISystem.createWindow("Pokemon/GameUI/TravelMonstersWindow", "_lt", 0, 0, 1920, 1080)
    local picture_background = GameUI.mTravelMonstersWindow:setZOrder(101)
    GameUI.mTravelMonstersWindow:createUI(
        "Picture",
        "Pokemon/GameUI/TravelMonstersWindow/Picture/Background",
        "_lt",
        0,
        0,
        1920,
        1080
    )
    local button_close =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/Close",
        "_lt",
        1870,
        0,
        50,
        50,
        picture_background
    )
    button_close:setBackgroundResource(15, nil, nil, nil, nil, "Fks3BQ5iCMkO8SJmgr1JSgqj0wDP")
    button_close:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonstersWindow()
        end
    )
    local button_property =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/Property",
        "_lt",
        1800,
        100,
        100,
        100,
        picture_background
    )
    button_property:setText("属性")
    button_property:setFontSize(50)
    button_property:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonsterSkillWindow()
            GameUI.closeTravelMonsterIndividualPropertyWindow()
            GameUI.showTravelMonsterPropertyWindow(gamePlayer)
        end
    )
    local button_love =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/Love",
        "_lt",
        1800,
        220,
        100,
        100,
        picture_background
    )
    button_love:setText("亲密")
    button_love:setFontSize(50)
    button_love:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonsterPropertyWindow()
            GameUI.closeTravelMonsterSkillWindow()
            GameUI.closeTravelMonsterIndividualPropertyWindow()
            GameUI.messageBox("设计中......")
        end
    )
    local button_skill =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/Skill",
        "_lt",
        1800,
        340,
        100,
        100,
        picture_background
    )
    button_skill:setText("技能")
    button_skill:setFontSize(50)
    button_skill:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonsterPropertyWindow()
            GameUI.closeTravelMonsterIndividualPropertyWindow()
            GameUI.showTravelMonsterSkillWindow(gamePlayer)
        end
    )
    local button_equipment =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/Equipment",
        "_lt",
        1800,
        460,
        100,
        100,
        picture_background
    )
    button_equipment:setText("装备")
    button_equipment:setFontSize(50)
    button_equipment:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonsterPropertyWindow()
            GameUI.closeTravelMonsterSkillWindow()
            GameUI.closeTravelMonsterIndividualPropertyWindow()
            GameUI.messageBox("设计中......")
        end
    )
    local button_dev =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/Dev",
        "_lt",
        1800,
        580,
        100,
        100,
        picture_background
    )
    button_dev:setText("培养")
    button_dev:setFontSize(50)
    button_dev:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonsterPropertyWindow()
            GameUI.closeTravelMonsterSkillWindow()
            GameUI.closeTravelMonsterIndividualPropertyWindow()
            GameUI.messageBox("设计中......")
        end
    )
    local button_evolution =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/evolution",
        "_lt",
        1800,
        700,
        100,
        100,
        picture_background
    )
    button_evolution:setText("进化")
    button_evolution:setFontSize(50)
    button_evolution:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonsterPropertyWindow()
            GameUI.closeTravelMonsterSkillWindow()
            GameUI.closeTravelMonsterIndividualPropertyWindow()
            GameUI.messageBox("设计中......")
        end
    )
    local button_left_shift =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/LeftShift",
        "_lt",
        50,
        900,
        150,
        150,
        picture_background
    )
    button_left_shift:setBackgroundResource(58, nil, nil, nil, nil, "FlyblQgTdd13iZG3KWa0ti_S7CM2")
    button_left_shift:addEventFunction(
        "onclick",
        function()
            GameUI.mTravelMonstersWindow_MonsterStartIndex =
                math.max(GameUI.mTravelMonstersWindow_MonsterStartIndex - 1, 1)
        end
    )
    GameUI.mTravelMonstersWindow_MonsterStartIndex = GameUI.mTravelMonstersWindow_MonsterStartIndex or 1
    GameUI.mTravelMonstersWindow_SelectMonsterIndex = GameUI.mTravelMonstersWindow_SelectMonsterIndex or 1
    for i = 1, 10 do
        local button_monster =
            GameUI.mTravelMonstersWindow:createUI(
            "Button",
            "Pokemon/GameUI/TravelMonstersWindow/Button/Monster/" .. tostring(i),
            "_lt",
            (i - 1) * 150 + 210,
            900,
            150,
            150,
            picture_background
        )
        button_monster:addEventFunction(
            "onclick",
            function()
                GameUI.mTravelMonstersWindow_SelectMonsterIndex =
                    math.min(GameUI.mTravelMonstersWindow_MonsterStartIndex + i - 1, #gamePlayer.mMonsters)
                GameUI.refreshTravelMonstersWindow(gamePlayer)
            end
        )
    end
    local button_right_shift =
        GameUI.mTravelMonstersWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonstersWindow/Button/RightShift",
        "_lt",
        1720,
        900,
        150,
        150,
        picture_background
    )
    button_right_shift:setBackgroundResource(55, nil, nil, nil, nil, "Fo7EBOINk8hR50ly8pqi9I9S27fC")
    button_right_shift:addEventFunction(
        "onclick",
        function()
            GameUI.mTravelMonstersWindow_MonsterStartIndex =
                math.min(GameUI.mTravelMonstersWindow_MonsterStartIndex + 1, math.max(1, #gamePlayer.mMonsters - 9))
        end
    )
    local text_monster_element1 =
        GameUI.mTravelMonstersWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonstersWindow/Text/MonsterElement1",
        "_lt",
        300,
        100,
        100,
        30,
        picture_background
    )
    text_monster_element1:setTextFormat(5)
    text_monster_element1:setFontSize(30)
    local text_monster_element2 =
        GameUI.mTravelMonstersWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonstersWindow/Text/MonsterElement2",
        "_lt",
        300,
        130,
        100,
        30,
        picture_background
    )
    text_monster_element2:setTextFormat(5)
    text_monster_element2:setFontSize(30)
    local text_monster_level =
        GameUI.mTravelMonstersWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonstersWindow/Text/MonsterLevel",
        "_lt",
        400,
        100,
        150,
        60,
        picture_background
    )
    text_monster_level:setTextFormat(5)
    text_monster_level:setFontSize(40)
    local text_monster_name =
        GameUI.mTravelMonstersWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonstersWindow/Text/MonsterName",
        "_lt",
        550,
        100,
        200,
        60,
        picture_background
    )
    text_monster_name:setTextFormat(5)
    text_monster_name:setFontSize(50)
    local picture_monster =
        GameUI.mTravelMonstersWindow:createUI(
        "Picture",
        "Pokemon/GameUI/TravelMonstersWindow/Picture/Monster",
        "_lt",
        0,
        160,
        1000,
        600,
        picture_background
    )
    GameUI.mTravelMonstersWindow_MonsterMiniScene =
        CreateMiniScene("Pokemon/GameUI/TravelMonstersWindow/MiniScene/Monster", 1000, 600)
    GameUI.mTravelMonstersWindow_MonsterMiniScene:addMiniGameUI(picture_monster)
    GameUI.mTravelMonstersWindow_MonsterMiniScene:setCameraLookAtPosition(0, 0, 10)
    GameUI.mTravelMonstersWindow_MonsterMiniScene:setCameraPosition(0, 0, -3)
    GameUI.refreshTravelMonstersWindow(gamePlayer)
end

function GameUI.refreshTravelMonstersWindow(gamePlayer)
    for i = 1, 10 do
        local index = GameUI.mTravelMonstersWindow_MonsterStartIndex + i - 1
        if #gamePlayer.mMonsters >= index then
            local button_monster =
                GameUI.mTravelMonstersWindow:getUI("Pokemon/GameUI/TravelMonstersWindow/Button/Monster/" .. tostring(i))
            local monster = gamePlayer.mMonsters[index]
            button_monster:setBackgroundResource(
                tonumber(monster:getConfig().mPictureResource.pid),
                nil,
                nil,
                nil,
                nil,
                monster:getConfig().mPictureResource.hash
            )
        end
    end
    local select_monster = gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex]
    local text_monster_element1 =
        GameUI.mTravelMonstersWindow:getUI("Pokemon/GameUI/TravelMonstersWindow/Text/MonsterElement1")
    text_monster_element1:setText(
        gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex]:getConfig().mElement[1]
    )
    local text_monster_element2 =
        GameUI.mTravelMonstersWindow:getUI("Pokemon/GameUI/TravelMonstersWindow/Text/MonsterElement2")
    if gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex]:getConfig().mElement[2] then
        text_monster_element2:setText(
            gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex]:getConfig().mElement[2]
        )
    end
    local text_monster_level =
        GameUI.mTravelMonstersWindow:getUI("Pokemon/GameUI/TravelMonstersWindow/Text/MonsterLevel")
    text_monster_level:setText(
        "Lv." .. tostring(gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mLevel)
    )
    local text_monster_name = GameUI.mTravelMonstersWindow:getUI("Pokemon/GameUI/TravelMonstersWindow/Text/MonsterName")
    text_monster_name:setText(
        gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mName or
            gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mType
    )
    GetResourceModel(
        select_monster:getConfig().mModelResource,
        function(path, error)
            if GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity then
                GameUI.mTravelMonstersWindow_MonsterMiniScene:removeEntity(
                    GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity
                )
                GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity:SetDead(true)
            end
            GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity = CreateEntity(0, 0, 0, path, true)
            GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity:SetPosition(0, -0.5, 0)
            GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity:SetFacing(0.8)
            GameUI.mTravelMonstersWindow_MonsterMiniScene:addEntity(GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity)
        end
    )
    if GameUI.mTravelMonsterPropertyWindow then
        GameUI.refreshTravelMonsterPropertyWindow(gamePlayer)
    end
    if GameUI.mTravelMonsterSkillWindow then
        GameUI.refreshTravelMonsterSkillWindow()
    end
end

function GameUI.closeTravelMonstersWindow()
    if GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity then
        GameUI.mTravelMonstersWindow_MonsterMiniScene:removeEntity(GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity)
        GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity:SetDead(true)
        GameUI.mTravelMonstersWindow_MonsterMiniSceneEntity = nil
    end
    if GameUI.mTravelMonstersWindow_MonsterMiniScene then
        DestroyMiniScene(GameUI.mTravelMonstersWindow_MonsterMiniScene.mName)
        GameUI.mTravelMonstersWindow_MonsterMiniScene = nil
    end
    if GameUI.mTravelMonstersWindow then
        MiniGameUISystem.destroyWindow(GameUI.mTravelMonstersWindow)
        GameUI.mTravelMonstersWindow = nil
    end
    GameUI.closeTravelMonsterPropertyWindow()
    GameUI.closeTravelMonsterSkillWindow()
    GameUI.closeTravelMonsterIndividualPropertyWindow()
end

function GameUI.showTravelMonsterPropertyWindow(gamePlayer)
    GameUI.closeTravelMonsterPropertyWindow()
    GameUI.mTravelMonsterPropertyWindow =
        MiniGameUISystem.createWindow("Pokemon/GameUI/TravelMonsterPropertyWindow", "_lt", 900, 20, 800, 850)
    GameUI.mTravelMonsterPropertyWindow:setZOrder(102)
    local picture_background =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Picture",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Picture/Background",
        "_lt",
        0,
        0,
        800,
        850
    )
    local text_property_panel_title =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelTitle",
        "_ctt",
        0,
        20,
        200,
        80,
        picture_background
    )
    text_property_panel_title:setText("属性")
    text_property_panel_title:setTextFormat(5)
    text_property_panel_title:setFontSize(60)
    local text_property_panel_life =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelLife",
        "_lt",
        100,
        100,
        250,
        50,
        picture_background
    )
    text_property_panel_life:setTextFormat(4)
    text_property_panel_life:setFontSize(20)
    local text_property_panel_speed =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelSpeed",
        "_lt",
        450,
        100,
        250,
        50,
        picture_background
    )
    text_property_panel_speed:setTextFormat(4)
    text_property_panel_speed:setFontSize(20)
    local text_property_panel_physical_attack =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelPhysicalAttack",
        "_lt",
        100,
        200,
        250,
        50,
        picture_background
    )
    text_property_panel_physical_attack:setTextFormat(4)
    text_property_panel_physical_attack:setFontSize(20)
    local text_property_panel_special_attack =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelSpecialAttack",
        "_lt",
        450,
        200,
        250,
        50,
        picture_background
    )
    text_property_panel_special_attack:setTextFormat(4)
    text_property_panel_special_attack:setFontSize(20)
    local text_property_panel_physical_defense =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelPhysicalDefense",
        "_lt",
        100,
        300,
        250,
        50,
        picture_background
    )
    text_property_panel_physical_defense:setTextFormat(4)
    text_property_panel_physical_defense:setFontSize(20)
    local text_property_panel_special_attack =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelSpecialDefense",
        "_lt",
        450,
        300,
        250,
        50,
        picture_background
    )
    text_property_panel_special_attack:setTextFormat(4)
    text_property_panel_special_attack:setFontSize(20)
    local text_property_panel_individual_total =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelIndividualTotal",
        "_ctt",
        0,
        400,
        450,
        80,
        picture_background
    )
    text_property_panel_individual_total:setText("个体值总和")
    text_property_panel_individual_total:setTextFormat(5)
    text_property_panel_individual_total:setFontSize(50)
    local text_property_panel_individual_total_value =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelIndividualTotalValue",
        "_ctt",
        0,
        500,
        700,
        50,
        picture_background
    )
    text_property_panel_individual_total_value:setTextFormat(5)
    text_property_panel_individual_total_value:setFontSize(20)
    local button_property_panel_individual_info =
        GameUI.mTravelMonsterPropertyWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Button/PropertyPanelIndividualInfo",
        "_lt",
        700,
        450,
        50,
        30,
        picture_background
    )
    button_property_panel_individual_info:setText("跳转")
    button_property_panel_individual_info:addEventFunction(
        "onclick",
        function()
            GameUI.closeTravelMonsterPropertyWindow()
            GameUI.showTravelMonsterIndividualPropertyWindow(gamePlayer)
        end
    )
    GameUI.refreshTravelMonsterPropertyWindow(gamePlayer)
end

function GameUI.refreshTravelMonsterPropertyWindow(gamePlayer)
    local value =
        GameCompute.computeTravelMonsterWindowProperty(
        gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex]
    )
    local text_property_panel_life =
        GameUI.mTravelMonsterPropertyWindow:getUI("Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelLife")
    text_property_panel_life:setText("生命：" .. tostring(value.mLife))
    local text_property_panel_speed =
        GameUI.mTravelMonsterPropertyWindow:getUI("Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelSpeed")
    text_property_panel_speed:setText("速度：" .. tostring(value.mSpeed))
    local text_property_panel_physical_attack =
        GameUI.mTravelMonsterPropertyWindow:getUI(
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelPhysicalAttack"
    )
    text_property_panel_physical_attack:setText("物攻：" .. tostring(value.mPhysicalAttack))
    local text_property_panel_special_attack =
        GameUI.mTravelMonsterPropertyWindow:getUI(
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelSpecialAttack"
    )
    text_property_panel_special_attack:setText("特攻：" .. tostring(value.mSpecialAttack))
    local text_property_panel_physical_defense =
        GameUI.mTravelMonsterPropertyWindow:getUI(
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelPhysicalDefense"
    )
    text_property_panel_physical_defense:setText("物防：" .. tostring(value.mPhysicalDefense))
    local text_property_panel_special_attack =
        GameUI.mTravelMonsterPropertyWindow:getUI(
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelSpecialDefense"
    )
    text_property_panel_special_attack:setText("特防：" .. tostring(value.mSpecialDefense))
    local text_property_panel_individual_total_value =
        GameUI.mTravelMonsterPropertyWindow:getUI(
        "Pokemon/GameUI/TravelMonsterPropertyWindow/Text/PropertyPanelIndividualTotalValue"
    )
    text_property_panel_individual_total_value:setText(
        tostring(
            GameCompute.computeIndividualSum(gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex])
        ) ..
            "/" ..
                tostring(
                    GameCompute.computeTypeIndividualSum(
                        gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mType
                    )
                )
    )
end

function GameUI.closeTravelMonsterPropertyWindow(gamePlayer)
    if GameUI.mTravelMonsterPropertyWindow then
        MiniGameUISystem.destroyWindow(GameUI.mTravelMonsterPropertyWindow)
        GameUI.mTravelMonsterPropertyWindow = nil
    end
end

function GameUI.showTravelMonsterIndividualPropertyWindow(gamePlayer)
    local monster = gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex]
    local monster_config = GameConfig.getMonsterConfigByMonsterType(monster.mType)
    GameUI.closeTravelMonsterIndividualPropertyWindow()
    GameUI.mTravelMonsterIndividualPropertyWindow =
        MiniGameUISystem.createWindow("Pokemon/GameUI/TravelMonsterIndividualPropertyWindow", "_lt", 900, 20, 800, 850)
    GameUI.mTravelMonsterIndividualPropertyWindow:setZOrder(102)
    local picture_background =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Picture",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Picture/Background",
        "_lt",
        0,
        0,
        800,
        850
    )
    local text_title =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/Title",
        "_ctt",
        0,
        20,
        200,
        80,
        picture_background
    )
    text_title:setText("个体值")
    text_title:setTextFormat(5)
    text_title:setFontSize(60)
    local text_life =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/Life",
        "_lt",
        0,
        100,
        100,
        50,
        picture_background
    )
    text_life:setText("生命：")
    text_life:setFontSize(25)
    text_life:setTextFormat(4)
    local text_life_value =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/LifeValue",
        "_lt",
        100,
        100,
        500,
        50,
        picture_background
    )
    text_life_value:setText(tostring(monster.mIndividual.mLife) .. "/" .. tostring(monster_config.mLifeUpperLimit))
    text_life_value:setFontSize(25)
    text_life_value:setTextFormat(5)
    local text_physical_attack =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/PhysicalAttack",
        "_lt",
        0,
        150,
        100,
        50,
        picture_background
    )
    text_physical_attack:setText("物攻：")
    text_physical_attack:setFontSize(25)
    text_physical_attack:setTextFormat(4)
    local text_physical_attack_value =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/PhysicalAttackValue",
        "_lt",
        100,
        150,
        500,
        50,
        picture_background
    )
    text_physical_attack_value:setText(
        tostring(monster.mIndividual.mPhysicalAttack) .. "/" .. tostring(monster_config.mPhysicalAttackUpperLimit)
    )
    text_physical_attack_value:setFontSize(25)
    text_physical_attack_value:setTextFormat(5)
    local text_special_attack =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/SpecialAttack",
        "_lt",
        0,
        200,
        100,
        50,
        picture_background
    )
    text_special_attack:setText("特攻：")
    text_special_attack:setFontSize(25)
    text_special_attack:setTextFormat(4)
    local text_special_attack_value =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/SpecialAttackValue",
        "_lt",
        100,
        200,
        500,
        50,
        picture_background
    )
    text_special_attack_value:setText(
        tostring(monster.mIndividual.mSpecialAttack) .. "/" .. tostring(monster_config.mSpecialAttackUpperLimit)
    )
    text_special_attack_value:setFontSize(25)
    text_special_attack_value:setTextFormat(5)
    local text_physical_defense =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/PhysicalDefense",
        "_lt",
        0,
        250,
        100,
        50,
        picture_background
    )
    text_physical_defense:setText("物防：")
    text_physical_defense:setFontSize(25)
    text_physical_defense:setTextFormat(4)
    local text_physical_defense_value =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/PhysicalDefenseValue",
        "_lt",
        100,
        250,
        500,
        50,
        picture_background
    )
    text_physical_defense_value:setText(
        tostring(monster.mIndividual.mPhysicalDefense) .. "/" .. tostring(monster_config.mPhysicalDefenseUpperLimit)
    )
    text_physical_defense_value:setFontSize(25)
    text_physical_defense_value:setTextFormat(5)
    local text_special_defense =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/SpecialDefense",
        "_lt",
        0,
        300,
        100,
        50,
        picture_background
    )
    text_special_defense:setText("特防：")
    text_special_defense:setFontSize(25)
    text_special_defense:setTextFormat(4)
    local text_special_defense_value =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/SpecialDefenseValue",
        "_lt",
        100,
        300,
        500,
        50,
        picture_background
    )
    text_special_defense_value:setText(
        tostring(monster.mIndividual.mSpecialDefense) .. "/" .. tostring(monster_config.mSpecialDefenseUpperLimit)
    )
    text_special_defense_value:setFontSize(25)
    text_special_defense_value:setTextFormat(5)
    local text_speed =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/Speed",
        "_lt",
        0,
        350,
        100,
        50,
        picture_background
    )
    text_speed:setText("速度：")
    text_speed:setFontSize(25)
    text_speed:setTextFormat(4)
    local text_speed_value =
        GameUI.mTravelMonsterIndividualPropertyWindow:createUI(
        "Text",
        "Pokemon/GameUI/TravelMonsterIndividualPropertyWindow/Text/SpeedValue",
        "_lt",
        100,
        350,
        500,
        50,
        picture_background
    )
    text_speed_value:setText(tostring(monster.mIndividual.mSpeed) .. "/" .. tostring(monster_config.mSpeedUpperLimit))
    text_speed_value:setFontSize(25)
    text_speed_value:setTextFormat(5)
end

function GameUI.closeTravelMonsterIndividualPropertyWindow()
    if GameUI.mTravelMonsterIndividualPropertyWindow then
        MiniGameUISystem.destroyWindow(GameUI.mTravelMonsterIndividualPropertyWindow)
        GameUI.mTravelMonsterIndividualPropertyWindow = nil
    end
end

function GameUI.showTravelMonsterSkillWindow(gamePlayer)
    GameUI.closeTravelMonsterSkillWindow()
    GameUI.mTravelMonsterSkillWindow =
        MiniGameUISystem.createWindow("Pokemon/GameUI/TravelMonsterSkillWindow", "_lt", 900, 20, 800, 850)
    GameUI.mTravelMonsterSkillWindow:setZOrder(102)
    local picture_background =
        GameUI.mTravelMonsterSkillWindow:createUI(
        "Picture",
        "Pokemon/GameUI/TravelMonsterSkillWindow/Picture/Background",
        "_lt",
        0,
        0,
        800,
        850
    )
    local button_skills =
        GameUI.mTravelMonsterSkillWindow:createUI(
        "Button",
        "Pokemon/GameUI/TravelMonsterSkillWindow/Button/Skills",
        "_lt",
        100,
        20,
        200,
        50,
        picture_background
    )
    button_skills:setText("技能")
    for i = 1, 5 do
        local picture_skill_background =
            GameUI.mTravelMonsterSkillWindow:createUI(
            "Picture",
            "Pokemon/GameUI/TravelMonsterSkillWindow/Picture/SkillBackground/" .. tostring(i),
            "_lt",
            25,
            100 + (i - 1) * 110,
            750,
            100,
            picture_background
        )
        local picture_skill_icon =
            GameUI.mTravelMonsterSkillWindow:createUI(
            "Picture",
            "Pokemon/GameUI/TravelMonsterSkillWindow/Picture/SkillIcon/" .. tostring(i),
            "_lt",
            10,
            10,
            80,
            80,
            picture_skill_background
        )
        local text_skill_name =
            GameUI.mTravelMonsterSkillWindow:createUI(
            "Text",
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillName/" .. tostring(i),
            "_lt",
            90,
            10,
            80,
            27,
            picture_skill_background
        )
        text_skill_name:setTextFormat(4)
        text_skill_name:setFontSize(18)
        local text_skill_level =
            GameUI.mTravelMonsterSkillWindow:createUI(
            "Text",
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillLevel/" .. tostring(i),
            "_lt",
            90,
            40,
            80,
            27,
            picture_skill_background
        )
        text_skill_level:setTextFormat(4)
        text_skill_level:setFontSize(18)
        local text_skill_element =
            GameUI.mTravelMonsterSkillWindow:createUI(
            "Text",
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillElement/" .. tostring(i),
            "_lt",
            90,
            70,
            80,
            26,
            picture_skill_background
        )
        text_skill_element:setTextFormat(4)
        text_skill_element:setFontSize(18)
        local text_skill_description1 =
            GameUI.mTravelMonsterSkillWindow:createUI(
            "Text",
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillDescription1/" .. tostring(i),
            "_lt",
            170,
            10,
            550,
            55,
            picture_skill_background
        )
        text_skill_description1:setFontSize(15)
        local text_skill_description2 =
            GameUI.mTravelMonsterSkillWindow:createUI(
            "Text",
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillDescription2/" .. tostring(i),
            "_lt",
            170,
            65,
            550,
            25,
            picture_skill_background
        )
        text_skill_description2:setFontSize(15)
    end
    GameUI.refreshTravelMonsterSkillWindow(gamePlayer)
end

function GameUI.refreshTravelMonsterSkillWindow(gamePlayer)
    local monster = gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex]
    local monster_config = GameConfig.getMonsterConfigByMonsterType(monster.mType)
    for i = 1, 5 do
        local picture_skill_background =
            GameUI.mTravelMonsterSkillWindow:getUI(
            "Pokemon/GameUI/TravelMonsterSkillWindow/Picture/SkillBackground/" .. tostring(i)
        )
        local picture_skill_icon =
            GameUI.mTravelMonsterSkillWindow:getUI(
            "Pokemon/GameUI/TravelMonsterSkillWindow/Picture/SkillIcon/" .. tostring(i)
        )
        local text_skill_name =
            GameUI.mTravelMonsterSkillWindow:getUI(
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillName/" .. tostring(i)
        )
        local text_skill_level =
            GameUI.mTravelMonsterSkillWindow:getUI(
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillLevel/" .. tostring(i)
        )
        local text_skill_element =
            GameUI.mTravelMonsterSkillWindow:getUI(
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillElement/" .. tostring(i)
        )
        local text_skill_description1 =
            GameUI.mTravelMonsterSkillWindow:getUI(
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillDescription1/" .. tostring(i)
        )
        local text_skill_description2 =
            GameUI.mTravelMonsterSkillWindow:getUI(
            "Pokemon/GameUI/TravelMonsterSkillWindow/Text/SkillDescription2/" .. tostring(i)
        )
        local skill_config
        local skill_info
        if i == 1 then
            skill_config =
                monster_config.mSkills[
                gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mBigSkill.mConfigIndex
            ]
            skill_info = gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mBigSkill
        elseif i == 5 then
            skill_config =
                monster_config.mSkills[
                gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mPassiveSkill.mConfigIndex
            ]
            skill_info = gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mPassiveSkill
        elseif gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mNormalSkills[i - 1] then
            skill_config =
                monster_config.mSkills[
                gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mNormalSkills[i - 1].mConfigIndex
            ]
            skill_info = gamePlayer.mMonsters[GameUI.mTravelMonstersWindow_SelectMonsterIndex].mNormalSkills[i - 1]
        end
        if skill_config and skill_info then
            text_skill_name:setText(skill_config.mName)
            text_skill_level:setText("Lv." .. tostring(skill_info.mLevel))
            text_skill_element:setText(skill_config.mElementType)
            text_skill_description1:setText(skill_config.mDescription)
            if i == 5 then
                local text
                for _, passive in pairs(skill_config.mPassives) do
                    if text then
                        text = text .. "，"
                    else
                        text = ""
                    end
                    text = text .. "提高" .. tostring(passive.mLevelValue * skill_info.mLevel) .. "点" .. passive.mType
                end
                text_skill_description1:setText(skill_config.mDescription .. "\n" .. text)
                text_skill_description2:setText(
                    "范围：" .. skill_config.mRange .. "，技能威力：" .. tostring(skill_config.mPower or 0)
                )
            else
                local text
                if skill_config.mPower then
                    local damage = GameCompute.computeTravelMonsterWindowSkillDamage(monster, skill_info, skill_config)
                    if damage.mSpecial then
                        text = "造成" .. tostring(damage.mSpecial) .. "点特攻伤害"
                    end
                    if damage.mPhysical then
                        if text then
                            text = text .. "，"
                        else
                            text = ""
                        end
                        text = text .. "造成" .. tostring(damage.mPhysical) .. "点物攻伤害"
                    end
                else
                    text = ""
                end
                text_skill_description1:setText(skill_config.mDescription .. "\n" .. text)
                text_skill_description2:setText(
                    "范围：" .. skill_config.mRange .. "，技能威力：" .. tostring(skill_config.mPower or 0)
                )
            end
        end
    end
end

function GameUI.closeTravelMonsterSkillWindow()
    if GameUI.mTravelMonsterSkillWindow then
        MiniGameUISystem.destroyWindow(GameUI.mTravelMonsterSkillWindow)
        GameUI.mTravelMonsterSkillWindow = nil
    end
end
-----------------------------------------------------------------------------------------Game Config-----------------------------------------------------------------------------------------
GameConfig.mMonsterTerrains = {
    {
        mBlockID = 113,
        mMonsterChanceRange = {0, 0.1},
        mMonsters = {
            {mType = "皮卡丘", mChanceRange = {0, 0.1}},
            {mType = "妙蛙种子", mChanceRange = {0.1, 0.2}},
            {mType = "小火龙", mChanceRange = {0.2, 0.3}},
            {mType = "绿毛虫", mChanceRange = {0.3, 1}}
        }
    },
    {mBlockID = 114},
    {mBlockID = 115},
    {mBlockID = 116},
    {mBlockID = 132},
    {mBlockID = 162},
    {mBlockID = 164},
    {mBlockID = 165},
    {mBlockID = 2041},
    {mBlockID = 2043},
    {mBlockID = 2044},
    {
        mBlockID = 75,
        mMonsterChanceRange = {0, 0.1},
        mMonsters = {{mType = "杰尼龟", mChanceRange = {0, 0.1}}, {mType = "鲤鱼王", mChanceRange = {0.1, 0.9}}}
    },
    {
        mBlockID = 76,
        mMonsterChanceRange = {0, 0.1},
        mMonsters = {{mType = "杰尼龟", mChanceRange = {0, 0.1}}, {mType = "鲤鱼王", mChanceRange = {0.1, 0.9}}}
    }
}
GameConfig.mMonsters = {
    {
        mType = "皮卡丘",
        mPictureResource = {hash = "FgoPZuJkUV-DWjFcFfM5U9jxLnu5", pid = "184", ext = "png"},
        mModelResource = {hash = "FsahwZt0kz9W3aGyk9kSvhgeodbK", pid = "131", ext = "bmax"},
        mLifeUpperLimit = 78,
        mSpecialAttackUpperLimit = 104,
        mPhysicalAttackUpperLimit = 70,
        mSpeedUpperLimit = 87,
        mSpecialDefenseUpperLimit = 78,
        mPhysicalDefenseUpperLimit = 70,
        mElement = {"电"},
        mSkills = {
            {
                mElementType = "电",
                mName = "百万伏特",
                mPower = 30,
                mRange = "群体",
                mRange2 = {"地面"},
                mDescription = "用强大的雷暴攻击全体敌人造成电系特攻伤害，有30%几率麻痹敌人",
                mAttacks = {{mType = "特攻", mLevelValue = 6}},
                mBuffs = {
                    {
                        mType = "麻痹",
                        mTarget = "目标",
                        mTime = 3
                    }
                },
                mBuffChances = {0.3},
                mTarget = "敌军",
                mType = "大招"
            },
            {
                mElementType = "电",
                mName = "电击",
                mPower = 30,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "用电流攻击单个敌人造成电系特攻伤害，有45%几率麻痹敌人",
                mAttacks = {{mType = "特攻", mLevelValue = 4}},
                mBuffs = {
                    {
                        mType = "麻痹",
                        mTarget = "目标",
                        mTime = 3
                    }
                },
                mBuffChances = {0.45},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "电",
                mName = "疯狂伏特",
                mPower = 65,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "身上缠绕电器撞向单个敌人造成电系特攻伤害，自身承受20%的反弹伤害",
                mAttacks = {{mType = "特攻", mLevelValue = 20}},
                mSelfDamage = {mValueType = "百分比", mValue = 20},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "钢",
                mName = "铁尾",
                mPower = 50,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "用坚硬的尾巴攻击单个敌人造成钢系特攻伤害，有50%几率降低对方50%的特殊防御力，持续三回合",
                mAttacks = {{mType = "特攻", mLevelValue = 12}},
                mBuffs = {
                    {
                        mType = "属性下降",
                        mPropertyTypes = {"特防"},
                        mValueType = "百分比",
                        mValue = 50,
                        mTarget = "目标",
                        mTime = 3
                    }
                },
                mBuffChances = {0.5},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "静电",
                mDescription = "提高自身特殊攻击力",
                mRange = "单体",
                mPassives = {{mType = "特攻", mLevelValue = 17}},
                mType = "被动"
            }
        }
    },
    {
        mType = "小火龙",
        mPictureResource = {hash = "FuTRPmcFFRRs3MmYsp2YvUNs3uTW", pid = "185", ext = "png"},
        mModelResource = {hash = "FtX-dI8bph8eztlGvHtp3cMuRaRY", pid = "132", ext = "bmax"},
        mLifeUpperLimit = 61,
        mSpecialAttackUpperLimit = 97,
        mPhysicalAttackUpperLimit = 65,
        mSpeedUpperLimit = 81,
        mSpecialDefenseUpperLimit = 65,
        mPhysicalDefenseUpperLimit = 57,
        mElement = {"火"},
        mSkills = {
            {
                mElementType = "火",
                mName = "喷射火焰",
                mPower = 45,
                mRange = "群体",
                mRange2 = {"地面"},
                mDescription = "用炙热火焰攻击全部敌人造成火系特攻伤害。",
                mAttacks = {{mType = "特攻", mLevelValue = 13}},
                mTarget = "敌军",
                mType = "大招"
            },
            {
                mElementType = "火",
                mName = "火花",
                mPower = 45,
                mRange = "单体",
                mRange2 = {"地面", "天空"},
                mDescription = "用小型火焰攻击单个敌人造成火系特攻伤害。该技能可命中飞空中得敌人",
                mAttacks = {{mType = "特攻", mLevelValue = 9}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "火",
                mName = "爆炸火焰",
                mPower = 25,
                mRange = "群体",
                mRange2 = {"地面"},
                mDescription = "喷射出爆炸火焰造成火系特攻伤害。",
                mAttacks = {{mType = "特攻", mLevelValue = 7}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "火",
                mName = "炎牙",
                mPower = 55,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "用充满火焰的牙撕咬单个敌人造成火系特攻伤害，同时使对方点燃",
                mAttacks = {{mType = "特攻", mLevelValue = 13}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "猛火",
                mRange = "单体",
                mDescription = "提高自身特殊攻击力",
                mPassives = {{mType = "特攻", mLevelValue = 16}},
                mType = "被动"
            }
        }
    },
    {
        mType = "妙蛙种子",
        mPictureResource = {hash = "FuKMtX_1tCxtPwrkKi3hr_nwuL13", pid = "187", ext = "png"},
        mModelResource = {hash = "Fo_Rup2lNwJqtJzl7qaT5XLbMQcV", pid = "134", ext = "bmax"},
        mLifeUpperLimit = 65,
        mSpecialAttackUpperLimit = 65,
        mPhysicalAttackUpperLimit = 93,
        mSpeedUpperLimit = 81,
        mSpecialDefenseUpperLimit = 61,
        mPhysicalDefenseUpperLimit = 69,
        mElement = {"草"},
        mSkills = {
            {
                mElementType = "草",
                mName = "种子爆弹",
                mPower = 50,
                mRange = "群体",
                mRange2 = {"地面"},
                mDescription = "用外壳坚硬的巨大种子，从上方喷出攻击多个敌人造成草系物攻伤害。",
                mAttacks = {{mType = "物攻", mLevelValue = 12}},
                mTarget = "敌军",
                mType = "大招"
            },
            {
                mElementType = "草",
                mName = "藤鞭",
                mPower = 50,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "使用如同鞭子般细长得藤蔓抽打单个敌人造成草系物攻伤害。",
                mAttacks = {{mType = "物攻", mLevelValue = 5}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "草",
                mName = "睡眠粉",
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "将催眠粉洒向敌人，降低20%物理防御与特殊防御，并有45%几率使单个敌人睡眠两回合。",
                mBuffs = {
                    {
                        mType = "属性下降",
                        mPropertyTypes = {"特防", "物防"},
                        mValueType = "百分比",
                        mValue = 20,
                        mTarget = "目标",
                        mTime = 3,
                        mLevelValue = 5
                    },
                    {
                        mType = "睡眠",
                        mTarget = "目标",
                        mTime = 2
                    }
                },
                mBuffChances = {1, 0.45},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "猛撞",
                mPower = 85,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "使出全身的力气，向单个敌人冲撞过去造成一般系物攻伤害，自己也会受到20%的伤害反弹。",
                mAttacks = {{mType = "物攻", mLevelValue = 15}},
                mSelfDamage = {mValueType = "百分比", mValue = 20},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "叶绿素",
                mRange = "单体",
                mDescription = "提高自身物理攻击力",
                mPassives = {{mType = "物攻", mLevelValue = 14}},
                mType = "被动"
            }
        }
    },
    {
        mType = "杰尼龟",
        mPictureResource = {hash = "FkWRFCC3KBJGP28-PvuveaAp_QGX", pid = "186", ext = "png"},
        mModelResource = {hash = "FjiL_8L-yV5E7Y2sadHBRNZWyXH7", pid = "133", ext = "bmax"},
        mLifeUpperLimit = 63,
        mSpecialAttackUpperLimit = 101,
        mPhysicalAttackUpperLimit = 67,
        mSpeedUpperLimit = 84,
        mSpecialDefenseUpperLimit = 67,
        mPhysicalDefenseUpperLimit = 59,
        mElement = {"水"},
        mSkills = {
            {
                mElementType = "水",
                mName = "水炮",
                mPower = 90,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "造成水系特攻伤害",
                mAttacks = {{mType = "特攻", mLevelValue = 20}},
                mTarget = "敌军",
                mType = "大招"
            },
            {
                mElementType = "一般",
                mName = "撞击",
                mPower = 60,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "造成一般系特攻伤害。",
                mAttacks = {{mType = "特攻", mLevelValue = 20}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "守住",
                mRange = "单体",
                mDescription = "获得抵挡一次攻击的守护之魂，护盾持续三回合，并恢复自身最大生命的15%，冷却两回合。",
                mBuffs = {
                    {
                        mType = "守护之魂",
                        mTarget = "自身",
                        mTime = 3
                    }
                },
                mBuffChances = {1},
                mRecovers = {{mType = "生命", mValueType = "百分比", mValue = 15, mLevelValue = 20}},
                mPause = 2,
                mTarget = "自身",
                mType = "普通"
            },
            {
                mElementType = "水",
                mName = "水枪",
                mPower = 50,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "造成水系特攻伤害，攻击有50%几率降低地方30%物理防御力和特殊防御力。",
                mBuffs = {
                    {
                        mType = "属性下降",
                        mPropertyTypes = {"特防", "物防"},
                        mValueType = "百分比",
                        mValue = 30,
                        mTarget = "目标",
                        mTime = 3
                    }
                },
                mBuffChances = {0.5},
                mAttacks = {{mType = "特攻", mLevelValue = 14}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "激流",
                mRange = "单体",
                mDescription = "提高自身特殊攻击力",
                mPassives = {{mType = "特攻", mLevelValue = 15}},
                mType = "被动"
            }
        }
    },
    {
        mType = "绿毛虫",
        mPictureResource = {hash = "FsofYGFbI3r5_lE6qjPsKLfPBiHS", pid = "188", ext = "png"},
        mModelResource = {hash = "FgxBHWvBCT95Ji2ZD30rgmsL7zFZ", pid = "135", ext = "bmax"},
        mLifeUpperLimit = 83,
        mSpecialAttackUpperLimit = 68,
        mPhysicalAttackUpperLimit = 60,
        mSpeedUpperLimit = 75,
        mSpecialDefenseUpperLimit = 75,
        mPhysicalDefenseUpperLimit = 68,
        mElement = {"虫"},
        mSkills = {
            {
                mElementType = "虫",
                mName = "电网",
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "对敌人洒出电网，降低敌人40%速度。",
                mBuffs = {
                    {
                        mType = "属性下降",
                        mPropertyTypes = {"速度"},
                        mValueType = "百分比",
                        mValue = 40,
                        mTarget = "目标",
                        mTime = 3,
                        mLevelValue = 3
                    }
                },
                mBuffChances = {1},
                mTarget = "敌军",
                mType = "大招"
            },
            {
                mElementType = "虫",
                mName = "冲击",
                mPower = 50,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "使出全身力气，撞击敌人造成虫系特攻伤害。",
                mAttacks = {{mType = "特攻", mLevelValue = 8}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "虫",
                mName = "吐丝",
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "从口中吐丝，降低敌人20%速度。",
                mBuffs = {
                    {
                        mType = "属性下降",
                        mPropertyTypes = {"速度"},
                        mValueType = "百分比",
                        mValue = 20,
                        mTarget = "目标",
                        mTime = 3,
                        mLevelValue = 5
                    }
                },
                mBuffChances = {1},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "虫",
                mName = "虫咬",
                mPower = 25,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "啃咬敌人吸取生命造成虫系特攻伤害并回复自身生命",
                mSuckBlood = {mValueType = "百分比", mValue = 100},
                mAttacks = {{mType = "特攻", mLevelValue = 4}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "鳞粉",
                mRange = "单体",
                mDescription = "提高自身特殊攻击力",
                mPassives = {{mType = "特攻", mLevelValue = 6}},
                mType = "被动"
            }
        }
    },
    {
        mType = "鲤鱼王",
        mPictureResource = {hash = "Fmf4BakNEpT5QPySVSW-RkSb1LZ1", pid = "190", ext = "png"},
        mModelResource = {hash = "FjXJVbpcn7Rkmipo40JxHYG5imGZ", pid = "137", ext = "bmax"},
        mLifeUpperLimit = 65,
        mSpecialAttackUpperLimit = 70,
        mPhysicalAttackUpperLimit = 104,
        mSpeedUpperLimit = 87,
        mSpecialDefenseUpperLimit = 61,
        mPhysicalDefenseUpperLimit = 70,
        mElement = {"水"},
        mSkills = {
            {
                mElementType = "一般",
                mName = "飞跳",
                mRange = "单体",
                mDescription = "飞到高处，飞空一回合，并提高自身25%物理攻击力。",
                mBuffs = {
                    {
                        mType = "飞空",
                        mTarget = "自身",
                        mTime = 1
                    },
                    {
                        mType = "属性上升",
                        mPropertyTypes = {"物攻"},
                        mValueType = "百分比",
                        mValue = 25,
                        mTarget = "自身",
                        mTime = 3,
                        mLevelValue = 35
                    }
                },
                mBuffChances = {1, 1},
                mTarget = "自身",
                mType = "大招"
            },
            {
                mElementType = "一般",
                mName = "水溅跃",
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "毫无攻击力的乱跳，似乎什么都不会发生......",
                mTarget = "自身",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "冲击",
                mPower = 65,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "使出全身力气，撞击单个敌人造成一般系物攻伤害。",
                mAttacks = {{mType = "物攻", mLevelValue = 16}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "手足慌乱",
                mPower = 70,
                mRange = "单体",
                mRange2 = {"地面"},
                mDescription = "拼命挣扎攻击单个敌人造成一般系物攻伤害，自身的HP越少,技能的威力越强。",
                mAttacks = {{mType = "物攻", mLevelValue = 10}},
                mTarget = "敌军",
                mType = "普通"
            },
            {
                mElementType = "一般",
                mName = "颤抖",
                mRange = "单体",
                mDescription = "提高自身物理攻击力和物理防御力",
                mPassives = {{mType = "物攻", mLevelValue = 11}, {mType = "物防", mLevelValue = 5}},
                mType = "被动"
            }
        }
    }
}
function GameConfig.getMonsterTerrain(blockID)
    for _, terrain in pairs(GameConfig.mMonsterTerrains) do
        if terrain.mBlockID == blockID then
            return terrain
        end
    end
end

function GameConfig.getMonsterConfigByMonsterType(type)
    for _, monster_config in pairs(GameConfig.mMonsters) do
        if monster_config.mType == type then
            return monster_config
        end
    end
end

function GameConfig.getSkillIndicesBySkillType(type, monsterConfig)
    local ret = {}
    for k, skill_config in pairs(monsterConfig.mSkills) do
        if type == skill_config.mType then
            ret[#ret + 1] = k
        end
    end
    return ret
end
-----------------------------------------------------------------------------------------Game Compute-----------------------------------------------------------------------------------------
function GameCompute.computeMonsterInitIndividualProperty(monsterType)
    local ret = {}
    local config = GameConfig.getMonsterConfigByMonsterType(monsterType)
    ret.mLife = math.random(math.ceil(config.mLifeUpperLimit * 0.3), config.mLifeUpperLimit)
    ret.mSpecialAttack = math.random(math.ceil(config.mSpecialAttackUpperLimit * 0.3), config.mSpecialAttackUpperLimit)
    ret.mPhysicalAttack =
        math.random(math.ceil(config.mPhysicalAttackUpperLimit * 0.3), config.mPhysicalAttackUpperLimit)
    ret.mSpeed = math.random(math.ceil(config.mSpeedUpperLimit * 0.3), config.mSpeedUpperLimit)
    ret.mSpecialDefense =
        math.random(math.ceil(config.mSpecialDefenseUpperLimit * 0.3), config.mSpecialDefenseUpperLimit)
    ret.mPhysicalDefense =
        math.random(math.ceil(config.mPhysicalDefenseUpperLimit * 0.3), config.mPhysicalDefenseUpperLimit)
    return ret
end
function GameCompute.computeInitSkills(monsterConfig)
    local ret = {}
    local big_skill_indices = GameConfig.getSkillIndicesBySkillType("大招", monsterConfig)
    local normal_skill_indices = GameConfig.getSkillIndicesBySkillType("普通", monsterConfig)
    local passive_skill_indices = GameConfig.getSkillIndicesBySkillType("被动", monsterConfig)
    ret.mBigSkill = {mConfigIndex = big_skill_indices[math.random(1, #big_skill_indices)], mLevel = 1}
    ret.mPassiveSkill = {mConfigIndex = passive_skill_indices[math.random(1, #passive_skill_indices)], mLevel = 1}
    local has_attack_skill
    ret.mNormalSkills = {}
    local i = math.random(1, #normal_skill_indices)
    ret.mNormalSkills[1] = {mConfigIndex = normal_skill_indices[i], mLevel = 1}
    has_attack_skill =
        has_attack_skill or
        (monsterConfig.mSkills[normal_skill_indices[i]].mPower and
            monsterConfig.mSkills[normal_skill_indices[i]].mPower > 0 and
            monsterConfig.mSkills[normal_skill_indices[i]].mTarget == "敌军")
    table.remove(normal_skill_indices, i)
    i = math.random(1, #normal_skill_indices)
    ret.mNormalSkills[2] = {mConfigIndex = normal_skill_indices[i], mLevel = 1}
    has_attack_skill =
        has_attack_skill or
        (monsterConfig.mSkills[normal_skill_indices[i]].mPower and
            monsterConfig.mSkills[normal_skill_indices[i]].mPower > 0 and
            monsterConfig.mSkills[normal_skill_indices[i]].mTarget == "敌军")
    table.remove(normal_skill_indices, i)
    if not has_attack_skill then
        i = 1
        while i <= #normal_skill_indices do
            if
                not monsterConfig.mSkills[normal_skill_indices[i]].mPower or
                    monsterConfig.mSkills[normal_skill_indices[i]].mPower == 0 or
                    monsterConfig.mSkills[normal_skill_indices[i]].mTarget ~= "敌军"
             then
                table.remove(normal_skill_indices, i)
            else
                i = i + 1
            end
        end
    end
    i = math.random(1, #normal_skill_indices)
    ret.mNormalSkills[3] = {mConfigIndex = normal_skill_indices[i], mLevel = 1}
    return ret
end
function GameCompute.computeHitMonster(blockID)
    local terrain = GameConfig.getMonsterTerrain(blockID)
    if terrain then
        local random_value = math.random()
        if random_value <= terrain.mMonsterChanceRange[2] and random_value >= terrain.mMonsterChanceRange[1] then
            random_value = math.random()
            for _, monster in pairs(terrain.mMonsters) do
                if random_value <= monster.mChanceRange[2] and random_value >= monster.mChanceRange[1] then
                    local monster_config = GameConfig.getMonsterConfigByMonsterType(monster.mType)
                    local skills = GameCompute.computeInitSkills(monster_config)
                    return new(
                        Monster,
                        {
                            mType = monster.mType,
                            mIndividual = GameCompute.computeMonsterInitIndividualProperty(monster.mType),
                            mLevel = math.random(1, 5),
                            mBigSkill = skills.mBigSkill,
                            mNormalSkills = skills.mNormalSkills,
                            mPassiveSkill = skills.mPassiveSkill
                        }
                    )
                end
            end
        end
    end
end
function GameCompute.computeIndividualSum(monster)
    local ret = 0
    for _, value in pairs(monster.mIndividual) do
        ret = ret + value
    end
    return ret
end
function GameCompute.computeTypeIndividualSum(monsterType)
    local config = GameConfig.getMonsterConfigByMonsterType(monsterType)
    local ret = 0
    ret = ret + config.mLifeUpperLimit
    ret = ret + config.mSpecialAttackUpperLimit
    ret = ret + config.mPhysicalAttackUpperLimit
    ret = ret + config.mSpeedUpperLimit
    ret = ret + config.mSpecialDefenseUpperLimit
    ret = ret + config.mPhysicalDefenseUpperLimit
    return ret
end
function GameCompute.computeTravelMonsterWindowProperty(monster)
    local ret = {}
    ret.mLife = monster.mIndividual.mLife * 100 * (1 + monster.mLevel * 0.1)
    ret.mPhysicalAttack = monster.mIndividual.mPhysicalAttack * 100 * (1 + monster.mLevel * 0.1)
    ret.mSpecialDefense = monster.mIndividual.mSpecialDefense * 100 * (1 + monster.mLevel * 0.1)
    ret.mSpecialAttack = monster.mIndividual.mSpecialAttack * 100 * (1 + monster.mLevel * 0.1)
    ret.mPhysicalDefense = monster.mIndividual.mPhysicalDefense * 100 * (1 + monster.mLevel * 0.1)
    ret.mSpeed = monster.mIndividual.mSpeed * 100 * (1 + monster.mLevel * 0.1)
    local monster_config = GameConfig.getMonsterConfigByMonsterType(monster.mType)
    local passive_skill_config = monster_config.mSkills[monster.mPassiveSkill.mConfigIndex]
    for _, passive in pairs(passive_skill_config.mPassives) do
        if not passive.mInFight then
            if passive.mType == "特攻" then
                ret.mSpecialAttack = ret.mSpecialAttack + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "物攻" then
                ret.mPhysicalAttack = ret.mPhysicalAttack + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "特防" then
                ret.mSpecialDefense = ret.mSpecialDefense + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "物防" then
                ret.mPhysicalDefense = ret.mPhysicalDefense + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "速度" then
                ret.mSpeed = ret.mSpeed + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "生命" then
                ret.mLife = ret.mLife + passive.mLevelValue * monster.mPassiveSkill.mLevel
            end
        end
    end
    return ret
end
function GameCompute.computeTravelMonsterWindowSkillDamage(monster, skillInfo, skillConfig)
    local property = GameCompute.computeTravelMonsterWindowProperty(monster)
    local ret = {}
    for _, attack in pairs(skillConfig.mAttacks) do
        if attack.mType == "特攻" then
            ret.mSpecial = ret.mSpecial or 0
            ret.mSpecial =
                ret.mSpecial + math.floor(property.mSpecialAttack * skillConfig.mPower * 0.01) +
                attack.mLevelValue * skillInfo.mLevel
        elseif attack.mType == "物攻" then
            ret.mPhysical = ret.mPhysical or 0
            ret.mPhysical =
                ret.mPhysical + math.floor(property.mPhysicalAttack * skillConfig.mPower * 0.01) +
                attack.mLevelValue * skillInfo.mLevel
        end
    end
    return ret
end
function GameCompute.computeFightMonsterWindowProperty(fightMonster)
    local monster = fightMonster:getProperty():cache().mMonster
    local ret = {}
    ret.mLife = monster.mIndividual.mLife * 100 * (1 + monster.mLevel * 0.1)
    ret.mPhysicalAttack = monster.mIndividual.mPhysicalAttack * 100 * (1 + monster.mLevel * 0.1)
    ret.mSpecialDefense = monster.mIndividual.mSpecialDefense * 100 * (1 + monster.mLevel * 0.1)
    ret.mSpecialAttack = monster.mIndividual.mSpecialAttack * 100 * (1 + monster.mLevel * 0.1)
    ret.mPhysicalDefense = monster.mIndividual.mPhysicalDefense * 100 * (1 + monster.mLevel * 0.1)
    ret.mSpeed = monster.mIndividual.mSpeed * 100 * (1 + monster.mLevel * 0.1)
    local monster_config = GameConfig.getMonsterConfigByMonsterType(monster.mType)
    local passive_skill_config = monster_config.mSkills[monster.mPassiveSkill.mConfigIndex]
    for _, passive in pairs(passive_skill_config.mPassives) do
        if not passive.mInFight then
            if passive.mType == "特攻" then
                ret.mSpecialAttack = ret.mSpecialAttack + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "物攻" then
                ret.mPhysicalAttack = ret.mPhysicalAttack + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "特防" then
                ret.mSpecialDefense = ret.mSpecialDefense + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "物防" then
                ret.mPhysicalDefense = ret.mPhysicalDefense + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "速度" then
                ret.mSpeed = ret.mSpeed + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "生命" then
                ret.mLife = ret.mLife + passive.mLevelValue * monster.mPassiveSkill.mLevel
            end
        end
    end
    for _, passive in pairs(passive_skill_config.mPassives) do
        if passive.mInFight then
            if passive.mType == "特攻" then
                ret.mSpecialAttack = ret.mSpecialAttack + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "物攻" then
                ret.mPhysicalAttack = ret.mPhysicalAttack + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "特防" then
                ret.mSpecialDefense = ret.mSpecialDefense + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "物防" then
                ret.mPhysicalDefense = ret.mPhysicalDefense + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "速度" then
                ret.mSpeed = ret.mSpeed + passive.mLevelValue * monster.mPassiveSkill.mLevel
            elseif passive.mType == "生命" then
                ret.mLife = ret.mLife + passive.mLevelValue * monster.mPassiveSkill.mLevel
            end
        end
    end
    local property_clone = clone(ret)
    for _, buff in pairs(fightMonster:getProperty():cache().mBuffs) do
        -- echo("devilwalk","devilwalk-------------------------------------------------------GameCompute.computeFightMonsterWindowProperty:buff:")
        -- echo("devilwalk",buff)
        local skill_monster_config = GameConfig.getMonsterConfigByMonsterType(buff.mMonsterType)
        local buff_config = skill_monster_config.mSkills[buff.mSkillConfigIndex].mBuffs[buff.mBuffConfigIndex]
        if buff_config.mType == "属性上升" then
            if buff_config.mValueType == "百分比" then
                for _, property in pairs(buff_config.mPropertyTypes) do
                    if property == "特攻" then
                        ret.mSpecialAttack =
                            ret.mSpecialAttack + (property_clone.mSpecialAttack * buff_config.mValue * 0.01) +
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物攻" then
                        ret.mPhysicalAttack =
                            ret.mPhysicalAttack + (property_clone.mPhysicalAttack * buff_config.mValue * 0.01) +
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "特防" then
                        ret.mSpecialDefense =
                            ret.mSpecialDefense + (property_clone.mSpecialDefense * buff_config.mValue * 0.01) +
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物防" then
                        ret.mPhysicalDefense =
                            ret.mPhysicalDefense + (property_clone.mPhysicalDefense * buff_config.mValue * 0.01) +
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "速度" then
                        ret.mSpeed =
                            ret.mSpeed + (property_clone.mSpeed * buff_config.mValue * 0.01) +
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    end
                end
            else
                for _, property in pairs(buff_config.mPropertyTypes) do
                    if property == "特攻" then
                        ret.mSpecialAttack =
                            ret.mSpecialAttack + buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物攻" then
                        ret.mPhysicalAttack =
                            ret.mPhysicalAttack + buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "特防" then
                        ret.mSpecialDefense =
                            ret.mSpecialDefense + buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物防" then
                        ret.mPhysicalDefense =
                            ret.mPhysicalDefense + buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "速度" then
                        ret.mSpeed = ret.mSpeed + buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    end
                end
            end
        elseif buff_config.mType == "属性下降" then
            if buff_config.mValueType == "百分比" then
                for _, property in pairs(buff_config.mPropertyTypes) do
                    if property == "特攻" then
                        ret.mSpecialAttack =
                            ret.mSpecialAttack - (property_clone.mSpecialAttack * buff_config.mValue * 0.01) -
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物攻" then
                        ret.mPhysicalAttack =
                            ret.mPhysicalAttack - (property_clone.mPhysicalAttack * buff_config.mValue * 0.01) -
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "特防" then
                        ret.mSpecialDefense =
                            ret.mSpecialDefense - (property_clone.mSpecialDefense * buff_config.mValue * 0.01) -
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物防" then
                        ret.mPhysicalDefense =
                            ret.mPhysicalDefense - (property_clone.mPhysicalDefense * buff_config.mValue * 0.01) -
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "速度" then
                        ret.mSpeed =
                            ret.mSpeed - (property_clone.mSpeed * buff_config.mValue * 0.01) -
                            (buff_config.mLevelValue or 0) * buff.mLevel
                    end
                end
            else
                for _, property in pairs(buff_config.mPropertyTypes) do
                    if property == "特攻" then
                        ret.mSpecialAttack =
                            ret.mSpecialAttack - buff_config.mValue - (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物攻" then
                        ret.mPhysicalAttack =
                            ret.mPhysicalAttack - buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "特防" then
                        ret.mSpecialDefense =
                            ret.mSpecialDefense - buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "物防" then
                        ret.mPhysicalDefense =
                            ret.mPhysicalDefense - buff_config.mValue + (buff_config.mLevelValue or 0) * buff.mLevel
                    elseif property == "速度" then
                        ret.mSpeed = ret.mSpeed - buff_config.mValue - (buff_config.mLevelValue or 0) * buff.mLevel
                    end
                end
            end
        end
    end
    for k, v in pairs(ret) do
        ret[k] = math.max(0, v)
    end
    return ret
end
function GameCompute.computeFightMonsterSkillDamage(
    srcAttack,
    targetDefense,
    srcSkillPower,
    srcSkillLevel,
    srcSkillLevelValue)
    return math.max(0, srcAttack - targetDefense) * srcSkillPower * 0.01 + srcSkillLevelValue * srcSkillLevel
end
-----------------------------------------------------------------------------------------Travel Host-----------------------------------------------------------------------------------------
function TravelHost:construction(parameter)
    self.mGame = parameter.mGame
    Host.addListener("Travel", self)
end

function TravelHost:destruction()
    Host.removeListener("Travel", self)
end

function TravelHost:update()
end

function TravelHost:receive(parameter)
end
-----------------------------------------------------------------------------------------Travel Client-----------------------------------------------------------------------------------------
function TravelClient:construction(parameter)
    self.mGame = parameter.mGame
    self.mCommandQueue = new(CommandQueue)
    GameUI.showBasicTravelWindow(self.mGame:getPlayer())
    self.mPlayerLastPosition = vector3d:new(GetPlayer():getPosition())

    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "TravelClient/Timer",
                mTimeOutProcess = function()
                end,
                mExecutingCallback = function(command)
                    command.mTime = command.mTime or GetTime()
                    local cur_time = GetTime()
                    if cur_time - command.mTime >= 100 then
                        command.mTime = cur_time
                        self.mCanCatchMonster = true
                    end
                end
            }
        )
    )
end

function TravelClient:destruction()
    GameUI.closeBasicTravelWindow()
    delete(self.mCommandQueue)
end

function TravelClient:update()
    self.mCommandQueue:update()
    if self.mCanCatchMonster then
        self.mCanCatchMonster = false
        local is_walking = not self.mPlayerLastPosition:compare(GetPlayer():getPosition())
        self.mPlayerLastPosition = vector3d:new(GetPlayer():getPosition())
        local player_block_pos_x, player_block_pos_y, player_block_pos_z = GetPlayer():GetBlockPos()
        local block_id = GetBlockId(player_block_pos_x, player_block_pos_y, player_block_pos_z)
        if is_walking then
            local monster = GameCompute.computeHitMonster(block_id)
            if monster then
                self.mGame.mFightClient:startMonsterCatch(monster)
            end
        end
    end
end

function TravelClient:receive(parameter)
end
-----------------------------------------------------------------------------------------Fight Scene Property-----------------------------------------------------------------------------------------
function FightSceneProperty:construction(parameter)
    self.mFightScenePosition = parameter.mFightScenePosition
end

function FightSceneProperty:destruction()
end

function FightSceneProperty:_getLockKey(property)
    return "FightSceneProperty/" ..
        tostring(self.mFightScenePosition[1]) ..
            "," ..
                tostring(self.mFightScenePosition[2]) .. "," .. tostring(self.mFightScenePosition[3]) .. "/" .. property
end
-----------------------------------------------------------------------------------------Fight Scene Host-----------------------------------------------------------------------------------------
function FightSceneHost:construction(parameter)
    self.mFightScenePosition = parameter.mFightScenePosition
    self.mCommandQueue = new(CommandQueue)
    self.mProperty = new(FightSceneProperty, {mFightScenePosition = self.mFightScenePosition})

    Host.addListener("FightScene", self)
end

function FightSceneHost:destruction()
    Host.removeListener("FightScene", self)
end

function FightSceneHost:update()
    self.mCommandQueue:update()
end

function FightSceneHost:sendToClient(playerID, message, parameter)
    Host.sendTo(playerID, {mKey = "FightScene", mMessage = message, mParameter = parameter})
end

function FightSceneHost:receive(parameter)
    --echo("devilwalk", "FightSceneHost:receive:parameter:")
    --echo("devilwalk", parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if self.mResponseCallback[message] then
            self.mResponseCallback[message](parameter.mParameter)
            self.mResponseCallback[message] = nil
        end
    end
end
-----------------------------------------------------------------------------------------Fight Scene Client-----------------------------------------------------------------------------------------
function FightSceneClient:construction(parameter)
    echo("devilwalk", "FightSceneClient:construction")
    --EnableAutoCamera(false)
    self.mFightClient = parameter.mFightClient
    self.mFightScenePosition = parameter.mFightScenePosition
    self.mType = parameter.mType
    self.mComputeMotion = parameter.mComputeMotion
    self.mCommandQueue = new(CommandQueue)
    self.mProperty = new(FightSceneProperty, {mFightScenePosition = self.mFightScenePosition})
    self.mLogs = {}

    local x, y, z = GetPlayer():GetBlockPos()
    self.mOriginalPlayerPosition = {x, y, z}
    self.mMonsters = {}

    local fight_scene_info = FightHost.getFightSceneInfo(self.mFightScenePosition)
    self.mProperty:addPropertyListener(
        "mCurrentMotionMonster",
        self,
        function(_, value, preValue)
            -- echo(
            --     "devilwalk",
            --     "FightSceneClient:construction:mCurrentMotionMonster:value:" ..
            --         tostring(value) .. ",preValue:" .. tostring(preValue)
            -- )
            if preValue then
                for _, monster in pairs(self.mMonsters) do
                    if preValue == monster.mID then
                        monster:restorePosition()
                        break
                    end
                end
            end
            if value then
                self.mCommandQueue:post(
                    new(
                        Command_Callback,
                        {
                            mDebug = "Command_Callback/UpdatePropertyCache",
                            mExecuteCallback = function(command)
                                self:updatePropertyCache(
                                    function()
                                        command.mState = Command.EState.Finish
                                    end
                                )
                            end
                        }
                    )
                )
                local cur_monster = self:getCachedCurrentMotionMonster()
                if
                    not cur_monster:getProperty():cache().mMonster.mPlayerID or
                        cur_monster:getProperty():cache().mMonster.mPlayerID == self.mFightClient.mGame:getPlayer().mID
                 then
                    self.mCommandQueue:post(
                        new(
                            Command_Callback,
                            {
                                mDebug = "Command_Callback/PreMotion",
                                mExecuteCallback = function(command)
                                    cur_monster:preMotion()
                                    command.mState = Command.EState.Finish
                                end
                            }
                        )
                    )
                end
                self.mCommandQueue:post(
                    new(
                        Command_Callback,
                        {
                            mDebug = "Command_Callback/Check",
                            mExecuteCallback = function(command)
                                for k, monster in pairs(self.mMonsters) do
                                    if monster:isDead() then
                                        delete(monster)
                                        table.remove(self.mMonsters, k)
                                    end
                                end
                                local left_players = {}
                                for _, monster in pairs(self.mMonsters) do
                                    local find
                                    for _, player in pairs(left_players) do
                                        if (monster:getProperty():cache().mMonster.mPlayerID or "fuck") == player then
                                            find = true
                                        end
                                    end
                                    if not find then
                                        left_players[#left_players + 1] =
                                            monster:getProperty():cache().mMonster.mPlayerID or "fuck"
                                    end
                                end
                                if #left_players == 1 then
                                    if left_players[1] == self.mFightClient.mGame:getPlayer().mID then
                                        GameUI.messageBox("恭喜你获得了胜利")
                                    else
                                        GameUI.messageBox("你被击败了，再接再厉")
                                    end
                                    self.mFightClient:finishFight()
                                    command.mState = Command.EState.Finish
                                    return
                                end
                                cur_monster:setPosition(
                                    fight_scene_info.mMonsterMotionPosition[1],
                                    fight_scene_info.mMonsterMotionPosition[2] + 1,
                                    fight_scene_info.mMonsterMotionPosition[3]
                                )
                                self.mCommandQueue:post(
                                    new(
                                        Command_Callback,
                                        {
                                            mDebug = "Command_Callback/UpdateUI",
                                            mExecuteCallback = function(command2)
                                                self:refreshOperationWindow()
                                                self:refreshBasicWindow()
                                                self:showSkillWindow()
                                                self:showTargetInfoWindow()
                                                command2.mState = Command.EState.Finish
                                            end
                                        }
                                    )
                                )
                                -- echo("devilwalk",cur_monster:getProperty():cache().mMonster.mPlayerID)
                                -- echo("devilwalk",self.mFightClient.mGame:getPlayer())
                                if
                                    cur_monster:getProperty():cache().mMonster.mPlayerID ==
                                        self.mFightClient.mGame:getPlayer().mID
                                 then
                                    self:running()
                                    self.mCommandQueue:post(
                                        new(
                                            Command_Callback,
                                            {
                                                mDebug = "Command_Callback/Next",
                                                mExecuteCallback = function(command2)
                                                    self.mLogic:nextMotion()
                                                    command2.mState = Command.EState.Finish
                                                end
                                            }
                                        )
                                    )
                                elseif not cur_monster:getProperty():cache().mMonster.mPlayerID then
                                    self:runAI()
                                    self.mCommandQueue:post(
                                        new(
                                            Command_Callback,
                                            {
                                                mDebug = "Command_Callback/Next",
                                                mExecuteCallback = function(command2)
                                                    self.mLogic:nextMotion()
                                                    command2.mState = Command.EState.Finish
                                                end
                                            }
                                        )
                                    )
                                end
                                command.mState = Command.EState.Finish
                            end
                        }
                    )
                )
            end
        end
    )
    Client.addListener("FightScene", self)

    if self.mComputeMotion then
        for k, monster in pairs(parameter.mMyMonsters) do
            self.mMonsters[#self.mMonsters + 1] =
                new(
                FightMonster,
                {
                    mFightSceneClient = self,
                    mMonster = monster.mMonster,
                    mPosition = {
                        fight_scene_info.mMonsterPositions.m1[k][1],
                        fight_scene_info.mMonsterPositions.m1[k][2] + 1,
                        fight_scene_info.mMonsterPositions.m1[k][3]
                    },
                    mFacing = -1.57,
                    mID = monster.mID
                }
            )
        end
        for k, monster in pairs(parameter.mEnemyMonsters) do
            self.mMonsters[#self.mMonsters + 1] =
                new(
                FightMonster,
                {
                    mFightSceneClient = self,
                    mMonster = parameter.mEnemyMonsters[k].mMonster,
                    mPosition = {
                        fight_scene_info.mMonsterPositions.m2[k][1],
                        fight_scene_info.mMonsterPositions.m2[k][2] + 1,
                        fight_scene_info.mMonsterPositions.m2[k][3]
                    },
                    mFacing = 1.57,
                    mID = parameter.mEnemyMonsters[k].mID
                }
            )
        end
    else
        for k, monster in pairs(parameter.mMyMonsters) do
            self.mMonsters[#self.mMonsters + 1] =
                new(
                FightMonster,
                {
                    mFightSceneClient = self,
                    mMonster = monster.mMonster,
                    mPosition = {
                        fight_scene_info.mMonsterPositions.m2[k][1],
                        fight_scene_info.mMonsterPositions.m2[k][2] + 1,
                        fight_scene_info.mMonsterPositions.m2[k][3]
                    },
                    mFacing = 1.57,
                    mID = monster.mID
                }
            )
        end
        for k, monster in pairs(parameter.mEnemyMonsters) do
            self.mMonsters[#self.mMonsters + 1] =
                new(
                FightMonster,
                {
                    mFightSceneClient = self,
                    mMonster = parameter.mEnemyMonsters[k].mMonster,
                    mPosition = {
                        fight_scene_info.mMonsterPositions.m1[k][1],
                        fight_scene_info.mMonsterPositions.m1[k][2] + 1,
                        fight_scene_info.mMonsterPositions.m1[k][3]
                    },
                    mFacing = -1.57,
                    mID = parameter.mEnemyMonsters[k].mID
                }
            )
        end
    end
    for _, monster in pairs(self.mMonsters) do
        monster.onClick = function(inst, x, y, z, mouseButton)
            self:setTarget(monster)
        end
    end

    self.mLogic = new(FightLogic, {mMonsters = self.mMonsters, mFightSceneClient = self})
    self:setTarget(self.mMonsters[#self.mMonsters])

    if self.mComputeMotion then
        self.mLogic:nextMotion()
    end
    GameUI.closeBasicTravelWindow()
    self:showBasicWindow()
    self:showOperationWindow()
    self:showLogWindow()
end

function FightSceneClient:destruction()
    self:closeLogWindow()
    self:closeSkillWindow()
    self:closeTargetInfoWindow()
    self:closeOperationWindow()
    self:closeBasicWindow()
    GameUI.showBasicTravelWindow(self.mFightClient.mGame:getPlayer())
    for _, monster in pairs(self.mMonsters) do
        delete(monster)
    end
    delete(self.mLogic)
    self.mProperty:removePropertyListener("mCurrentMotionMonster", self)
    self.mProperty:safeWrite("mCurrentMotionMonster")
    delete(self.mProperty)
    GlobalOperation.setEntityBlockPos(
        GetPlayerId(),
        self.mOriginalPlayerPosition[1],
        self.mOriginalPlayerPosition[2],
        self.mOriginalPlayerPosition[3]
    )
    delete(self.mCommandQueue)
    --EnableAutoCamera(true)
    Client.removeListener("FightScene", self)
end

function FightSceneClient:update()
    local fight_scene_info = FightHost.getFightSceneInfo(self.mFightScenePosition)
    local player_position
    if self.mComputeMotion then
        player_position = fight_scene_info.mPlayerPositions[1]
    else
        player_position = fight_scene_info.mPlayerPositions[2]
    end
    local x, y, z = GetPlayer():GetBlockPos()
    if not vec3Equal({x, y - 1, z}, player_position) then
        GlobalOperation.setEntityBlockPos(GetPlayerId(), player_position[1], player_position[2] + 1, player_position[3])
    end
    self.mProperty:update()
    for _, monster in pairs(self.mMonsters) do
        monster:update()
    end
    if self.mLogic then
        self.mLogic:update()
    end
    self.mCommandQueue:update()
end

function FightSceneClient:sendToHost(message, parameter)
    Client.sendToHost("FightScene", {mMessage = message, mParameter = parameter})
end

function FightSceneClient:requestToHost(message, parameter, callback)
    self.mResponseCallback = self.mResponseCallback or {}
    self.mResponseCallback[message] = callback
    self:sendToHost(message, parameter)
end

function FightSceneClient:receive(parameter)
    --echo("devilwalk", "FightSceneClient:receive:parameter:")
    --echo("devilwalk", parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if self.mResponseCallback[message] then
            self.mResponseCallback[message](parameter.mParameter)
            self.mResponseCallback[message] = nil
        end
    elseif parameter.mMessage == "MessageBox" then
        GameUI.messageBox(parameter.mParameter)
    end
end

function FightSceneClient:getProperty()
    return self.mProperty
end

function FightSceneClient:setTarget(monster)
    self.mTarget = monster
    self:showTargetInfoWindow()
    self:showSkillWindow()
end

function FightSceneClient:addLog(log)
    self.mLogs[#self.mLogs + 1] = log
    self:refreshLogWindow()
end

function FightSceneClient:running()
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Command_Callback/Running",
                mTimeOutProcess = function()
                end,
                mExecutingCallback = function(command)
                    if self.mFinish then
                        self:getCachedCurrentMotionMonster():postMotion()
                        command.mState = Command.EState.Finish
                        self.mFinish = nil
                    end
                end
            }
        )
    )
end

function FightSceneClient:runAI()
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Command_Callback/RunAI",
                mExecuteCallback = function(command)
                    local motion_monster = self:getCachedCurrentMotionMonster()
                    local motion_monster_config =
                        GameConfig.getMonsterConfigByMonsterType(motion_monster:getProperty():cache().mMonster.mType)
                    local skill_config
                    local skill_info
                    if motion_monster:getProperty():cache().mAngry == 1000 then
                        skill_config =
                            motion_monster_config.mSkills[
                            motion_monster:getProperty():cache().mMonster.mBigSkill.mConfigIndex
                        ]
                        skill_info = motion_monster:getProperty():cache().mMonster.mBigSkill
                    else
                        local skill_index = math.random(1, #motion_monster:getProperty():cache().mMonster.mNormalSkills)
                        skill_config =
                            motion_monster_config.mSkills[
                            motion_monster:getProperty():cache().mMonster.mNormalSkills[skill_index].mConfigIndex
                        ]
                        skill_info = motion_monster:getProperty():cache().mMonster.mNormalSkills[skill_index]
                    end
                    local target
                    if skill_config.mTarget == "敌军" then
                        for _, monster in pairs(self.mMonsters) do
                            if
                                monster:getProperty():cache().mMonster.mPlayerID ~=
                                    motion_monster:getProperty():cache().mMonster.mPlayerID
                             then
                                target = monster
                                break
                            end
                        end
                    elseif skill_config.mTarget == "友军" or skill_config.mTarget == "自身" then
                        target = motion_monster
                    end
                    self.mLogic:useSkill(motion_monster, target, skill_info)
                    motion_monster:postMotion()
                    local log = motion_monster:getProperty():cache().mMonster.mType .. "对"
                    if target == motion_monster then
                        log = log .. "自身"
                    else
                        log = log .. "你的" .. target:getProperty():cache().mMonster.mType
                    end
                    log = log .. "使用了" .. skill_config.mName
                    self:addLog(log)
                    command.mState = Command.EState.Finish
                end
            }
        )
    )
end

function FightSceneClient:updatePropertyCache(callback)
    local checks = {}
    local function _check()
        for k, monster in pairs(self.mMonsters) do
            if not checks[k] then
                return
            end
        end
        callback()
    end
    for k, monster in pairs(self.mMonsters) do
        monster:updatePropertyCache(
            function()
                checks[k] = true
                _check()
            end
        )
    end
end

function FightSceneClient:useSkill(skillInfo)
    local motion_monster = self:getCachedCurrentMotionMonster()
    local motion_monster_config =
        GameConfig.getMonsterConfigByMonsterType(motion_monster:getProperty():cache().mMonster.mType)
    local skill_config = motion_monster_config.mSkills[skillInfo.mConfigIndex]
    self.mLogic:useSkill(motion_monster, self.mTarget, skillInfo)
    local log =
        motion_monster:getProperty():cache().mMonster.mType ..
        "对敌方的" .. self.mTarget:getProperty():cache().mMonster.mType .. "使用了" .. skill_config.mName
    self:addLog(log)
    self.mFinish = true
end

function FightSceneClient:showBasicWindow()
    self.mProgressWindow =
        MiniGameUISystem.createWindow("Pokemon/FightSceneClient/Progress", "_lt", 1800, 240, 120, 600)
    self.mProgressWindow:setZOrder(101)
    local picture_background =
        self.mProgressWindow:createUI(
        "Picture",
        "Pokemon/FightSceneClient/Progress/Picture/Background",
        "_lt",
        0,
        0,
        120,
        600
    )
    for i = 1, 6 do
        local picture_progress =
            self.mProgressWindow:createUI(
            "Picture",
            "Pokemon/FightSceneClient/Progress/Picture/Progress/" .. tostring(i),
            "_lt",
            10,
            600 - i * 100,
            100,
            100,
            picture_background
        )
    end
end

function FightSceneClient:refreshBasicWindow()
    local motion_monster = self:getCachedCurrentMotionMonster()
    local ordered_monsters = {}
    for _, monster in pairs(self.mMonsters) do
        if monster ~= motion_monster then
            local inserted
            for k, test in pairs(ordered_monsters) do
                if monster:getProperty():cache().mProgress >= test:getProperty():cache().mProgress then
                    table.insert(ordered_monsters, k, monster)
                    inserted = true
                end
            end
            if not inserted then
                ordered_monsters[#ordered_monsters + 1] = monster
            end
        end
    end
    table.insert(ordered_monsters, 1, motion_monster)
    for i = 1, 6 do
        local picture_progress =
            self.mProgressWindow:getUI("Pokemon/FightSceneClient/Progress/Picture/Progress/" .. tostring(i))
        if ordered_monsters[i] then
            local monster_config =
                GameConfig.getMonsterConfigByMonsterType(ordered_monsters[i]:getProperty():cache().mMonster.mType)
            picture_progress:setBackgroundResource(
                tonumber(monster_config.mPictureResource.pid),
                nil,
                nil,
                nil,
                nil,
                monster_config.mPictureResource.hash
            )
        else
            picture_progress:setBackgroundFile("")
        end
    end
end

function FightSceneClient:closeBasicWindow()
    MiniGameUISystem.destroyWindow(self.mProgressWindow)
end

function FightSceneClient:showOperationWindow()
    self.mMonsterInfoWindow =
        MiniGameUISystem.createWindow("Pokemon/FightSceneClient/MonsterInfo", "_lt", 0, 840, 1000, 240)
    self.mMonsterInfoWindow:setZOrder(101)
    local picture_background =
        self.mMonsterInfoWindow:createUI(
        "Picture",
        "Pokemon/FightSceneClient/MonsterInfo/Picture/Background",
        "_lt",
        0,
        0,
        1000,
        240
    )
    local picture_icon =
        self.mMonsterInfoWindow:createUI(
        "Picture",
        "Pokemon/FightSceneClient/MonsterInfo/Picture/Icon",
        "_lt",
        0,
        0,
        240,
        240,
        picture_background
    )
    local text_life =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/Life",
        "_lt",
        240,
        0,
        200,
        40,
        picture_background
    )
    text_life:setFontSize(22)
    text_life:setTextFormat(4)
    local text_angry =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/Angry",
        "_lt",
        240,
        40,
        200,
        40,
        picture_background
    )
    text_angry:setFontSize(22)
    text_angry:setTextFormat(4)
    local text_special_attack =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/SpecialAttack",
        "_lt",
        240,
        80,
        160,
        40,
        picture_background
    )
    text_special_attack:setFontSize(22)
    text_special_attack:setTextFormat(4)
    local text_physical_attack =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/PhysicalAttack",
        "_lt",
        400,
        80,
        160,
        40,
        picture_background
    )
    text_physical_attack:setFontSize(22)
    text_physical_attack:setTextFormat(4)
    local text_special_defense =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/SpecialDefense",
        "_lt",
        240,
        120,
        160,
        40,
        picture_background
    )
    text_special_defense:setFontSize(22)
    text_special_defense:setTextFormat(4)
    local text_physical_defense =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/PhysicalDefense",
        "_lt",
        400,
        120,
        160,
        40,
        picture_background
    )
    text_physical_defense:setFontSize(22)
    text_physical_defense:setTextFormat(4)
    local text_speed =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/Speed",
        "_lt",
        240,
        160,
        160,
        40,
        picture_background
    )
    text_speed:setFontSize(22)
    text_speed:setTextFormat(4)
    local text_level =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/Level",
        "_lt",
        400,
        160,
        160,
        40,
        picture_background
    )
    text_level:setFontSize(22)
    text_level:setTextFormat(4)
    local text_buffs =
        self.mMonsterInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/MonsterInfo/Text/Buffs",
        "_lt",
        600,
        0,
        400,
        240,
        picture_background
    )
    text_buffs:setFontSize(20)
    text_buffs:setTextFormat(1)
end

function FightSceneClient:refreshOperationWindow()
    local monster = self:getCachedCurrentMotionMonster()
    local monster_config = GameConfig.getMonsterConfigByMonsterType(monster:getProperty():cache().mMonster.mType)
    local monster_property = GameCompute.computeFightMonsterWindowProperty(monster)
    local picture_icon = self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Picture/Icon")
    picture_icon:setBackgroundResource(
        tonumber(monster_config.mPictureResource.pid),
        nil,
        nil,
        nil,
        nil,
        monster_config.mPictureResource.hash
    )
    local text_life = self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/Life")
    text_life:setText("生命：" .. tostring(monster:getProperty():cache().mLife) .. "/" .. tostring(monster_property.mLife))
    local text_angry = self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/Angry")
    text_angry:setText("怒气：" .. tostring(monster:getProperty():cache().mAngry) .. "/1000")
    local text_speed = self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/Speed")
    text_speed:setText("速度：" .. tostring(monster_property.mSpeed))
    local text_level = self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/Level")
    text_level:setText("等级：" .. tostring(monster:getProperty():cache().mMonster.mLevel))
    local text_special_attack = self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/SpecialAttack")
    text_special_attack:setText("特攻：" .. tostring(monster_property.mSpecialAttack))
    local text_physical_attack =
        self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/PhysicalAttack")
    text_physical_attack:setText("物攻：" .. tostring(monster_property.mPhysicalAttack))
    local text_special_defense =
        self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/SpecialDefense")
    text_special_defense:setText("特防：" .. tostring(monster_property.mSpecialDefense))
    local text_physical_defense =
        self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/PhysicalDefense")
    text_physical_defense:setText("物防：" .. tostring(monster_property.mPhysicalDefense))
    local text_buffs = self.mMonsterInfoWindow:getUI("Pokemon/FightSceneClient/MonsterInfo/Text/Buffs")
    local buffs_text = ""
    for _, buff in pairs(monster:getProperty():cache().mBuffs) do
        local skill_monster_config = GameConfig.getMonsterConfigByMonsterType(buff.mMonsterType)
        local buff_config = skill_monster_config.mSkills[buff.mSkillConfigIndex].mBuffs[buff.mBuffConfigIndex]
        local buff_text = buff_config.mType
        if buff_config.mType == "属性上升" or buff_config.mType == "属性下降" then
            buff_text = buff_text .. "："
            for _, property in pairs(buff_config.mPropertyTypes) do
                buff_text = buff_text .. property
            end
        end
        if buff_config.mValueType == "百分比" then
            buff_text = buff_text .. tostring(buff_config.mValue) .. "%"
        end
        buffs_text = buffs_text .. buff_text .. "（剩余" .. tostring(buff_config.mTime - buff.mTime) .. "回合）\n"
    end
    text_buffs:setText(buffs_text)
end

function FightSceneClient:closeOperationWindow()
    MiniGameUISystem.destroyWindow(self.mMonsterInfoWindow)
end

function FightSceneClient:getCachedCurrentMotionMonster()
    for _, monster in pairs(self.mMonsters) do
        if monster.mID == self.mProperty:cache().mCurrentMotionMonster then
            return monster
        end
    end
end

function FightSceneClient:showSkillWindow()
    self:closeSkillWindow()
    local monster = self:getCachedCurrentMotionMonster()
    local monster_config
    local monster_property
    if monster then
        monster_config = GameConfig.getMonsterConfigByMonsterType(monster:getProperty():cache().mMonster.mType)
        monster_property = GameCompute.computeFightMonsterWindowProperty(monster)
    end
    self.mSkillWindow = MiniGameUISystem.createWindow("Pokemon/FightSceneClient/Skill", "_lt", 1000, 840, 920, 240)
    self.mSkillWindow:setZOrder(101)
    local picture_background =
        self.mSkillWindow:createUI(
        "Picture",
        "Pokemon/FightSceneClient/Skill/Picture/Background",
        "_lt",
        0,
        0,
        920,
        240
    )
    if monster then
        if monster:getProperty():cache().mMonster.mPlayerID == self.mFightClient.mGame:getPlayer().mID then
            for i = 1, 4 do
                if i == 1 then
                    local skill_config =
                        monster_config.mSkills[monster:getProperty():cache().mMonster.mBigSkill.mConfigIndex]
                    if self.mTarget:getProperty():cache().mMonster.mPlayerID == self.mFightClient.mGame:getPlayer().mID then
                        local has_skill =
                            monster:getProperty():cache().mAngry == 1000 and
                            (skill_config.mTarget == "友军" or skill_config.mTarget == "自身")
                        if has_skill then
                            local button_skill =
                                self.mSkillWindow:createUI(
                                "Button",
                                "Pokemon/FightSceneClient/Skill/Button/Skill/" .. tostring(i),
                                "_lt",
                                (i - 1) * 230,
                                10,
                                220,
                                220,
                                picture_background
                            )
                            button_skill:setText(skill_config.mName)
                            button_skill:setFontSize(50)
                            button_skill:addEventFunction(
                                "onclick",
                                function()
                                    self:useSkill(monster:getProperty():cache().mMonster.mBigSkill)
                                    self:closeSkillWindow()
                                end
                            )
                        end
                    else
                        local has_skill =
                            monster:getProperty():cache().mAngry == 1000 and
                            (skill_config.mTarget == "敌军" or skill_config.mTarget == "自身")
                        if has_skill then
                            local button_skill =
                                self.mSkillWindow:createUI(
                                "Button",
                                "Pokemon/FightSceneClient/Skill/Button/Skill/" .. tostring(i),
                                "_lt",
                                (i - 1) * 230,
                                10,
                                220,
                                220,
                                picture_background
                            )
                            button_skill:setText(skill_config.mName)
                            button_skill:setFontSize(50)
                            button_skill:addEventFunction(
                                "onclick",
                                function()
                                    self:useSkill(monster:getProperty():cache().mMonster.mBigSkill)
                                    self:closeSkillWindow()
                                end
                            )
                        end
                    end
                elseif monster:getProperty():cache().mMonster.mNormalSkills[i - 1] then
                    local skill_config =
                        monster_config.mSkills[monster:getProperty():cache().mMonster.mNormalSkills[i - 1].mConfigIndex]
                    if self.mTarget:getProperty():cache().mMonster.mPlayerID == self.mFightClient.mGame:getPlayer().mID then
                        local has_skill = skill_config.mTarget == "友军" or skill_config.mTarget == "自身"
                        if has_skill then
                            local button_skill =
                                self.mSkillWindow:createUI(
                                "Button",
                                "Pokemon/FightSceneClient/Skill/Button/Skill/" .. tostring(i),
                                "_lt",
                                (i - 1) * 230,
                                10,
                                220,
                                220,
                                picture_background
                            )
                            button_skill:setText(skill_config.mName)
                            button_skill:setFontSize(50)
                            button_skill:addEventFunction(
                                "onclick",
                                function()
                                    self:useSkill(monster:getProperty():cache().mMonster.mNormalSkills[i - 1])
                                    self:closeSkillWindow()
                                end
                            )
                        end
                    else
                        local has_skill = skill_config.mTarget == "敌军" or skill_config.mTarget == "自身"
                        if has_skill then
                            local button_skill =
                                self.mSkillWindow:createUI(
                                "Button",
                                "Pokemon/FightSceneClient/Skill/Button/Skill/" .. tostring(i),
                                "_lt",
                                (i - 1) * 230,
                                10,
                                220,
                                220,
                                picture_background
                            )
                            button_skill:setText(skill_config.mName)
                            button_skill:setFontSize(50)
                            button_skill:addEventFunction(
                                "onclick",
                                function()
                                    self:useSkill(monster:getProperty():cache().mMonster.mNormalSkills[i - 1])
                                    self:closeSkillWindow()
                                end
                            )
                        end
                    end
                end
            end
        else
            for i = 1, 4 do
                if i == 1 then
                    local skill_config =
                        monster_config.mSkills[monster:getProperty():cache().mMonster.mBigSkill.mConfigIndex]
                    local picture_skill =
                        self.mSkillWindow:createUI(
                        "Picture",
                        "Pokemon/FightSceneClient/Skill/Picture/Skill/" .. tostring(i),
                        "_lt",
                        (i - 1) * 230,
                        10,
                        220,
                        220,
                        picture_background
                    )
                    local text_skill =
                        self.mSkillWindow:createUI(
                        "Text",
                        "Pokemon/FightSceneClient/Skill/Text/Skill/" .. tostring(i),
                        "_lt",
                        0,
                        0,
                        220,
                        220,
                        picture_skill
                    )
                    text_skill:setText(skill_config.mName)
                    text_skill:setTextFormat(5)
                    text_skill:setFontSize(50)
                elseif monster:getProperty():cache().mMonster.mNormalSkills[i - 1] then
                    local skill_config =
                        monster_config.mSkills[monster:getProperty():cache().mMonster.mNormalSkills[i - 1].mConfigIndex]
                    local picture_skill =
                        self.mSkillWindow:createUI(
                        "Picture",
                        "Pokemon/FightSceneClient/Skill/Picture/Skill/" .. tostring(i),
                        "_lt",
                        (i - 1) * 230,
                        10,
                        220,
                        220,
                        picture_background
                    )
                    local text_skill =
                        self.mSkillWindow:createUI(
                        "Text",
                        "Pokemon/FightSceneClient/Skill/Text/Skill/" .. tostring(i),
                        "_lt",
                        0,
                        0,
                        220,
                        220,
                        picture_skill
                    )
                    text_skill:setText(skill_config.mName)
                    text_skill:setTextFormat(5)
                    text_skill:setFontSize(50)
                end
            end
        end
    end
end

function FightSceneClient:closeSkillWindow()
    if self.mSkillWindow then
        MiniGameUISystem.destroyWindow(self.mSkillWindow)
        self.mSkillWindow = nil
    end
end

function FightSceneClient:showTargetInfoWindow()
    self:closeTargetInfoWindow()
    self.mTargetInfoWindow =
        MiniGameUISystem.createWindow("Pokemon/FightSceneClient/TargetInfo", "_lt", 0, 0, 1920, 240)
    self.mTargetInfoWindow:setZOrder(101)
    local picture_background =
        self.mTargetInfoWindow:createUI(
        "Picture",
        "Pokemon/FightSceneClient/TargetInfo/Picture/Background",
        "_lt",
        0,
        0,
        1920,
        240
    )
    local picture_icon =
        self.mTargetInfoWindow:createUI(
        "Picture",
        "Pokemon/FightSceneClient/TargetInfo/Picture/Icon",
        "_lt",
        0,
        0,
        240,
        240,
        picture_background
    )
    local text_life =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/Life",
        "_lt",
        240,
        0,
        200,
        40,
        picture_background
    )
    text_life:setFontSize(22)
    text_life:setTextFormat(4)
    local text_angry =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/Angry",
        "_lt",
        240,
        40,
        200,
        40,
        picture_background
    )
    text_angry:setFontSize(22)
    text_angry:setTextFormat(4)
    local text_special_attack =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/SpecialAttack",
        "_lt",
        240,
        80,
        160,
        40,
        picture_background
    )
    text_special_attack:setFontSize(22)
    text_special_attack:setTextFormat(4)
    local text_physical_attack =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/PhysicalAttack",
        "_lt",
        400,
        80,
        160,
        40,
        picture_background
    )
    text_physical_attack:setFontSize(22)
    text_physical_attack:setTextFormat(4)
    local text_special_defense =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/SpecialDefense",
        "_lt",
        240,
        120,
        160,
        40,
        picture_background
    )
    text_special_defense:setFontSize(22)
    text_special_defense:setTextFormat(4)
    local text_physical_defense =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/PhysicalDefense",
        "_lt",
        400,
        120,
        160,
        40,
        picture_background
    )
    text_physical_defense:setFontSize(22)
    text_physical_defense:setTextFormat(4)
    local text_speed =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/Speed",
        "_lt",
        240,
        160,
        160,
        40,
        picture_background
    )
    text_speed:setFontSize(22)
    text_speed:setTextFormat(4)
    local text_level =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/Level",
        "_lt",
        400,
        160,
        160,
        40,
        picture_background
    )
    text_level:setFontSize(22)
    text_level:setTextFormat(4)
    local text_buffs =
        self.mTargetInfoWindow:createUI(
        "Text",
        "Pokemon/FightSceneClient/TargetInfo/Text/Buffs",
        "_lt",
        600,
        0,
        400,
        240,
        picture_background
    )
    text_buffs:setFontSize(20)
    text_buffs:setTextFormat(1)

    local monster = self.mTarget
    if monster:getProperty():cache().mMonster then
        local monster_config = GameConfig.getMonsterConfigByMonsterType(monster:getProperty():cache().mMonster.mType)
        local monster_property = GameCompute.computeFightMonsterWindowProperty(monster)
        picture_icon:setBackgroundResource(
            tonumber(monster_config.mPictureResource.pid),
            nil,
            nil,
            nil,
            nil,
            monster_config.mPictureResource.hash
        )
        text_life:setText(
            "生命：" .. tostring(monster:getProperty():cache().mLife) .. "/" .. tostring(monster_property.mLife)
        )
        text_angry:setText("怒气：" .. tostring(monster:getProperty():cache().mAngry) .. "/1000")
        text_speed:setText("速度：" .. tostring(monster_property.mSpeed))
        text_level:setText("等级：" .. tostring(monster:getProperty():cache().mMonster.mLevel))
        text_special_attack:setText("特攻：" .. tostring(monster_property.mSpecialAttack))
        text_physical_attack:setText("物攻：" .. tostring(monster_property.mPhysicalAttack))
        text_special_defense:setText("特防：" .. tostring(monster_property.mSpecialDefense))
        text_physical_defense:setText("物防：" .. tostring(monster_property.mPhysicalDefense))
        local buffs_text = ""
        for _, buff in pairs(monster:getProperty():cache().mBuffs) do
            local skill_monster_config = GameConfig.getMonsterConfigByMonsterType(buff.mMonsterType)
            local buff_config = skill_monster_config.mSkills[buff.mSkillConfigIndex].mBuffs[buff.mBuffConfigIndex]
            local buff_text = buff_config.mType
            if buff_config.mType == "属性上升" or buff_config.mType == "属性下降" then
                buff_text = buff_text .. "："
                for _, property in pairs(buff_config.mPropertyTypes) do
                    buff_text = buff_text .. property
                end
            end
            if buff_config.mValueType == "百分比" then
                buff_text = buff_text .. tostring(buff_config.mValue) .. "%"
            end
            buffs_text = buffs_text .. buff_text .. "（剩余" .. tostring(buff_config.mTime - buff.mTime) .. "回合）\n"
        end
        text_buffs:setText(buffs_text)
        for i = 1, 4 do
            if i == 1 then
                local skill_config =
                    monster_config.mSkills[monster:getProperty():cache().mMonster.mBigSkill.mConfigIndex]
                local picture_skill =
                    self.mTargetInfoWindow:createUI(
                    "Picture",
                    "Pokemon/FightSceneClient/TargetInfo/Picture/Skill/" .. tostring(i),
                    "_lt",
                    1000 + (i - 1) * 230,
                    10,
                    220,
                    220,
                    picture_background
                )
                local text_skill =
                    self.mTargetInfoWindow:createUI(
                    "Text",
                    "Pokemon/FightSceneClient/TargetInfo/Text/Skill/" .. tostring(i),
                    "_lt",
                    0,
                    0,
                    220,
                    220,
                    picture_skill
                )
                text_skill:setText(skill_config.mName)
                text_skill:setTextFormat(5)
                text_skill:setFontSize(50)
            elseif monster:getProperty():cache().mMonster.mNormalSkills[i - 1] then
                local skill_config =
                    monster_config.mSkills[monster:getProperty():cache().mMonster.mNormalSkills[i - 1].mConfigIndex]
                local picture_skill =
                    self.mTargetInfoWindow:createUI(
                    "Picture",
                    "Pokemon/FightSceneClient/TargetInfo/Picture/Skill/" .. tostring(i),
                    "_lt",
                    1000 + (i - 1) * 230,
                    10,
                    220,
                    220,
                    picture_background
                )
                local text_skill =
                    self.mTargetInfoWindow:createUI(
                    "Text",
                    "Pokemon/FightSceneClient/TargetInfo/Text/Skill/" .. tostring(i),
                    "_lt",
                    0,
                    0,
                    220,
                    220,
                    picture_skill
                )
                text_skill:setText(skill_config.mName)
                text_skill:setTextFormat(5)
                text_skill:setFontSize(50)
            end
        end
    end
end

function FightSceneClient:closeTargetInfoWindow()
    if self.mTargetInfoWindow then
        MiniGameUISystem.destroyWindow(self.mTargetInfoWindow)
        self.mTargetInfoWindow = nil
    end
end

function FightSceneClient:showLogWindow()
    self.mLogWindowStartIndex = 1
    self.mLogWindow = MiniGameUISystem.createWindow("Pokemon/FightSceneClient/Log", "_lt", 0, 240, 300, 600)
    local picture_background =
        self.mLogWindow:createUI("Picture", "Pokemon/FightSceneClient/Log/Picture/Background", "_lt", 0, 0, 300, 600)
    local button_up =
        self.mLogWindow:createUI(
        "Button",
        "Pokemon/FightSceneClient/Log/Button/Up",
        "_ctt",
        0,
        0,
        50,
        50,
        picture_background
    )
    button_up:setBackgroundResource(880, nil, nil, nil, nil, "FuSKsieBX5y4OQQwwlFQt5p8prkV")
    button_up:addEventFunction(
        "onclick",
        function()
            self.mLogWindowStartIndex = math.max(1, self.mLogWindowStartIndex - 1)
        end
    )
    local button_down =
        self.mLogWindow:createUI(
        "Button",
        "Pokemon/FightSceneClient/Log/Button/Down",
        "_ctb",
        0,
        0,
        50,
        50,
        picture_background
    )
    button_down:addEventFunction(
        "onclick",
        function()
            self.mLogWindowStartIndex = math.max(1, #self.mLogs - 9)
        end
    )
    button_down:setBackgroundResource(881, nil, nil, nil, nil, "FnVe_fwd5qoHgSdb06Q7iW6Mj0VU")
    for i = 1, 10 do
        local text_info =
            self.mLogWindow:createUI(
            "Text",
            "Pokemon/FightSceneClient/Log/Text/Info/" .. tostring(i),
            "_lt",
            0,
            50 + (i - 1) * 50,
            300,
            50,
            picture_background
        )
        text_info:setTextFormat(4)
        text_info:setFontSize(20)
    end
    self:refreshLogWindow()
end

function FightSceneClient:closeLogWindow()
    if self.mLogWindow then
        MiniGameUISystem.destroyWindow(self.mLogWindow)
        self.mLogWindow = nil
    end
end

function FightSceneClient:refreshLogWindow()
    for i = 1, 10 do
        local log_index = i + self.mLogWindowStartIndex - 1
        if log_index <= #self.mLogs then
            local text_info = self.mLogWindow:getUI("Pokemon/FightSceneClient/Log/Text/Info/" .. tostring(i))
            text_info:setText(self.mLogs[log_index])
        end
    end
end
-----------------------------------------------------------------------------------------Fight Monster Property-----------------------------------------------------------------------------------------
function FightMonsterProperty:construction(parameter)
    self.mMonster = parameter.mMonster
end

function FightMonsterProperty:destruction()
end

function FightMonsterProperty:_getLockKey(property)
    return "FightMonster/" .. tostring(self.mMonster.mID) .. "/" .. property
end
-----------------------------------------------------------------------------------------Fight Monster-----------------------------------------------------------------------------------------
function FightMonster:construction(parameter)
    echo("devilwalk", "FightMonster:construction")
    self.mFightSceneClient = parameter.mFightSceneClient
    self.mOriginalPosition = parameter.mPosition
    self.mMonster = parameter.mMonster
    self.mID = parameter.mID
    self.mProperty = new(FightMonsterProperty, {mMonster = self})
    self.mCommandQueue = new(CommandQueue)
    local function _createEntity()
        local monster_config = GameConfig.getMonsterConfigByMonsterType(self.mProperty:cache().mMonster.mType)
        GetResourceModel(
            monster_config.mModelResource,
            function(path, error)
                self.mEntity =
                    CreateEntity(parameter.mPosition[1], parameter.mPosition[2], parameter.mPosition[3], path, true)
                self.mEntity:SetFacing(parameter.mFacing)

                self.mEntity.OnClick = function(inst, x, y, z, mouseButton)
                    self:onClick(x, y, z, mouseButton)
                end
            end
        )
    end
    if self.mMonster then
        self.mProperty:safeWrite("mMonster", self.mMonster)
        self.mProperty:safeWrite("mProgress", 0)
        self.mProperty:safeWrite("mAngry", 0)
        self.mProperty:safeWrite("mBuffs", {})
        local monster_property = GameCompute.computeFightMonsterWindowProperty(self)
        self.mProperty:safeWrite("mLife", monster_property.mLife)
        _createEntity()
        self.mInitialized = true
    else
        self.mCommandQueue:post(
            new(
                Command_Callback,
                {
                    mDebug = "FightMonster:construction/updatePropertyCache",
                    mExecutingCallback = function(command)
                        if command.mUpdating then
                            return
                        end
                        if
                            self.mProperty:cache().mMonster and self.mProperty:cache().mProgress and
                                self.mProperty:cache().mAngry and
                                self.mProperty:cache().mBuffs and
                                self.mProperty:cache().mLife
                         then
                            _createEntity()
                            self.mInitialized = true
                            command.mState = Command.EState.Finish
                            return
                        end
                        command.mUpdating = true
                        self:updatePropertyCache(
                            function()
                                command.mUpdating = nil
                            end
                        )
                    end
                }
            )
        )
    end
end

function FightMonster:destruction()
    echo("devilwalk", "FightMonster:destruction")
    if self.mEntity then
        self.mEntity:SetDead(true)
        self.mEntity = nil
    end
    if self.mMonster then
        self.mProperty:safeWrite("mMonster")
        self.mProperty:safeWrite("mProgress")
        self.mProperty:safeWrite("mLife")
        self.mProperty:safeWrite("mAngry")
        self.mProperty:safeWrite("mBuffs")
    end
    delete(self.mProperty)
    delete(self.mCommandQueue)
end

function FightMonster:getProperty()
    return self.mProperty
end

function FightMonster:update()
    self:setPosition()
    self.mProperty:update()
    self.mCommandQueue:update()
end

function FightMonster:updatePropertyCache(callback)
    self.mProperty:commandRead("mMonster")
    self.mProperty:commandRead("mProgress")
    self.mProperty:commandRead("mLife")
    self.mProperty:commandRead("mAngry")
    self.mProperty:commandRead("mBuffs")
    self.mProperty:commandFinish(
        function()
            callback()
        end
    )
end

function FightMonster:setPosition(x, y, z)
    if not x and not self.mPosition then
        return
    end
    if self.mEntity then
        if x then
            self.mEntity:SetBlockPos(x, y, z)
        else
            self.mEntity:SetBlockPos(self.mPosition[1], self.mPosition[2], self.mPosition[3])
            self.mPosition = nil
        end
    else
        if x then
            self.mPosition = {x, y, z}
        end
    end
end

function FightMonster:restorePosition()
    self:setPosition(self.mOriginalPosition[1], self.mOriginalPosition[2], self.mOriginalPosition[3])
end

function FightMonster:onClick(x, y, z, mouseButton)
end

function FightMonster:isDead()
    return self.mInitialized and (not self.mProperty:cache().mLife or self.mProperty:cache().mLife <= 0)
end

function FightMonster:addBuff(monster, skillInfo, buffConfigIndex)
    local buffs = self:getProperty():cache().mBuffs or {}
    local match_buffs = self:getBuffs(monster, skillInfo, buffConfigIndex)
    local add_buff
    if #match_buffs > 0 then
        local monster_config = GameConfig.getMonsterConfigByMonsterType(monster:getProperty():cache().mMonster.mType)
        local buff_config = monster_config.mSkills[skillInfo.mConfigIndex].mBuffs[buffConfigIndex]
        if buff_config.mAdditionType == "叠加" then
            if buff_config.mAdditionTimes > #match_buffs then
                add_buff = true
            else
                local time_lesses_buff
                for _, buff in pairs(match_buffs) do
                    if not time_lesses_buff or time_lesses_buff.mTime > buff then
                        time_lesses_buff = buff
                    end
                end
                time_lesses_buff.mTime = 0
            end
        else
            match_buffs[1].mTime = 0
        end
    else
        add_buff = true
    end
    if add_buff then
        buffs[#buffs + 1] = {
            mSkillConfigIndex = skillInfo.mConfigIndex,
            mBuffConfigIndex = buffConfigIndex,
            mTime = 0,
            mLevel = skillInfo.mLevel,
            mMonsterType = monster:getProperty():cache().mMonster.mType
        }
    end
    self:getProperty():safeWrite("mBuffs", buffs)
end

function FightMonster:getBuffs(monster, skillInfo, buffConfigIndex)
    local ret = {}
    local buffs = self:getProperty():cache().mBuffs or {}
    for _, buff in pairs(buffs) do
        if
            buff.mMonsterType == monster:getProperty():cache().mMonster.mType and
                buff.mSkillConfigIndex == skillInfo.mConfigIndex and
                buff.mBuffConfigIndex == buffConfigIndex
         then
            ret[#ret + 1] = buff
        end
    end
    return ret
end

function FightMonster:preMotion()
    local buffs = self:getProperty():cache().mBuffs or {}
    local i = 1
    while i <= #buffs do
        local buff = buffs[i]
        local skill_monster_config = GameConfig.getMonsterConfigByMonsterType(buff.mMonsterType)
        local buff_config = skill_monster_config.mSkills[buff.mSkillConfigIndex].mBuffs[buff.mBuffConfigIndex]
        if buff_config.mTime <= buff.mTime then
            table.remove(buffs, i)
        else
            i = i + 1
        end
    end
    self:getProperty():safeWrite("mBuffs", buffs)
end

function FightMonster:postMotion()
    local buffs = self:getProperty():cache().mBuffs or {}
    for _, buff in pairs(buffs) do
        buff.mTime = buff.mTime + 1
    end
    self:getProperty():safeWrite("mBuffs", buffs)
end
-----------------------------------------------------------------------------------------Game-----------------------------------------------------------------------------------------
function Game.singleton()
    Game.msInstance = Game.msInstance or new(Game)
    return Game.msInstance
end

function Game:construction()
    self.mPlayerData = GetSavedData() or {}
    self.mPlayers = {}
    if not next(self.mPlayerData) then
        self:showFirstWindow()
    else
        self.mPlayers[GetPlayerId()] = new(GamePlayer, {mID = GetPlayerId(), mSavedData = self.mPlayerData})
        self.mTravelClient = new(TravelClient, {mGame = self})
    end
    self.mTravelHost = new(TravelHost, {mGame = self})
    self.mFightHost = new(FightHost, {mGame = self})
    self.mFightClient = new(FightClient, {mGame = self})

    EntityWatcher.on(
        "create",
        function(entityWatcher)
            self.mPlayers[#self.mPlayers + 1] = new(GamePlayer, {mID = entityWatcher.id})
            GameUI.refreshBasicTravelWindow()
        end
    )
end

function Game:destruction()
    delete(self.mTravelClient)
    delete(self.mTravelHost)
    delete(self.mFightClient)
    delete(self.mFightHost)
end

function Game:update()
    for k, player in pairs(self.mPlayers) do
        if not GetEntityById(player.mID) then
            self.mPlayers[k] = nil
            GameUI.refreshBasicTravelWindow()
        end
    end
    self.mFightClient:update()
    if self.mTravelClient then
        self.mTravelClient:update()
    end
    self.mTravelHost:update()
    self.mFightHost:update()
end

function Game:getPlayer(id)
    id = id or GetPlayerId()
    return self.mPlayers[id]
end

function Game:showFirstWindow()
    local window = MiniGameUISystem.createWindow("Pokemon/FirstWindow", "_ct", 0, 0, 800, 600)
    local background = window:createUI("Picture", "Pokemon/FirstWindow/Background", "_lt", 0, 0, 800, 600)
    local text_title = window:createUI("Text", "Pokemon/FirstWindow/Title", "_lt", 0, 0, 800, 100, background)
    text_title:setText("请选择你最初的小精灵")
    text_title:setTextFormat(5)
    text_title:setFontSize(50)
    local button_fire = window:createUI("Button", "Pokemon/FirstWindow/Fire", "_lt", 0, 150, 250, 400, background)
    button_fire:setBackgroundResource(185, nil, nil, nil, nil, "FuTRPmcFFRRs3MmYsp2YvUNs3uTW")
    button_fire:addEventFunction(
        "onclick",
        function()
            GameUI.yesOrNo(
                "选择小火龙(火系)，可以吗？",
                function()
                    self:initMonster("小火龙")
                    MiniGameUISystem.destroyWindow(window)
                    self.mTravelClient = new(TravelClient, {mGame = self})
                end
            )
        end
    )
    local button_water = window:createUI("Button", "Pokemon/FirstWindow/Water", "_lt", 275, 150, 250, 400, background)
    button_water:setBackgroundResource(186, nil, nil, nil, nil, "FkWRFCC3KBJGP28-PvuveaAp_QGX")
    button_water:addEventFunction(
        "onclick",
        function()
            GameUI.yesOrNo(
                "选择杰尼龟(水系)，可以吗？",
                function()
                    self:initMonster("杰尼龟")
                    MiniGameUISystem.destroyWindow(window)
                    self.mTravelClient = new(TravelClient, {mGame = self})
                end
            )
        end
    )
    local button_grass = window:createUI("Button", "Pokemon/FirstWindow/Grass", "_lt", 550, 150, 250, 400, background)
    button_grass:setBackgroundResource(187, nil, nil, nil, nil, "FuKMtX_1tCxtPwrkKi3hr_nwuL13")
    button_grass:addEventFunction(
        "onclick",
        function()
            GameUI.yesOrNo(
                "选择妙蛙种子(草系)，可以吗？",
                function()
                    self:initMonster("妙蛙种子")
                    MiniGameUISystem.destroyWindow(window)
                    self.mTravelClient = new(TravelClient, {mGame = self})
                end
            )
        end
    )
end

function Game:initMonster(monsterType)
    self.mPlayers[GetPlayerId()] = new(GamePlayer, {mID = GetPlayerId(), mSavedData = self.mPlayerData})
    local monster_init_individual = GameCompute.computeMonsterInitIndividualProperty(monsterType)
    local monster_config = GameConfig.getMonsterConfigByMonsterType(monsterType)
    local skills = GameCompute.computeInitSkills(monster_config)
    self:getPlayer():addMonster(
        new(
            Monster,
            {
                mType = monsterType,
                mIndividual = monster_init_individual,
                mLevel = 3,
                mBigSkill = skills.mBigSkill,
                mNormalSkills = skills.mNormalSkills,
                mPassiveSkill = skills.mPassiveSkill
            }
        )
    )
end
-----------------------------------------------------------------------------------------Monster-----------------------------------------------------------------------------------------
function Monster:construction(parameter)
    self.mPlayerID = parameter.mPlayerID
    self.mType = parameter.mType
    self.mIndividual = parameter.mIndividual
    self.mLevel = parameter.mLevel
    self.mBigSkill = parameter.mBigSkill
    self.mNormalSkills = parameter.mNormalSkills
    self.mPassiveSkill = parameter.mPassiveSkill
end

function Monster:destruction()
end

function Monster:getConfig()
    return GameConfig.getMonsterConfigByMonsterType(self.mType)
end

function Monster:getPlayer()
    if self.mPlayerID then
        Game.singleton():getPlayer(self.mPlayerID)
    end
end
-----------------------------------------------------------------------------------------Game Player-----------------------------------------------------------------------------------------
function GamePlayer:construction(parameter)
    self.mID = parameter.mID
    self.mSavedData = parameter.mSavedData
    self.mMonsters = {}
    self:applySavedData()
end

function GamePlayer:destruction()
end

function GamePlayer:applySavedData()
end

function GamePlayer:addMonster(monster)
    self.mMonsters[#self.mMonsters + 1] = monster
    monster.mPlayerID = self.mID
end
-----------------------------------------------------------------------------------------Fight Host-----------------------------------------------------------------------------------------
function FightHost:construction(parameter)
    self.mGame = parameter.mGame
    self.mLeftFightScenePositions = {}
    self.mUsedFightScenes = {}
    local x, y, z = GetPlayer():GetBlockPos()
    for i = 1, 16 do
        self.mLeftFightScenePositions[#self.mLeftFightScenePositions + 1] = {x, y + 10 * i, z}
    end
    self.mFightSceneHosts = {}
    self.mNextMonsterID = 1

    Host.addListener("Fight", self)
end

function FightHost:destruction()
    for _, info in pairs(self.mUsedFightScenes) do
        for i = info.mPosition[1] - 5, info.mPosition[1] + 5 do
            for j = info.mPosition[3] - 10, info.mPosition[3] + 10 do
                SetBlock(i, info.mPosition[2], j, 0)
            end
        end
    end
    for _, fight_scene_host in pairs(self.mFightSceneHosts) do
        delete(fight_scene_host)
    end
    Host.removeListener("Fight", self)
end

function FightHost:update()
    local i = 1
    while i <= #self.mUsedFightScenes do
        if not GetEntityById(self.mUsedFightScenes[i].mPlayerID) then
            self:destroyFightScene(self.mUsedFightScenes[i].mPosition)
        else
            i = i + 1
        end
    end
    for _, fight_scene_host in pairs(self.mFightSceneHosts) do
        fight_scene_host:update()
    end
end

function FightHost:receive(parameter)
    --echo("devilwalk", "FightHost:receive:parameter:")
    --echo("devilwalk", parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if self.mResponseCallback[message] then
            self.mResponseCallback[message](parameter.mParameter)
            self.mResponseCallback[message] = nil
        end
    elseif parameter.mMessage == "CreateFightScene" then
        local fight_scene_pos = self:createFightScene()
        self.mUsedFightScenes[#self.mUsedFightScenes + 1] = {mPosition = fight_scene_pos, mPlayerID = parameter.mFrom}
        self:sendToClient(parameter.mFrom, "CreateFightScene_Response", {mFightScenePosition = fight_scene_pos})
    elseif parameter.mMessage == "CreateFightMonsterID" then
        local ids = {}
        for i = 1, parameter.mParameter.mCount do
            ids[#ids + 1] = self.mNextMonsterID
            self.mNextMonsterID = self.mNextMonsterID + 1
        end
        self:sendToClient(parameter.mFrom, "CreateFightMonsterID_Response", {mIDs = ids})
    elseif parameter.mMessage == "DestroyFightScene" then
        self:destroyFightScene(parameter.mParameter.mFightScenePosition)
    end
end

function FightHost:sendToClient(playerID, message, parameter)
    Host.sendTo(playerID, {mKey = "Fight", mMessage = message, mParameter = parameter})
end

function FightHost.getFightSceneInfo(pos)
    local ret = {
        mBlockPositions = {},
        mPlayerPositions = {},
        mMonsterPositions = {m1 = {}, m2 = {}}
    }
    for i = pos[1] - 5, pos[1] + 5 do
        for j = pos[3] - 10, pos[3] + 10 do
            if (i == pos[1] and j == pos[3] - 9) or (i == pos[1] and j == pos[3] + 9) then
                ret.mPlayerPositions[#ret.mPlayerPositions + 1] = {i, pos[2], j}
            elseif
                (i == pos[1] - 3 and j == pos[3] - 7) or (i == pos[1] and j == pos[3] - 7) or
                    (i == pos[1] + 3 and j == pos[3] - 7) or
                    (i == pos[1] - 3 and j == pos[3] + 7) or
                    (i == pos[1] and j == pos[3] + 7) or
                    (i == pos[1] + 3 and j == pos[3] + 7)
             then
                if j == pos[3] - 7 then
                    ret.mMonsterPositions.m1[#ret.mMonsterPositions.m1 + 1] = {i, pos[2], j}
                else
                    ret.mMonsterPositions.m2[#ret.mMonsterPositions.m2 + 1] = {i, pos[2], j}
                end
            elseif i == pos[1] and j == pos[3] then
                ret.mMonsterMotionPosition = {i, pos[2], j}
            end
        end
    end
    return ret
end

function FightHost:createFightScene()
    local pos = self.mLeftFightScenePositions[1]
    table.remove(self.mLeftFightScenePositions, 1)
    for i = pos[1] - 5, pos[1] + 5 do
        for j = pos[3] - 10, pos[3] + 10 do
            if (i == pos[1] and j == pos[3] - 9) or (i == pos[1] and j == pos[3] + 9) then
                SetBlock(i, pos[2], j, 2051)
            elseif
                (i == pos[1] - 3 and j == pos[3] - 7) or (i == pos[1] and j == pos[3] - 7) or
                    (i == pos[1] + 3 and j == pos[3] - 7) or
                    (i == pos[1] - 3 and j == pos[3] + 7) or
                    (i == pos[1] and j == pos[3] + 7) or
                    (i == pos[1] + 3 and j == pos[3] + 7)
             then
                SetBlock(i, pos[2], j, 2055)
            elseif i == pos[1] and j == pos[3] then
                SetBlock(i, pos[2], j, 2079)
            else
                SetBlock(i, pos[2], j, 2218)
            end
        end
    end
    return pos
end

function FightHost:destroyFightScene(pos)
    for i = pos[1] - 5, pos[1] + 5 do
        for j = pos[3] - 10, pos[3] + 10 do
            SetBlock(i, pos[2], j, 0)
        end
    end
    for k, info in pairs(self.mUsedFightScenes) do
        if vec3Equal(pos, info.mPosition) then
            table.remove(self.mUsedFightScenes, k)
            break
        end
    end
    self.mLeftFightScenePositions[#self.mLeftFightScenePositions + 1] = pos
end
-----------------------------------------------------------------------------------------Fight Client-----------------------------------------------------------------------------------------
function FightClient:construction(parameter)
    self.mGame = parameter.mGame

    Client.addListener("Fight", self)
end

function FightClient:destruction()
    delete(self.mFightSceneClient)
    Client.removeListener("Fight", self)
end

function FightClient:update()
    if self.mFightSceneClient then
        self.mFightSceneClient:update()
    end
end

function FightClient:receive(parameter)
    --echo("devilwalk", "FightClient:receive:parameter:")
    --echo("devilwalk", parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if self.mResponseCallback[message] then
            self.mResponseCallback[message](parameter.mParameter)
            self.mResponseCallback[message] = nil
        end
    elseif parameter.mMessage == "TryBattle" then
        if not self.mBattle and self.mGame:getPlayer() and #self.mGame:getPlayer().mMonsters > 0 then
            local text = GetEntityById(parameter.mFrom).nickname .. "请求与你对战，对方出战的宠物是："
            for _, monster in pairs(parameter.mParameter.mMonsters) do
                text = text .. monster.mType .. "，"
            end
            text = text .. "是否同意？"
            GameUI.yesOrNo(
                text,
                function()
                    self:showSelectFightMonstersWindow(
                        function()
                            local monsters = {}
                            for _, monster_index in pairs(self.mSelectFightMonsters) do
                                monsters[#monsters + 1] = {
                                    mType = self.mGame:getPlayer().mMonsters[monster_index].mType
                                }
                            end
                            self:sendToClient(
                                parameter.mFrom,
                                "TryBattle_Response",
                                {mResult = true, mMonsters = monsters}
                            )
                            self.mBattle = "Waiting"
                        end
                    )
                end,
                function()
                    self:sendToClient(parameter.mFrom, "TryBattle_Response", {mResult = false})
                end
            )
        else
            self:sendToClient(parameter.mFrom, "TryBattle_Response", {mResult = false})
        end
    elseif parameter.mMessage == "Battle" then
        local my_monsters = {}
        for k, monster in pairs(self:getSelectMonsters()) do
            my_monsters[#my_monsters + 1] = {mMonster = monster, mID = parameter.mParameter.mMyIDs[k]}
        end
        local enemy_monsters = {}
        for k, id in pairs(parameter.mParameter.mEnemyIDs) do
            enemy_monsters[#enemy_monsters + 1] = {mID = id}
        end
        local battle_parameter = {
            mMyMonsters = my_monsters,
            mEnemyMonsters = enemy_monsters,
            mFightScenePosition = parameter.mParameter.mFightScenePosition,
            mType = "对战"
        }
        self:battle(battle_parameter)
    end
end

function FightClient:sendToHost(message, parameter)
    Client.sendToHost("Fight", {mMessage = message, mParameter = parameter})
end

function FightClient:requestToHost(message, parameter, callback)
    self.mResponseCallback = self.mResponseCallback or {}
    self.mResponseCallback[message] = callback
    self:sendToHost(message, parameter)
end

function FightClient:sendToClient(id, message, parameter)
    Client.sendToClient(id, "Fight", {mMessage = message, mParameter = parameter})
end

function FightClient:requestToClient(id, message, parameter, callback)
    self.mResponseCallback = self.mResponseCallback or {}
    self.mResponseCallback[message] = callback
    self:sendToClient(id, message, parameter)
end

function FightClient:getSelectMonsters()
    local ret = {}
    for k, index in pairs(self.mSelectFightMonsters) do
        ret[#ret + 1] = self.mGame:getPlayer().mMonsters[index]
    end
    return ret
end

function FightClient:startMonsterCatch(monster)
    delete(self.mGame.mTravelClient)
    self.mGame.mTravelClient = nil
    self:showSelectFightMonstersWindow(
        function()
            self:requestToHost(
                "CreateFightScene",
                nil,
                function(parameter1)
                    self:requestToHost(
                        "CreateFightMonsterID",
                        {mCount = 1 + #self.mSelectFightMonsters},
                        function(parameter2)
                            local my_monsters = {}
                            for k, monster in pairs(self:getSelectMonsters()) do
                                my_monsters[#my_monsters + 1] = {mMonster = monster, mID = parameter2.mIDs[k]}
                            end
                            local battle_parameter = {
                                mMyMonsters = my_monsters,
                                mEnemyMonsters = {{mMonster = monster, mID = parameter2.mIDs[#parameter2.mIDs]}},
                                mFightScenePosition = parameter1.mFightScenePosition,
                                mType = "野生",
                                mComputeMotion = true
                            }
                            self:battle(battle_parameter)
                        end
                    )
                end
            )
        end
    )
end

function FightClient:tryBattle(playerID)
    if self.mBattle then
        GameUI.messageBox("当前正在战斗")
        return
    end
    self.mBattle = "Try"
    self:showSelectFightMonstersWindow(
        function()
            local monsters = {}
            for _, monster_index in pairs(self.mSelectFightMonsters) do
                monsters[#monsters + 1] = {mType = self.mGame:getPlayer().mMonsters[monster_index].mType}
            end
            self:requestToClient(
                playerID,
                "TryBattle",
                {mMonsters = monsters},
                function(parameter)
                    echo("devilwalk", parameter)
                    if parameter.mResult then
                        self.mBattle = "Waiting"
                        self:requestToHost(
                            "CreateFightScene",
                            nil,
                            function(parameter1)
                                self:requestToHost(
                                    "CreateFightMonsterID",
                                    {mCount = #parameter.mMonsters + #self.mSelectFightMonsters},
                                    function(parameter2)
                                        local my_ids = {}
                                        local enemy_ids = {}
                                        for i = #self.mSelectFightMonsters + 1, #parameter2.mIDs do
                                            enemy_ids[#enemy_ids + 1] = parameter2.mIDs[i]
                                        end
                                        for i = 1, #self.mSelectFightMonsters do
                                            my_ids[#my_ids + 1] = parameter2.mIDs[i]
                                        end
                                        self:sendToClient(
                                            playerID,
                                            "Battle",
                                            {
                                                mMyIDs = enemy_ids,
                                                mEnemyIDs = my_ids,
                                                mFightScenePosition = parameter1.mFightScenePosition
                                            }
                                        )
                                        local my_monsters = {}
                                        for k, monster in pairs(self:getSelectMonsters()) do
                                            my_monsters[#my_monsters + 1] = {
                                                mMonster = monster,
                                                mID = parameter2.mIDs[k]
                                            }
                                        end
                                        local enemy_monsters = {}
                                        for k, monster in pairs(parameter.mMonsters) do
                                            enemy_monsters[#enemy_monsters + 1] = {mID = enemy_ids[k]}
                                        end
                                        local battle_parameter = {
                                            mMyMonsters = my_monsters,
                                            mEnemyMonsters = enemy_monsters,
                                            mFightScenePosition = parameter1.mFightScenePosition,
                                            mType = "对战",
                                            mComputeMotion = true
                                        }
                                        self:battle(battle_parameter)
                                    end
                                )
                            end
                        )
                    else
                        self.mBattle = nil
                        GameUI.messageBox("对方拒绝与你战斗")
                    end
                end
            )
        end
    )
end

function FightClient:battle(parameter)
    self.mBattle = true
    delete(self.mGame.mTravelClient)
    self.mGame.mTravelClient = nil
    self.mFightSceneClient =
        new(
        FightSceneClient,
        {
            mFightClient = self,
            mType = parameter.mType,
            mMyMonsters = parameter.mMyMonsters,
            mEnemyMonsters = parameter.mEnemyMonsters,
            mFightScenePosition = parameter.mFightScenePosition,
            mComputeMotion = parameter.mComputeMotion
        }
    )
end

function FightClient:finishFight()
    echo("devilwalk", "FightClient:finishFight")
    if self.mFightSceneClient.mComputeMotion then
        self:sendToHost("DestroyFightScene", {mFightScenePosition = self.mFightSceneClient.mFightScenePosition})
    end
    delete(self.mFightSceneClient)
    self.mFightSceneClient = nil
    self.mGame.mTravelClient = new(TravelClient, {mGame = self.mGame})
    self.mBattle = nil
end

function FightClient:showSelectFightMonstersWindow(callback)
    self.mSelectFightMonsters = {}
    self.mSelectFightMonstersWindow =
        MiniGameUISystem.createWindow("Pokemon/FightClient/SelectFightMonstersWindow", "_ct", 0, 0, 1920, 1080)
    self.mSelectFightMonstersWindow:setZOrder(101)
    local picture_background =
        self.mSelectFightMonstersWindow:createUI(
        "Picture",
        "Pokemon/FightClient/SelectFightMonstersWindow/Picture/Background",
        "_lt",
        10,
        40,
        1900,
        1000
    )
    local text_title =
        self.mSelectFightMonstersWindow:createUI(
        "Text",
        "Pokemon/FightClient/SelectFightMonstersWindow/Text/Title",
        "_lt",
        0,
        0,
        1900,
        100,
        picture_background
    )
    text_title:setText("选择出战宠物")
    text_title:setTextFormat(5)
    text_title:setFontSize(50)
    local button_up =
        self.mSelectFightMonstersWindow:createUI(
        "Button",
        "Pokemon/FightClient/SelectFightMonstersWindow/Button/Up",
        "_lt",
        0,
        100,
        1900,
        100,
        picture_background
    )
    button_up:setBackgroundResource(880, nil, nil, nil, nil, "FuSKsieBX5y4OQQwwlFQt5p8prkV")
    local button_down =
        self.mSelectFightMonstersWindow:createUI(
        "Button",
        "Pokemon/FightClient/SelectFightMonstersWindow/Button/Down",
        "_lt",
        0,
        800,
        1900,
        100,
        picture_background
    )
    button_down:setBackgroundResource(881, nil, nil, nil, nil, "FnVe_fwd5qoHgSdb06Q7iW6Mj0VU")
    local button_ok =
        self.mSelectFightMonstersWindow:createUI(
        "Button",
        "Pokemon/FightClient/SelectFightMonstersWindow/Button/OK",
        "_ctb",
        0,
        0,
        1900,
        100,
        picture_background
    )
    button_ok:setBackgroundResource(34, nil, nil, nil, nil, "FtFq7Cxh7NP2JrWjJX2zUPdWFwJ7")
    button_ok:addEventFunction(
        "onclick",
        function()
            if #self.mSelectFightMonsters < 1 then
                GameUI.messageBox("至少选择一个出战的宠物")
            else
                MiniGameUISystem.destroyWindow(self.mSelectFightMonstersWindow)
                self.mSelectFightMonstersWindow = nil
                callback()
            end
        end
    )
    for y = 1, 6 do
        for x = 1, 19 do
            local monster_index = (y - 1) * 19 + x
            local monster = self.mGame:getPlayer().mMonsters[monster_index]
            if monster then
                local monster_config = GameConfig.getMonsterConfigByMonsterType(monster.mType)
                local button_monster =
                    self.mSelectFightMonstersWindow:createUI(
                    "Button",
                    "Pokemon/FightClient/SelectFightMonstersWindow/Button/Monster/" .. tostring(monster_index),
                    "_lt",
                    (x - 1) * 100,
                    200 + (y - 1) * 100,
                    100,
                    100,
                    picture_background
                )
                button_monster:setBackgroundResource(
                    tonumber(monster_config.mPictureResource.pid),
                    nil,
                    nil,
                    nil,
                    nil,
                    monster_config.mPictureResource.hash
                )
                button_monster:setFontSize(30)
                button_monster:addEventFunction(
                    "onclick",
                    function()
                        for k, index in pairs(self.mSelectFightMonsters) do
                            if index == monster_index then
                                table.remove(self.mSelectFightMonsters, k)
                                button_monster:setText("")
                                return
                            end
                        end
                        if #self.mSelectFightMonsters < 3 then
                            self.mSelectFightMonsters[#self.mSelectFightMonsters + 1] = monster_index
                            button_monster:setText("上阵")
                        end
                    end
                )
            end
        end
    end
end
-----------------------------------------------------------------------------------------Fight Logic-----------------------------------------------------------------------------------------
function FightLogic:construction(parameter)
    self.mMonsters = parameter.mMonsters
    self.mFightSceneClient = parameter.mFightSceneClient
    self.mCommandQueue = new(CommandQueue)
end

function FightLogic:destruction()
    delete(self.mCommandQueue)
end

function FightLogic:update()
    self.mCommandQueue:update()
end

function FightLogic:nextMotion()
    self.mCommandQueue:post(
        new(
            Command_Callback,
            {
                mDebug = "Command_Callback/FightLogic:nextMotion",
                mExecutingCallback = function(command)
                    for _, monster in pairs(self.mMonsters) do
                        if not monster.mInitialized then
                            return
                        end
                    end
                    local fastest_monster
                    local finish_time = 66666666666
                    for _, monster in pairs(self.mMonsters) do
                        local monster_property = GameCompute.computeFightMonsterWindowProperty(monster)
                        local time = (100 - monster:getProperty():cache().mProgress) / monster_property.mSpeed
                        --echo("devilwalk", monster:getProperty():cache().mMonster.mType .. ":" .. tostring(time))
                        if finish_time > time then
                            finish_time = time
                            fastest_monster = monster
                        end
                    end
                    for _, monster in pairs(self.mMonsters) do
                        local monster_property = GameCompute.computeFightMonsterWindowProperty(monster)
                        if monster == fastest_monster then
                            monster:getProperty():safeWrite("mProgress", 0)
                        else
                            monster:getProperty():safeWrite(
                                "mProgress",
                                monster:getProperty():cache().mProgress + monster_property.mSpeed * finish_time
                            )
                        end
                    end
                    --echo("devilwalk", fastest_monster:getProperty():cache().mMonster.mType)
                    self.mFightSceneClient:getProperty():safeWrite("mCurrentMotionMonster", fastest_monster.mID)
                    command.mState = Command.EState.Finish
                end
            }
        )
    )
end

function FightLogic:useSkill(srcMonster, targetMonster, skillInfo)
    local src_monster_config = GameConfig.getMonsterConfigByMonsterType(srcMonster:getProperty():cache().mMonster.mType)
    local src_monster_proerty = GameCompute.computeFightMonsterWindowProperty(srcMonster)
    local skill_config = src_monster_config.mSkills[skillInfo.mConfigIndex]

    local log = ""
    if srcMonster:getProperty():cache().mPlayerID then
        log = log .. GetEntityById(srcMonster:getProperty():cache().mPlayerID).nickname .. "的"
    else
        log = log .. "野生的"
    end
    log = log .. srcMonster:getProperty():cache().mMonster.mType .. "使用了技能" .. skill_config.mName .. "。"

    if skill_config.mTarget ~= "自身" then
        local target_monsters = {}
        if skill_config.mTarget == "敌军" then
            if skill_config.mRange == "单体" then
                target_monsters[1] = targetMonster
            else
                for _, monster in pairs(self.mFightSceneClient.mMonsters) do
                    if
                        monster:getProperty():cache().mMonster.mPlayerID ==
                            targetMonster:getProperty():cache().mMonster.mPlayerID
                     then
                        target_monsters[#target_monsters + 1] = monster
                    end
                end
            end
            for _, monster in pairs(target_monsters) do
                local monster_config =
                    GameConfig.getMonsterConfigByMonsterType(monster:getProperty().cache().mMonster.mType)
                local monster_property = GameCompute.computeFightMonsterWindowProperty(monster)
                local damage = 0
                if skill_config.mPower and skill_config.mPower > 0 then
                    for _, attack_type in pairs(skill_config.mAttacks) do
                        local attack
                        local defense
                        if attack_type == "特攻" then
                            attack = src_monster_proerty.mSpecialAttack
                            defense = monster_property.mSpecialDefense
                        elseif attack_type == "物攻" then
                            attack = src_monster_proerty.mPhysicalAttack
                            defense = monster_property.mPhysicalDefense
                        end
                        damage =
                            damage +
                            GameCompute.computeFightMonsterSkillDamage(
                                attack,
                                defense,
                                skill_config.mPower,
                                skillInfo.mLevel,
                                skill_config.mLevelValue
                            )
                    end
                    log = log .. "对"
                    if monster:getProperty():cache().mPlayerID then
                        log = log .. GetEntityById(srcMonster:getProperty():cache().mPlayerID).nickname .. "的"
                    else
                        log = log .. "野生的"
                    end
                    log = log .. monster:getProperty():cache().mMonster.mType .. "造成了" .. tostring(damage) .. "点伤害"
                    log = log .. "。"
                    local delta_angry = damage / (monster_property.mLife * 0.9) * 1000
                    monster:getProperty():safeWrite(
                        "mAngry",
                        math.min(1000, monster:getProperty():cache().mAngry + delta_angry)
                    )
                end
                if skill_config.mType == "大招" then
                    srcMonster:getProperty():safeWrite("mAngry", 0)
                else
                    srcMonster:getProperty():safeWrite(
                        "mAngry",
                        math.min(1000, srcMonster:getProperty():cache().mAngry + 100)
                    )
                end
                if skill_config.mBuffs then
                    for k, buff in pairs(skill_config.mBuffs) do
                        if math.random() <= skill_config.mBuffChances[k] and buff.mTarget == "目标" then
                            monster:addBuff(srcMonster, skillInfo, k)
                        end
                    end
                end
                if damage > 0 then
                    monster:getProperty():safeWrite("mLife", monster:getProperty():cache().mLife - damage)
                end
            end
        end
    else
        local target_monsters = {}
        if skill_config.mRange == "单体" then
            target_monsters[1] = srcMonster
        else
        end
        for _, monster in pairs(target_monsters) do
            local monster_config =
                GameConfig.getMonsterConfigByMonsterType(monster:getProperty().cache().mMonster.mType)
            local monster_property = GameCompute.computeFightMonsterWindowProperty(monster)
            for _, recover in pairs(skill_config.mRecovers) do
                if srcMonster:getProperty():cache().mPlayerID then
                    log = log .. GetEntityById(srcMonster:getProperty():cache().mPlayerID).nickname .. "的"
                else
                    log = log .. "野生的"
                end
                log = log .. monster:getProperty():cache().mMonster.mType .. "恢复了"

                local property_value
                local property_name
                if recover.mValueType == "百分比" then
                    if recover.mType == "生命" then
                        property_value =
                            math.min(
                            monster:getProperty():cache().mLife + monster_property.mLife * recover.mValue * 0.01,
                            monster_property.mLife
                        )
                        property_name = "mLife"

                        log = log .. tostring(property_value - monster:getProperty():cache().mLife)
                    end
                end
                monster:getProperty():safeWrite(property_name, property_value)

                log = log .. "点" .. recover.mType
            end
        end
    end
    if skill_config.mBuffs then
        for k, buff in pairs(skill_config.mBuffs) do
            if math.random() <= skill_config.mBuffChances[k] and buff.mTarget == "自身" then
                srcMonster:addBuff(srcMonster, skillInfo, k)
            end
        end
    end

    self.mFightSceneClient:addLog(log)
end
-----------------------------------------------------------------------------------------Host-----------------------------------------------------------------------------------------
function Host.addListener(key, listener)
    local listenerKey = tostring(listener)
    Host.mListeners = Host.mListeners or {}
    Host.mListeners[key] = Host.mListeners[key] or {}
    Host.mListeners[key][listenerKey] = listener
end

function Host.removeListener(key, listener)
    local listenerKey = tostring(listener)
    Host.mListeners[key][listenerKey] = nil
end

function Host.receive(parameter)
    if Host.mListeners then
        local listeners = Host.mListeners[parameter.mKey]
        if listeners then
            for _, listener in pairs(listeners) do
                listener:receive(parameter)
            end
        end
    end
end

function Host.sendTo(clientPlayerID, parameter)
    local new_parameter = clone(parameter)
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    SendTo(clientPlayerID, new_parameter)
end

function Host.broadcast(parameter, exceptSelf)
    local new_parameter = clone(parameter)
    new_parameter.mFrom = GetPlayerId()
    SendTo(nil, new_parameter)
    if not exceptSelf then
        receiveMsg(parameter)
    end
end

-----------------------------------------------------------------------------------------Client-----------------------------------------------------------------------------------------
function Client.addListener(key, listener)
    local listenerKey = tostring(listener)
    Client.mListeners = Client.mListeners or {}
    Client.mListeners[key] = Client.mListeners[key] or {}
    Client.mListeners[key][listenerKey] = listener
end

function Client.removeListener(key, listener)
    local listenerKey = tostring(listener)
    Client.mListeners[key][listenerKey] = nil
end

function Client.receive(parameter)
    if Client.mListeners then
        if parameter.mKey then
            local listeners = Client.mListeners[parameter.mKey]
            if listeners then
                for _, listener in pairs(listeners) do
                    listener:receive(parameter)
                end
            end
        elseif parameter.mMessage == "clear" then
            clear()
        end
    end
end

function Client.sendToHost(key, parameter)
    local new_parameter = clone(parameter)
    new_parameter.mKey = key
    new_parameter.mTo = "Host"
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    SendTo("host", new_parameter)
end

function Client.sendToClient(playerID, key, parameter)
    local new_parameter = clone(parameter)
    new_parameter.mKey = key
    new_parameter.mTo = playerID
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    if playerID == GetPlayerId() then
        Client.receive(new_parameter)
    else
        SendTo("host", new_parameter)
    end
end

function Client.broadcast(key, parameter)
    local new_parameter = clone(parameter)
    new_parameter.mKey = key
    new_parameter.mTo = "All"
    if not new_parameter.mFrom then
        new_parameter.mFrom = GetPlayerId()
    end
    SendTo("host", new_parameter)
end
-----------------------------------------------------------------------------------------GlobalProperty-----------------------------------------------------------------------------------------
function GlobalProperty.initialize()
    GlobalProperty.mProperties = {}
    GlobalProperty.mCommandList = {}
    Host.addListener("GlobalProperty", GlobalProperty)
    Client.addListener("GlobalProperty", GlobalProperty)
end

function GlobalProperty.update()
    for index, command in pairs(GlobalProperty.mCommandList) do
        local ret = command:frameMove()
        if ret then
            table.remove(GlobalProperty.mCommandList, index)
            break
        end
    end
end

function GlobalProperty.clear()
end

function GlobalProperty.lockWrite(key, callback)
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    assert(GlobalProperty.mResponseCallback["LockWrite"][key] == nil, "GlobalProperty.lockWrite:key:" .. key)
    GlobalProperty.mResponseCallback["LockWrite"][key] = {callback}
    Client.sendToHost("GlobalProperty", {mMessage = "LockWrite", mParameter = {mKey = key}})
end
--must be locked
function GlobalProperty.write(key, value, callback)
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    assert(GlobalProperty.mResponseCallback["Write"][key] == nil, "GlobalProperty.Write:key:" .. key)
    GlobalProperty.mResponseCallback["Write"][key] = {callback}
    Client.sendToHost("GlobalProperty", {mMessage = "Write", mParameter = {mKey = key, mValue = value}})
end

function GlobalProperty.unlockWrite(key)
    Client.sendToHost("GlobalProperty", {mMessage = "UnlockWrite", mParameter = {mKey = key}})
end

function GlobalProperty.lockRead(key, callback)
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    assert(GlobalProperty.mResponseCallback["LockRead"][key] == nil, "GlobalProperty.lockRead:key:" .. key)
    GlobalProperty.mResponseCallback["LockRead"][key] = {callback}
    Client.sendToHost("GlobalProperty", {mMessage = "LockRead", mParameter = {mKey = key}})
end

function GlobalProperty.unlockRead(key)
    Client.sendToHost("GlobalProperty", {mMessage = "UnlockRead", mParameter = {mKey = key}})
end

function GlobalProperty.read(key, callback)
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    GlobalProperty.mResponseCallback["Read"][key] = GlobalProperty.mResponseCallback["Read"][key] or {}
    local callbacks = GlobalProperty.mResponseCallback["Read"][key]
    callbacks[#callbacks + 1] = callback
    Client.sendToHost("GlobalProperty", {mMessage = "Read", mParameter = {mKey = key}})
end

function GlobalProperty.lockAndWrite(key, value, callback)
    GlobalProperty.mResponseCallback =
        GlobalProperty.mResponseCallback or {LockWrite = {}, LockRead = {}, Write = {}, Read = {}, LockAndWrite = {}}
    assert(GlobalProperty.mResponseCallback["LockAndWrite"][key] == nil, "GlobalProperty.LockAndWrite:key:" .. key)
    GlobalProperty.mResponseCallback["LockAndWrite"][key] = {callback}
    Client.sendToHost("GlobalProperty", {mMessage = "LockAndWrite", mParameter = {mKey = key, mValue = value}})
end

function GlobalProperty.addListener(key, listenerKey, callback, parameter)
    listenerKey = tostring(listenerKey)
    GlobalProperty.mListeners = GlobalProperty.mListeners or {}
    GlobalProperty.mListeners[key] = GlobalProperty.mListeners[key] or {}
    GlobalProperty.mListeners[key][listenerKey] = {mCallback = callback, mParameter = parameter}

    GlobalProperty.read(
        key,
        function(value)
            if value then
                callback(parameter, value, value)
            end
        end
    )
end

function GlobalProperty.removeListener(key, listenerKey)
    listenerKey = tostring(listenerKey)
    if GlobalProperty.mListeners and GlobalProperty.mListeners[key] then
        GlobalProperty.mListeners[key][listenerKey] = nil
    end
end

function GlobalProperty.notify(key, value, preValue)
    if GlobalProperty.mListeners and GlobalProperty.mListeners[key] then
        for listener_key, callback in pairs(GlobalProperty.mListeners[key]) do
            callback.mCallback(callback.mParameter, value, preValue)
        end
    end
end

function GlobalProperty:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if
            GlobalProperty.mResponseCallback and GlobalProperty.mResponseCallback[message] and
                GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey]
         then
            local callbacks = GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey]
            GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey] = nil
            for _, callback in pairs(callbacks) do
                callback(parameter.mParameter.mValue)
            end
        end
    else
        GlobalProperty.mProperties[parameter.mParameter.mKey] =
            GlobalProperty.mProperties[parameter.mParameter.mKey] or {}
        if parameter.mMessage == "LockWrite" then -- host
            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                GlobalProperty._lockWrite(parameter.mParameter.mKey, parameter._from)
                Host.sendTo(
                    parameter._from,
                    {
                        mMessage = "LockWrite_Response",
                        mKey = "GlobalProperty",
                        mParameter = {
                            mKey = parameter.mParameter.mKey,
                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                        }
                    }
                )
            else
                GlobalProperty.mCommandList[#GlobalProperty.mCommandList + 1] =
                    new(
                    Command_Callback,
                    {
                        mDebug = GetEntityById(parameter._from).nickname .. ":LockWrite:" .. parameter.mParameter.mKey,
                        mExecutingCallback = function(command)
                            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                                GlobalProperty._lockWrite(parameter.mParameter.mKey, parameter._from)
                                Host.sendTo(
                                    parameter._from,
                                    {
                                        mMessage = "LockWrite_Response",
                                        mKey = "GlobalProperty",
                                        mParameter = {
                                            mKey = parameter.mParameter.mKey,
                                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                                        }
                                    }
                                )
                                command.mState = Command.EState.Finish
                            end
                        end,
                        mTimeOutProcess = function(command)
                            echo("devilwalk", "GlobalProperty write lock time out:" .. command.mDebug)
                            echo("devilwalk", GlobalProperty.mProperties[parameter.mParameter.mKey])
                            if
                                GlobalProperty.mProperties[parameter.mParameter.mKey] and
                                    GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked
                             then
                                echo(
                                    "devilwalk",
                                    GetEntityById(GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked).nickname ..
                                        " locked"
                                )
                            end
                        end
                    }
                )
            end
        elseif parameter.mMessage == "UnlockWrite" then -- host
            GlobalProperty._unlockWrite(parameter.mParameter.mKey, parameter._from)
        elseif parameter.mMessage == "Write" then -- host
            GlobalProperty._write(parameter.mParameter.mKey, parameter.mParameter.mValue, parameter._from)
            Host.sendTo(
                parameter._from,
                {
                    mMessage = "Write_Response",
                    mKey = "GlobalProperty",
                    mParameter = {
                        mKey = parameter.mParameter.mKey,
                        mValue = parameter.mParameter.mValue
                    }
                }
            )
        elseif parameter.mMessage == "LockRead" then -- host
            if GlobalProperty._canRead(parameter.mParameter.mKey) then
                GlobalProperty._lockRead(parameter.mParameter.mKey, parameter._from)
                Host.sendTo(
                    parameter._from,
                    {
                        mMessage = "LockRead_Response",
                        mKey = "GlobalProperty",
                        mParameter = {
                            mKey = parameter.mParameter.mKey,
                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                        }
                    }
                )
            else
                GlobalProperty.mCommandList[#GlobalProperty.mCommandList + 1] =
                    new(
                    Command_Callback,
                    {
                        mDebug = tostring(parameter._from) .. ":LockRead:" .. parameter.mParameter.mKey,
                        mExecutingCallback = function(command)
                            if GlobalProperty._canRead(parameter.mParameter.mKey) then
                                GlobalProperty._lockRead(parameter.mParameter.mKey, parameter._from)
                                Host.sendTo(
                                    parameter._from,
                                    {
                                        mMessage = "LockRead_Response",
                                        mKey = "GlobalProperty",
                                        mParameter = {
                                            mKey = parameter.mParameter.mKey,
                                            mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                                        }
                                    }
                                )
                                command.mState = Command.EState.Finish
                            end
                        end,
                        mTimeOutProcess = function(command)
                            echo("devilwalk", "GlobalProperty read lock time out:" .. command.mDebug)
                            echo("devilwalk", GlobalProperty.mProperties[parameter.mParameter.mKey])
                        end
                    }
                )
            end
        elseif parameter.mMessage == "UnlockRead" then -- host
            GlobalProperty._unlockRead(parameter.mParameter.mKey, parameter._from)
        elseif parameter.mMessage == "Read" then -- host
            Host.sendTo(
                parameter._from,
                {
                    mMessage = "Read_Response",
                    mKey = "GlobalProperty",
                    mParameter = {
                        mKey = parameter.mParameter.mKey,
                        mValue = GlobalProperty.mProperties[parameter.mParameter.mKey].mValue
                    }
                }
            )
        elseif parameter.mMessage == "LockAndWrite" then -- host
            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                GlobalProperty._lockWrite(parameter.mParameter.mKey, parameter._from)
                GlobalProperty._write(parameter.mParameter.mKey, parameter.mParameter.mValue, parameter._from)
                Host.sendTo(
                    parameter._from,
                    {
                        mMessage = "LockAndWrite_Response",
                        mKey = "GlobalProperty",
                        mParameter = {
                            mKey = parameter.mParameter.mKey,
                            mValue = parameter.mParameter.mValue
                        }
                    }
                )
            else
                GlobalProperty.mCommandList[#GlobalProperty.mCommandList + 1] =
                    new(
                    Command_Callback,
                    {
                        mDebug = GetEntityById(parameter._from).nickname ..
                            ":LockAndWrite:" .. parameter.mParameter.mKey,
                        mExecutingCallback = function(command)
                            if GlobalProperty._canWrite(parameter.mParameter.mKey) then
                                GlobalProperty._lockWrite(parameter.mParameter.mKey, parameter._from)
                                GlobalProperty._write(
                                    parameter.mParameter.mKey,
                                    parameter.mParameter.mValue,
                                    parameter._from
                                )
                                Host.sendTo(
                                    parameter._from,
                                    {
                                        mMessage = "LockAndWrite_Response",
                                        mKey = "GlobalProperty",
                                        mParameter = {
                                            mKey = parameter.mParameter.mKey,
                                            mValue = parameter.mParameter.mValue
                                        }
                                    }
                                )
                                command.mState = Command.EState.Finish
                            end
                        end,
                        mTimeOutProcess = function(command)
                            echo("devilwalk", "GlobalProperty LockAndWrite lock time out:" .. command.mDebug)
                            echo("devilwalk", GlobalProperty.mProperties[parameter.mParameter.mKey])
                            if
                                GlobalProperty.mProperties[parameter.mParameter.mKey] and
                                    GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked
                             then
                                echo(
                                    "devilwalk",
                                    GetEntityById(GlobalProperty.mProperties[parameter.mParameter.mKey].mWriteLocked).nickname ..
                                        " locked"
                                )
                            end
                        end
                    }
                )
            end
        elseif parameter.mMessage == "PropertyChange" then -- client
            GlobalProperty.notify(
                parameter.mParameter.mKey,
                parameter.mParameter.mValue,
                parameter.mParameter.mPreValue
            )
        end
    end
end

function GlobalProperty._lockWrite(key, playerID)
    assert(
        GlobalProperty.mProperties[key].mWriteLocked == nil,
        "GlobalProperty._lockWrite:GlobalProperty.mProperties[key].mWriteLocked ~= nil"
    )
    assert(
        not GlobalProperty.mProperties[key].mReadLocked or #GlobalProperty.mProperties[key].mReadLocked == 0,
        "GlobalProperty._lockWrite:#GlobalProperty.mProperties[key].mReadLocked ~= 0 or GlobalProperty.mProperties[key].mReadLocked ~= nil"
    )
    -- echo("devilwalk", "GlobalProperty._lockWrite:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    GlobalProperty.mProperties[key].mWriteLocked = playerID
    -- GlobalProperty._lockRead(key, playerID)
end

function GlobalProperty._unlockWrite(key, playerID)
    assert(
        GlobalProperty.mProperties[key].mWriteLocked == playerID,
        "GlobalProperty._unlockWrite:GlobalProperty.mProperties[key].mWriteLocked ~= playerID"
    )
    -- echo("devilwalk", "GlobalProperty._unlockWrite:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    GlobalProperty.mProperties[key].mWriteLocked = nil
    -- GlobalProperty._unlockRead(key, playerID)
end

function GlobalProperty._write(key, value, playerID)
    assert(
        GlobalProperty.mProperties[key].mWriteLocked == playerID,
        "GlobalProperty._write:GlobalProperty.mProperties[key].mWriteLocked ~= playerID"
    )
    -- echo("devilwalk", "GlobalProperty._write:key,playerID,value:" .. tostring(key) .. "," .. tostring(playerID))
    -- echo("devilwalk", value)
    local pre_value = GlobalProperty.mProperties[key].mValue
    GlobalProperty.mProperties[key].mValue = value
    GlobalProperty._unlockWrite(key, playerID)
    Host.broadcast(
        {
            mMessage = "PropertyChange",
            mKey = "GlobalProperty",
            mParameter = {mKey = key, mValue = value, mPreValue = pre_value, mPlayerID = playerID}
        }
    )
end

function GlobalProperty._lockRead(key, playerID)
    --echo("devilwalk", "GlobalProperty._lockRead:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    GlobalProperty.mProperties[key].mReadLocked = GlobalProperty.mProperties[key].mReadLocked or {}
    GlobalProperty.mProperties[key].mReadLocked[#GlobalProperty.mProperties[key].mReadLocked + 1] = playerID
end

function GlobalProperty._unlockRead(key, playerID)
    --echo("devilwalk", "GlobalProperty._unlockRead:key,playerID:" .. tostring(key) .. "," .. tostring(playerID))
    for k, lock in pairs(GlobalProperty.mProperties[key].mReadLocked) do
        if lock == playerID then
            table.remove(GlobalProperty.mProperties[key].mReadLocked, k)
            break
        end
    end
end

function GlobalProperty._canWrite(key)
    -- echo("devilwalk", "GlobalProperty._canWrite:key:" .. tostring(key))
    -- echo("devilwalk", GlobalProperty.mProperties)
    return not GlobalProperty.mProperties[key].mWriteLocked and
        (not GlobalProperty.mProperties[key].mReadLocked or #GlobalProperty.mProperties[key].mReadLocked == 0)
end

function GlobalProperty._canRead(key)
    -- return GlobalProperty._canWrite(key)
    return not GlobalProperty.mProperties[key].mWriteLocked
end
-----------------------------------------------------------------------------------------Global Operation-----------------------------------------------------------------------------------------
function GlobalOperation.initialize()
    Host.addListener("GlobalOperation", GlobalOperation)
    Client.addListener("GlobalOperation", GlobalOperation)
end

function GlobalOperation.sendToHost(message, parameter)
    Client.sendToHost("GlobalOperation", {mMessage = message, mParameter = parameter})
end

function GlobalOperation.setEntityBlockPos(id, x, y, z)
    GlobalOperation.sendToHost("SetEntityBlockPos", {mID = id, mX = x, mY = y, mZ = z})
end

function GlobalOperation:receive(parameter)
    local is_responese, _ = string.find(parameter.mMessage, "_Response")
    if is_responese then
        local message = string.sub(parameter.mMessage, 1, is_responese - 1)
        if
            GlobalProperty.mResponseCallback and GlobalProperty.mResponseCallback[message] and
                GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey]
         then
            local callbacks = GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey]
            GlobalProperty.mResponseCallback[message][parameter.mParameter.mKey] = nil
            for _, callback in pairs(callbacks) do
                callback(parameter.mParameter.mValue)
            end
        end
    else
        if parameter.mMessage == "SetEntityBlockPos" then -- host
            SetEntityBlockPos(
                parameter.mParameter.mID,
                parameter.mParameter.mX,
                parameter.mParameter.mY,
                parameter.mParameter.mZ
            )
        end
    end
end
-----------------------------------------------------------------------------------------Input Manager-----------------------------------------------------------------------------------------
InputManager.mListeners = {}
function InputManager.addListener(key, callback, parameter)
    key = tostring(key)
    InputManager.mListeners[key] = {mCallback = callback, mParameter = parameter}
end

function InputManager.removeListener(key)
    key = tostring(key)
    InputManager.mListeners[key] = nil
end

function InputManager.notify(event)
    for _, listener in pairs(InputManager.mListeners) do
        listener.mCallback(listener.mParameter, event)
    end
end
-----------------------------------------------------------------------------------------App-----------------------------------------------------------------------------------------
local App = {}
function App.start()
    App.mRunning = true
    GlobalProperty.initialize()
    GlobalOperation.initialize()
    EntitySyncerManager.singleton()
end

function App.update()
    GlobalProperty.update()
    EntitySyncerManager.singleton():update()
    Game.singleton():update()
end

function App.stop()
    delete(Game.singleton())
    App.mRunning = false
    MiniGameUISystem.shutdown()
end

function App.receiveMsg(parameter)
    if parameter.mKey ~= "GlobalProperty" then
        echo("devilwalk", "App.receiveMsg:parameter:")
        echo("devilwalk", parameter)
    end
    if parameter.mTo then
        if parameter.mTo == "Host" then
            Host.receive(parameter)
        elseif parameter.mTo == "All" then
            parameter.mTo = nil
            Host.broadcast(parameter)
        else
            local to = parameter.mTo
            parameter.mTo = nil
            Host.sendTo(to, parameter)
        end
    else
        Client.receive(parameter)
    end
end

function App.handleInput(event)
    InputManager.notify(event)
end
-----------------------------------------------------------------------------------------main-----------------------------------------------------------------------------------------
function main()
    App.start()
    SetPermission("triggerBlock", false)
    SetPermission("editEntity", false)
end

function update()
    if App.mRunning then
        App.update()
    end
end

function clear()
    App.stop()

    Host.broadcast({mMessage = "clear"}, true)
    SetPermission("triggerBlock", true)
    SetPermission("editEntity", true)
end

function handleInput(event)
    if App.mRunning then
        App.handleInput(event)
    end
end

function receiveMsg(parameter)
    if App.mRunning then
        App.receiveMsg(parameter)
    end
end
