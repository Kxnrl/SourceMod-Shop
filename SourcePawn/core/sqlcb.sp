
public void LoadClientCallback(Database db, DBResultSet results, const char[] error, int uid)
{
    int client = GetClientOfUserId(uid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "LoadClientCallback -> SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    if(results.RowCount <= 0 || results.FetchRow())
    {
        KickClient(client, "系统无法获取您的数据");
        return;
    }

    g_ClientData[client][bLoaded] = true;
    g_ClientData[client][iUid]    = results.FetchInt(0);
    g_ClientData[client][iMoney]  = results.FetchInt(1);
    g_ClientData[client][bVip]    = (results.FetchInt(2) == 1);

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT * FROM dxg_inventory WHERE uid = %d AND date_of_expiration > %d", g_ClientData[client][iUid], GetTime());
    g_MySQL.Query(LoadInventoryCallback, m_szQuery, uid);
}

public void LoadInventoryCallback(Database db, DBResultSet results, const char[] error, int uid)
{
    int client = GetClientOfUserId(uid);
    if(!client)
        return;

    if(results == null || error[0])
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "LoadClientCallback -> SQL Error:  %s -> \"%L\"", error, client);
        CreateTimer(5.0, Timer_ReAuthorize, client, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    if(results.RowCount <= 0)
        return;

    int items = 0;
    char unique[32];
    while(results.FetchRow())
    {
        results.FetchString(2, unique, 32);
        
        g_ClientItem[client][items][iItemIndex] = UTIL_FindItemByUniqueId(unique);
        
        if(g_ClientItem[client][items][iItemIndex] == -1)
            continue;
        
        g_ClientItem[client][items][iDbIndex]           = results.FetchInt(0);
        g_ClientItem[client][items][iCost]              = results.FetchInt(3);
        g_ClientItem[client][items][iDateOfPurchase]    = results.FetchInt(4);
        g_ClientItem[client][items][iDateOfExpiration]  = results.FetchInt(5);
        
        items++;
        
        LogMessage("Load %N item -> %s -> %s", client, unique, g_Items[g_ClientItem[client][items][iItemIndex]][szFullName]);
    }
    
    g_ClientData[client][iItems] = items;
}

public void BuyItemCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    int client = GetClientOfUserId(pack.ReadCell());
    int cost   = pack.ReadCell();
    char unique[32];
    pack.ReadString(unique, 32);
    int length = pack.ReadCell();
    Handle plugin = pack.ReadCell();
    Function callback = pack.ReadFunction();
    delete pack;

    if(results == null || error[0])
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "BuyItemCallback -> SQL Error:  %s -> %N -> %d -> %s -> %d -> %d", error, client, cost, unique, length);
        return;
    }

    if(!client)
        return;
    
    if(!results.FetchRow())
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "BuyItemCallback -> SQL Error:  Can not fetch row -> %N -> %d -> %s -> %d -> %d", client, cost, unique, length);
        return;
    }
    
    int dbIndex = results.FetchInt(0);
    int logCost = results.FetchInt(1);
    
    if(dbIndex <= 0)
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "BuyItemCallback -> SQL Error:  dbIndex failed -> %N -> %d -> %s -> %d -> %d", client, cost, unique, length);
        return;
    }
    
    g_ClientData[client][iMoney] += logCost;

    int items = g_ClientData[client][iItems];
    
    g_ClientItem[client][items][iItemIndex] = UTIL_FindItemByUniqueId(unique);

    if(g_ClientItem[client][items][iItemIndex] != -1)
    {
        g_ClientItem[client][items][iDbIndex]           = dbIndex;
        g_ClientItem[client][items][iCost]              = cost;
        g_ClientItem[client][items][iDateOfPurchase]    = GetTime();
        g_ClientItem[client][items][iDateOfExpiration]  = length != 0 ? GetTime()+length : 0;
        
        g_ClientData[client][iItems]++;
    }

    if(callback != INVALID_FUNCTION)
    {
        Call_StartFunction(plugin, callback);
        Call_PushCell(client);
        Call_PushCell(cost);
        Call_PushString(unique);
        Call_Finish();
    }
}

public void SellItemCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    int client = GetClientOfUserId(pack.ReadCell());
    char unique[32];
    pack.ReadString(unique, 32);
    Handle plugin = pack.ReadCell();
    Function callback = pack.ReadFunction();
    delete pack;

    if(results == null || error[0])
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "SellItemCallback -> SQL Error:  %s -> %N -> %s", error, client, unique);
        return;
    }

    if(!client)
        return;
    
    if(!results.FetchRow())
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "SellItemCallback -> SQL Error:  Can not fetch row -> %N -> %s", client, unique);
        return;
    }

    int price = results.FetchInt(0);
    int ecode = results.FetchInt(1);

    if(ecode != 0)
    {
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "SellItemCallback -> SQL Error:  err_code is %d -> %N -> %s", ecode, client, unique);
        return;
    }

    g_ClientData[client][iMoney] += price;

    int itemid = UTIL_FindItemByUniqueId(unique);
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(itemid == g_ClientItem[client][i][iItemIndex])
            g_ClientItem[client][i][iDateOfExpiration] = -1;
        
    if(callback != INVALID_FUNCTION)
    {
        Call_StartFunction(plugin, callback);
        Call_PushCell(client);
        Call_PushCell(price);
        Call_PushString(unique);
        Call_Finish();
    }
}

public void QueryNoCallback(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if(results == null || error[0] || results.AffectedRows == 0)
    {
        int maxLen = pack.ReadCell();
        char[] m_szQueryString = new char[maxLen];
        pack.ReadString(m_szQueryString, maxLen);
        LogToFileEx("addons/sourcemod/logs/MagicGirl.Net/Shop_err.log", "LoadInventoryCallback -> SQL Error: %s\nQuery: %s", (results == null || error[0]) ? error : "No affected row", m_szQueryString);
    }

    delete pack;
}