/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#file "Application.Bridge.AdminMenu.Overrides"

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
                Overrides_New(iParam1);
                return;
            }

            PrintToChat(iParam1, "%t%t", "Chat: Prefix", "Dev: TODO");
        }
    }
}

void Overrides_New(int iClient)
{
    Overrides_New_Step1(iClient);
}

void Overrides_New_Step1(int iClient)
{
    SetGlobalTransTarget(iClient);

    Menu hMenu = new Menu(Overrides_New_Step1_HandleAction, MenuAction_End|MenuAction_Cancel);
    hMenu.SetTitle("%t\n%t\n \n%t", "AdminMenu: Overrides", "Generic: Create new entry", "Override: Please fill command");
    hMenu.AddItem(NULL_STRING, NULL_STRING, ITEMDRAW_SPACER);
    g_ptrChatHandler[iClient] = Overrides_New_Step2;
    hMenu.ExitBackButton = true;
    hMenu.ExitButton = true;
    hMenu.Display(iClient, 0);
}

Action Overrides_New_Step2(int iClient, const char[] szMessage)
{
    SetGlobalTransTarget(iClient);

    Menu hMenu = new Menu(Overrides_New_Step2_HandleAction);
    hMenu.ExitBackButton = true;
    hMenu.ExitButton = true;
    hMenu.SetTitle("%t\n%t\n \n%t\n ", "AdminMenu: Overrides", "Generic: Create new entry", "Override: Select type");
    UTIL_AddMenuItem(hMenu, ITEMDRAW_DISABLED, szMessage, "%t", "Override: Filled command", szMessage);
    UTIL_AddMenuItem(hMenu, ITEMDRAW_DEFAULT, "1", "%t", "Override Type: Command");
    UTIL_AddMenuItem(hMenu, ITEMDRAW_DEFAULT, "2", "%t", "Override Type: CommandGroup");
    hMenu.Display(iClient, 0);
    return Plugin_Handled;
}

void Overrides_New_Step3(int iClient, const char[] szMessage, OverrideType eType)
{
    DataPack hPack = new DataPack();
    hPack.WriteString(szMessage);
    hPack.WriteCell(eType);

    UTIL_RenderFlagsSelectorMenu(iClient, Overrides_New_Step3_HandleAction, hPack);
}

void Overrides_NewUpdate_Finish(int iClient, const char[] szMessage, OverrideType eType, int iFlags)
{
    LogAction(iClient, -1, "Created new override %s (type %d), new required flags %d", szMessage, eType, iFlags);

    char szQuery[256];
    g_hDB.Format(szQuery, sizeof(szQuery), "INSERT INTO `uas_override` (`command`, `override_type`, `flags`) VALUES('%s', CASE %d WHEN 1 THEN 'Command' WHEN 2 THEN 'CommandGroup' END, %d) ON DUPLICATE KEY UPDATE `flags` = %d", szMessage, eType, iFlags, iFlags);
    g_hDB.Query(SQL_GlobalResultHandler, szQuery, GetClientUserId(iClient));
}

public int Overrides_New_Step1_HandleAction(Menu hMenu, MenuAction eAction, int iClient, int iCancelReason)
{
    if (eAction == MenuAction_End)
    {
        hMenu.Close();
        return;
    }

    g_ptrChatHandler[iClient] = INVALID_FUNCTION;
    if (iCancelReason == MenuCancel_ExitBack)
    {
        Overrides_Menu(iClient);
    }
}

public int Overrides_New_Step2_HandleAction(Menu hMenu, MenuAction eAction, int iClient, int iSelectedType)
{
    switch (eAction)
    {
        case MenuAction_End:    hMenu.Close();
        case MenuAction_Cancel: {
            if (iSelectedType == MenuCancel_ExitBack)
            {
                Overrides_New_Step1(iClient);
                return;
            }
        }

        case MenuAction_Select: {
            char szData[64];

            // Get command type.
            hMenu.GetItem(iSelectedType, szData, sizeof(szData));
            OverrideType eType = view_as<OverrideType>(StringToInt(szData));

            // Get command.
            hMenu.GetItem(0, szData, sizeof(szData));

            // Render 3rd step.
            Overrides_New_Step3(iClient, szData, eType);
        }
    }
}

public void Overrides_New_Step3_HandleAction(int iClient, bool bCancelled, int iFlags, DataPack hPack)
{
    char szMessage[64];
    hPack.Reset();
    hPack.ReadString(szMessage, sizeof(szMessage));
    OverrideType eType = hPack.ReadCell();
    hPack.Close();

    if (bCancelled)
    {
        Overrides_New_Step2(iClient, szMessage);
        return;
    }

    Overrides_NewUpdate_Finish(iClient, szMessage, eType, iFlags);
    Overrides_Menu(iClient);
}