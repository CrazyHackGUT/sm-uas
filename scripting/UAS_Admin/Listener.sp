/**
 * This file is a part of "Unified Admin System".
 * Licensed by GNU GPL v3
 *
 * All rights reserved.
 * (c) 2019 CrazyHackGUT aka Kruzya
 */

#file "Application.Listener"

/**
 * @section Player event listeners
 */
public void OnClientDisconnect_Post(int iClient)
{
    g_ptrChatHandler[iClient] = INVALID_FUNCTION;
}

public Action OnClientSayCommand(int iClient, const char[] szCommand, const char[] szMessage)
{
    Function ptrChatHandler = g_ptrChatHandler[iClient];
    if (ptrChatHandler == INVALID_FUNCTION)
    {
        return Plugin_Continue;
    }

    Action eRetVal;
    Call_StartFunction(null, ptrChatHandler);
    Call_PushCell(iClient);
    Call_PushString(szMessage);
    Call_Finish(eRetVal);

    return eRetVal;
}