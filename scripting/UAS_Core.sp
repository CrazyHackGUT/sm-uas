/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#include <sourcemod>

KeyValues   g_hConfiguration;
Database    g_hDB;

int         g_iServerID;

bool        g_bReady;
bool        g_bRequiredAdmins;

bool        g_bLoading[AdminCachePart];
int         g_iSequence[AdminCachePart];

// Enable this if you have something problems with queries and you want profile him.
// #define _UAS_DEBUG 1

#if defined _UAS_DEBUG
#define SQL_ExecuteQuery(%0,%1,%2,%3,%4)    LogMessage(%4), g_hDB.Query(%0,%1,%2,%3)
#else
#define SQL_ExecuteQuery(%0,%1,%2,%3,%4)    g_hDB.Query(%0,%1,%2,%3)
#endif

public Plugin myinfo = {
    description = "Performs a operation for loading administrators and groups",
    version     = "1.0.0.5",
    author      = "CrazyHackGUT aka Kruzya",
    name        = "[UAS] Core",
    url         = "https://kruzya.me"
};

/**
 * @section API
 */
public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] szBuffer, int iBufferLength)
{
    // Natives
    CreateNative("UAS_GetDatabase",         Native_GetDatabase);
    CreateNative("UAS_GetConfiguration",    Native_GetConfiguration);

    RegPluginLibrary("uas");
}

public int Native_GetDatabase(Handle hPlugin, int iNumParams)
{
    return view_as<int>(APIUTIL_CloneHandle(g_hDB, hPlugin));
}

public int Native_GetConfiguration(Handle hPlugin, int iNumParams)
{
    return view_as<int>(APIUTIL_CloneHandle(g_hConfiguration, hPlugin));
}

Handle APIUTIL_CloneHandle(Handle hHandle, Handle hPlugin)
{
    return hHandle ? CloneHandle(hHandle, hPlugin) : null;
}

/**
 * @section Startup logic
 */
public void OnPluginStart()
{
    g_bReady = false;

    // Load configuration file.
    char szPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szPath, sizeof(szPath), "configs/uas.cfg");

    g_hConfiguration = new KeyValues("uas");
    if (!g_hConfiguration)
    {
        SetFailState("Configuration failure: Cannot allocate memory for KeyValues handle");
        return;
    }

    if (!g_hConfiguration.ImportFromFile(szPath))
    {
        SetFailState("Configuration failure: Cannot read configuration (%s)", szPath);
        return;
    }

    // Initialize database connection.
    //
    // We can use SQL_TConnect(), but i want guarantee
    // connection existing in OnAllPluginsLoaded().
    // Without forwards like UAS_OnDatabaseConnected().
    char szConnectionName[64];
    g_hConfiguration.GetString("connection_name", szConnectionName, sizeof(szConnectionName), "uac");

    char szError[256];
    g_hDB = SQL_Connect(szConnectionName, true, szError, sizeof(szError));
    if (!g_hDB)
    {
        SetFailState("Database failure (connection %s): %s", szConnectionName, szError);
        return;
    }

    g_hDB.SetCharset("utf8");
    QueryServer();
}

public void OnMapStart()
{
    QueryUpdateServer();
}

/**
 * @section Client loader
 */
public Action OnClientPreAdminCheck(int iClient)
{
    return (g_bLoading[AdminCache_Admins]) ? Plugin_Handled
        : Plugin_Continue;
}

/**
 * @section OnRebuildAdminCache event handler
 */
public void OnRebuildAdminCache(AdminCachePart ePart)
{
    if (!g_bReady)
    {
        return;
    }

    QueryUpdateServer();
    switch (ePart)
    {
        case AdminCache_Overrides:  QueryOverrides();
        case AdminCache_Groups:     g_bRequiredAdmins = true, QueryGroups();
        // AdminCache_Admin is not used. We can't load only admins, if groups is not exists.
    }
}

/**
 * @section Query builders
 */
void QueryServer()
{
    g_bReady = false;
    char szAddress[32], szHostname[256];

    g_hConfiguration.JumpToKey("server", true);
    g_hConfiguration.GetString("address",   szAddress,  sizeof(szAddress),  "0.0.0.0");
    g_hConfiguration.GetString("hostname",  szHostname, sizeof(szHostname), "");
    int iPort = g_hConfiguration.GetNum("port", 0);
    int iServerID = g_hConfiguration.GetNum("id", -1);
    g_hConfiguration.Rewind();

    // Autodetect any unset value.
    if (iPort == 0) iPort = UTIL_GetServerPort();
    if (!strcmp(szAddress, "0.0.0.0")) UTIL_GetServerAddress(szAddress, sizeof(szAddress));
    if (szHostname[0] == 0) UTIL_GetServerHostname(szHostname, sizeof(szHostname));

    // If server id is not filled - drop plugin.
    if (iServerID < 0)
    {
        SetFailState("Configuration problems: Server ID cannot be less than 0!");
        return;
    }

    DataPack hPack = new DataPack();
    hPack.WriteCell(iPort);
    hPack.WriteCell(iServerID);
    hPack.WriteString(szAddress);
    hPack.WriteString(szHostname);

    char szQuery[256];
    // TODO: rework query and handler.
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT `server_id` FROM `uas_server` WHERE `address` = INET_ATON('%s') AND `port` = %d", szAddress, iPort);
    SQL_ExecuteQuery(SQL_QueryServer, szQuery, hPack, DBPrio_High, "QueryServer()");
}

void QueryOverrides()
{
    g_bLoading[AdminCache_Overrides] = true;
    if (!g_hDB) return;

    char szQuery[512];
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT `command`, CASE `override_type` WHEN 'Command' THEN 1 WHEN 'CommandGroup' THEN 2 ELSE -1 END AS `override_type`, `flags` FROM `uas_override_server` INNER JOIN `uas_override` ON `uas_override`.`override_id` = `uas_override_server`.`override_id` WHERE `server_id` = %d OR `server_id` IS NULL", g_iServerID);
    SQL_ExecuteQuery(SQL_QueryOverrides, szQuery, ++g_iSequence[AdminCache_Overrides], DBPrio_Normal, "QueryOverrides()");
}

void QueryGroups()
{
    g_bLoading[AdminCache_Groups] = true;
    if (!g_hDB) return;
    if (g_bRequiredAdmins) g_bLoading[AdminCache_Admins] = true;

    char szPrefix[128];
    g_hConfiguration.GetString("group_prefix", szPrefix, sizeof(szPrefix), "");

    char szQuery[512];
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT CONCAT('%s', `title`) AS `title`, `immunity`, `flags` FROM `uas_group` WHERE `deleted_at` IS NULL", szPrefix);
    SQL_ExecuteQuery(SQL_QueryGroups, szQuery, ++g_iSequence[AdminCache_Groups], DBPrio_Normal, "QueryGroups()");
}

void QueryAdmins()
{
    g_bLoading[AdminCache_Admins] = true; // set true if not set already.
    if (!g_hDB) return;

    char szQuery[1024];
    char szPrefix[128];
    g_hConfiguration.GetString("group_prefix", szPrefix, sizeof(szPrefix), "");
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT `uas_admin`.`admin_id`, `uas_admin`.`auth_method`, `uas_admin`.`auth_value`, CONCAT('%s', `uas_admin_group`.`title`) AS `group_title`, `uas_admin`.`username`, `uas_admin`.`password`, IFNULL(`uas_admin_flags`.`flags`, `uas_admin`.`flags`) AS `flags`, IFNULL(`uas_admin_flags`.`immunity`, `uas_admin`.`immunity`) AS `immunity` FROM `uas_admin` LEFT JOIN `uas_admin_group` ON `uas_admin_group`.`admin_id` = `uas_admin`.`admin_id` LEFT JOIN `uas_admin_flags` ON `uas_admin_flags`.`admin_id` = `uas_admin`.`admin_id` WHERE IFNULL(`uas_admin_flags`.`server_id`, `uas_admin_group`.`server_id`) = %d AND IFNULL(IFNULL(`uas_admin_flags`.`deleted_at`, `uas_admin_group`.`deleted_at`), UNIX_TIMESTAMP()) >= UNIX_TIMESTAMP() GROUP BY `admin_id`, `auth_method`, `auth_value`, `group_title`;", szPrefix, g_iServerID);
    SQL_ExecuteQuery(SQL_QueryAdmins, szQuery, ++g_iSequence[AdminCache_Admins], DBPrio_Normal, "QueryAdmins()");
}

void QueryUpdateServer()
{
    if (!g_hDB) return;

    char szQuery[256];
    char szHostname[256];

    g_hConfiguration.JumpToKey("server", true);
    g_hConfiguration.GetString("hostname",  szHostname, sizeof(szHostname), "");
    g_hConfiguration.Rewind();

    if (szHostname[0] == 0) UTIL_GetServerHostname(szHostname, sizeof(szHostname));
    
    g_hDB.Format(szQuery, sizeof(szQuery), "UPDATE `uas_server` SET `hostname` = '%s', `synced_at` = UNIX_TIMESTAMP() WHERE `server_id` = %d", szHostname, g_iServerID);
    SQL_ExecuteQuery(SQL_GlobalResultHandle, szQuery, 103, DBPrio_High, "QueryUpdateServer())");
}

/**
 * @section Query responsers.
 */
public void SQL_GlobalResultHandle(Database hDb, DBResultSet hResults, const char[] szError, int iQueryId)
{
    /**
     * Query ID definitions:
     *
     * 101  <-> Update hostname  (DEPRECATED; SEE 103)
     * 102  <-> Update Server ID
     * 103  <-> Update hostname and synced_at
     */
    if (hResults)
    {
        // All OK.
        return;
    }

    LogError("SQL_GlobalResultHandle: query %d -> %s", iQueryId, szError);
}

public void SQL_QueryServer(Database hDB, DBResultSet hResults, const char[] szError, DataPack hPack)
{
    hPack.Reset();
    char szAddress[32], szHostname[256];

    int iPort = hPack.ReadCell();
    int iServerID = hPack.ReadCell();
    hPack.ReadString(szAddress, sizeof(szAddress));
    hPack.ReadString(szHostname, sizeof(szHostname));
    hPack.Close();

    if (!hResults)
    {
        SetFailState("SQL_QueryServer: %s", szError);
        return;
    }

    char szQuery[512];
    if (hResults.HasResults && hResults.RowCount > 0 && hResults.FetchRow())
    {
        int iFetchedServerID = hResults.FetchInt(0);
        if (iServerID != iFetchedServerID)
        {
            // Update Server ID.
            hDB.Format(szQuery, sizeof(szQuery), "UPDATE `uas_server` SET `server_id` = %d WHERE `server_id` = %d", iServerID, iFetchedServerID);
            SQL_ExecuteQuery(SQL_GlobalResultHandle, szQuery, 102, DBPrio_High, "SQL_QueryServer(ServerID)");
        }

        g_iServerID = iServerID;

        // Update hostname.
        g_bReady = true;

        QueryUpdateServer();
        CheckLateLoad();
        return;
    }

    // Create server.
    hDB.Format(szQuery, sizeof(szQuery), "INSERT INTO `uas_server` (`server_id`, `address`, `port`, `hostname`, `deleted_at`, `synced_at`) VALUES (%d, INET_ATON('%s'), %d, '%s', NULL, UNIX_TIMESTAMP())", iServerID, szAddress, iPort, szHostname);
    SQL_ExecuteQuery(SQL_CreateServer, szQuery, iServerID, DBPrio_High, "SQL_QueryServer(NewEntry)");
}

public void SQL_CreateServer(Database hDB, DBResultSet hResults, const char[] szError, int iServerID)
{
    if (!hResults)
    {
        SetFailState("SQL_CreateServer: %s", szError);
        return;
    }

    g_iServerID = iServerID;
    g_bReady = true;

    CheckLateLoad();
}

public void SQL_QueryOverrides(Database hDB, DBResultSet hResults, const char[] szError, int iSequence)
{
    if (iSequence != g_iSequence[AdminCache_Overrides])
    {
        // Sequence is not equal.
        return;
    }

    // Reset loading state.
    g_bLoading[AdminCache_Overrides] = false;

    if (!hResults)
    {
        LogError("SQL_QueryOverrides: %s", szError);
        return;
    }

    if (!hResults.HasResults || hResults.RowCount < 1)
    {
        LogMessage("SQL_QueryOverrides: No one override has been assigned to this server");
        return;
    }

    char szCommand[256];
    while (hResults.FetchRow())
    {
        hResults.FetchString(0, szCommand, sizeof(szCommand));
        AddCommandOverride(szCommand, view_as<OverrideType>(hResults.FetchInt(1)), hResults.FetchInt(2));
    }
}

public void SQL_QueryGroups(Database hDB, DBResultSet hResults, const char[] szError, int iSequence)
{
    if (iSequence != g_iSequence[AdminCache_Groups])
    {
        // Sequence is not equal.
        return;
    }

    // Reset loading state.
    g_bLoading[AdminCache_Groups] = false;

    if (!hResults)
    {
        LogError("SQL_QueryGroups: %s", szError);
        return;
    }

    if (!hResults.HasResults || hResults.RowCount < 1)
    {
        LogMessage("SQL_QueryGroups: No one group has been added to database");
        return;
    }

    char szTitle[256];
    GroupId eGroup;
    while (hResults.FetchRow())
    {
        hResults.FetchString(0, szTitle, sizeof(szTitle));
        eGroup = CreateAdmGroup(szTitle);
        if (eGroup == INVALID_GROUP_ID)
        {
            LogError("SQL_QueryGroups: %s already exists", szTitle);
            continue;
        }

        eGroup.ImmunityLevel = hResults.FetchInt(1);
        UTIL_AssignGroupPermissions(eGroup, hResults.FetchInt(2));
    }

    char szPrefix[128];
    char szQuery[768];
    g_hConfiguration.GetString("group_prefix", szPrefix, sizeof(szPrefix), "");
    
    // Load group immunity and overrides.
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT CONCAT('%s', `uas_group_immunity`.`target`) AS `target`, CONCAT('%s', `uas_group_immunity`.`other`) AS `other` FROM `uas_group_immunity` INNER JOIN `uas_group` `target_group` ON `uas_group_immunity`.`target` = `target_group`.`title` INNER JOIN `uas_group` `other_group` ON `uas_group_immunity`.`other` = `other_group`.`title` WHERE `target_group`.`deleted_at` IS NULL AND `other_group`.`deleted_at` IS NULL ORDER BY `target`", szPrefix, szPrefix);
    SQL_ExecuteQuery(SQL_QueryGroups_Immunity, szQuery, iSequence, DBPrio_Normal, "SQL_QueryGroups(Immunity)");

    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT CONCAT('%s', `uas_group`.`title`) AS `title`, `uas_group_override`.`command`, CASE `uas_group_override`.`override_type` WHEN 'Command' THEN 1 WHEN 'CommandGroup' THEN 2 ELSE -1 END AS `override_type`, CASE `uas_group_override`.`has_access` WHEN 'Y' THEN 1 WHEN 'N' THEN 0 END AS `has_access` FROM `uas_group_override` INNER JOIN `uas_group` ON `uas_group_override`.`title` = `uas_group`.`title` WHERE `uas_group`.`deleted_at` IS NULL ORDER BY `title`", szPrefix);
    SQL_ExecuteQuery(SQL_QueryGroups_Overrides, szQuery, iSequence, DBPrio_Normal, "SQL_QueryGroups(Override)");

    // Load admins.
    if (g_bRequiredAdmins) QueryAdmins();
}

public void SQL_QueryGroups_Immunity(Database hDB, DBResultSet hResults, const char[] szError, int iSequence)
{
    if (iSequence != g_iSequence[AdminCache_Groups])
    {
        // Sequence is not equal.
        return;
    }

    if (!hResults)
    {
        LogError("SQL_QueryGroups_Immunity: %s", szError);
        return;
    }

    if (!hResults.HasResults || hResults.RowCount < 1)
    {
        LogMessage("SQL_QueryGroups_Immunity: No one group has been assigned to immunity other in database");
        return;
    }

    char szImmutable[256];
    char szOther[256];
    GroupId eImmutable, eOther;
    while (hResults.FetchRow())
    {
        hResults.FetchString(0, szImmutable, sizeof(szImmutable));
        hResults.FetchString(1, szOther,     sizeof(szOther));

        eImmutable = FindAdmGroup(szImmutable);
        if (eImmutable == INVALID_GROUP_ID)
        {
            LogError("SQL_QueryGroups_Immunity: Immutable admin group (%s) not found", szImmutable);
            continue;
        }

        eOther = FindAdmGroup(szOther);
        if (eImmutable == INVALID_GROUP_ID)
        {
            LogError("SQL_QueryGroups_Immunity: Other admin group (%s) not found", szOther);
            continue;
        }

        eImmutable.AddGroupImmunity(eOther);
    }
}

public void SQL_QueryGroups_Overrides(Database hDB, DBResultSet hResults, const char[] szError, int iSequence)
{
    if (iSequence != g_iSequence[AdminCache_Groups])
    {
        // Sequence is not equal.
        return;
    }

    if (!hResults)
    {
        LogError("SQL_QueryGroups_Overrides: %s", szError);
        return;
    }

    if (!hResults.HasResults || hResults.RowCount < 1)
    {
        LogMessage("SQL_QueryGroups_Overrides: No one group has been received overrides in database");
        return;
    }

    char szTitle[256], szCommand[256];
    GroupId eGroup;
    while (hResults.FetchRow())
    {
        hResults.FetchString(0, szTitle,    sizeof(szTitle));
        hResults.FetchString(1, szCommand,  sizeof(szCommand));

        eGroup = FindAdmGroup(szTitle);
        if (eGroup == INVALID_GROUP_ID)
        {
            LogError("SQL_QueryGroups_Overrides: Admin group (%s) not found", szTitle);
            continue;
        }

        eGroup.AddCommandOverride(szCommand, view_as<OverrideType>(hResults.FetchInt(2)), view_as<OverrideRule>(hResults.FetchInt(3)));
    }
}

public void SQL_QueryAdmins(Database hDB, DBResultSet hResults, const char[] szError, int iSequence)
{
    if (iSequence != g_iSequence[AdminCache_Admins])
    {
        // Sequence is not equal.
        return;
    }

    // Reset loading state.
    g_bLoading[AdminCache_Admins] = false;

    if (!hResults)
    {
        LogError("SQL_QueryAdmins: %s", szError);
        return;
    }

    if (!hResults.HasResults || hResults.RowCount < 1)
    {
        LogMessage("SQL_QueryAdmins: No one admin has been assigned to this server in database");
        return;
    }

    AdminId eAID;
    GroupId eGID;
    int iPreviousAdminId = -1, iAdminId;
    char szAuthMethod[32];
    char szAuthValue[256];
    char szGroupTitle[256];
    char szUsername[256];
    char szPassword[256];

    while (hResults.FetchRow())
    {
        iAdminId = hResults.FetchInt(0);
        if (iAdminId != iPreviousAdminId)
        {
            hResults.FetchString(4, szUsername, sizeof(szUsername));
            eAID = CreateAdmin(szUsername);

            iPreviousAdminId = iAdminId;

            // Auth method
            hResults.FetchString(1, szAuthMethod, sizeof(szAuthMethod));
            hResults.FetchString(2, szAuthValue,  sizeof(szAuthValue));
            eAID.BindIdentity(szAuthMethod, szAuthValue); // ignore result.

            // Immunity, flags
            eAID.ImmunityLevel = hResults.FetchInt(7);
            UTIL_AssignAdminPermissions(eAID, hResults.FetchInt(6));

            // Passwords
            hResults.FetchString(5, szPassword, sizeof(szPassword));
            eAID.SetPassword(szPassword);

        }

        // Groups
        hResults.FetchString(3, szGroupTitle, sizeof(szGroupTitle));
        eGID = FindAdmGroup(szGroupTitle);
        if (eGID != INVALID_GROUP_ID)
        {
            eAID.InheritGroup(eGID); // ignore result.
        }
    }

    for (int iClient = MaxClients; iClient != 0; --iClient)
    {
        if (IsClientInGame(iClient))
        {
            RunAdminCacheChecks(iClient);
            NotifyPostAdminCheck(iClient);
        }
    }
}

/**
 * @section Some helpful code.
 */
void CheckLateLoad()
{
    g_bRequiredAdmins = true;

    QueryOverrides();
    QueryGroups();
}

/**
 * @section Server determine functions.
 */
int UTIL_GetServerPort()
{
    static ConVar hostport = null;
    if (hostport == null)
    {
        hostport = FindConVar("hostport");
    }

    return hostport.IntValue;
}

void UTIL_GetServerAddress(char[] szBuffer, int iBufferSize)
{
    static ConVar hostip = null;
    if (hostip == null)
    {
        hostip = FindConVar("hostip");
    }

    int iIp = hostip.IntValue;
    FormatEx(
        szBuffer, iBufferSize, "%d.%d.%d.%d",
        (iIp >> 24)     & 0xFF,
        (iIp >> 16)     & 0xFF,
        (iIp >> 8 )     & 0xFF,
        (iIp      )     & 0xFF
    );
}

void UTIL_GetServerHostname(char[] szBuffer, int iBufferSize)
{
    static ConVar hostname = null;
    if (hostname == null)
    {
        hostname = FindConVar("hostname");
    }

    hostname.GetString(szBuffer, iBufferSize);
}

/**
 * @section String to internal converters
 */
void UTIL_AssignGroupPermissions(GroupId eGroup, int iFlags)
{
    int iFlag;
    AdminFlag eFlag;
    for (int iFlagId = 0; iFlagId < 33; ++iFlagId)
    {
        iFlag = (1 << iFlagId);

        if ((iFlags & iFlag) && BitToFlag(iFlag, eFlag))
        {
            eGroup.SetFlag(eFlag, true);
        }
    }
}

void UTIL_AssignAdminPermissions(AdminId eAID, int iFlags)
{
    int iFlag;
    AdminFlag eFlag;
    for (int iFlagId = 0; iFlagId < 33; ++iFlagId)
    {
        iFlag = (1 << iFlagId);

        if ((iFlags & iFlag) && BitToFlag(iFlag, eFlag))
        {
            eAID.SetFlag(eFlag, true);
        }
    }
}