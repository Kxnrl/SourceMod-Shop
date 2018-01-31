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

#define PI_NAME "MagicGirl.NET - Shop :: Core [DARLING IN THE FRANXX]"
#define PI_AUTH "Kyle"
#define PI_DESC "In-game Shop for MagicGirl.NET"
#define PI_VERS "<commit-count>"
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
    Function:fnMenuInventory,
    Function:fnMenuPreview
}

enum Item_Data
{
    iPrice[4],
    iParent,
    bool:bBuyable,
    bool:bGiftable,
    bool:bVipItem,
    String:szFullName[128],
    String:szShrotName[32],
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
    bool:bLoaded
}

any g_ClientData[MAXPLAYERS+1][Client_Data];
any g_ClientItem[MAXPLAYERS+1][MAX_ITEMS][Client_Item];
any g_Items[MAX_ITEMS][Item_Data];
any g_Category[MAX_ITEM_CATEGORY][Item_Categories];

int g_iItems;
int g_iCategories;
int g_iFakeCategory;

Database g_MySQL;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(late)
    {
        strcopy(error, err_max, "Late load this plugin is not allowed.");
        return APLRes_Failure;
    }
    
    Native_AskPluginLoad2();

    RegPluginLibrary("mg-shop");

    return APLRes_Success;
}

public void OnPluginStart()
{
    // databse ann item.
    ConnectAndLoad();

    // fake category
    g_iFakeCategory = UTIL_RegItemCategory("fakeCategory", false, INVALID_FUNCTION, INVALID_FUNCTION);

    // console command
    RegConsoleCmd("sm_shop",        Command_Shop);
    RegConsoleCmd("sm_store",       Command_Shop);
    RegConsoleCmd("sm_inventory",   Command_Inv);
}

// why use public
public void ConnectAndLoad()
{
    char error[256];
    g_MySQL = SQL_Connect("csgo", false, error, 256);
    if(g_MySQL == null)
        SetFailState("Connect to database Error.");

    g_MySQL.SetCharset("utf8");

    //delete old item 
    SQL_FastQuery(g_MySQL, "DELETE FROM dxg_inventory WHERE date_of_expiration < UNIX_TIMESTAMP()", 128);

    // load items
    // table: id parent unique fullname shortname description personalId buyable giftable vipitem price0 price1 price2 price3
    DBResultSet items = SQL_Query(g_MySQL, "SELECT * FROM store_item_parent ORDER BY id;", 128);
    if(itemsitems == INVALID_HANDLE)
    {
        char error[512];
        SQL_GetError(g_hDatabase, error, 512);
        SetFailState("Can not retrieve items from database: %s", error);
    }

    if(items.RowCount <= 0)
        SetFailState("Can not retrieve items from database: no result row");

    while(items.FetchRow())
    {
        char fullname[128], shortname[32], unique[32], description[128], personal[128];
        
        
    }
}

public void OnClientConnected(int client)
{
    g_ClientData[client][bLoaded] = false;

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

    char m_szQuery[64];
    FormatEx(m_szQuery, 64, "SELECT uid,money,spt FROM dxg_users WHERE uid = '%s'", steamid);
    g_MySQL.Query(LoadClientCallback, m_szQuery, GetClientUserId(client));
}

public Action Timer_ReAuthorize(Handle timer, int client)
{
    if(!IsClientInGame(client) || g_ClientData[client][bLoaded])
        return Plugin_Stop;

    OnClientConnected(client);
    OnClientPostAdminCheck(client);

    return Plugin_Stop;
}
