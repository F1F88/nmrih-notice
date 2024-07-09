/** Double-include prevention */
#if defined _utils_events_by_f1f88_included
    #endinput
#endif
#define _utils_events_by_f1f88_included

#pragma newdecls required
#pragma semicolon 1


methodmap EventUtils < Event
{
    public static void ChangeHook(bool isHook, const char[] name, EventHook callback, EventHookMode mode=EventHookMode_Post)
    {
        isHook ? HookEvent(name, callback) : UnhookEvent(name, callback);
    }
}
