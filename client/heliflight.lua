local heliModel = "supervolito2" -- Helikopter-Modell
local pilotModel = "s_m_m_pilot_01" -- NPC Pilot
local heli, pilot = nil, nil
local heliBlip = nil
local heliSpawned = false
local playerPed = PlayerPedId()

-- Fester Spawnpunkt für den Helikopter
local heliSpawnCoords = vector4(-1178.58, -2845.85, 13.10, 333.51)

-- Funktion: Helikopter an festem Punkt spawnen
function SpawnHeli()
    RequestModel(GetHashKey(heliModel))
    RequestModel(GetHashKey(pilotModel))
    while not HasModelLoaded(GetHashKey(heliModel)) or not HasModelLoaded(GetHashKey(pilotModel)) do
        Wait(100)
    end

    -- Helikopter auf sicherem Boden spawnen
    heli = CreateVehicle(GetHashKey(heliModel), heliSpawnCoords.x, heliSpawnCoords.y, heliSpawnCoords.z, heliSpawnCoords.w, true, false)
    SetVehicleEngineOn(heli, true, true, false)

    -- Pilot erstellen
    pilot = CreatePedInsideVehicle(heli, 4, GetHashKey(pilotModel), -1, true, false)

    -- Blip für Helikopter setzen
    heliBlip = AddBlipForEntity(heli)
    SetBlipSprite(heliBlip, 43)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Helikopter Taxi")
    EndTextCommandSetBlipName(heliBlip)

    -- NPC-Pilot fliegt jetzt zum Spieler
    local playerCoords = GetEntityCoords(playerPed)
    TaskHeliMission(pilot, heli, 0, 0, playerCoords.x, playerCoords.y, playerCoords.z + 20, 4, 50.0, -1.0, 0.0, 200, 200, -1.0, 0)

    heliSpawned = true

    -- Überwachung: Erst landen, wenn X UND Y erreicht sind
    Citizen.CreateThread(function()
        while heliSpawned do
            local heliCoords = GetEntityCoords(heli)
            
            -- Prüft, ob die X- und Y-Koordinaten erreicht wurden
            if math.abs(heliCoords.x - playerCoords.x) < 1.0 and math.abs(heliCoords.y - playerCoords.y) < 1.0 then
                StartManualLanding(playerCoords) -- Startet die Landung
                heliSpawned = false
                break
            end
            Wait(500)
        end
    end)
end

-- Funktion: Manuelle Landung des Helikopters
function StartManualLanding(targetCoords)
    if DoesEntityExist(heli) and DoesEntityExist(pilot) then
        local landX = targetCoords.x
        local landY = targetCoords.y

        -- Bodenhöhe ermitteln
        local _, groundZ = GetGroundZFor_3dCoord(landX, landY, targetCoords.z, false)
        print("[DEBUG] Erkannte Bodenhöhe: "..groundZ)

        -- Langsames Absinken bis zur Bodenhöhe
        Citizen.CreateThread(function()
            local heliCoords = GetEntityCoords(heli)
            local currentZ = heliCoords.z
            local stepSize = 2.0  -- Schrittweise Absenkung

            while currentZ > groundZ + 5 do
                currentZ = math.max(currentZ - stepSize, groundZ)  -- Begrenzen auf Bodenhöhe
                TaskHeliMission(pilot, heli, 0, 0, landX, landY, currentZ, 4, 10.0, -1.0, 0.0, 10, 10, -1.0, 0)
                Wait(1000) -- 1 Sekunde pro Schritt
            end

            TaskVehicleTempAction(pilot, heli, 1, 5000) -- KI-Kontrolle deaktivieren
            -- SetHeliEngineHealth(heli, 1000.0) -- Motor nicht abschalten
            SetVehicleEngineOn(heli, true, true, false)
            -- SetHeliBladesFullSpeed(heli)
            SetVehicleForwardSpeed(heli, 0.1)
            -- SetVehicleThrottle(heli, 1.0)
            SetVehicleEnginePowerMultiplier(heli, 0.1) -- Versuchen, Leistung zu reduzieren
            SetEntityRotation(heli, 0.0, 0.0, GetEntityHeading(heli), 2, true)
            Wait(10000) -- Warte 10 Sekunden bis Helikopter gesunken ist

            -- Endgültige Landung auf der Bodenhöhe
            -- TaskHeliMission(pilot, heli, 0, 0, landX, landY, groundZ, 4, 5.0, -1.0, 0.0, 0, 0, -1.0, 0)
            print("[DEBUG] Helikopter gelandet und instand gesetzt")
            SetHeliEngineHealth(heli, 1000.0)
        end)
    end
end

-- Funktion: Helikopter fliegt zum Wegpunkt und landet
function StartHeli()
    if DoesEntityExist(heli) then
        local waypointBlip = GetFirstBlipInfoId(8) -- Spieler-Wegpunkt holen
        if DoesBlipExist(waypointBlip) then
            local coord = GetBlipInfoIdCoord(waypointBlip)

            -- Helikopter fliegt zum Ziel
            TaskHeliMission(pilot, heli, 0, 0, coord.x, coord.y, coord.z + 50, 4, 50.0, -1.0, 0.0, 200, 200, -1.0, 0)

            Citizen.CreateThread(function()
                while true do
                    local heliCoords = GetEntityCoords(heli)

                    -- Prüfen, ob X und Y erreicht wurden
                    if math.abs(heliCoords.x - coord.x) < 1.0 and math.abs(heliCoords.y - coord.y) < 1.0 then
                        StartManualLanding(coord) -- Jetzt beginnt die manuelle Landung
                        break
                    end
                    Wait(1000)
                end

                -- Warten bis Spieler aussteigt
                Citizen.CreateThread(function()
                    while true do
                        if not IsPedInVehicle(playerPed, heli, false) then
                            TakeOffAndLeave()
                            break
                        end
                        Wait(1000)
                    end
                end)
            end)
        else
            print("Kein Wegpunkt gesetzt!")
        end
    end
end

-- Funktion: Helikopter hebt nach dem Aussteigen ab
function TakeOffAndLeave()
    if DoesEntityExist(heli) and DoesEntityExist(pilot) then
        TaskHeliMission(pilot, heli, 0, 0, heliSpawnCoords.x, heliSpawnCoords.y, heliSpawnCoords.z + 50, 4, 100.0, -1.0, 0.0, 300, 300, -1.0, 0)
        Wait(10000)
        DeleteEntity(heli)
        DeleteEntity(pilot)
        RemoveBlip(heliBlip)
    end
end

-- Command für Helikopter anfordern
RegisterCommand("heli", function()
    if not DoesEntityExist(heli) then
        SpawnHeli()
    else
        print("Helikopter ist bereits unterwegs!")
    end
end, false)

-- Command um Helikopter zu starten
RegisterCommand("helistart", function()
    StartHeli()
end, false)
