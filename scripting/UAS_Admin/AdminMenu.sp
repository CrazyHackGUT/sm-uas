/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#file "Application.Bridge.AdminMenu"

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
    g_hAdminMenu.AddItem("uas_list",      OnAdminList,    eTopObj, "uas_list",      ADMFLAG_ROOT);
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

// #include "UAS_Admin/AdminMenu/Admins.sp"
#include "UAS_Admin/AdminMenu/Servers.sp"
// #include "UAS_Admin/AdminMenu/Groups.sp"
#include "UAS_Admin/AdminMenu/Overrides.sp"
