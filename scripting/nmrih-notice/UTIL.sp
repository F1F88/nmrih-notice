#pragma newdecls required
#pragma semicolon 1

int UTIL_LoadOffsetOrFail(const char[] cls,
                    const char[] prop,
                    PropFieldType &type=view_as<PropFieldType>(0),
                    int &num_bits=0,
                    int &local_offset=0,
                    int &array_size=0)
{
    int offset = FindSendPropInfo(cls, prop, type, num_bits, local_offset, array_size);
    if( offset < 1 )
        SetFailState("Can't find offset [%s] [%s]", cls, prop);
    return offset;
}

// 根据 isHook 执行 HookEvent 或 UnhookEvent
stock void UTIL_ChangeHookEvent(bool isHook, const char[] name, EventHook callback, EventHookMode mode=EventHookMode_Post)
{
    isHook ? HookEvent(name, callback) : UnhookEvent(name, callback);
}

// 根据 convar 和 clientPrefBit 判断是否输出
void UTIL_CPrintToChatAll(bool convar, int bit, const char[] message, any ...)
{
    if( ! convar )
        return ;

    char formatMessage[512];
    for( int client=1; client<=MaxClients; ++client )
    {
        if( IsClientInGame(client) && ClientPrefs_CanPrint(client, bit) )
        {
            VFormat(formatMessage, sizeof(formatMessage), message, 4);
            CPrintToChat(client, formatMessage);
        }
    }
}

stock bool UTIL_IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}
