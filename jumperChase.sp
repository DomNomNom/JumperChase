#include <sourcemod>
#include <sdktools>
#include <tf2_stocks> // respawn
 


new currentFlagHolder = 0


public Plugin:myinfo = {
    name = "noDamage",
    author = "Dominik Schmid",
    description = "My first hook plugin",
    version = "0.0.2",
    url = "dominikschmid.de",
}


public OnPluginStart() {
    SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0); 
    //SetConVarInt(FindConVar("mp_teams_unbalance_limit"), 0); 

    HookEvent("player_hurt", handleHurt, EventHookMode_Pre)
    
    //HookEvent("player_join", handleJoin, EventHookMode_Pre)
    //HookEvent("player_leave", handleJoin, EventHookMode_Pre)
    
    // TODO: keep track of when a player leaves

    HookEvent("player_death", handleDeath, EventHookMode_Post)
}


//public OnMapEnd();
public OnClientDisconnect(client) { }


public instantRespawn(userid) {
    //CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(userid))
    CreateTimer(0.1, Timer_ResetPlayer, GetClientOfUserId(userid))
}
public Action:Timer_ResetPlayer(Handle:timer, any:client) {
    //TODO test me
    if (!IsPlayerAlive(client))
        TF2_RespawnPlayer(client)
    else
        PrintToConsole(client, "\n");

}

//public OnClientDied(attacker, victim, const String:weapon[], bool:headshot){
public handleDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    instantRespawn(GetEventInt(event, "userid"))
    //return _:Plugin_Handled
}


public handleHurt(Handle:event, const String:name[], bool:dontBroadcast) {
    //ServerCommand("say debug-start")

    new userid = GetEventInt(event, "userid")
    new attacker = GetEventInt(event, "attacker")
    new client = GetClientOfUserId(userid)

    PrintToChat(client, "hurt %d ==[%d]==> %d", attacker,  userid)
    //PrintToChat("say hurt %d ==> %d", attacker, userid)

    if (currentFlagHolder == 0) currentFlagHolder = userid // TODO handle this properly.

    //SetEntProp(client, Prop_Send, "m_iHealth", health, 1);
    if (userid == currentFlagHolder && attacker != currentFlagHolder && attacker != 0) { // the only damadge is from others to the flagHolder
        SetEntProp(client, Prop_Data, "m_iHealth", 0, 1);

        ServerCommand("say FlagHolder changed: %d ==> %d", currentFlagHolder, attacker)
        currentFlagHolder = attacker
        instantRespawn(userid)
    }
    else { // everything else kills you
        new maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
        SetEntProp(client, Prop_Data, "m_iHealth", maxHealth, 1);
    }
    
    setInfiniteClip(client)
    

    //ServerCommand("say \"plugin debug: end\"")

    //return Plugin_Continue
    //return Plugin_Handled
    return _:Plugin_Changed
}


setInfiniteClip(client) {
    SetClip(client, 0, 99)
    SetClip(client, 1, 0)
    SetAmmo(client, 0, 99)
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


// TODO try: CPrintToChatAll(), PrintCenterText(attacker, "TELEFRAG! You are a pro.")
// SetEntProp(Hale, Prop_Send, "m_bGlowEnabled", 0);
// SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);

/*
stock ForceTeamWin(team)
{
    new ent = FindEntityByClassname2(-1, "team_control_point_master");
    if (ent == -1)
    {
        ent = CreateEntityByName("team_control_point_master");
        DispatchSpawn(ent);
        AcceptEntityInput(ent, "Enable");
    }
    SetVariantInt(team);
    AcceptEntityInput(ent, "SetWinner");
}
*/
/*
stock SetControlPoint(bool:enable)
{
    new CPm=-1; //CP = -1;
    while ((CPm = FindEntityByClassname2(CPm, "team_control_point")) != -1)
    {
        if (CPm > MaxClients && IsValidEdict(CPm))
        {
            AcceptEntityInput(CPm, (enable ? "ShowModel" : "HideModel"));
            SetVariantInt(enable ? 0 : 1);
            AcceptEntityInput(CPm, "SetLocked");
        }
    }
}
*/
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