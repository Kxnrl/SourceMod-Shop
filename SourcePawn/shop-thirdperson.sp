/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          shop-thirdperson.sp                            */
/*  Description:   A new Shop system for source game.             */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2017/02/11 03:21:15                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/


#pragma semicolon 1
#pragma newdecls required

#include <shop>

#define PI_NAME "MagicGirl.NET - Shop :: Thrid Person [DARLING IN THE FRANXX]"
#define PI_AUTH "Kyle"
#define PI_DESC "In-game Shop for MagicGirl.NET"
#define PI_VERS "[DARLING IN THE FRANXX] v" ... MAJORV ... "." ... MINORV ... "." ... BUILDs
#define PI_URLS "https://MagicGirl.net"

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

ConVar sv_allow_thirdperson;
ConVar mp_forcecamera;

bool g_bThirdPerson[MAXPLAYERS+1];
bool g_bMirrorMode[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Shop_TP_IsClientTP", Native_IsClientTP);

    RegPluginLibrary("shop-thirdperson");

    return APLRes_Success;
}

public int Native_IsClientTP(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return g_bThirdPerson[client] || g_bMirrorMode[client];
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_tp",      Command_TP);
    RegConsoleCmd("sm_seeme",   Command_Mirror);
    
    HookEventEx("player_spawn", Event_Player, EventHookMode_Post);
    HookEventEx("player_death", Event_Player, EventHookMode_Post);

    sv_allow_thirdperson = FindConVar("sv_allow_thirdperson");
    mp_forcecamera = FindConVar("mp_forcecamera");
}

public void OnClientConnected(int client)
{
    g_bMirrorMode[client]  = false;
    g_bThirdPerson[client] = false;
}

public void Event_Player(Event event, const char[] name, bool dontBroadcast)
{
    CheckClientTP(GetClientOfUserId(event.GetInt("userid")));
}

public Action Command_TP(int client, int args)
{
    if(!client)
        return Plugin_Handled;
    
    if(!IsPlayerAlive(client))
    {
        PrintToChat(client, "[\x04TP\x01]  死人不能使用TP功能");
        return Plugin_Handled;
    }
    
    if(g_bMirrorMode[client])
    {
        PrintToChat(client, "[\x04TP\x01]  你已经在使用镜像模式了");
        return Plugin_Handled;
    }
    
    g_bThirdPerson[client] = !g_bThirdPerson[client];
    sv_allow_thirdperson.SetInt(1);
    ClientCommand(client, g_bThirdPerson[client] ? "thirdperson" : "firstperson");
    
    return Plugin_Handled;
}

public Action Command_Mirror(int client, int args)
{
    if(!client)
        return Plugin_Handled;

    if(!IsPlayerAlive(client))
    {
        PrintToChat(client, "[\x04TP\x01]  死人不能使用TP功能");
        return Plugin_Handled;
    }
    
    if(g_bThirdPerson[client])
    {
        PrintToChat(client, "[\x04TP\x01]  你已经在使用第三人称视角了");
        return Plugin_Handled;
    }
    
    if(!g_bMirrorMode[client])
    {
        g_bMirrorMode[client] = true;
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0); 
        SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
        SetEntProp(client, Prop_Send, "m_iFOV", 120);
        mp_forcecamera.ReplicateToClient(client, "1");
    }
    else
    {
        g_bMirrorMode[client] = false;
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
        SetEntProp(client, Prop_Send, "m_iFOV", 90);
        char value[8];
        mp_forcecamera.GetString(value, 8);
        mp_forcecamera.ReplicateToClient(client, value);
    }

    return Plugin_Handled;
}

void CheckClientTP(int client)
{
    if(g_bThirdPerson[client])
    {
        ClientCommand(client, "firstperson");
        g_bThirdPerson[client] = false;
    }

    if(g_bMirrorMode[client])
    {
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
        SetEntProp(client, Prop_Send, "m_iFOV", 90);
        char value[8];
        mp_forcecamera.GetString(value, 8);
        mp_forcecamera.ReplicateToClient(client, value);
        g_bMirrorMode[client] = false;
    }
}