/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#file "Application.Bridge.AdminMenu.Servers"

/**
 * @section Servers
 */
void Servers_Menu(int iClient)
{
    if (!UTIL_IsReady(iClient))
    {
        return;
    }

    g_hDB.Query(Servers_OnLoaded, "SELECT `server_id`, INET_NTOA(`address`) AS `address`, `port`, `hostname`, `synced_at`, COUNT(*) AS `total` FROM `uas_server` WHERE `deleted_at` IS NULL", GetClientUserId(iClient));
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
        char szSyncDate[48];

        while (hResults.FetchRow())
        {
            hResults.FetchString(1, szAddress, sizeof(szAddress));
            hResults.FetchString(3, szHostname, sizeof(szHostname));
            UTIL_FormatTime(iClient, szSyncDate, sizeof(szSyncDate), hResults.FetchInt(4));

            FormatEx(szBuffer, sizeof(szBuffer), "%t", "Server: Entry template", szHostname, szAddress, hResults.FetchInt(2), szSyncDate);
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
