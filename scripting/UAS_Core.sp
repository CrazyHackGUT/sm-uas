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

bool        g_bLate;
int         g_iServerID;

bool        g_bReady;

public Plugin myinfo = {
    description = "Performs a operation for loading administrators and groups",
    version     = "0.0.0.3",
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

    g_bLate = bLate;
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
    QueryServer();
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

    switch (ePart)
    {
        case AdminCache_Overrides:  QueryOverrides();
        case AdminCache_Groups:     QueryGroups();
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
    g_hDB.Query(SQL_QueryServer, szQuery, hPack);
}

void QueryOverrides()
{
    char szQuery[256];
    g_hDB.Format(szQuery, sizeof(szQuery), "SELECT `command`, `override_type`, `flags` FROM `uas_override_server` INNER JOIN `uas_override` ON `uas_override`.`override_id` = `uas_override_server`.`override_id` WHERE `server_id` = %d", g_iServerID);
    g_hDB.Query(SQL_QueryOverrides, szQuery);
}

void QueryGroups()
{}

/**
 * @section Query responsers.
 */
public void SQL_GlobalResultHandle(Database hDb, DBResultSet hResults, const char[] szError, int iQueryId)
{
    /**
     * Query ID definitions:
     *
     * 101  <-> Update hostname
     * 102  <-> Update Server ID
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
            hDB.Query(SQL_GlobalResultHandle, szQuery, 102);
        }

        g_iServerID = iServerID;

        // Update hostname.
        hDB.Format(szQuery, sizeof(szQuery), "UPDATE `uas_server` SET `hostname` = '%s' WHERE `server_id` = %d", szHostname, g_iServerID);
        hDB.Query(SQL_GlobalResultHandle, szQuery, 101);
        g_bReady = true;

        CheckLateLoad();
        return;
    }

    // Create server.
    hDB.Format(szQuery, sizeof(szQuery), "INSERT INTO `uas_server` (`server_id`, `address`, `port`, `hostname`, `deleted_at`) VALUES (%d, INET_ATON('%s'), %d, '%s', NULL)", iServerID, szAddress, iPort, szHostname);
    hDB.Query(SQL_CreateServer, szQuery, iServerID);
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

public void SQL_QueryOverrides(Database hDB, DBResultSet hResults, const char[] szError, any data)
{
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
    char szOverrideType[32];
    while (hResults.FetchRow())
    {
        hResults.FetchString(0, szCommand, sizeof(szCommand));
        hResults.FetchString(1, szOverrideType, sizeof(szOverrideType));

        AddCommandOverride(szCommand, UTIL_StringOverrideTypeToInternal(szOverrideType), hResults.FetchInt(2));
    }
}

/**
 * @section Some helpful code.
 */
void CheckLateLoad()
{
    if (g_bLate)
    {
        QueryOverrides();
        QueryGroups();
    }
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
OverrideType UTIL_StringOverrideTypeToInternal(const char[] szOverrideType)
{
    if (!strcmp(szOverrideType, "CommandGroup", true))
    {
        return Override_CommandGroup;
    }

    if (!strcmp(szOverrideType, "Command", true))
    {
        return Override_Command;
    }

    return view_as<OverrideType>(-1);
}