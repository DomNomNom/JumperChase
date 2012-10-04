#include <sourcemod>
#include <sdktools>
#include <tf2_stocks> // respawn



new Float:FlagHolderOrigin[3];
new Float:FlagHolderAngles[3];
new shouldRespawn = false;

new currentFlagHolder = 0;

new Handle:doorchecktimer = INVALID_HANDLE; // checks that the doors are open at all times
new checkdoors = true;

new WORLD = 0; // Just a constant to hold the userID of the world. TODO: try using a #define

new pointOwner = 0; // the team that currently owns the point

#define TEAM_FLAG  2
#define TEAM_NON_FLAG  3


public Plugin:myinfo = {
    name = "JumperChase",
    author = "Dominik Schmid",
    description = "A mod about rocket jumping like crazy and hitting huge middies",
    version = "0.0.5",
    url = "dominikschmid.de",
}


public OnPluginStart() {
    //SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0); 
    //initMap()

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
        checkTeam(client)
    }
}


public OnMapStart() {
    initMap()
}

public OnClientDisconnect(client) {
    // TODO: check whether the flag holder left
}

public handleTeamChange(Handle:event, const String:name[], bool:dontBroadcast) {
    checkTeam(GetEventInt(event, "userid"))
}

public handleResupply(Handle:event, const String:name[], bool:dontBroadcast) {
    new userid = GetEventInt(event, "userid")
    new client = GetClientOfUserId(userid)

    // Force the class to solider. TODO: or demoman
    if (TF2_GetPlayerClass(client) != TFClass_Soldier) {
        //ServerCommand("say resup")
        TF2_SetPlayerClass(client, TFClass_Soldier, false, true)
        TF2_RegeneratePlayer(client)
    }

    setInfiniteClip(client)
    TF2_RemoveWeaponSlot(client, 1); // disallow the shotgun
    //return _:Plugin_Handled
}

public checkTeam(userid) {

}

public initMap() {
    ServerCommand("mp_teams_unbalance_limit 0")
    ServerCommand("mp_friendlyfire 1")


    SetControlPoint(false) // don't enable manual capture of the point

    // remove spawn protection (doors)
    if (doorchecktimer == INVALID_HANDLE)
        doorchecktimer = CreateTimer(1.0, Timer_CheckDoors, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    ServerCommand("sv_cheats 1")
    ServerCommand("ent_remove_all func_respawnroomvisualizer") // This kinda does irrepairable damadge to the map. TODO find a nicer way
    ServerCommand("sv_cheats 0")
}

//public OnClientDied(attacker, victim, const String:weapon[], bool:headshot){
public handleDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    instantRespawn(GetEventInt(event, "userid"))
    //return _:Plugin_Handled
}


public handleSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new userid = GetEventInt(event, "userid")
    new client = GetClientOfUserId(userid)
    new team = GetClientTeam(client)
    

    // Force the class to solider. TODO: or demoman
    if (team == TEAM_FLAG  &&  userid != currentFlagHolder) {
        ChangeClientTeam(client, TEAM_NON_FLAG)
        TF2_RegeneratePlayer(client)
    }
}


public handleHurt(Handle:event, const String:name[], bool:dontBroadcast) {
    //ServerCommand("say debug-start")
    new userid = GetEventInt(event, "userid")
    new attacker = GetEventInt(event, "attacker")
    new client = GetClientOfUserId(userid)
    new damadge = GetEventInt(event, "damageamount")

    pointOwner += 1;
    SetControlPointOwner(pointOwner);
    //PrintToChat(client, "hurt %d ==[%d]==> %d", attacker, damadge, userid)

    if (attacker == WORLD && damadge >= 500) { // kill the player if the world is trying to kill him
        instantRespawn(userid)
    }
    //(currentFlagHolder == userid || currentFlagHolder == WORLD)  && attacker != currentFlagHolder && attacker != WORLD) { // The flagholder dies when other hit him
    else if (attacker!=WORLD && attacker!=userid && (currentFlagHolder==userid || (currentFlagHolder)==WORLD)) {
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
    }
    if (IsValidClient(newFlagHolder)) {
        SetEntProp(newFlagHolder, Prop_Send, "m_bGlowEnabled", 1)
        ChangeClientTeam(newFlagHolder, TEAM_FLAG);
        GetClientAbsOrigin(newFlagHolder, FlagHolderOrigin); 
        GetClientAbsAngles(newFlagHolder, FlagHolderAngles);
        shouldRespawn = true;
    }


    //TeleportEntity(newFlagHolder, Spawn, SpawnAngles, vel)


    // TODO TeleportEntity(client,g_fArenaSpawnOrigin[arena_index
    // ][RandomSpawn[i]],g_fArenaSpawnAngles[arena_index][RandomSpawn[i]],vel)
    // ;

    
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
                TeleportEntity(client, FlagHolderOrigin, FlagHolderAngles, NULL_VECTOR)
                shouldRespawn = false;
            }
            else 
                setFlagHolder(WORLD);
        }
    }
    else
        PrintToConsole(client, "[SM] Trying to respawn alive player\n");
}




public Action:Timer_CheckDoors(Handle:timer) {
    if (!checkdoors) { // when we should stop
        doorchecktimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    // open all doors
    new ent = -1;
    while ((ent = FindEntityByClassname2(ent, "func_door")) != -1) {
        AcceptEntityInput(ent, "Open");
        AcceptEntityInput(ent, "Unlock");
    }
    return Plugin_Continue;
}


/*
stock ForceTeamWin(team) {
    new ent = FindEntityByClassname2(-1, "team_control_point_master");
    if (ent == -1) {
        ent = CreateEntityByName("team_control_point_master");
        DispatchSpawn(ent);
        AcceptEntityInput(ent, "Enable");
    }
    SetVariantInt(team);
    AcceptEntityInput(ent, "SetWinner");
}
*/

stock SetControlPointOwner(team) {
    //SetControlPoint(true);
    new ent=-1; //CP = -1;
    while ((ent = FindEntityByClassname2(ent, "team_control_point")) != -1) {
        if (ent > MaxClients && IsValidEdict(ent)) {
            //ServerCommand("say changed owner %d", team)

            //AcceptEntityInput(ent,  "ShowModel");
            SetVariantInt(team);
            AcceptEntityInput(ent, "SetOwner");
            //SetVariantInt(team);
            //AcceptEntityInput(ent, "FireUser1");

/*
            new String:addoutput[64];
            Format(addoutput, sizeof(addoutput), "OnUser1 !self:setowner:%i:0:1",team);
            SetVariantString(addoutput);
            AcceptEntityInput(ent, "AddOutput");
            AcceptEntityInput(ent, "FireUser1");
*/

            //name: controlpoint_updateowner
            //short:   index  -  index of the cap being updated

            // teamplay_round_start
            
            new Handle:event = CreateEvent("controlpoint_starttouch")
            if (event == INVALID_HANDLE) {
                ServerCommand("say INVALID_HANDLE!")
                return
            }
            //SetEventInt(event, "userid", GetClientUserId(victim))
            //SetEventInt(event, "attacker", GetClientUserId(attacker))
            //SetEventString(event, "weapon", weapon)
            //SetEventBool(event, "headshot", headshot)
            FireEvent(event)

            //ServerCommand("say success!")
        }
    }

    //ent = FindEntityByClassname2(-1, "team_control_point_master");
    //SetVariantInt(team);
    //AcceptEntityInput(ent, "SetWinner");
}

stock SetControlPoint(bool:enable) {
    new CPm=-1; //CP = -1;
    while ((CPm = FindEntityByClassname2(CPm, "team_control_point")) != -1) {
        if (CPm > MaxClients && IsValidEdict(CPm)) {
            AcceptEntityInput(CPm, (enable ? "ShowModel" : "HideModel"));
            SetVariantInt(enable ? 0 : 1);
            AcceptEntityInput(CPm, "SetLocked");
        }
    }
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

/*stock SetArenaCapEnableTime(Float:time)
{
    new ent = -1;
    decl String:strTime[32];
    FloatToString(time, strTime, sizeof(strTime));
    if ((ent = FindEntityByClassname2(-1, "tf_logic_arena")) != -1 && IsValidEdict(ent))
    {
        DispatchKeyValue(ent, "CapEnableDelay", strTime);
    }
}
*/
/*
public Action:Timer_EnableCap(Handle:timer)
{
    if (VSHRoundState == -1)
    {
        SetControlPoint(true);
        if (checkdoors)
        {
            new ent = -1;
            while ((ent = FindEntityByClassname2(ent, "func_door")) != -1)
            {
                AcceptEntityInput(ent, "Open");
                AcceptEntityInput(ent, "Unlock");
            }
            if (doorchecktimer == INVALID_HANDLE)
                doorchecktimer = CreateTimer(5.0, Timer_CheckDoors, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
        }
    }
}
*/