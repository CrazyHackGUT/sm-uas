/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#if defined _uas_included
  #endinput
#endif // defined _uas_included
#define _uas_included

/**
 * Returns the database handle.
 *
 * NOTE: you receive a database clone.
 * You should close this.
 *
 * @return  Database connection handle, or null if connection is not established.
 */
native Database UAS_GetDatabase();

/**
 * Returns the configuration handle.
 *
 * NOTE: you receive a configuration clone.
 * You should close this.
 *
 * @return  Configuration handle, or null if configuration isn't ready yet.
 */
native KeyValues UAS_GetConfiguration();

public SharedPlugin __pl_uas = {
    name = "uas",
    file = "UAS/Core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else // defined REQUIRE_PLUGIN
    required = 0,
#endif // defined REQUIRE_PLUGIN
};

#if !defined REQUIRE_PLUGIN
public void __pl_uas_SetNTVOptional()
{
    // v0.0.0.1
    MarkNativeAsOptional("UAS_GetDatabase");
    MarkNativeAsOptional("UAS_GetConfiguration");
}
#endif // defined REQUIRE_PLUGIN