-- =================================================================
-- KissoHub — Anime Monster Collector (v2 — defensive)
-- =================================================================
return function(KissoCore)
    -- =============================================================
    -- SANITY CHECK
    -- =============================================================
    if type(KissoCore) ~= "table" then
        warn("[AMC] KissoCore not passed in — running standalone?")
        return
    end
    if not KissoCore.Rayfield then
        warn("[AMC] Rayfield missing from KissoCore.")
        return
    end

    local Rayfield          = KissoCore.Rayfield
    local ASSET_ICON        = KissoCore.ASSET_ICON or "rbxassetid://89387722763691"

    local Players     = game:GetService("Players")
    local Workspace   = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    -- =============================================================
    -- SAFE UI HELPER — every UI creation runs through this
    -- =============================================================
    local function TryUI(label, fn)
        local ok, result = pcall(fn)
        if not ok then
            warn("[AMC] Failed: " .. label .. " → " .. tostring(result))
            return nil
        end
        return result
    end

    -- =============================================================
    -- WINDOW + TAGS
    -- =============================================================
    local Window = TryUI("BuildWindow", function()
        return KissoCore.BuildWindow("Anime Monster Collector", "AMCPrefs")
    end)
    if not Window then
        warn("[AMC] Window creation failed — aborting.")
        return
    end

    local StatusTag, StateTag, SetActivity = TryUI("BuildTags", function()
        return KissoCore.BuildTags(Window)
    end) or (nil, nil, function() end)

    local SafeNotify = function(t, c, d) pcall(function() KissoCore.SafeNotify(Window, t, c, d) end) end
    local QuickToast = function(t, s) pcall(function() KissoCore.QuickToast(Window, t, s) end) end

    -- =============================================================
    -- STATE VARIABLES
    -- =============================================================
    local SpiritMapping = {}
    local SelectedSpiritInstance = nil
    local SelectedSortMethod = "Level (High to Low)"
    local AutoLockSpiritEnabled = false

    local ChestMapping = {}
    local SelectedChestInstance = nil
    local AutoOpenChestsEnabled = false

    local WalkSpeedValue = 16
    local InfZoomEnabled = false
    local AntiVoidEnabled = false

    -- =============================================================
    -- HELPERS: SPIRITS
    -- =============================================================
    local function getSpiritName(spirit)
        local obj = spirit:FindFirstChild("SpiritName", true)
        if obj then
            if obj:IsA("TextLabel") or obj:IsA("TextBox") then
                if obj.Text ~= "" then return obj.Text end
            elseif obj:IsA("ValueBase") then
                if tostring(obj.Value) ~= "" then return tostring(obj.Value) end
            end
        end
        return spirit.Name
    end

    local function getSpiritLevel(spirit)
        local obj = spirit:FindFirstChild("SpiritLevel", true)
        if obj then
            if obj:IsA("TextLabel") or obj:IsA("TextBox") then
                local n = tonumber(string.match(obj.Text, "%d+"))
                if n then return n end
                if obj.Text ~= "" then return obj.Text end
            elseif obj:IsA("ValueBase") then
                return tonumber(obj.Value) or obj.Value
            end
        end
        local attr = spirit:GetAttribute("Level") or spirit:GetAttribute("Lvl")
        if attr then return tonumber(attr) or attr end
        return 0
    end

    local function getSpiritMaxHP(spirit)
        local maxHp = spirit:GetAttribute("MaxHP") or spirit:GetAttribute("MaxHealth") or 0
        if maxHp == 0 then
            local hum = spirit:FindFirstChildOfClass("Humanoid") or spirit:FindFirstChildWhichIsA("Humanoid", true)
            if hum then maxHp = hum.MaxHealth end
        end
        if maxHp == 0 then
            local hpObj = spirit:FindFirstChild("MaxHP", true)
                or spirit:FindFirstChild("MaxHealth", true)
                or spirit:FindFirstChild("Health", true)
            if hpObj and hpObj:IsA("ValueBase") then maxHp = hpObj.Value end
        end
        return tonumber(maxHp) or 0
    end

    -- =============================================================
    -- HELPERS: CHESTS
    -- =============================================================
    local function isChestOnCooldown(chest)
        local statusUI = chest:FindFirstChild("ClientComponent_ChestRewardStatus", true)
        if statusUI then
            local cd = statusUI:FindFirstChild("CooldownGui", true) or statusUI:FindFirstChild("Cooldown", true)
            if cd then
                if cd:IsA("GuiObject") then return cd.Visible end
                if cd:IsA("LayerCollector") then return cd.Enabled end
                return true
            end
        end
        local cdDirect = chest:FindFirstChild("CooldownGui", true)
        if cdDirect then
            if cdDirect:IsA("GuiObject") then return cdDirect.Visible end
            if cdDirect:IsA("LayerCollector") then return cdDirect.Enabled end
            return true
        end
        return false
    end

    local function refreshChestList(ChestDropdown)
        local activeLevels = Workspace:FindFirstChild("ActiveLevels")
        local chestData = {}
        ChestMapping = {}

        if activeLevels then
            local excludedKeywords = {"button","frame","ui","gui","icon","prompt","label","text","template","holder","close","open"}
            local addedInstances = {}

            for _, desc in ipairs(activeLevels:GetDescendants()) do
                if desc:IsA("Model") or desc:IsA("BasePart") then
                    local lower = string.lower(desc.Name)
                    if string.find(lower, "chest") then
                        local excluded = false
                        for _, kw in ipairs(excludedKeywords) do
                            if string.find(lower, kw) then excluded = true; break end
                        end

                        local parent = desc.Parent
                        while parent and parent ~= activeLevels do
                            if addedInstances[parent] then excluded = true; break end
                            parent = parent.Parent
                        end

                        if not excluded and isChestOnCooldown(desc) then excluded = true end

                        if not excluded then
                            local area = "Unknown Area"
                            local p = desc.Parent
                            while p and p ~= activeLevels do
                                if string.find(p.Name, "Level") or string.find(p.Name, "Area") then
                                    area = p.Name
                                    break
                                end
                                p = p.Parent
                            end

                            addedInstances[desc] = true
                            table.insert(chestData, { instance = desc, name = desc.Name, area = area })
                        end
                    end
                end
            end
        end

        local opts = {}
        for i, data in ipairs(chestData) do
            local s = string.format("[%s] %s (#%d)", data.area, data.name, i)
            table.insert(opts, s)
            ChestMapping[s] = data.instance
        end
        if #opts == 0 then
            table.insert(opts, "No Ready Chests Found")
            SelectedChestInstance = nil
        end
        if ChestDropdown then pcall(function() ChestDropdown:Refresh(opts) end) end
        return chestData
    end

    -- =============================================================
    -- HOME TAB
    -- =============================================================
    local HomeTab, HomeStats = TryUI("BuildHomeTab", function()
        return KissoCore.BuildHomeTab(Window, "Anime Monster Collector")
    end) or (nil, {})

    -- =============================================================
    -- SPIRITS TAB
    -- =============================================================
    local SpiritsTab = TryUI("SpiritsTab", function()
        return Window:CreateTab({ name = "👻 Spirits", icon = ASSET_ICON })
    end)

    local SpiritDropdown

    if SpiritsTab then
        TryUI("SpiritsSection", function()
            SpiritsTab:CreateSection({ name = "🎯 Target Selection" })
        end)

        local function refreshSpiritList()
            local folder = Workspace:FindFirstChild("ActiveSpirits")
            local spiritData = {}
            SpiritMapping = {}

            if folder then
                for _, spirit in ipairs(folder:GetChildren()) do
                    pcall(function()
                        table.insert(spiritData, {
                            instance = spirit,
                            name = getSpiritName(spirit),
                            level = getSpiritLevel(spirit),
                            maxHp = getSpiritMaxHP(spirit),
                            rawId = spirit.Name,
                        })
                    end)
                end
            end

            if SelectedSortMethod == "Level (High to Low)" then
                table.sort(spiritData, function(a, b) return (tonumber(a.level) or 0) > (tonumber(b.level) or 0) end)
            elseif SelectedSortMethod == "Max HP (High to Low)" then
                table.sort(spiritData, function(a, b) return a.maxHp > b.maxHp end)
            elseif SelectedSortMethod == "Name (A-Z)" then
                table.sort(spiritData, function(a, b) return a.name < b.name end)
            end

            local opts = {}
            for _, data in ipairs(spiritData) do
                local s = string.format("[%s] Lvl: %s | HP: %d (%s)", data.name, tostring(data.level), data.maxHp, data.rawId)
                table.insert(opts, s)
                SpiritMapping[s] = data.instance
            end

            if #spiritData > 0 then
                if not SelectedSpiritInstance or not SelectedSpiritInstance.Parent then
                    SelectedSpiritInstance = spiritData[1].instance
                end
            else
                table.insert(opts, "No Spirits Found")
                SelectedSpiritInstance = nil
            end

            if SpiritDropdown then pcall(function() SpiritDropdown:Refresh(opts) end) end
            return spiritData
        end

        TryUI("SortDropdown", function()
            SpiritsTab:CreateDropdown({
                name = "Sort Method",
                flag = "SortDropdown",
                options = {"Level (High to Low)", "Max HP (High to Low)", "Name (A-Z)"},
                value = {"Level (High to Low)"},
                multiSelect = false,
                callback = function(Option)
                    local choice = typeof(Option) == "table" and Option[1] or Option
                    SelectedSortMethod = choice
                    refreshSpiritList()
                end,
            })
        end)

        SpiritDropdown = TryUI("SpiritDropdown", function()
            return SpiritsTab:CreateDropdown({
                name = "Select Spirit",
                flag = "SpiritSelectDropdown",
                options = {"Click Refresh Below"},
                value = {"Click Refresh Below"},
                multiSelect = false,
                callback = function(Option)
                    local choice = typeof(Option) == "table" and Option[1] or Option
                    SelectedSpiritInstance = SpiritMapping[choice]
                end,
            })
        end)

        TryUI("RefreshSpiritBtn", function()
            SpiritsTab:CreateButton({
                name = "🔄 Refresh Spirit List",
                callback = function()
                    local list = refreshSpiritList()
                    SafeNotify("Spirits Refreshed", "Found " .. tostring(#list) .. " spirit(s).", 2)
                end,
            })
        end)

        TryUI("TPSpiritBtn", function()
            SpiritsTab:CreateButton({
                name = "📍 Teleport to Selected Spirit",
                callback = function()
                    if not SelectedSpiritInstance or not SelectedSpiritInstance.Parent then
                        SafeNotify("Teleport Failed", "Selected spirit no longer exists. Please refresh!", 3)
                        return
                    end
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local cf
                    if SelectedSpiritInstance:IsA("Model") then
                        local part = SelectedSpiritInstance.PrimaryPart or SelectedSpiritInstance:FindFirstChildWhichIsA("BasePart", true)
                        if part then cf = part.CFrame end
                    elseif SelectedSpiritInstance:IsA("BasePart") then
                        cf = SelectedSpiritInstance.CFrame
                    end
                    if cf then
                        hrp.CFrame = cf * CFrame.new(0, 3, 0)
                        QuickToast("Teleported", "Moved to selected spirit")
                    end
                end,
            })
        end)

        TryUI("SpiritsDivider", function() SpiritsTab:CreateDivider({ text = "automation" }) end)
        TryUI("AutoSection", function() SpiritsTab:CreateSection({ name = "🔄 Auto Tracking" }) end)

        TryUI("AutoLockToggle", function()
            SpiritsTab:CreateToggle({
                name = "Auto Lock & TP to Spirit",
                flag = "AutoLockSpiritToggle",
                value = false,
                callback = function(Value)
                    AutoLockSpiritEnabled = Value
                    if not Value then return end
                    if SetActivity then SetActivity(true, "TRACKING") end
                    QuickToast("Auto Lock", "Started tracking")
                    task.spawn(function()
                        while AutoLockSpiritEnabled do
                            if not SelectedSpiritInstance or not SelectedSpiritInstance.Parent then
                                refreshSpiritList()
                            end
                            local target = SelectedSpiritInstance
                            if target and target.Parent then
                                local char = LocalPlayer.Character
                                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    local cf
                                    if target:IsA("Model") then
                                        local part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
                                        if part then cf = part.CFrame end
                                    elseif target:IsA("BasePart") then
                                        cf = target.CFrame
                                    end
                                    if cf then hrp.CFrame = cf * CFrame.new(0, 3, 0) end
                                end
                            end
                            task.wait(0.05)
                        end
                    end)
                end,
            })
        end)
    end

    -- =============================================================
    -- CHESTS TAB
    -- =============================================================
    local ChestsTab = TryUI("ChestsTab", function()
        return Window:CreateTab({ name = "📦 Chests", icon = ASSET_ICON })
    end)

    local ChestDropdown

    if ChestsTab then
        TryUI("ChestsSection", function()
            ChestsTab:CreateSection({ name = "🎯 Target Selection" })
        end)

        ChestDropdown = TryUI("ChestDropdown", function()
            return ChestsTab:CreateDropdown({
                name = "Select Chest",
                flag = "ChestSelectDropdown",
                options = {"Click Refresh Below"},
                value = {"Click Refresh Below"},
                multiSelect = false,
                callback = function(Option)
                    local choice = typeof(Option) == "table" and Option[1] or Option
                    SelectedChestInstance = ChestMapping[choice]
                end,
            })
        end)

        TryUI("RefreshChestBtn", function()
            ChestsTab:CreateButton({
                name = "🔄 Refresh Chest List",
                callback = function()
                    local data = refreshChestList(ChestDropdown)
                    SafeNotify("Chests Refreshed", "Found " .. tostring(#data) .. " ready chest(s).", 2)
                end,
            })
        end)

        TryUI("TPChestBtn", function()
            ChestsTab:CreateButton({
                name = "📍 Teleport to Selected Chest",
                callback = function()
                    if not SelectedChestInstance or not SelectedChestInstance.Parent then
                        SafeNotify("Teleport Failed", "Selected chest no longer exists!", 3)
                        return
                    end
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local cf
                    if SelectedChestInstance:IsA("Model") then
                        local part = SelectedChestInstance.PrimaryPart or SelectedChestInstance:FindFirstChildWhichIsA("BasePart", true)
                        if part then cf = part.CFrame end
                    elseif SelectedChestInstance:IsA("BasePart") then
                        cf = SelectedChestInstance.CFrame
                    end
                    if cf then
                        hrp.CFrame = cf * CFrame.new(0, 3, 0)
                        QuickToast("Teleported", "Moved to selected chest")
                    end
                end,
            })
        end)

        TryUI("ChestsDivider", function() ChestsTab:CreateDivider({ text = "automation" }) end)
        TryUI("AutoChestSection", function() ChestsTab:CreateSection({ name = "🔄 Auto Collect" }) end)

        TryUI("AutoOpenToggle", function()
            ChestsTab:CreateToggle({
                name = "Auto Open All Chests",
                flag = "AutoOpenChestsToggle",
                value = false,
                callback = function(Value)
                    AutoOpenChestsEnabled = Value
                    if not Value then return end
                    if SetActivity then SetActivity(true, "FARMING") end
                    QuickToast("Auto Open", "Started opening chests")
                    task.spawn(function()
                        while AutoOpenChestsEnabled do
                            local available = refreshChestList(ChestDropdown)
                            if #available == 0 then
                                task.wait(3)
                            else
                                for _, chestData in ipairs(available) do
                                    if not AutoOpenChestsEnabled then break end
                                    local chestObj = chestData.instance
                                    if chestObj and chestObj.Parent and not isChestOnCooldown(chestObj) then
                                        local char = LocalPlayer.Character
                                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                                        if hrp then
                                            local cf
                                            if chestObj:IsA("Model") then
                                                local part = chestObj.PrimaryPart or chestObj:FindFirstChildWhichIsA("BasePart", true)
                                                if part then cf = part.CFrame end
                                            elseif chestObj:IsA("BasePart") then
                                                cf = chestObj.CFrame
                                            end
                                            if cf then
                                                hrp.CFrame = cf * CFrame.new(0, 3, 0)
                                                task.wait(0.3)
                                                local prompt = chestObj:FindFirstChildWhichIsA("ProximityPrompt", true)
                                                if prompt and fireproximityprompt then
                                                    pcall(function() fireproximityprompt(prompt) end)
                                                end
                                                task.wait(0.8)
                                            end
                                        end
                                    end
                                end
                            end
                            task.wait(1)
                        end
                    end)
                end,
            })
        end)
    end

    -- =============================================================
    -- MISC TAB
    -- =============================================================
    local MiscTab = TryUI("MiscTab", function()
        return Window:CreateTab({ name = "🛠️ Misc", icon = ASSET_ICON })
    end)

    if MiscTab then
        TryUI("MiscMovementSection", function() MiscTab:CreateSection({ name = "🚀 Movement" }) end)

        TryUI("WalkSpeedSlider", function()
            MiscTab:CreateSlider({
                name = "Walk Speed",
                flag = "WalkSpeedSlider",
                range = {16, 300},
                increment = 1,
                value = 16,
                suffix = " Speed",
                callback = function(Value)
                    WalkSpeedValue = Value
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = Value end
                end,
            })
        end)

        -- Walk speed keeper
        task.spawn(function()
            while true do
                task.wait(0.1)
                if WalkSpeedValue ~= 16 then
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.WalkSpeed ~= WalkSpeedValue then
                        hum.WalkSpeed = WalkSpeedValue
                    end
                end
            end
        end)

        TryUI("CamDivider", function() MiscTab:CreateDivider({ text = "camera" }) end)
        TryUI("CamSection", function() MiscTab:CreateSection({ name = "🎥 Camera" }) end)

        TryUI("InfZoomToggle", function()
            MiscTab:CreateToggle({
                name = "Infinite Zoom Out",
                flag = "InfZoomToggle",
                value = false,
                callback = function(Value)
                    InfZoomEnabled = Value
                    LocalPlayer.CameraMaxZoomDistance = Value and 100000 or 128
                end,
            })
        end)

        task.spawn(function()
            while true do
                task.wait(0.5)
                if InfZoomEnabled and LocalPlayer.CameraMaxZoomDistance ~= 100000 then
                    LocalPlayer.CameraMaxZoomDistance = 100000
                end
            end
        end)

        TryUI("SafetyDivider", function() MiscTab:CreateDivider({ text = "safety" }) end)
        TryUI("SafetySection", function() MiscTab:CreateSection({ name = "🛡️ Protection" }) end)

        TryUI("AntiVoidToggle", function()
            MiscTab:CreateToggle({
                name = "Anti Fall Void",
                flag = "AntiVoidToggle",
                value = false,
                callback = function(Value)
                    AntiVoidEnabled = Value
                    if not Value then return end
                    QuickToast("Anti-Void", "Enabled")
                    task.spawn(function()
                        while AntiVoidEnabled do
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local voidHeight = Workspace.FallenPartsDestroyHeight + 50
                                if hrp.Position.Y < voidHeight or hrp.Position.Y < -200 then
                                    hrp.AssemblyLinearVelocity = Vector3.zero
                                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 300, 0)
                                    SafeNotify("Anti-Void Triggered", "Prevented falling into the void!", 2)
                                end
                            end
                        end
                        task.wait(0.3)
                    end)
                end,
            })
        end)
    end

    -- =============================================================
    -- LIVE REFRESH
    -- =============================================================
    if HomeStats then
        KissoCore.StartLiveRefresh(HomeStats, function()
            local count = 0
            if AutoLockSpiritEnabled then count += 1 end
            if AutoOpenChestsEnabled then count += 1 end
            if InfZoomEnabled then count += 1 end
            if AntiVoidEnabled then count += 1 end
            if WalkSpeedValue ~= 16 then count += 1 end

            if StateTag then
                if AutoLockSpiritEnabled then
                    StateTag:Set({ text = "TRACKING", color = Color3.fromRGB(0, 200, 255) })
                elseif AutoOpenChestsEnabled then
                    StateTag:Set({ text = "FARMING", color = Color3.fromRGB(0, 220, 130) })
                elseif count > 0 then
                    StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
                else
                    StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
                end
            end
            return count
        end)
    end
end
