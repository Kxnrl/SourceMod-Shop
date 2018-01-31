bool UTIL_RegItemCategory(const char[] type, bool equip, Fcuntion inventory, Function preview)
{
    int index = UTIL_FindCategoryByType(type);

    if(index != -1)
        return true;

    index = g_iCategories;
    
    strcopy(g_Category[index][szType], 32, type);
    g_Category[index][bEquipable] = equip;
    g_Category[index][hPlugin] = plugin;
    g_Category[index][fnMenuInventory] = inventory;
    g_Category[index][fnMenuPreview] = preview;

    g_iCategories++;
}

int UTIL_FindCategoryByType(const char[] type)
{
    for(int i = 0; i < g_iCategories; ++i)
        if(strcmp(type, g_Category[i][szType]) == 0)
            return i;
    return -1;
}

int UTIL_FindItemByUniqueId(const char[] uniqueId)
{
    for(int i = 0; i < g_iItems; ++i)
        if(strcmp(uniqueId, g_Items[i][szUniqueId]) == 0)
            return i;
    return -1;
}

bool UTIL_HasClientItem(int client, const char[] uniqueId)
{
    if(!g_ClientData[client][bLoaded])
        return false;
    
    int itemid = UTIL_FindItemByUniqueId(uniqueId);
    
    if(itemid == -1)
        return false;
    
    if(g_Items[itemid][bVipItem])
        return g_ClientData[client][bVip];
    
    if(g_Items[itemid][szPersonalId][0] != '\0')
    {
        char m_szUserId[12];
        IntToString(g_ClientData[client][iUid], m_szUserId, 12);
        return (StrContains(g_Items[itemid][szPersonalId], m_szUserId) != -1);
    }
    
    if(UTIL_IsItemFreeForAll(itemid))
        return true;

    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(itemid == g_ClientItem[client][i][iItemIndex])
        {
            if(g_ClientItem[client][i][iDateOfExpiration] == 0 || g_ClientItem[client][i][iDateOfExpiration] > GetTime())
                return true;
            break;
        }

    return false;
}

int UTIL_GetDateofExpiration(int client, int itemid)
{
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iDateOfExpiration];

    return -1;
}

int UTIL_GetDateOfPurchase(int client, int itemid)
{
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iDateOfPurchase];

    return -1;
}

int UTIL_GetCostofPurchase(int client, int itemid)
{
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iCost];

    return -1;
}

bool UTIL_EarnMoney(int client, int earn, const char[] reason)
{
    g_ClientData[client][iMoney] += earn;
    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "UPDATE dxg_users SET money=money+%d WHERE uid=%d", earn, g_ClientData[client][iUid]);
    UTIL_SQLNoCallback(m_szQuery, 128);
    UTIL_DBLogging(client, earn, reason);
    return true;
}

bool UTIL_CostMoney(int client, int cost, const char[] reason)
{
    g_ClientData[client][iMoney] -= cost;
    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "UPDATE dxg_users SET money=money-%d WHERE uid=%d", cost, g_ClientData[client][iUid]);
    UTIL_SQLNoCallback(m_szQuery, 128);
    UTIL_DBLogging(client, -cost, reason);
    return true;
}

void UTIL_DBLogging(int client, int money, const char[] reason)
{
    char eR[256], m_szQuery[512];
    g_MySQL.Escape(reason, eR, 256);
    FormatEx(m_szQuery, 512, "INSERT INTO dxg_banklog VALUES (DEFAULT, %d, %d, '%s', %d)", g_ClientData[client][iUid], money, eR, GetTime());
    UTIL_SQLNoCallback(m_szQuery, 512);
}

void UTIL_SQLNoCallback(const char[] m_szQuery, int maxLen)
{
    DataPack pack = new DataPack();
    pack.WriteCell(maxLen);
    pack.WriteString(m_szQuery);
    pack.Reset();

    g_MySQL.Query(QueryNoCallback, m_szQuery, pack);
}

void UTIL_BuyItem(int client, int cost, const char[] unique, Handle plugin, Fcuntion callback)
{
    if(!g_ClientData[client][bLoaded])
        return;

    if(cost > g_ClientData[client][iMoney])
        return;

    if(UTIL_HasClientItem(client, unique))
        return;

    int itemid = UTIL_FindItemByUniqueId(unique);
    if(itemid == -1)
        return;

    int length = UTIL_GetLengthByPrice(itemid, cost);
    if(length == -1)
        return;

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(cost);
    pack.WriteString(unique);
    pack.WriteCell(length);
    pack.WriteCell(plugin);
    pack.WriteFunction(callback);
    pack.Reset();
    
    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "CALL `shop_buyItem` (%d, '%s', %d, %d, 'Purchase %s.%s');", g_ClientData[client][iUid], unique, cost, length != 0 ? GetTime()+length : 0, g_Category[g_Items[itemid][iTypeIndex]][szType], g_Items[itemid][szShrotName]);
    g_MySQL.Query(BuyItemCallback, m_szQuery, pack, DBPrio_High);
}

void UTIL_SellItem(int client, const char[] unique, Handle plugin, Function callback)
{
    int itemid = UTIL_FindItemByUniqueId(unique);
    if(itemid == -1)
        return;
    
    if(UTIL_IsItemFreeForAll(itemid))
        return;
    
    if(UTIL_AllowItemForSelling(itemid))
        return;

    int cost = UTIL_GetCostofPurchase(client, itemid);
    if(cost == -1)
        return;

    int length = UTIL_GetLengthByPrice(itemid, cost);
    if(length == -1)
        return;

    int left = UTIL_GetItemRemainingTime(client, itemid);
    if(left == -1)
        return;
    
    int earn = UTIL_SellingForEarning(itemid, length, left, cost);
    if(earn == -1)
        return;
    
    int dbIndex = UTIL_GetClientItemDbIndex(client, itemid);
    if(dbIndex == -1)
        return;

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteString(unique);
    pack.WriteCell(plugin);
    pack.WriteFunction(callback);
    pack.Reset();

    // sql PROCEDURE
    char m_szQuery[256];
    FormatEx(m_szQuery, 256, "CALL `shop_sellItem` (%d, %d, %d, 'sell %s.%s');", g_ClientData[client][iUid], dbIndex, earn, g_Category[g_Items[itemid][iTypeIndex]][szType], g_Items[itemid][szShrotName]);
    g_MySQL.Query(SellItemCallback, m_szQuery, pack, DBPrio_High);
}


bool UTIL_IsItemFreeForAll(int itemid)
{
    return (g_Items[itemid][bBuyable] && g_Items[itemid][iPrice][0] == 0 && g_Items[itemid][iPrice][1] == 0 && g_Items[itemid][iPrice][2] == 0 && g_Items[itemid][iPrice][3] == 0)
}

bool UTIL_AllowItemForSelling(int itemid)
{
    if(g_Items[itemid][bVipItem])
        return false;
    
    if(g_Items[itemid][szPersonalId][0] != '\0')
        return false;
    
    return true;
}

int UTIL_GetLengthByPrice(int itemid, int cost)
{
    int index = -1;
    for(int i = 0; i < 4; ++i)
        if(g_Items[itemid][iPrice][i] == cost)
            index = i;
    
    switch(index)
    {
        case 3 : return 0;
        case 2 : return 2592000;
        case 1 : return  604800;
        case 0 : return   86400;
    }

    return -1;
}

int UTIL_GetItemRemainingTime(int client, int itemid)
{
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(itemid == g_ClientItem[client][i][iItemIndex])
        {
            if(g_ClientItem[client][i][iDateOfExpiration] == 0)
                return 0;
            
            if(g_ClientItem[client][i][iDateOfExpiration] <= GetTime())
                return -1;
            
            return g_ClientItem[client][i][iDateOfExpiration] - GetTime();
        }
        
    return -1;
}

int UTIL_GetCostofPurchase(int client, int itemid)
{
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iCost];

    return -1;
}

int UTIL_SellingForEarning(int itemid, int length, int left, int cost)
{
    if(left == 0)
        return RoundToFloor(cost * 0.6);
    
    float per = (float(left)/float(length));
    
    return RoundToFloor(cost * 0.6 * per);
}

int UTIL_GetClientItemDbIndex(int client, int itemid)
{
    for(int i = 0; i < g_ClientData[client][iItems]; ++i)
        if(g_ClientItem[client][i][iItemIndex] == itemid)
            return g_ClientItem[client][i][iDbIndex];
        
    return -1;
}
