/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          shop-skin.sp                                   */
/*  Description:   A new Shop system for source game.             */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2017/02/01 11:37:14                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/


#pragma semicolon 1
#pragma newdecls required

#define PI_NAME "MagicGirl.NET - Shop :: Player Skin [DARLING IN THE FRANXX]"
#define PI_AUTH "Kyle"
#define PI_DESC "In-game Shop for MagicGirl.NET"
#define PI_VERS "<commit-count>"
#define PI_URLS "https://MagicGirl.net"

#include <shop>
#include <clientprefs>
#include <sdktools_sound>
#include <sdktools_functions>
#include <sdktools_stringtables>

#define COOKIE_TEs  0
#define COOKIE_CTs  1
#define COOKIE_ANY  2
#define MAX_SKINS  64

#define MODEL_HUMAN "models/player/custom_player/legacy/tm_leet_variant_classic.mdl"

enum Skins
{
    String:szUniqueId[32],
    String:szModel[192],
    String:szArms[192],
    String:szSound[192],
    iTeam,
    
    // other data.
    String:szName[128],
    String:szDesc[128]
}

any g_Skins[MAX_SKINS][Skins];
int g_iSkins;

Handle g_cookieSkin[3];

int g_iDataIndex[MAXPLAYERS+1];

bool g_bIsGlobalMode = false;

bool g_pZombieReloaded;

public void OnPluginStart()
{
    // category
    MG_Shop_RegItemCategory("skin", true, OnMenuInventory);

    // cookies
    g_cookieSkin[COOKIE_TEs] = RegClientCookie("skins_tes", "", CookieAccess_Private);
    g_cookieSkin[COOKIE_CTs] = RegClientCookie("skins_cts", "", CookieAccess_Private);
    g_cookieSkin[COOKIE_ANY] = RegClientCookie("skins_any", "", CookieAccess_Private);

    // databse and item.
    ConnectAndLoad();

    // events
    AddNormalSoundHook(Event_NormalSound);
    HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
}

public void ConnectAndLoad()
{
    char error[256];
    Database mySQL = SQL_Connect("default", true, error, 256);
    if(mySQL == null)
        SetFailState("Connect to database Error.");
    
    mySQL.SetCharset("utf8");

    // load items
    DBResultSet items = SQL_Query(mySQL, "SELECT a.*, b.fullname, b.description FROM dxg_items_skin a LEFT JOIN dxg_items b ON a.uniqueId = b.uniqueId ORDER BY a.id ASC;");
    if(items == null)
    {
        SQL_GetError(mySQL, error, 256);
        SetFailState("Can not retrieve items.skin from database: %s", error);
    }

    if(items.RowCount <= 0)
        SetFailState("Can not retrieve items.skin from database: no result row");

    while(items.FetchRow())
    {
        g_Skins[g_iSkins][iTeam] = items.FetchInt(5);
        items.FetchString(1, g_Skins[g_iSkins][szUniqueId],  32);
        items.FetchString(2, g_Skins[g_iSkins][szModel],    192);
        items.FetchString(3, g_Skins[g_iSkins][szArms],     192);
        items.FetchString(4, g_Skins[g_iSkins][szSound],    192);
        items.FetchString(6, g_Skins[g_iSkins][szName],     128);
        items.FetchString(7, g_Skins[g_iSkins][szDesc],     128);

        if(!FileExists(g_Skins[g_iSkins][szModel]))
            continue;

        g_iSkins++;
    }
    
    delete items;
    delete mySQL;
}

public void OnMapStart()
{
    g_bIsGlobalMode = (FindPluginByFile("zombiereloaded.smx") || FindPluginByFile("ttt.smx"));

    for(int skin = 0; skin < g_iSkins; ++skin)
    {
        PrecacheModel(g_Skins[skin][szModel], true);
        
        if(strlen(g_Skins[skin][szArms]) > 3 && FileExists(g_Skins[skin][szArms], true))
            PrecacheModel(g_Skins[skin][szArms], true);

        if(strlen(g_Skins[skin][szSound]) > 3)
            PrepareSound(g_Skins[skin][szSound]);
    }
    
    g_pZombieReloaded = (FindPluginByFile("zombiereloaded.smx") != INVALID_HANDLED);
    
    if(g_pZombieReloaded)
        PrecacheModel(MODEL_HUMAN);
}

void PrepareSound(const char[] sound)
{
    char szPath[192];
    FormatEx(szPath, 192, "sound/%s", sound);
    if(!FileExists(szPath, true))
        return;
    
    AddFileToDownloadsTable(szPath);
    ReplaceString(szPath, 192, "sound/", "*");
    AddToStringTable(FindStringTable("soundprecache"), szPath);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    g_iDataIndex[client] = -1;
    
    int team;

    if(g_bIsGlobalMode)
        team = 2;
    else
        team = GetClientTeam(client) - 2;
    
    if(team > 2 || team < 0)
        return Plugin_Continue;

    char skin_uid[32];
    GetClientCookie(client, g_cookieSkin[team], skin_uid, 32);
    
    if(strlen(skin_uid) < 4 || !MG_Shop_HasClientItem(client, skin_uid))
    {
        if(g_pZombieReloaded)
            CreateTimer(0.02, Timer_SetClientModel_Human, client, TIMER_FLAG_NO_MAPCHANGE);
        
        return Plugin_Continue;
    }
    
    g_iDataIndex[client] = UTIL_GetSkin(skin_uid);
    if(g_iDataIndex[client] == -1)
    {
        if(g_pZombieReloaded)
            CreateTimer(0.02, Timer_SetClientModel_Human, client, TIMER_FLAG_NO_MAPCHANGE);

        return Plugin_Continue;
    }

    CreateTimer(0.02, Timer_SetClientModel, client, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Continue;
}

public Action Timer_SetClientModel(Handle timer, int client)
{
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;
    
    SetEntityModel(client, g_Skins[g_iDataIndex[client]][szModel]);

    if(strlen(g_Skins[g_iDataIndex[client]][szArms]) > 3 && IsModelPrecached(g_Skins[g_iDataIndex[client]][szArms]))
        SetEntPropString(client, Prop_Send, "m_szArmsModel", g_Skins[g_iDataIndex[client]][szArms]);

    return Plugin_Stop;
}

public Action Timer_SetClientModel_Human(Handle timer, int client)
{
    if(!IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;
    
    SetEntityModel(client, MODEL_HUMAN);

    return Plugin_Stop;
}

public Action Event_NormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &client, int &channel, float &volume, int &level, int &pitch, int &flags)
{
    if(channel != SNDCHAN_VOICE || client > MaxClients || client < 1 || !IsClientInGame(client) || g_iDataIndex[client] < 0 || g_iDataIndex[client] > g_iSkins)
        return Plugin_Continue;
    
    if(g_pZombieReloaded && GetClientTeam(client) == 2)
        return Plugin_Stop;

    if  ( 
            StrEqual(sample, "~player/death1.wav", false)||
            StrEqual(sample, "~player/death2.wav", false)||
            StrEqual(sample, "~player/death3.wav", false)||
            StrEqual(sample, "~player/death4.wav", false)||
            StrEqual(sample, "~player/death5.wav", false)||
            StrEqual(sample, "~player/death6.wav", false)
        )
        {
            FormatEx(sample, PLATFORM_MAX_PATH, "*%s", g_Skins[g_iDataIndex[client]][szSound]);
            volume = 1.0;
            return Plugin_Changed;
        }

    return Plugin_Continue;
}

int UTIL_GetSkin(const char[] uid)
{
    for(int i = 0; i < g_iSkins; ++i)
        if(strcmp(uid, g_Skins[i][szUniqueId]) == 0)
            return i;
        
    return -1;
}

public void OnMenuInventory(int client, const char[] uniqueId, bool inventory)
{
    Menu menu = new Menu(MenuHandler_InvMenu);
    
    menu.ExitButton = false;
    menu.ExitBackButton = true;
    
    int skin = UTIL_GetSkin(uniqueId);
    if(skin == -1)
    {
        PrintToChat(client, "[\x04Shop\x01]   \x10该物品目前不可用...");
        MG_Shop_DisplayPreviousMenu(client);
        return;
    }

    menu.SetTitle("商店 - %s\n余额: %d G\n \n%s\n%s\n \n阵营: %s\n ", inventory ? "库存" : "展柜", MG_Shop_GetClientMoney(client), g_Skins[skin][szName], g_Skins[skin][szDesc], g_bIsGlobalMode ? "通用" : (g_Skins[skin][iTeam] == 3 ? "CT" : "TE"));

    menu.AddItem(uniqueId, "预览");
    menu.AddItem(uniqueId, inventory ? "装备" : "购买");
    menu.AddItem(uniqueId, inventory ? "售出" : "开箱");

    menu.Display(client, 60);
}

public int MenuHandler_InvMenu(Menu menu, MenuAction action, int param1, int param2)
{
    if(action == MenuAction_Select)
    {
        char uniqueId[32];
        menu.GetItem(param2, uniqueId, 32);
        switch(param2)
        {
            case 0: PrintToChat(param1, "[\x04Shop\x01]   \x07该功能目前不可用...");
            case 1: if(MG_Shop_HasClientItem(param1, uniqueId)) EquipSkin(param1, uniqueId); else MG_Shop_BuyItemMenu(param1, uniqueId);
            case 2: PrintToChat(param1, "[\x04Shop\x01]   \x07该功能目前不可用...");
        }
        
        MG_Shop_DisplayPreviousMenu(param1);
    }
    else if(action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
        MG_Shop_DisplayPreviousMenu(param1);
    else if(action == MenuAction_End)
        delete menu;
}

void EquipSkin(int client, const char[] uniqueId)
{
    int skin = UTIL_GetSkin(uniqueId);
    
    if(g_bIsGlobalMode)
        SetClientCookie(client, g_cookieSkin[COOKIE_ANY], uniqueId);
    else
        SetClientCookie(client, g_cookieSkin[g_Skins[skin][iTeam]-2], uniqueId);

    PrintToChat(client, "[\x04Shop\x01]  ***\x10Skin\x01***   您已装备[\x10%s\x01]于%s\x01阵营", g_Skins[skin][szName], g_bIsGlobalMode ? "\x0A通用" : (g_Skins[skin][iTeam] == 3 ? "\x0BCT" : "\x05TE"));
}