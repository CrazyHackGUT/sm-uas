/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#file "Application.ThirdParty->FlagSelector"

StringMap UTIL_InitializeAdminFlags()
{
    StringMap hMap = new StringMap();

    hMap.SetValue("Reservation",    ADMFLAG_RESERVATION);
    hMap.SetValue("Generic",        ADMFLAG_GENERIC);
    hMap.SetValue("Kick",           ADMFLAG_KICK);
    hMap.SetValue("Ban",            ADMFLAG_BAN);
    hMap.SetValue("Unban",          ADMFLAG_UNBAN);
    hMap.SetValue("Slay",           ADMFLAG_SLAY);
    hMap.SetValue("Changemap",      ADMFLAG_CHANGEMAP);
    hMap.SetValue("Convars",        ADMFLAG_CONVARS);
    hMap.SetValue("Config",         ADMFLAG_CONFIG);
    hMap.SetValue("Chat",           ADMFLAG_CHAT);
    hMap.SetValue("Vote",           ADMFLAG_VOTE);
    hMap.SetValue("Password",       ADMFLAG_PASSWORD);
    hMap.SetValue("RCON",           ADMFLAG_RCON);
    hMap.SetValue("Cheats",         ADMFLAG_CHEATS);
    hMap.SetValue("Root",           ADMFLAG_ROOT);
    hMap.SetValue("Custom1",        ADMFLAG_CUSTOM1);
    hMap.SetValue("Custom2",        ADMFLAG_CUSTOM2);
    hMap.SetValue("Custom3",        ADMFLAG_CUSTOM3);
    hMap.SetValue("Custom4",        ADMFLAG_CUSTOM4);
    hMap.SetValue("Custom5",        ADMFLAG_CUSTOM5);
    hMap.SetValue("Custom6",        ADMFLAG_CUSTOM6);

    return hMap;
}

void UTIL_RenderFlagsSelectorMenu(int iClient, Function ptrCallback, any data = 0, int iSelectedFlags = 0)
{
    SetGlobalTransTarget(iClient);

    Menu hMenu = UTIL_GetFlagsSelectorMenu(iSelectedFlags, ptrCallback, data);
    hMenu.Display(iClient, 0);
}

Menu UTIL_GetFlagsSelectorMenu(int iSelectedFlags = 0, Function ptrHandler = INVALID_FUNCTION, any data = 0)
{
    Menu hMenu = new Menu(FlagSelector_Handler, MenuAction_Select | MenuAction_Cancel | MenuAction_DisplayItem);
    hMenu.SetTitle("%t\n ", "AdminMenu: AdminFlags Selector");
    hMenu.Pagination = 6; // 6 flags per page

    StringMap hFlags = g_hAdministratorFlags;
    StringMapSnapshot hSnapshot = hFlags.Snapshot();
    int iFlagsCount = hFlags.Size;

    int iFlagBit; char szTranslationName[32], szData[16];
    for (int iFlag = 0; iFlag < iFlagsCount; ++iFlag)
    {
        hSnapshot.GetKey(iFlag, szTranslationName, sizeof(szTranslationName));
        hFlags.GetValue(szTranslationName, iFlagBit);
        IntToString(iFlagBit, szData, sizeof(szData));

        hMenu.AddItem(szData, szTranslationName, ITEMDRAW_DEFAULT);
    }

    hSnapshot.Close();
    IntToString(iSelectedFlags, szData, sizeof(szData));

    UTIL_AddMenuItem(hMenu, ITEMDRAW_SPACER, NULL_STRING, NULL_STRING);
    UTIL_AddMenuItem(hMenu, ITEMDRAW_DEFAULT, "save", "%t", "Generic: Confirm");

    hMenu.AddItem(szData, NULL_STRING, ITEMDRAW_IGNORE); // 1 - old flags
    hMenu.AddItem(szData, NULL_STRING, ITEMDRAW_IGNORE); // 2 - new flags

    DataPack hPack = new DataPack();
    hPack.WriteFunction(ptrHandler);
    hPack.WriteCell(data);
    IntToString(view_as<int>(hPack), szData, sizeof(szData));
    hMenu.AddItem(szData, NULL_STRING, ITEMDRAW_IGNORE);

    hMenu.ExitBackButton = true;
    hMenu.ExitButton = true;

    return hMenu;
}

static int FlagSelector_Handler(Menu hMenu, MenuAction eAction, int iParam1, int iParam2)
{
    // SM BUG? This handler called after menu closing, MenuAction_End is disabled.
    // int iItemCount = hMenu.ItemCount;
    /*
L 09/20/2019 - 18:15:37: [SM] Exception reported: Menu handle 3cbf3bc6 is invalid (error 3)
L 09/20/2019 - 18:15:37: [SM] Blaming: UAS_Admin.smx
L 09/20/2019 - 18:15:37: [SM] Call stack trace:
L 09/20/2019 - 18:15:37: [SM]   [0] Menu.ItemCount.get
L 09/20/2019 - 18:15:37: [SM]   [1] Line 573, UAS_Admin.sp::FlagsSelectorHandler
    */
    switch (eAction)
    {
        case MenuAction_Cancel:         {
            char szOldFlags[16];
            int iItemCount = hMenu.ItemCount;

            int iOldFlagId = iItemCount - 3;
            int iFunctionId = iItemCount - 1;

            // Get flags.
            hMenu.GetItem(iOldFlagId, szOldFlags, sizeof(szOldFlags));
            int iFlags = StringToInt(szOldFlags);

            // Get function ptr and call.
            hMenu.GetItem(iFunctionId, szOldFlags, sizeof(szOldFlags));
            DataPack hPack = view_as<DataPack>(StringToInt(szOldFlags));
            hPack.Reset();
            Call_StartFunction(null, hPack.ReadFunction());
            Call_PushCell(iParam1);
            Call_PushCell(1);
            Call_PushCell(iFlags);
            Call_PushCell(hPack.ReadCell());
            Call_Finish();
            hPack.Close();
            hMenu.Close();
        }

        case MenuAction_Select:         {
            char szNewFlags[16];
            int iItemCount = hMenu.ItemCount;

            // Check "Save" button.
            if ((iItemCount-4) == iParam2)
            {
                // Get flags.
                hMenu.GetItem(iItemCount - 2, szNewFlags, sizeof(szNewFlags));
                int iFlags = StringToInt(szNewFlags);

                // Get function ptr and call.
                hMenu.GetItem(iItemCount - 1, szNewFlags, sizeof(szNewFlags));
                DataPack hPack = view_as<DataPack>(StringToInt(szNewFlags));
                hPack.Reset();
                Call_StartFunction(null, hPack.ReadFunction());
                Call_PushCell(iParam1);
                Call_PushCell(0);
                Call_PushCell(iFlags);
                Call_PushCell(hPack.ReadCell());
                Call_Finish();
                hPack.Close();
                hMenu.Close();
                return 0;
            }

            int iNewFlagId = iItemCount - 2;

            // Get flags.
            hMenu.GetItem(iNewFlagId, szNewFlags, sizeof(szNewFlags));
            int iFlags = StringToInt(szNewFlags);

            // Add/Remove new flag to bitsumm.
            char szDisplayBuffer[48];
            hMenu.GetItem(iParam2, szNewFlags, sizeof(szNewFlags), _, szDisplayBuffer, sizeof(szDisplayBuffer));
            iFlags ^= StringToInt(szNewFlags);
            IntToString(iFlags, szNewFlags, sizeof(szNewFlags));

            // Set new flags to menu.
            hMenu.RemoveItem(iNewFlagId);
            hMenu.InsertItem(iNewFlagId, szNewFlags, szDisplayBuffer, ITEMDRAW_IGNORE);

            // Render menu repeatedly.
            hMenu.DisplayAt(iParam1, GetMenuSelectionPosition(), 0);
        }

        case MenuAction_DisplayItem:    {
            int iStyle;
            char szData[32];
            char szViewableBuffer[64];
            int iItemCount = hMenu.ItemCount;

            int iPos = strcopy(szViewableBuffer, sizeof(szViewableBuffer), "AdminFlag: ");
            hMenu.GetItem(iParam2, szData, sizeof(szData), iStyle, szViewableBuffer[iPos], sizeof(szViewableBuffer)-iPos);

            if (iStyle == ITEMDRAW_DEFAULT || (iItemCount-6) > iParam2)
            {
                char szCurrentFlags[16];
                hMenu.GetItem(hMenu.ItemCount - 2, szCurrentFlags, sizeof(szCurrentFlags));
                int iCurrentFlags = StringToInt(szCurrentFlags);
                int iRenderableFlag = StringToInt(szData);
                bool bChecked = ((iCurrentFlags & iRenderableFlag) == iRenderableFlag);

                SetGlobalTransTarget(iParam1);
                Format(szViewableBuffer, sizeof(szViewableBuffer), "%t", "AdminMenu: Item selector", (bChecked ? "X" : " "), szViewableBuffer);

                return RedrawMenuItem(szViewableBuffer);
            }

            return iParam2;
        }
    }

    return 0;
}