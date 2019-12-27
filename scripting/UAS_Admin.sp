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

#file "Application.Core"

Database    g_hDB;
TopMenu     g_hAdminMenu;
Function    g_ptrChatHandler[MAXPLAYERS+1];
StringMap   g_hAdministratorFlags;
//char        g_szAdministratorCode[64];

public Plugin myinfo = {
    description = "Provides interface for managing administrators",
    version     = "0.0.0.3",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[UAS] Admin",
    url         = "https://kruzya.me"
};

/**
 * @section Global SQL callback
 */
public void SQL_GlobalResultHandler(Database hDB, DBResultSet hResults, const char[] szError, any iSqlCode)
{
    if (hResults)
    {
        return;
    }

    LogError("SQL_GlobalResultHandler: %d -> %s", iSqlCode, szError);
}

#include "UAS_Admin/Bootstrap.sp"

#include "UAS_Admin/FlagSelector.sp"
#include "UAS_Admin/AdminMenu.sp"
#include "UAS_Admin/Listener.sp"
#include "UAS_Admin/UTIL.sp"
