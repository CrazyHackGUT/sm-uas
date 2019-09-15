/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#include <sourcemod>
#include <adminmenu>
#include <uas>

Database    g_hDB;
TopMenu     g_hAdminMenu;
//char        g_szAdministratorCode[64];

public Plugin myinfo = {
    description = "Provides interface for managing administrators",
    version     = "0.0.0.1",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[UAS] Admin",
    url         = "https://kruzya.me"
};

/**
 * @section Plugin startup events
 */
public void OnPluginStart()
{
    //RegConsoleCmd(  "sm_code",          CmdCode,                        "Provides ability to get temporary admin by random code (listed in log)");
    //RegAdminCmd(    "sm_disable_code",  CmdDisableCode, ADMFLAG_ROOT,   "Disables the ability to get temporary admin by random code"            );

    LoadTranslations("uas_admin.phrases");

    if (LibraryExists("adminmenu"))
    {
        Handle hTopMenu = GetAdminTopMenu();

        if (hTopMenu != null)
        {
            OnAdminMenuReady(hTopMenu);
        }
    }
}

public void OnAllPluginsLoaded()
{
    g_hDB = UAS_GetDatabase();
}

/**
 * @section Adminmenu integration
 */
public void OnAdminMenuReady(Handle hTopMenu)
{
    if (hTopMenu == g_hAdminMenu)
    {
        return;
    }

    g_hAdminMenu = view_as<TopMenu>(hTopMenu);
    TopMenuObject eTopObj = g_hAdminMenu.AddCategory("uas", OnCategoryDisplay, _, ADMFLAG_ROOT);

    /*
    g_hAdminMenu.AddItem("uas_admin_list",      OnAdminList,    eTopObj, "uas_admin_list",      ADMFLAG_ROOT);
    */

    g_hAdminMenu.AddItem("uas_server_list",     OnServerList,   eTopObj, "uas_server_list",     ADMFLAG_ROOT);

    /*
    g_hAdminMenu.AddItem("uas_group_list",      OnGroupList,    eTopObj, "uas_group_list",      ADMFLAG_ROOT);
    */

    g_hAdminMenu.AddItem("uas_overrides_list", OnOverridesList, eTopObj, "uas_overrides_list",  ADMFLAG_ROOT);
}

public void OnCategoryDisplay(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject eTopObj, int iParam, char[] szBuffer, int iMaxLength)
{
    switch (eAction)
    {
        case TopMenuAction_DisplayOption, TopMenuAction_DisplayTitle:   {
            FormatEx(szBuffer, iMaxLength, "%T%s", "AdminMenu: Category", iParam, eAction == TopMenuAction_DisplayTitle ? ":\n " : "");
        }
    }
}

public void OnServerList(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject eTopObj, int iParam, char[] szBuffer, int iMaxLength)
{
    switch (eAction)
    {
        case TopMenuAction_DisplayOption:   {
            FormatEx(szBuffer, iMaxLength, "%T", "AdminMenu: Servers", iParam);
        }

        case TopMenuAction_SelectOption:    {
            Servers_Menu(iParam);
        }
    }
}

public void OnOverridesList(TopMenu hTopMenu, TopMenuAction eAction, TopMenuObject eTopObj, int iParam, char[] szBuffer, int iMaxLength)
{
    switch (eAction)
    {
        case TopMenuAction_DisplayOption:   {
            FormatEx(szBuffer, iMaxLength, "%T", "AdminMenu: Overrides", iParam);
        }

        case TopMenuAction_SelectOption:    {
            Overrides_Menu(iParam);
        }
    }
}

/**
 * @section Servers
 */
void Servers_Menu(int iClient)
{
    if (!UTIL_IsReady(iClient))
    {
        return;
    }

    g_hDB.Query(Servers_OnLoaded, "SELECT `server_id`, INET_NTOA(`address`) AS `address`, `port`, `hostname` FROM `uas_server` WHERE `deleted_at` IS NULL", GetClientUserId(iClient));
}

public void Servers_OnLoaded(Database hDB, DBResultSet hResults, const char[] szError, int iClient)
{
    if ((iClient = GetClientOfUserId(iClient)) == 0)
    {
        return; // client disconnected.
    }

    if (!UTIL_IsResponseOk(hResults, iClient, szError))
    {
        return;
    }

    SetGlobalTransTarget(iClient);

    char szBuffer[256];
    Menu hMenu = new Menu(Servers_HandleAction);

    int iDisplayedServers;
    if (hResults.RowCount < 1)
    {
        FormatEx(szBuffer, sizeof(szBuffer), "%t", "Generic: No entries available");
        hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
    }
    else 
    {
        char szAddress[32];
        char szHostname[128]; // yeah, in database we store 256...

        while (hResults.FetchRow())
        {
            hResults.FetchString(1, szAddress, sizeof(szAddress));
            hResults.FetchString(3, szHostname, sizeof(szHostname));
            FormatEx(szBuffer, sizeof(szBuffer), "%t", "Server: Entry template", szHostname, szAddress, hResults.FetchInt(2));
            hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
            iDisplayedServers++;

            // TODO: add ability to see server administrators, overrides.
        }
    }

    hMenu.SetTitle("%t\n%t\n ", "AdminMenu: Servers", "AdminMenu: Showed x elements", iDisplayedServers, 1);

    hMenu.ExitBackButton = true;
    hMenu.ExitButton = true;
    hMenu.Display(iClient, 0);
}

public int Servers_HandleAction(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
    switch (eAction)
    {
        case MenuAction_End:    hMenu.Close();
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
            {
                RedisplayAdminMenu(g_hAdminMenu, iParam1);
            }
        }
    }
}

/**
 * @section Overrides
 */
void Overrides_Menu(int iClient, int iPage = 1)
{
    if (!UTIL_IsReady(iClient))
    {
        return;
    }

    DataPack hPack = new DataPack();
    hPack.WriteCell(GetClientUserId(iClient));
    hPack.WriteCell(iPage);

    char szQuery[256];
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT `override_id`, `command`, `override_type` FROM `uas_override` ORDER BY `override_type` LIMIT %d, 50", (iPage - 1) * 50);
    g_hDB.Query(Overrides_OnLoaded, szQuery, hPack);
}

public void Overrides_OnLoaded(Database hDB, DBResultSet hResults, const char[] szError, DataPack hPack)
{
    hPack.Reset();
    int iClient = GetClientOfUserId(hPack.ReadCell());
    int iPage = hPack.ReadCell();
    hPack.Close();

    if (iClient == 0)
    {
        return;
    }

    if (!UTIL_IsResponseOk(hResults, iClient, szError))
    {
        return;
    }

    SetGlobalTransTarget(iClient);

    char szBuffer[256];
    FormatEx(szBuffer, sizeof(szBuffer), "%t", "Generic: Create new entry");

    Menu hMenu = new Menu(Overrides_HandleAction);
    hMenu.AddItem("new", szBuffer);
    hMenu.AddItem(NULL_STRING, NULL_STRING, ITEMDRAW_SPACER);

    int iDisplayedOverrides = 0;
    if (hResults.RowCount < 1)
    {
        FormatEx(szBuffer, sizeof(szBuffer), "%t", "Generic: No entries available");
        hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
    }
    else
    {
        char szData[16];
        char szCommand[64];
        char szCommandType[64];
        int iCommandTypeBasePos = strcopy(szCommandType, sizeof(szCommandType), "Override Type: ");

        while (hResults.FetchRow())
        {
            IntToString(hResults.FetchInt(0), szData, sizeof(szData));
            hResults.FetchString(1, szCommand, sizeof(szCommand));
            hResults.FetchString(2, szCommandType[iCommandTypeBasePos], sizeof(szCommandType) - iCommandTypeBasePos);

            FormatEx(szBuffer, sizeof(szBuffer), "%t", "Override: Entry template", szCommandType, szCommand);
            hMenu.AddItem(szData, szBuffer);

            iDisplayedOverrides++;
        }
    }

    hMenu.SetTitle("%t\n%t\n ", "AdminMenu: Overrides", "AdminMenu: Showed x elements", iDisplayedOverrides, ((iPage - 1) * 50) + 1);

    hMenu.ExitBackButton = true;
    hMenu.ExitButton = true;
    hMenu.Display(iClient, 0);
}

public int Overrides_HandleAction(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
    switch (eAction)
    {
        case MenuAction_End:    hMenu.Close();
        case MenuAction_Cancel: {
            if (iParam2 == MenuCancel_ExitBack)
            {
                RedisplayAdminMenu(g_hAdminMenu, iParam1);
            }
        }

        case MenuAction_Select: {
            if (iParam2 == 0)
            {
                // new item
                return;
            }

            PrintToChat(iParam1, "%t%t", "Chat: Prefix", "Dev: TODO");
        }
    }
}

/**
 * @section Helpful functions
 */
bool UTIL_IsReady(int iClient)
{
    if (!g_hDB)
    {
        PrintToChat(iClient, "%t%t", "Chat: Prefix", "Chat: Database is not ready");
        return false;
    }

    return true;
}

bool UTIL_IsResponseOk(DBResultSet hResults, int iClient, const char[] szError)
{
    if (!hResults)
    {
        LogError("Database failure (%s): %s", szError);
        PrintToChat(iClient, "%t%t", "Chat: Prefix", "Chat: Database problems");
        return false;
    }

    return true;
}