function Trig_Magnetar_cast_Conditions takes nothing returns boolean
    if ( not ( GetSpellAbilityId() == udg_magnetar_ability ) ) then
        return false
    endif
    return true
endfunction

function Trig_Magnetar_cast_Func008Func001Func002C takes nothing returns boolean
    if ( not ( GetUnitTypeId(GetEnumUnit()) == 'u00E' ) ) then
        return false
    endif
    return true
endfunction

function Trig_Magnetar_cast_Func008Func001C takes nothing returns boolean
    if ( not ( IsUnitType(GetEnumUnit(), UNIT_TYPE_STRUCTURE) == false ) ) then
        return false
    endif
    if ( not ( IsUnitAliveBJ(GetEnumUnit()) == true ) ) then
        return false
    endif
    if ( not ( IsUnitEnemy(GetEnumUnit(), GetOwningPlayer(GetSpellAbilityUnit())) == true ) ) then
        return false
    endif
    return true
endfunction

function Trig_Magnetar_cast_Func008A takes nothing returns nothing
    local unit target = GetEnumUnit()
    local integer targetId = GetHandleId(target)
    local lightning lightningEffect
    local effect specialEffect
    local location dummyLoc = GetUnitLoc(udg_magnetar_dummy)
    local location targetLoc = GetUnitLoc(target)

    if IsUnitType(target, UNIT_TYPE_STRUCTURE) == false and IsUnitAliveBJ(target) and IsUnitEnemy(target, GetOwningPlayer(udg_magnetar_caster)) then
        // Save data in the hashtable
        call SaveReal(udg_magnetar_hash, targetId, 6, 100.00) // Initial size
        call SaveReal(udg_magnetar_hash, targetId, 0, udg_magnetar_temporizador) // Timer duration
        call SaveUnitHandle(udg_magnetar_hash, targetId, 2, udg_magnetar_dummy) // Dummy
        call SaveUnitHandle(udg_magnetar_hash, targetId, 1, udg_magnetar_caster) // Caster
        call GroupAddUnit(udg_magnetar_targets, target)

        // Add special effects
        set specialEffect = AddSpecialEffectTarget("chest", target, "Abilities\\Spells\\Demon\\DemonBoltImpact\\DemonBoltImpact.mdl")
        call SaveEffectHandle(udg_magnetar_hash, targetId, 4, specialEffect)

        set lightningEffect = AddLightningLoc("FORK", dummyLoc, targetLoc)
        call SetLightningColorBJ(lightningEffect, 1, 1, 0.00, 1)
        call SaveLightningHandle(udg_magnetar_hash, targetId, 5, lightningEffect)

        set udg_counter_has_light = udg_counter_has_light + 1
    endif

    // Clean up
    call RemoveLocation(dummyLoc)
    call RemoveLocation(targetLoc)
endfunction
function MagnetarTimerCallback takes nothing returns nothing
    local timer t = GetExpiredTimer()
    local integer timerId = GetHandleId(t)
    local unit dummy = LoadUnitHandle(udg_magnetar_hash, timerId, 1)
    local unit caster = LoadUnitHandle(udg_magnetar_hash, timerId, 2)
    local real size = LoadReal(udg_magnetar_hash, timerId, 3)
    local real timerValue = LoadReal(udg_magnetar_hash, timerId, 4)
    local lightning lightningEffect
    local location dummyLoc = GetUnitLoc(dummy)
    local group gravitationalGroup = LoadGroupHandle(udg_magnetar_hash, timerId, 6)
    local group nearbyEnemies
    local unit enemy
    local real moveX
    local real moveY
    local real enemyX
    local real enemyY
    local real dummyX = GetLocationX(dummyLoc)
    local real dummyY = GetLocationY(dummyLoc)
    local real colorFactor
    local group tempGroup
    local location tempEnemyLoc

    if timerValue > 0.00 then
        // Grow the magnetar
        set size = size + 3.50
        call SetUnitScalePercent(dummy, size, size, size)
        call SaveReal(udg_magnetar_hash, timerId, 3, size)

        // Move enemies slightly toward the star and adjust their color
        set tempGroup = CreateGroup()
        call GroupAddGroup(gravitationalGroup, tempGroup) // Copy gravitationalGroup to tempGroup

        loop
            set enemy = FirstOfGroup(tempGroup)
            exitwhen enemy == null
            call GroupRemoveUnit(tempGroup, enemy)
            set lightningEffect = LoadLightningHandle(udg_magnetar_hash, GetHandleId(enemy), 5)
            set tempEnemyLoc = GetUnitLoc(enemy)
            call MoveLightningLoc(lightningEffect, dummyLoc, tempEnemyLoc)

            if IsUnitAliveBJ(enemy) then
                // Calculate movement toward the star
                set enemyX = GetUnitX(enemy)
                set enemyY = GetUnitY(enemy)
                set moveX = enemyX + (dummyX - enemyX) * 0.02 // Move 0.5% closer to the star
                set moveY = enemyY + (dummyY - enemyY) * 0.02
                call SetUnitX(enemy, moveX)
                call SetUnitY(enemy, moveY)

                // Adjust color to yellow based on timerValue
                set colorFactor = 255 * (1.00 - (timerValue / 15.00))  // Gradually increase yellow
                call SetUnitVertexColor(enemy, 255, R2I(255 - colorFactor), R2I(255 - colorFactor), 255)
            else 
                // If the unit is dead, remove it from the gravitational group
                call GroupRemoveUnit(gravitationalGroup, enemy)
                set lightningEffect = LoadLightningHandle(udg_magnetar_hash, GetHandleId(enemy), 5)
                if lightningEffect != null then
                    call DestroyLightningBJ(lightningEffect)
                endif
                //clear dead unit information from hash
                call FlushChildHashtable(udg_magnetar_hash, GetHandleId(enemy))
            endif
            call RemoveLocation(tempEnemyLoc)
        endloop

        // Clean up
        call DestroyGroup(tempGroup)

        // Decrease timer
        set timerValue = timerValue - 0.04
        call SaveReal(udg_magnetar_hash, timerId, 4, timerValue)

        // Restart the timer
        call TimerStart(t, 0.04, false, function MagnetarTimerCallback)
    else
        // Explosion logic
        set nearbyEnemies = GetUnitsInRangeOfLocAll(1000.00, dummyLoc)

        // Add remaining enemies to the gravitational group
        loop
            set enemy = FirstOfGroup(nearbyEnemies)
            exitwhen enemy == null
            call GroupRemoveUnit(nearbyEnemies, enemy)

            if IsUnitAliveBJ(enemy) and IsUnitEnemy(enemy, GetOwningPlayer(caster)) and not IsUnitType(enemy, UNIT_TYPE_STRUCTURE) then
                call GroupAddUnit(gravitationalGroup, enemy)
            endif
        endloop

        // Move all units in the gravitational group to the center and apply damage
        loop
            set enemy = FirstOfGroup(gravitationalGroup)
            exitwhen enemy == null
            call GroupRemoveUnit(gravitationalGroup, enemy)

            if IsUnitAliveBJ(enemy) then
                // Move enemy to the center of the dummy
                call SetUnitPositionLoc(enemy, dummyLoc)
                // Destroy the lightning effect
                set lightningEffect = LoadLightningHandle(udg_magnetar_hash, GetHandleId(enemy), 5)
                if lightningEffect != null then
                    call DestroyLightningBJ(lightningEffect)
                endif

                // Apply damage
                call UnitDamageTargetBJ(caster, enemy, GetUnitTotalAttack(caster,0) * 3, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC)

                // Reset color to normal
                call SetUnitVertexColor(enemy, 255, 255, 255, 255)
            endif
        endloop

        // Create explosion effects
        call CreateNUnitsAtLoc(1, 'u013', GetOwningPlayer(dummy), dummyLoc, bj_UNIT_FACING)
        call UnitApplyTimedLifeBJ(15.00, 'BTLF', GetLastCreatedUnit())
        call CreateNUnitsAtLoc(1, 'u00F', GetOwningPlayer(dummy), dummyLoc, bj_UNIT_FACING)
        call IssueImmediateOrderBJ(GetLastCreatedUnit(), "thunderclap")

        // Clean up
        call KillUnit(dummy)
        call DestroyLightningBJ(lightningEffect)
        call FlushChildHashtable(udg_magnetar_hash, timerId)
        call DestroyGroup(gravitationalGroup)
        call DestroyGroup(nearbyEnemies)
    endif

    // Clean up
    call RemoveLocation(dummyLoc)
endfunction

function StartMagnetarTimer takes unit dummy, unit caster, real duration returns nothing
    local timer t = CreateTimer()
    local integer timerId = GetHandleId(t)
    local location dummyLoc = GetUnitLoc(dummy)
    local group gravitationalGroup = CreateGroup()
    local group nearbyEnemies = GetUnitsInRangeOfLocAll(1500.00, dummyLoc)
    local unit enemy

    // Add initial enemies to the gravitational group
    loop
        set enemy = FirstOfGroup(nearbyEnemies)
        exitwhen enemy == null
        call GroupRemoveUnit(nearbyEnemies, enemy)

        if IsUnitAliveBJ(enemy) and IsUnitEnemy(enemy, GetOwningPlayer(caster)) and not IsUnitType(enemy, UNIT_TYPE_STRUCTURE) then
            call GroupAddUnit(gravitationalGroup, enemy)
        endif
    endloop

    // Attach data to the timer
    call SaveUnitHandle(udg_magnetar_hash, timerId, 1, dummy) // Dummy
    call SaveUnitHandle(udg_magnetar_hash, timerId, 2, caster) // Caster
    call SaveReal(udg_magnetar_hash, timerId, 3, 100.00) // Initial size
    call SaveReal(udg_magnetar_hash, timerId, 4, duration) // Timer duration
    call SaveGroupHandle(udg_magnetar_hash, timerId, 6, gravitationalGroup) // Gravitational group

    // Start the timer
    call TimerStart(t, 0.04, false, function MagnetarTimerCallback)

    // Clean up
    call RemoveLocation(dummyLoc)
    call DestroyGroup(nearbyEnemies)
endfunction

function Trig_Magnetar_cast_Actions takes nothing returns nothing
    local location spellTargetLoc = GetSpellTargetLoc()
    local location dummyLoc
    local group nearbyUnits
    local unit dummy
    local unit caster = GetSpellAbilityUnit()

    set udg_magnetar_caster = caster
    set udg_magnetar_bool = true

    // Create the magnetar dummy
    call CreateNUnitsAtLoc(1, 'u00E', GetOwningPlayer(caster), spellTargetLoc, bj_UNIT_FACING)
    set dummy = GetLastCreatedUnit()
    call GroupAddUnit(udg_magnetar_targets, dummy)

    // Process nearby units
    set dummyLoc = GetUnitLoc(dummy)
    set nearbyUnits = GetUnitsInRangeOfLocAll(600.00, dummyLoc)
    call ForGroup(nearbyUnits, function Trig_Magnetar_cast_Func008A)

    // Start the timer for the magnetar
    call StartMagnetarTimer(dummy, caster, udg_magnetar_temporizador)

    // Clean up
    call RemoveLocation(spellTargetLoc)
    call RemoveLocation(dummyLoc)
    call DestroyGroup(nearbyUnits)
endfunction

//===========================================================================
function InitTrig_Magnetar_cast takes nothing returns nothing
    set gg_trg_Magnetar_cast = CreateTrigger(  )
    call TriggerRegisterAnyUnitEventBJ( gg_trg_Magnetar_cast, EVENT_PLAYER_UNIT_SPELL_EFFECT )
    call TriggerAddCondition( gg_trg_Magnetar_cast, Condition( function Trig_Magnetar_cast_Conditions ) )
    call TriggerAddAction( gg_trg_Magnetar_cast, function Trig_Magnetar_cast_Actions )
endfunction

