/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#file "Application.Utilities"

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

void UTIL_FormatTime(int iClient, char[] szOutput, int iBufferSize, int iTimestamp = -1)
{
    // Set global translation target.
    SetGlobalTransTarget(iClient);

    // Build buffer with datetime format.
    char szBuffer[64];
    FormatEx(szBuffer, sizeof(szBuffer), "%t", "Locale: DateTime format");
    FormatTime(szOutput, iBufferSize, szBuffer, iTimestamp);
}

void UTIL_AddMenuItem(Menu hMenu, int iStyle, const char[] szData, const char[] szFormatString, any ...)
{
    char szViewableBuffer[512];
    VFormat(szViewableBuffer, sizeof(szViewableBuffer), szFormatString, 5);

    hMenu.AddItem(szData, szViewableBuffer, iStyle);
}
