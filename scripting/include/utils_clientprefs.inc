/** Double-include prevention */
#if defined _utils_clientprefs_by_f1f88_included
  #endinput
#endif
#define _utils_clientprefs_by_f1f88_included

#include <clientprefs>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#define MAX_CLIENT_PREFS_ITEM_DISPLAY_LEN   128

methodmap CookieEx < Cookie
{
    /**
     * 在其他方法之前执行, 否则
     */
    public CookieEx(const char[] name, const char[] description, CookieAccess access=CookieAccess_Protected)
    {
        if( ! Util_ClientPrefsLibExists() || ! name[0] )
            return view_as<CookieEx>(INVALID_HANDLE);

        return view_as<CookieEx>( new Cookie(name, description, access) );
    }

    property bool libExists
    {
        public get()            { return Util_ClientPrefsLibExists(); }
    }

    property bool isValid
    {
        public get()            { return this.libExists && ! ( ! this || this == null || this == INVALID_HANDLE ); }
    }

    public void SetEx(int client, const char[] value)
    {
        if( ! this.isValid )
            return ;

        this.Set(client, value);
    }

    public void SetIntEx(int client, int value)
    {
        if( ! this.isValid )
            return ;

        char buffer[16];
        IntToString(value, buffer, sizeof(buffer));
        this.Set(client, buffer);
    }

    public void SetFloatEx(int client, float value)
    {
        if( ! this.isValid )
            return ;

        char buffer[32];
        FloatToString(value, buffer, sizeof(buffer));
        this.Set(client, buffer);
    }

    /**
     * 如果 LibExists 返回 false, 使用 defaultValue
     */
    public void GetEx(int client, char[] buffer, int maxlen)
    {
        if( ! this.isValid )
            return ;

        this.Get(client, buffer, maxlen);
    }

    public int GetIntEx(int client, int defaultValue = 0)
    {
        if( ! this.isValid )
            return defaultValue;

        char buffer[16];
        this.Get(client, buffer, sizeof(buffer));
        return StringToInt(buffer);
    }

    public float GetFloatEx(int client, float defaultValue = 0.0)
    {
        if( ! this.isValid )
            return defaultValue;

        char buffer[32];
        this.Get(client, buffer, sizeof(buffer));
        return StringToFloat(buffer);
    }

	public void SetByAuthIdEx(const char[] authID, const char[] value)
    {
        if( ! this.isValid )
            return ;

        this.SetByAuthId(authID, value);
    }

    public void SetPrefabMenuEx(CookieMenu type, const char[] display, CookieMenuHandler handler=INVALID_FUNCTION, any info=0)
    {
        if( ! this.isValid )
            return ;

        this.SetPrefabMenu(type, display, handler, info);
    }

	public int GetClientTimeEx(int client)
    {
        if( ! this.isValid )
            return 0;

        return this.GetClientTime(client);
    }


    public bool IsBitEnable(int client, int defaultValue, int prefsBit)
    {
        return ( this.GetIntEx(client, defaultValue) & prefsBit ) != 0;
    }

    public void AddBitItem(int client, int defaultValue, int prefsBit, Menu menu, const char[] phrases)
    {
        bool isBitEnable = this.IsBitEnable(client, defaultValue, prefsBit);

        char itemInfo[12];
        FormatEx(itemInfo, sizeof(itemInfo), "%d", prefsBit);

        char itemDisplay[MAX_CLIENT_PREFS_ITEM_DISPLAY_LEN];
        FormatEx(itemDisplay, sizeof(itemDisplay), "%T - %T", phrases, client, (isBitEnable ? "Yes" : "No"), client);

        menu.AddItem(itemInfo, itemDisplay, ITEMDRAW_DEFAULT);
    }

    public void SwitchBitItem(int client, int defaultValue, int prefsBit)
    {
        int clientCookie = this.GetIntEx(client, defaultValue);
        clientCookie ^= prefsBit;
        this.SetIntEx(client, clientCookie);
    }

    public void CPrintToChatAllEx(int defaultValue, int prefsBit, const char[] phrases)
    {
        for(int i=1; i<=MaxClients; ++i)
        {
            if( ! IsClientInGame(i) )
                continue;

            if( ! this.IsBitEnable(i, defaultValue, prefsBit) )
                continue;

            CPrintToChat(i, "%t", phrases);
        }
    }

    public void CPrintToChatAllExI(int defaultValue, int prefsBit, const char[] phrases, any param1)
    {
        for(int i=1; i<=MaxClients; ++i)
        {
            if( ! IsClientInGame(i) )
                continue;

            if( ! this.IsBitEnable(i, defaultValue, prefsBit) )
                continue;

            CPrintToChat(i, "%t", phrases, param1);
        }
    }

    public void CPrintToChatAllExII(int defaultValue, int prefsBit, const char[] phrases, any param1, any param2)
    {
        for(int i=1; i<=MaxClients; ++i)
        {
            if( ! IsClientInGame(i) )
                continue;

            if( ! this.IsBitEnable(i, defaultValue, prefsBit) )
                continue;

            CPrintToChat(i, "%t", phrases, param1, param2);
        }
    }

    public void CPrintToChatAllExIS(int defaultValue, int prefsBit, const char[] phrases, any param1, char[] param2)
    {
        for(int i=1; i<=MaxClients; ++i)
        {
            if( ! IsClientInGame(i) )
                continue;

            if( ! this.IsBitEnable(i, defaultValue, prefsBit) )
                continue;

            CPrintToChat(i, "%t", phrases, param1, param2);
        }
    }

}


/**
 * @return 是否加载了 clientprefs 插件
 */
stock bool Util_ClientPrefsLibExists()
{
    return LibraryExists("clientprefs");
}

stock void Util_MarkClientPrefsNativeAsOptional()
{
    MarkNativeAsOptional("Cookie.Cookie");
    MarkNativeAsOptional("Cookie.Get");
    MarkNativeAsOptional("Cookie.GetInt");
    MarkNativeAsOptional("Cookie.Set");
    MarkNativeAsOptional("Cookie.SetInt");
    MarkNativeAsOptional("SetCookieMenuItem");
}

stock int Util_GetBitItemAtPage(float prefsBit)
{
    return RoundToFloor(Logarithm(prefsBit, 2.0)) / 7 * 7;
}
