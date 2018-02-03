/******************************************************************/
/*                                                                */
/*                  MagicGirl.NET Shop System                     */
/*                                                                */
/*                                                                */
/*  File:          native.sp                                      */
/*  Description:   A new Shop system for source game.             */
/*                                                                */
/*                                                                */
/*  Copyright (C) 2018  Kyle                                      */
/*  2017/02/01 11:37:14                                           */
/*                                                                */
/*  This code is licensed under the Apache License.               */
/*                                                                */
/******************************************************************/


void Native_AskPluginLoad2()
{
    //global
    CreateNative("MG_Shop_RegItemCategory",             Native_RegItemCategory);
    CreateNative("MG_Shop_RemoveItemCategory",          Native_RemoveItemCategory);
    CreateNative("MG_Shop_GetItemIndex",                Native_GetItemIndex);

    //client
    CreateNative("MG_Shop_HasClientItem",               Native_HasClientItem);
    CreateNative("MG_Shop_ClientGetDateofExpiration",   Native_GetDateofExpiration);
    CreateNative("MG_Shop_ClientGetDateofPurchase",     Native_GetDateofPurchase);
    CreateNative("MG_Shop_ClientGetCostofPurchase",     Native_GetCostofPurchase);
    
    CreateNative("MG_Shop_GetClientMoney",              Native_GetClientMoney);
    CreateNative("MG_Shop_ClientEarnMoney",             Native_ClientEarnMoney);
    CreateNative("MG_Shop_ClientCostMoney",             Native_ClientCostMoney);
    
    CreateNative("MG_Shop_ClientBuyItem",               Native_ClientBuyItem);
    CreateNative("MG_Shop_ClientSellItem",              Native_ClientSellItem);
    //CreateNative("MG_Shop_ClientGiftItem",              Native_ClientGiftItem);

    //menu
    CreateNative("MG_Shop_BuyItemMenu",                 Native_BuyItemMenu);
    CreateNative("MG_Shop_DisplayPreviousMenu",         Native_DisplayPreviousMenu);
}

public int Native_RegItemCategory(Handle plugin, int numParams)
{
    char m_szType[32];
    if(GetNativeString(1, m_szType, 32) != SP_ERROR_NONE)
        return false;

    return UTIL_RegItemCategory(m_szType, GetNativeCell(2), plugin, GetNativeFunction(3));
}

public int Native_RemoveItemCategory(Handle plugin, int numParams)
{
    char m_szType[32];
    if(GetNativeString(1, m_szType, 32) != SP_ERROR_NONE)
        return false;
    
    int category = UTIL_FindCategoryByType(m_szType);
    if(category == -1)
        return true;
    
    g_Category[category][bRemoved] = true;
    
    UTIL_RefreshItem();

    return true;
}

public int Native_GetItemIndex(Handle plugin, int numParams)
{
    char m_szUniqueId[32];
    if(GetNativeString(1, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;

    return UTIL_FindItemByUniqueId(m_szUniqueId);
}

public int Native_HasClientItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if(!IsClientInGame(client))
        return false;
    
    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return false;

    return UTIL_HasClientItem(client, m_szUniqueId);
}

public int Native_GetDateofExpiration(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;
    
    int itemid = UTIL_FindItemByUniqueId(m_szUniqueId);
    
    if(itemid == -1)
        return -1;

    return UTIL_GetDateofExpiration(client, itemid);
}

public int Native_GetDateofPurchase(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;

    int itemid = UTIL_FindItemByUniqueId(m_szUniqueId);
    
    if(itemid == -1)
        return -1;

    return UTIL_GetDateOfPurchase(client, itemid);
}

public int Native_GetCostofPurchase(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    char m_szUniqueId[32];
    if(GetNativeString(2, m_szUniqueId, 32) != SP_ERROR_NONE)
        return -1;
    
    int itemid = UTIL_FindItemByUniqueId(m_szUniqueId);
    
    if(itemid == -1)
        return -1;

    return UTIL_GetCostofPurchase(client, itemid);
}

public int Native_GetClientMoney(Handle plugin, int numParams)
{
    return g_ClientData[GetNativeCell(1)][iMoney];
}

public int Native_ClientEarnMoney(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if(!g_ClientData[client][bLoaded])
        return false;
    
    char reason[128];
    if(GetNativeString(3, reason, 128) != SP_ERROR_NONE)
        return false;
    
    return UTIL_EarnMoney(client, GetNativeCell(2), reason);
}

public int Native_ClientCostMoney(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if(!g_ClientData[client][bLoaded])
        return false;
    
    int cost = GetNativeCell(2);
    if(cost > g_ClientData[client][iMoney])
        return false;

    char reason[128];
    if(GetNativeString(3, reason, 128) != SP_ERROR_NONE)
        return false;

    return UTIL_CostMoney(client, cost, reason);
}

public int Native_ClientBuyItem(Handle plugin, int numParams)
{
    char unique[32];
    if(GetNativeString(3, unique, 32) != SP_ERROR_NONE)
        return;

    UTIL_BuyItem(GetNativeCell(1), GetNativeCell(2), unique, plugin, GetNativeFunction(4));
}

public int Native_ClientSellItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if(!g_ClientData[client][bLoaded])
        return;

    char unique[32];
    if(GetNativeString(2, unique, 32) != SP_ERROR_NONE)
        return;

    UTIL_SellItem(client, unique, plugin, GetNativeFunction(3));
}

public int Native_BuyItemMenu(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if(!g_ClientData[client][bLoaded])
        return;
    
    char unique[32];
    if(GetNativeString(2, unique, 32) != SP_ERROR_NONE)
        return;
    
    Chat(client, "暂时不开放购买功能...");
}

public int Native_DisplayPreviousMenu(Handle plugin, int numParams)
{
    DisplayPreviousMenu(GetNativeCell(1));
}