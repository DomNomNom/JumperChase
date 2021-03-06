#include <sourcemod>
#include <sdktools>
#include <tf2_stocks> // respawn
#include <sdkhooks>

#define TEAM_FLAG  2
#define TEAM_NON_FLAG  3

#define WORLD  0

#define TRACKED_PLAYER_COUNT MAXPLAYERS+1

#define UBER_TIME 3.0
new flagHolderUbererd = false;

new Float:FlagHolderOrigin[3];
new Float:FlagHolderAngles[3];
new Float:FlagHolderVelocity[3];
new shouldRespawn = false;

new currentFlagHolder = 0;

new Handle:doorchecktimer = INVALID_HANDLE; // checks that the doors are open at all times
new checkdoors = true;

// Time-keeping stuff
new timeLeft[TRACKED_PLAYER_COUNT],
    ent_roundTimer = -1,
    timerInitialLength = -1,
    flagStartTime;



public Plugin:myinfo = {
    name = "JumperChase",
    author = "Dominik Schmid",
    description = "A mod about rocket jumping like crazy and hitting huge middies",
    version = "0.1.0",
    url = "dominikschmid.de",
}


public OnPluginStart() {
    ent_roundTimer = FindEntityByClassname2(-1, "team_round_timer");
    if (ent_roundTimer == -1) return; // we should't continue if the map doesn't have a timer.
    timerInitialLength = GetEntProp(ent_roundTimer, Prop_Send, "m_nTimerInitialLength");
    for (new i=0; i<TRACKED_PLAYER_COUNT; ++i)
        timeLeft[i] = timerInitialLength;

    HookEvent("player_hurt", handleHurt, EventHookMode_Pre)
    HookEvent("player_spawn", handleSpawn, EventHookMode_Post)
    HookEvent("player_death", handleDeath, EventHookMode_Post)

    HookEvent("post_inventory_application", handleResupply, EventHookMode_Post)
    HookEvent("player_team", handleTeamChange, EventHookMode_Pre)

    //HookEvent("player_join", handleJoin, EventHookMode_Pre)
    //HookEvent("player_leave", handleJoin, EventHookMode_Pre)
    setFlagHolder(WORLD)
    for (new client = 0; client <= MaxClients; client++) {
        if (!IsValidClient(client)) continue;
        SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0)
        checkTeam(GetClientUserId(client))
    }
}


public OnMapStart() {

    ServerCommand("mp_teams_unbalance_limit 0")
    ServerCommand("mp_friendlyfire 1")
    ServerCommand("sv_alltalk 1")

    // remove spawn protection (doors)
    if (doorchecktimer == INVALID_HANDLE)
        doorchecktimer = CreateTimer(1.0, Timer_CheckDoors, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}



public OnClientDisconnect(client) {
    if (GetClientUserId(client) == currentFlagHolder)
        setFlagHolder(WORLD)
    timeLeft[client] = timerInitialLength
}

public handleTeamChange(Handle:event, const String:name[], bool:dontBroadcast) {
    //checkTeam(GetEventInt(event, "userid"))
}

public handleResupply(Handle:event, const String:name[], bool:dontBroadcast) {
    new userid = GetEventInt(event, "userid")
    new client = GetClientOfUserId(userid)

    // Force the class to solider. TODO: or demoman
    if (TF2_GetPlayerClass(client) != TFClass_Soldier) {
        TF2_SetPlayerClass(client, TFClass_Soldier, false, true)
        TF2_RegeneratePlayer(client)
    }

    setInfiniteClip(client)
    TF2_RemoveWeaponSlot(client, 1); // disallow the shotgun
    //return _:Plugin_Handled
}

public checkTeam(userid) {
    new client = GetClientOfUserId(userid)
    if (!IsValidClient(client)) return
    new team = GetClientTeam(client)
    // Force the class to solider. TODO: or demoman
    if (team == TEAM_FLAG  &&  GetClientUserId(client) != currentFlagHolder) {
        ChangeClientTeam(client, TEAM_NON_FLAG)
        TF2_RegeneratePlayer(client)
    }
}

//public OnClientDied(attacker, victim, const String:weapon[], bool:headshot){
public handleDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    instantRespawn(GetEventInt(event, "userid"))
    //return _:Plugin_Handled
}


public handleSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new userid = GetEventInt(event, "userid")
    checkTeam(userid)
}


public handleHurt(Handle:event, const String:name[], bool:dontBroadcast) {
    //ServerCommand("say debug-start")
    new userid = GetEventInt(event, "userid")
    new attacker = GetEventInt(event, "attacker")
    new client = GetClientOfUserId(userid)
    new damadge = GetEventInt(event, "damageamount")

    //PrintToChat(client, "hurt %d ==[%d]==> %d", attacker, damadge, userid)

    if (attacker == WORLD && damadge >= 500) { // kill the player if the world is trying to kill him
        instantRespawn(userid)
    }
    //(currentFlagHolder == userid || currentFlagHolder == WORLD)  && attacker != currentFlagHolder && attacker != WORLD) { // The flagholder dies when other hit him
    else if (attacker!=WORLD && attacker!=userid && (currentFlagHolder==userid || (currentFlagHolder)==WORLD) && !flagHolderUbererd) {
        setFlagHolder(attacker)
        instantRespawn(userid)
    }
    else { // everything else doesn't do damadge
        new maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
        SetEntProp(client, Prop_Data, "m_iHealth", maxHealth, 1);
    }
    
    setInfiniteClip(client) // TODO: do this when the player fires
    

    //ServerCommand("say \"plugin debug: end\"")

    //return Plugin_Continue
    //return Plugin_Handled
    return _:Plugin_Changed
}




// SET FLAG HOLDER

setFlagHolder(userid) {
    ServerCommand("say FlagHolder changed: %d ==> %d", currentFlagHolder, userid)
    //PrintCenterText(GetClientOfUserId(userid), "YOU ARE IT!")
    new oldFlagHolder = GetClientOfUserId(currentFlagHolder)
    new newFlagHolder = GetClientOfUserId(userid)

    if (IsValidClient(oldFlagHolder)) {
        SetEntProp(oldFlagHolder, Prop_Send, "m_bGlowEnabled", 0);
        ChangeClientTeam(oldFlagHolder, TEAM_NON_FLAG);
        timeLeft[oldFlagHolder] -= GetTime()-flagStartTime;
    }

    if (IsValidClient(newFlagHolder)) {
        //SetEntProp(newFlagHolder, Prop_Send, "m_bGlowEnabled", 1)
        ChangeClientTeam(newFlagHolder, TEAM_FLAG);
        GetClientAbsOrigin(newFlagHolder, FlagHolderOrigin); 
        GetClientAbsAngles(newFlagHolder, FlagHolderAngles);
        GetEntPropVector(newFlagHolder, Prop_Data, "m_vecVelocity", FlagHolderVelocity);
        shouldRespawn = true;

        //ServerCommand("say here's the new time: %f", timeLeft[newFlagHolder])
        //SetEntPropFloat(ent_roundTimer, Prop_Send, "m_flTimeRemaining", timeLeft[newFlagHolder])
        
        flagStartTime = GetTime()
        setRoundTimer(timeLeft[newFlagHolder], true);
    }
    else { // newFlagHolder == WORLD
        ServerCommand("say === FREE FOR ALL ===")
        setRoundTimer(timerInitialLength, false);
    }

    currentFlagHolder = userid
}






// CLIP

setInfiniteClip(client) {
    SetClip(client, 0, 99)
    SetAmmo(client, 0, 20)
}
stock SetClip(client, wepslot, newAmmo) {
    new weapon = GetPlayerWeaponSlot(client, wepslot);
    if (IsValidEntity(weapon)) {
        new iAmmoTable = FindSendPropInfo("CTFWeaponBase", "m_iClip1");
        SetEntData(weapon, iAmmoTable, newAmmo, 4, true);
    }
    //else ServerCommand("say [SetAmmo]: Invalid weapon slot: %d", wepslot)
}

stock SetAmmo(client, wepslot, newAmmo) {
    new weapon = GetPlayerWeaponSlot(client, wepslot);
    if (IsValidEntity(weapon)) {
        new iOffset = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 1)*4;
        new iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
        SetEntData(client, iAmmoTable+iOffset, newAmmo, 4, true);
    }
    //else ServerCommand("say [SetAmmo]: Invalid weapon slot: %d", wepslot)
}


public instantRespawn(userid) {
    SetEntProp(GetClientOfUserId(userid), Prop_Data, "m_iHealth", 0, 1); // make sure he's dead

    CreateTimer(0.1, Timer_RespawnPlayer, GetClientOfUserId(userid)) // schedule the respawn
}
public Action:Timer_RespawnPlayer(Handle:timer, any:client) {
    if (!IsPlayerAlive(client)) {
        TF2_RespawnPlayer(client)
        if (client == GetClientOfUserId(currentFlagHolder)) {
            if (shouldRespawn) {
                SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1)
                TeleportEntity(client, FlagHolderOrigin, FlagHolderAngles, FlagHolderVelocity)
                TF2_AddCondition(client, TFCond_Kritzkrieged, 9001.0)
                TF2_AddCondition(client, TFCond_Ubercharged, UBER_TIME)
                CreateTimer(UBER_TIME, Timer_unUber)
                flagHolderUbererd = true;
                shouldRespawn = false;
            }
            else
                setFlagHolder(WORLD);
        }
    }
    else
        PrintToConsole(client, "[DT] Trying to respawn alive player\n");
}


public Action:Timer_unUber(Handle:timer) {
    flagHolderUbererd = false
}

public Action:Timer_CheckDoors(Handle:timer) {
    if (!checkdoors) { // when we should stop
        doorchecktimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    // stop all spawn protetors 
    new ent = -1;
    while ((ent = FindEntityByClassname2(ent, "func_respawnroomvisualizer")) != -1) {
        AcceptEntityInput(ent, "Disable");
    }

    // open all doors
    ent = -1;
    while ((ent = FindEntityByClassname2(ent, "func_door")) != -1) {
        AcceptEntityInput(ent, "Open");
        AcceptEntityInput(ent, "Unlock");
    }

    return Plugin_Continue;
}


stock setRoundTimer(time, bool:enable) {
    if (enable) AcceptEntityInput(ent_roundTimer, "Resume");
    else        AcceptEntityInput(ent_roundTimer, "Pause" );

    SetVariantInt(time);
    AcceptEntityInput(ent_roundTimer, "SetTime");
}

stock FindEntityByClassname2(startEnt, const String:classname[]) {
    /* If startEnt isn't valid shifting it back to the nearest valid one */
    while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
    return FindEntityByClassname(startEnt, classname);
}

stock bool:IsValidClient(client, bool:replaycheck = true) {
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
    if (replaycheck)
        if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
    return true;
}