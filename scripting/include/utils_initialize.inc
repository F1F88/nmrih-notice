/** Double-include prevention */
#if defined _utils_initialize_by_f1f88_included
    #endinput
#endif
#define _utils_initialize_by_f1f88_included

#pragma newdecls required
#pragma semicolon 1



/**
 * Retrieve an offset from a game conf or abort the plugin.
 *
 * @param gameConfig        Game config handle.
 * @param key               Key to retrieve from the offset section.
 *
 * @return                  An offset.
 */
stock int UTIL_GetOffsetOrFail(Handle gameConfig, const char[] key)
{
    int offset = GameConfGetOffset(gameConfig, key);
    if( offset == -1 )
    {
        delete gameConfig;
        SetFailState("Failed to read gamedata offset of '%s'", key);
    }
    return offset;
}


stock int UTIL_LoadOffsetOrFail(const char[] cls, const char[] prop, PropFieldType &type=view_as<PropFieldType>(0), int &num_bits=0, int &local_offset=0, int &array_size=0)
{
    int offset = FindSendPropInfo(cls, prop, type, num_bits, local_offset, array_size);
    if( offset < 1 )
        SetFailState("Can't find offset [%s] [%s]", cls, prop);
    return offset;
}


/**
 * 根据 name 查找 ConVar, 如果不存在则创建
 *
 * @param name              The name of the convar to find, if not, create it.
 * @param defaultValue      String containing the default value of new convar.
 * @param description       Optional description of the convar.
 * @param flags             Optional bitstring of flags determining how the convar should be handled. See FCVAR_* constants for more details.
 * @param hasMin            Optional boolean that determines if the convar has a minimum value.
 * @param min               Minimum floating point value that the convar can have if hasMin is true.
 * @param hasMax            Optional boolean that determines if the convar has a maximum value.
 * @param max               Maximum floating point value that the convar can have if hasMax is true.
 *
 * @return                  convar handle.
 */
stock ConVar UTIL_FindOrCreateConVar(
    const char[] name,
    const char[] defaultValue,
    const char[] description = "",
    int flags = 0,
    bool hasMin = false,
    float min = 0.000000,
    bool hasMax = false,
    float max = 0.000000
) {
    ConVar convar = FindConVar(name);
    if( convar == null )
        convar = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
    return convar;
}
