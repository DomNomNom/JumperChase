#include <sourcemod>
#include <sdktools>
#include <tf2_stocks> // respawn
 


new currentFlagHolder = 0;
new bool:controlPointEnabled = false; // note this is currently used for something else

new WORLD = 0; // Just a constant to hold the userID of the world. TODO: try using a #define


public Plugin:myinfo = {
    name = "JumperChase",
    author = "Dominik Schmid",
    description = "A mod about rocket jumping like crazy and hitting huge middies",
    version = "0.0.4",
    url = "dominikschmid.de",
}


public OnPluginStart() {
    SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0); 
    //SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0); 

    HookEvent("player_hurt", handleHurt, EventHookMode_Pre)
    HookEvent("player_spawn", handleSpawn, EventHookMode_Post)
    HookEvent("player_death", handleDeath, EventHookMode_Post)

    HookEvent("post_inventory_application", handleResupply, EventHookMode_Post)

    SetControlPoint(false)

    //HookEvent("player_join", handleJoin, EventHookMode_Pre)
    //HookEvent("player_leave", handleJoin, EventHookMode_Pre)
    
    // TODO: keep track of when a player leaves
}


//public OnMapEnd();
public OnClientDisconnect(client) { }


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
    //return _:Plugin_Handled
}

//public OnClientDied(attacker, victim, const String:weapon[], bool:headshot){
public handleDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    instantRespawn(GetEventInt(event, "userid"))
    //return _:Plugin_Handled
}


public handleSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
    /*
    new userid = GetEventInt(event, "userid")
    new client = GetClientOfUserId(userid)
    setInfiniteClip(client)
    ServerCommand("say class: %d", TFClass_Soldier)//TF2_GetPlayerClass(client))
    if (TF2_GetPlayerClass(client) != TFClass_Soldier) {
        //TF2_SetPlayerClass(client, TFClass_Soldier, false, true)
        //SetEntProp(client, Prop_Data, "m_iHealth", -1, 1);
        instantDeath(userid)
    }
    */
    //PrintToChat(client, "\x04[!]\x01 You are restricted to one class.");
    //TF2_RespawnPlayer(client);
}


public handleHurt(Handle:event, const String:name[], bool:dontBroadcast) {
    //ServerCommand("say debug-start")
    new userid = GetEventInt(event, "userid")
    new attacker = GetEventInt(event, "attacker")
    new client = GetClientOfUserId(userid)
    new damadge = GetEventInt(event, "damageamount")

    controlPointEnabled = !controlPointEnabled;
    SetDoorState(controlPointEnabled);

    //PrintToChat(client, "hurt %d ==[%d]==> %d", attacker, damadge, userid)
    //PrintToChat("say hurt %d ==> %d", attacker, userid)

    //if (currentFlagHolder == WORLD) currentFlagHolder = userid // TODO handle this properly.

    //SetEntProp(client, Prop_Send, "m_iHealth", health, 1);
    if (attacker == WORLD && damadge >= 500) // kill the player if the world is trying to kill him
        instantRespawn(userid)
    //(currentFlagHolder == userid || currentFlagHolder == WORLD)  && attacker != currentFlagHolder && attacker != WORLD) { // The flagholder dies when other hit him
    else if (attacker!=WORLD && attacker!=userid && (currentFlagHolder==userid || currentFlagHolder==WORLD)) {
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


setFlagHolder(userid) {
    ServerCommand("say FlagHolder changed: %d ==> %d", currentFlagHolder, userid)

    if (currentFlagHolder != WORLD) SetEntProp(GetClientOfUserId(currentFlagHolder), Prop_Send, "m_bGlowEnabled", 0)
    if (userid            != WORLD) SetEntProp(GetClientOfUserId(userid),            Prop_Send, "m_bGlowEnabled", 1)

    currentFlagHolder = userid
}


setInfiniteClip(client) {
    // TODO: call me everytime the ammo capacity changes
    //       or remove the secondary weapon
    SetClip(client, 0, 99)
    SetAmmo(client, 0, 99)
    SetClip(client, 1, 0)
    SetAmmo(client, 1, 0)
}

// TFClassType:g_tfctPlayerClass[MAXPLAYERS+1];
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
    if (currentFlagHolder == userid) setFlagHolder(WORLD); // reset the flag
    SetEntProp(GetClientOfUserId(userid), Prop_Data, "m_iHealth", 0, 1); // make sure he's dead

    CreateTimer(0.1, Timer_RespawnPlayer, GetClientOfUserId(userid)) // schedule the respawn
}
public Action:Timer_RespawnPlayer(Handle:timer, any:client) {
    if (!IsPlayerAlive(client))
        TF2_RespawnPlayer(client)
    else
        PrintToConsole(client, "[SM] Trying to respawn alive player\n");
}



// TODO try: PrintCenterText(attacker, "TELEFRAG! You are a pro.")

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


stock SetDoorState(bool:open) {
    new CPm=-1; //CP = -1;
    while ((CPm = FindEntityByClassname2(CPm, "team_control_point")) != -1) {
        if (CPm > MaxClients && IsValidEdict(CPm)) {
            /* TODO: unlock doors
            ServerCommand("say locking controlPoint")
            AcceptEntityInput(CPm, (open ? "ShowModel" : "HideModel"));
            SetVariantInt(open ? 0 : 1);
            AcceptEntityInput(CPm, "SetLocked");
            */
        }
    }
}
stock SetControlPoint(bool:enable) {
    new CPm=-1; //CP = -1;
    while ((CPm = FindEntityByClassname2(CPm, "team_control_point")) != -1) {
        if (CPm > MaxClients && IsValidEdict(CPm)) {
            ServerCommand("say locking controlPoint")
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