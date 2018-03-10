/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          shop-core.sp                                   */
/*  Description:   A new Shop system for source game.             */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2017/01/31 20:40:02                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/


#pragma semicolon 1
#pragma newdecls required

#include <shop>

#define PI_NAME "MagicGirl.NET - Shop :: Core [DARLING IN THE FRANXX]"
#define PI_AUTH "Kyle"
#define PI_DESC "In-game Shop for MagicGirl.NET"
#define PI_VERS "[DARLING IN THE FRANXX] v" ... MAJORV ... "." ... MINORV ... "." ... BUILDs
#define PI_URLS "https://MagicGirl.net"

#define MAX_ITEMS 512
#define MAX_ITEM_CATEGORY 32

public Plugin myinfo = 
{
    name        = PI_NAME,
    author      = PI_AUTH,
    description = PI_DESC,
    version     = PI_VERS,
    url         = PI_URLS
};

enum Item_Categories //Category
{
    String:szType[32],
    bool:bEquipable,
    Handle:hPlugin,
    Function:fnMenu,
    bool:bRemoved
}

enum Item_Data
{
    iIndex,
    iPrice[4],
    iParent,
    iCategory,
    bool:bBuyable,
    bool:bGiftable,
    bool:bVipItem,
    String:szFullName[128],
    String:szShortName[32],
    String:szCategory[32],
    String:szUniqueId[32],
    String:szDescription[128],
    String:szPersonalId[128]
}

enum Client_Item
{
    iItemIndex,
    iDbIndex,
    iCost,
    iDateOfPurchase,
    iDateOfExpiration
}

enum Client_Data
{
    iUid,
    iMoney,
    iItems,
    bool:bVip,
    bool:bLoaded,
    Handle:hTimer
}

any g_ClientData[MAXPLAYERS+1][Client_Data];
any g_ClientItem[MAXPLAYERS+1][MAX_ITEMS][Client_Item];
any g_Items[MAX_ITEMS][Item_Data];
any g_Category[MAX_ITEM_CATEGORY][Item_Categories];

int g_iItems;
int g_iCategories;
int g_iFakeCategory;

Database g_MySQL;

#include "core/native.sp"
#include "core/sqlcb.sp"
#include "core/utils.sp"
#include "core/menu.sp"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    Native_AskPluginLoad2();

    RegPluginLibrary("shop-core");

    return APLRes_Success;
}

public void OnPluginStart()
{
    // fake category
    g_iFakeCategory = UTIL_RegItemCategory("fakeCategory", false, GetMyHandle(), INVALID_FUNCTION);

    // console command
    RegConsoleCmd("sm_shop",        Command_Shop);
    RegConsoleCmd("sm_store",       Command_Shop);
    RegConsoleCmd("buyammo1",       Command_Shop);
    RegConsoleCmd("sm_inventory",   Command_Inv);

    // clients
    for(int client = 1; client <= MaxClients; ++client)
        if(IsClientConnected(client))
        {
            OnClientConnected(client);
            if(IsClientInGame(client))
                OnClientPostAdminCheck(client);
        }
}

public void OnAllPluginsLoaded()
{
    // databse and item.
    ConnectAndLoad();
}

// why use public
public void ConnectAndLoad()
{
    if(g_MySQL != null)
        return;

    char error[256];

    // connect
    g_MySQL = SQL_Connect("default", false, error, 256);
    if(g_MySQL == null)
        SetFailState("Connect to database Error. -> %s", error);

    g_MySQL.SetCharset("utf8");

    //delete old item 
    SQL_FastQuery(g_MySQL, "DELETE FROM dxg_inventory WHERE date_of_expiration < UNIX_TIMESTAMP()", 128);

    // load items
    // table: id parent type unique fullname shortname description personalId buyable giftable vipitem price0 price1 price2 price3
    DBResultSet items = SQL_Query(g_MySQL, "SELECT * FROM dxg_items ORDER BY id;", 128);
    if(items == null)
    {
        SQL_GetError(g_MySQL, error, 256);
        SetFailState("Can not retrieve items from database: %s", error);
    }

    if(items.RowCount <= 0)
        SetFailState("Can not retrieve items from database: no result row");

    while(items.FetchRow())
    {
        g_Items[g_iItems][iIndex]  = items.FetchInt(0);
        g_Items[g_iItems][iParent] = items.FetchInt(1);
        items.FetchString(2, g_Items[g_iItems][szCategory],     32);
        items.FetchString(3, g_Items[g_iItems][szUniqueId],     32);
        items.FetchString(4, g_Items[g_iItems][szFullName],    128);
        items.FetchString(5, g_Items[g_iItems][szShortName],    32);
        items.FetchString(6, g_Items[g_iItems][szDescription],  32);
        items.FetchString(7, g_Items[g_iItems][szPersonalId],  128);
        g_Items[g_iItems][bBuyable]  = (items.FetchInt( 8) == 1);
        g_Items[g_iItems][bGiftable] = (items.FetchInt( 9) == 1);
        g_Items[g_iItems][bVipItem]  = (items.FetchInt(10) == 1);
        g_Items[g_iItems][iPrice][0] = items.FetchInt(11);
        g_Items[g_iItems][iPrice][1] = items.FetchInt(12);
        g_Items[g_iItems][iPrice][2] = items.FetchInt(13);
        g_Items[g_iItems][iPrice][3] = items.FetchInt(14);

        g_iItems++;
    }
    
    delete items;
    
    UTIL_RefreshItem();
}

public void OnClientConnected(int client)
{
    g_ClientData[client][iUid] = 0;
    
    g_ClientData[client][bLoaded] = false;
    g_ClientData[client][bVip]    = false;

    g_ClientData[client][iMoney] = 0;
    g_ClientData[client][iItems] = 0;
}

public void OnClientPostAdminCheck(int client)
{
    if(IsFakeClient(client))
        return;

    char steamid[32];
    if(!GetClientAuthId(client, AuthId_SteamID64, steamid, 32, true))
    {
        KickClient(client, "系统无法获取您的SteamID");
        return;
    }

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT uid,money,spt FROM dxg_users WHERE steamid = '%s'", steamid);
    g_MySQL.Query(LoadClientCallback, m_szQuery, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
    OnClientConnected(client);
    
    if(g_ClientData[client][hTimer] != INVALID_HANDLE)
        KillTimer(g_ClientData[client][hTimer]);
    g_ClientData[client][hTimer] = INVALID_HANDLE;
}

public Action Timer_ReAuthorize(Handle timer, int client)
{
    if(!IsClientInGame(client) || g_ClientData[client][bLoaded])
        return Plugin_Stop;

    OnClientDisconnect(client);
    OnClientPostAdminCheck(client);

    return Plugin_Stop;
}

public Action Command_Shop(int client, int args)
{
    if(!IsClientInGame(client))
        return Plugin_Handled;
    
    if(!g_ClientData[client][bLoaded])
    {
        Chat(client, "\x05请等待数据加载完毕...");
        return Plugin_Handled;
    }
    
    DisplayMainMenu(client);
    
    return Plugin_Handled;
}

public Action Command_Inv(int client, int args)
{
    if(!g_ClientData[client][bLoaded])
    {
        Chat(client, "\x05请等待数据加载完毕...");
        return Plugin_Handled;
    }
    
    DisplayShopMenu(client, true);

    return Plugin_Handled;
}

public Action Timer_EarnMoney(Handle timer, int client)
{
    if(!IsClientInGame(client))
        return Plugin_Continue;
    
    if(GetClientCount(true) < 6)
    {
        Chat(client, "服务器内人数不足,需要最少6人才能获得在线时长奖励");
        return Plugin_Continue;
    }

    UTIL_EarnMoney(client, 2, "在线120秒");
    Chat(client, "\x04游戏在线时长获得奖励\x102G");
    
    return Plugin_Continue;
}