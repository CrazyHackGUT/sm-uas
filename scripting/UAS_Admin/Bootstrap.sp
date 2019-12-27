/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#file "Application.Bootstrap"

/**
 * @section Plugin startup events
 */
public void OnPluginStart()
{
    g_hAdministratorFlags = UTIL_InitializeAdminFlags();
    //RegConsoleCmd(  "sm_code",          CmdCode,                        "Provides ability to get temporary admin by random code (listed in log)");
    //RegAdminCmd(    "sm_disable_code",  CmdDisableCode, ADMFLAG_ROOT,   "Disables the ability to get temporary admin by random code"            );

    LoadTranslations("core.phrases");
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