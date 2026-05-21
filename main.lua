-- ============================================================
--  no_gangs — Désactivation des PNJ hostiles
--  Approche : scan 500ms + cache des peds traités
-- ============================================================

local GANG_GROUPS = {
    "AMBIENT_GANG_BALLAS", "AMBIENT_GANG_LOST", "AMBIENT_GANG_MARABUS",
    "AMBIENT_GANG_SALVA", "AMBIENT_GANG_VAGOS", "AMBIENT_GANG_MEXICAN",
    "AMBIENT_GANG_FAMILIES", "AMBIENT_GANG_CULT", "AMBIENT_GANG_HILLBILLY",
    "AMBIENT_GANG_WEICHENG", "AMBIENT_GANG_KOREAN", "AMBIENT_GANG_ARMENIAN",
    "AMBIENT_GANG_PROFESSIONALS",
}

local GANG_MODELS = {
    GetHashKey("g_m_y_ballaorig_01"), GetHashKey("g_m_y_ballaeast_01"), GetHashKey("g_m_y_ballasout_01"),
    GetHashKey("g_m_y_mexgang_01"), GetHashKey("g_m_y_mexgoon_01"), GetHashKey("g_m_y_mexgoon_02"), GetHashKey("g_m_y_mexgoon_03"),
    GetHashKey("g_m_y_famca_01"), GetHashKey("g_m_y_famdnf_01"), GetHashKey("g_m_y_famfor_01"),
    GetHashKey("g_m_y_lost_01"), GetHashKey("g_m_y_lost_02"), GetHashKey("g_m_y_lost_03"),
    GetHashKey("g_m_y_salvadoran_01"), GetHashKey("g_m_y_salvadoran_02"),
    GetHashKey("g_m_y_korean_01"), GetHashKey("g_m_y_korean_02"),
    GetHashKey("g_m_m_armboss_01"), GetHashKey("g_m_m_armgoon_01"),
    GetHashKey("g_m_y_hillbilly_01"), GetHashKey("g_m_y_hillbilly_02"),
}

local GANG_MODEL_SET = {}
for _, v in ipairs(GANG_MODELS) do
    GANG_MODEL_SET[v] = true
end

-- Cache des peds déjà neutralisés
local treatedPeds = {}

-- ── Relations neutres ─────────────────────────────────────────
local function SetAllNeutral()
    local playerGroup = GetHashKey("PLAYER")
    for _, group in ipairs(GANG_GROUPS) do
        local hash = GetHashKey(group)
        SetRelationshipBetweenGroups(3, hash, playerGroup)
        SetRelationshipBetweenGroups(3, playerGroup, hash)
        SetRelationshipBetweenGroups(3, hash, GetHashKey("CIVMALE"))
        SetRelationshipBetweenGroups(3, hash, GetHashKey("CIVFEMALE"))
        for _, other in ipairs(GANG_GROUPS) do
            if group ~= other then
                SetRelationshipBetweenGroups(3, hash, GetHashKey(other))
            end
        end
    end
end

-- ── Neutralise un ped ─────────────────────────────────────────
local function NeutralizeGangPed(ped)
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    RemoveAllPedWeapons(ped, true)
    SetPedCombatAttributes(ped, 17, false)
    SetPedCombatAttributes(ped, 46, false)
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    SetPedConfigFlag(ped, 78, true)
    SetPedConfigFlag(ped, 241, true)
    SetPedStayInVehicleWhenJacked(ped, true)

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        -- -1 = siège conducteur, on force la conduite en balade
        SetPedIntoVehicle(ped, veh, -1)
        TaskVehicleDriveWander(ped, veh, 15.0, 786603)
    else
        TaskWanderStandard(ped, 10.0, 10)
    end
end

-- ── Scan 500ms ────────────────────────────────────────────────
CreateThread(function()
    SetAllNeutral()

    while true do
        Wait(500)

        SetAllNeutral()

        local player    = PlayerPedId()
        local playerPos = GetEntityCoords(player)
        local peds      = GetGamePool('CPed')

        -- Purge le cache des peds disparus
        for handle in pairs(treatedPeds) do
            if not DoesEntityExist(handle) then
                treatedPeds[handle] = nil
            end
        end

        for _, ped in ipairs(peds) do
            if ped ~= player and not IsPedAPlayer(ped) then
                local dist = #(playerPos - GetEntityCoords(ped))

                if dist < 150.0 then
                    local isGangModel = GANG_MODEL_SET[GetEntityModel(ped)]
                    local isHostile   = IsPedInCombat(ped, player)
                    local isAlert     = GetPedAlertness(ped) >= 2

                    -- Neutralise si : modèle gang, en combat, ou en alerte (pas encore traité)
                    if isHostile or isGangModel or (isAlert and not treatedPeds[ped]) then
                        NeutralizeGangPed(ped)
                        treatedPeds[ped] = true
                    end
                end
            end
        end
    end
end)

-- ── Flags joueur 500ms ────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(500)
        local player = PlayerPedId()
        SetPedRelationshipGroupHash(player, GetHashKey("PLAYER"))
        SetIgnoreLowPriorityShockingEvents(player, true)
        SetPedConfigFlag(player, 208, true)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SetAllNeutral()
    print("[no_gangs] Ressource démarrée.")
end)