#if defined _logger_methodmap_by_f1f88_included
 #endinput
#endif
#define _logger_methodmap_by_f1f88_included

#pragma newdecls required
#pragma semicolon 1

/**
 * Plugin Name          "logger"
 * Description          "A simple sourcemod logging framework"
 * Author               "F1F88"
 * URL                  "https://github.com/F1F88/sm-logdebug"
 * Adapted from
 *      by Dr. McKay   "https://forums.alliedmods.net/showthread.php?t=258855"
 *      by Alienmario  "https://github.com/Alienmario/sm-logdebug"
 */

enum
{
    LogLevel_OFF                                    = 0,
    LogLevel_Trace                                  = 1,
    LogLevel_Debug                                  = 2,
    LogLevel_Info                                   = 4,
    LogLevel_Warn                                   = 8,
    LogLevel_Error                                  = 16,
    LogLevel_Fatal                                  = 32,
    LogLevel_ALL                                    = 63
}

enum
{
    LogLocation_OFF                                 = 0,    /**< Do nothing */
    LogLocation_ServerConsole                       = 1,    /**< Message will be routed to server console */
    LogLocation_ClientConsoleAll                    = 2,    /**< Message will be routed to all clients' consoles */
    LogLocation_AdminConsoleAll                     = 4,    /**< Message will be routed to consoles of admins with a flag specified by plugin */
    LogLocation_ClientChatAll                       = 8,    /**< Message will be routed to all clients' chat boxes (and consequently consoles) */
    LogLocation_AdminChatAll                        = 16,   /**< Message will be routed to chat boxes of admins with a flag specified by plugin */
    LogLocation_File                                = 32,   /**< Message will be routed to plugin's debug log */
    LogLocation_ALL                                 = 63
}

enum
{
    LogParts_OFF                                    = 0,    /**< Message only */
    LogParts_Time                                   = 1,    /**< Message will include current time */
    LogParts_TickCount                              = 2,    /**< Message will include current tick count */
    LogParts_Level                                  = 4,    /**< Message will include log level */
    LogParts_StackCallerFile                        = 8,    /**< Message will include full location in the following syntax sourcefile (Multiple stack caller bits prioritize selecting smaller bits)*/
    LogParts_StackCallerFileAndFunc                 = 16,   /**< Message will include full location in the following syntax sourcefile::function (Multiple stack caller bits prioritize selecting smaller bits)*/
    LogParts_StackCallerFileAndFuncAndLine          = 32,   /**< Message will include full location in the following syntax sourcefile::function::line (Multiple stack caller bits prioritize selecting smaller bits)*/
    LogParts_ALL                                    = 39
}

#define LOG_LEVEL_NAME_TRACE                        "Trace"
#define LOG_LEVEL_NAME_DEBUG                        "Debug"
#define LOG_LEVEL_NAME_INFO                         "Info"
#define LOG_LEVEL_NAME_WARN                         "Warn"
#define LOG_LEVEL_NAME_ERROR                        "Error"
#define LOG_LEVEL_NAME_FATAL                        "Fatal"


// 可以适当调整这些值
#define LOG_MAX_CONVAR_TAG                          32
#define LOG_MAX_CONVAR                              64
#define LOG_MAX_LOG_TAG                             64
// #define LOG_MAX_FILE_NAME                           64
#define LOG_MAX_USER_MESSAGE                        2048

#define LOG_MAX_TIME_FORMAT                         64
#define LOG_MAX_TICK_COUNT                          12
#define LOG_MAX_LEVEL_NAME                          10
#define LOG_MAX_FILE                                PLATFORM_MAX_PATH
#define LOG_MAX_FUNCTION                            128
#define LOG_MAX_CALLER_BRIEF                        LOG_MAX_FILE + LOG_MAX_FUNCTION

// 只在本文件内使用, 缓存
static char _convarTag[LOG_MAX_CONVAR_TAG];
static char _logTag[LOG_MAX_LOG_TAG];
static char _logFilePath[LOG_MAX_FILE];
static char _userMessage[LOG_MAX_USER_MESSAGE];

static int _cvGlobalLevel;
static int _cvGlobalLocation;
static int _cvGlobalParts;
static int _cvGlobalAdminFlags;

static int _cvCustomLevel;
static int _cvCustomLocation;
static int _cvCustomParts;
static int _cvCustomAdminFlags;
static bool _cvCustomGlobalContral;

// Log Api
methodmap Logger
{
    /**
     * 建议在 OnPluginStart() 时调用。
     *
     * @param convarTag                     为插件创建 sm_{tag}_*** ConVar。 当 sm_{tag}_global_contral = false 时，使用 sm_{tag}_*** 控制日志输出。
     * @param failOnCustomConVarExists      当 sm_{tag}_*** ConVar 已存在时，将插件设为失败状态。否则将使用已存在的 ConVar。
     * @param logTag                        日志信息的标签，将被放在消息头，默认为空 ""。
     * @param logFileName                   日志信息如果写入的文件名, 默认为空 "" 时，使用调用者的文件名作为日志文件名称。
     */
    public static Logger GetLogger(const char[] convarTag, bool failOnCustomConVarExists = false, const char[] logTag = "", const char[] logFileName = "")
    {
        strcopy(_convarTag, sizeof(_convarTag), convarTag);

        _InitConVar(_convarTag, failOnCustomConVarExists);

        strcopy(_logTag, sizeof(_logTag), logTag);

        if( ! logFileName[0] )
        {
            char buffer[LOG_MAX_FILE];
            _GetCallerFileName(buffer, sizeof(buffer));
            BuildPath(Path_SM, _logFilePath, sizeof(_logFilePath), "logs/%s.log", buffer);
        }
        else
        {
            BuildPath(Path_SM, _logFilePath, sizeof(_logFilePath), "logs/%s.log", logFileName);
        }

        return view_as<Logger>( 0xF1F88 );
    }

    // LogLevel_Trace
    public void Trace(const char[] format, any ...)
    {
        if( ! _LocationAccess() || ! _LevelAccess(LogLevel_Trace) )
            return ;

        VFormat(_userMessage, sizeof(_userMessage), format, 3);

        _OutputPretty(LogLevel_Trace);
    }

    // LogLevel_Debug
    public void Debug(const char[] format, any ...)
    {
        if( ! _LocationAccess() || ! _LevelAccess(LogLevel_Debug) )
            return ;

        VFormat(_userMessage, sizeof(_userMessage), format, 3);

        _OutputPretty(LogLevel_Debug);
    }

    // LogLevel_Info
    public void Info(const char[] format, any ...)
    {
        if( ! _LocationAccess() || ! _LevelAccess(LogLevel_Info) )
            return ;

        VFormat(_userMessage, sizeof(_userMessage), format, 3);

        _OutputPretty(LogLevel_Info);
    }


    // LogLevel_Warn
    public void Warn(const char[] format, any ...)
    {
        if( ! _LocationAccess() || ! _LevelAccess(LogLevel_Warn) )
            return ;

        VFormat(_userMessage, sizeof(_userMessage), format, 3);

        _OutputPretty(LogLevel_Warn);
    }


    // LogLevel_Error
    public void Error(const char[] format, any ...)
    {
        if( ! _LocationAccess() || ! _LevelAccess(LogLevel_Error) )
            return ;

        VFormat(_userMessage, sizeof(_userMessage), format, 3);

        _OutputPretty(LogLevel_Error);
    }


    // LogLevel_Fatal
    public void Fatal(const char[] format, any ...)
    {
        if( ! _LocationAccess() || ! _LevelAccess(LogLevel_Fatal) )
            return ;

        VFormat(_userMessage, sizeof(_userMessage), format, 3);

        _OutputPretty(LogLevel_Fatal);
    }
}



static void _OutputPretty(int level)
{
    for(int location=1; location<=LogLocation_ALL; location <<= 1)
    {
        if( _cvCustomGlobalContral && ! (location & _cvGlobalLocation) )
            continue;

        if( ! _cvCustomGlobalContral && ! (location & _cvCustomLocation) )
            continue;

        _OutputMessageToLocation(level, location);

        if( level & LogLevel_Trace || level & LogLevel_Fatal )
            _OutputStackCallerToLocation(location);
    }
}

static void _OutputMessageToLocation(int level, int location)
{
    // Prepare Log Message
    char timeFmt[LOG_MAX_TIME_FORMAT];
    char tickCount[LOG_MAX_TICK_COUNT];
    char levelName[LOG_MAX_LEVEL_NAME];
    char callerFile[LOG_MAX_FILE];
    char callerFunc[LOG_MAX_FUNCTION];
    int callerLine;
    char callerInfo[LOG_MAX_CALLER_BRIEF];

    // Get Part - Time
    if( _PartsAcess(LogParts_Time) )
    {
        FormatTime(timeFmt, sizeof(timeFmt), NULL_STRING);
        StrCat(timeFmt, sizeof(timeFmt), " ");
    }

    // Get Part - Tick Count
    if( _PartsAcess(LogParts_TickCount) )
    {
        FormatEx(tickCount, sizeof(tickCount), "<%d> ", GetGameTickCount());
    }

    // Get Part - Level Name
    if( _PartsAcess(LogParts_Level) )
    {
        switch( level )
        {
            case LogLevel_Trace:    FormatEx(levelName, sizeof(levelName), "<%s> ", LOG_LEVEL_NAME_TRACE);
            case LogLevel_Debug:    FormatEx(levelName, sizeof(levelName), "<%s> ", LOG_LEVEL_NAME_DEBUG);
            case LogLevel_Info:     FormatEx(levelName, sizeof(levelName), "<%s> ", LOG_LEVEL_NAME_INFO);
            case LogLevel_Warn:     FormatEx(levelName, sizeof(levelName), "<%s> ", LOG_LEVEL_NAME_WARN);
            case LogLevel_Error:    FormatEx(levelName, sizeof(levelName), "<%s> ", LOG_LEVEL_NAME_ERROR);
            case LogLevel_Fatal:    FormatEx(levelName, sizeof(levelName), "<%s> ", LOG_LEVEL_NAME_FATAL);
            default :               levelName[0] = '\0';
        }
    }

    // Get Part - Stack Caller Brief
    if( _PartsAcess(LogParts_StackCallerFile) )
    {
        _GetCallerDesc(callerFile, sizeof(callerFile), callerFunc, sizeof(callerFunc), callerLine);

        FormatEx(callerInfo, sizeof(callerInfo), "(%s) ", callerFile);

    }
    else if( _PartsAcess(LogParts_StackCallerFileAndFunc) )
    {
        _GetCallerDesc(callerFile, sizeof(callerFile), callerFunc, sizeof(callerFunc), callerLine);

        FormatEx(callerInfo, sizeof(callerInfo), "(%s::%s) ", callerFile, callerFunc);
    }
    else if( _PartsAcess(LogParts_StackCallerFileAndFuncAndLine) )
    {
        _GetCallerDesc(callerFile, sizeof(callerFile), callerFunc, sizeof(callerFunc), callerLine);

        FormatEx(callerInfo, sizeof(callerInfo), "(%s::%s::%d) ", callerFile, callerFunc, callerLine);
    }

    // Output To Location
    // Output To Server Console
    if( location & LogLocation_ServerConsole )
    {
        PrintToServer("%s%s%s%s%s%s", timeFmt, tickCount, levelName, callerInfo, _logTag, _userMessage);
    }

    // Output To All Client Console
    if( location & LogLocation_ClientConsoleAll )
    {
        PrintToConsoleAll("%s%s%s%s%s%s", timeFmt, tickCount, levelName, callerInfo, _logTag, _userMessage);
    }

    // Output To All Client Chat
    if( location & LogLocation_ClientChatAll )
    {
        PrintToChatAll("%s%s%s%s%s", tickCount, levelName, callerInfo, _logTag, _userMessage);
    }

    // Output To All Admin Console Or Chat
    for(int client = 1; client <= MaxClients; ++client)
    {
        if( ! IsClientInGame(client) || ! _AdminAccess(client) )
            continue;

        if( location & LogLocation_AdminConsoleAll )
        {
            PrintToConsole(client, "%s%s%s%s%s%s", timeFmt, tickCount, levelName, callerInfo, _logTag, _userMessage);
        }

        if( location & LogLocation_AdminChatAll )
        {
            PrintToChat(client, "%s%s%s%s%s", tickCount, levelName, callerInfo, _logTag, _userMessage);
        }
    }

    // Output To log file
    if( location & LogLocation_File )
    {
        LogToFileEx(_logFilePath, "%s%s%s%s%s", tickCount, levelName, callerInfo, _logTag, _userMessage);
    }
}

static void _OutputStackCallerToLocation(int location)
{
    // Get Part - Time
    char timeFmt[LOG_MAX_TIME_FORMAT];
    if( _PartsAcess(LogParts_Time) )
    {
        FormatTime(timeFmt, sizeof(timeFmt), NULL_STRING);
        StrCat(timeFmt, sizeof(timeFmt), " ");
    }

    char file[LOG_MAX_FILE];
    char func[LOG_MAX_FUNCTION];

    FrameIterator frames = new FrameIterator();

    frames.Next();  // 跳出 0 -  :: FrameIterator.FrameIterator
    frames.Next();  // 跳出 1 - ***\include\log_methodmap.inc :: _OutputPretty
    // frames.Next();  // 跳出 2 - ***\include\log_methodmap.inc :: _OutputStackCallerToLocation
    // frames.Next();  // 跳出 3 - ***\include\log_methodmap.inc :: Logger.***

    // for 表达式会先执行一次跳出，即跳出 2，进入 3 ==> Logger.***
    for(int idx=0; frames.Next(); ++idx)
    {
        frames.GetFilePath(file, sizeof(file));
        frames.GetFunctionName(func, sizeof(func));

        if( file[0] && idx > 0 )
        {
            if( location & LogLocation_ServerConsole )
            {
                PrintToServer("%s%s  [%d] Line %d, %s::%s", timeFmt, _logTag, idx, frames.LineNumber, file, func);
            }

            if( location & LogLocation_ClientConsoleAll )
            {
                PrintToConsoleAll("%s%s  [%d] Line %d, %s::%s", timeFmt, _logTag, idx, frames.LineNumber, file, func);
            }

            if( location & LogLocation_ClientChatAll )
            {
                PrintToChatAll("%s  [%d] Line %d, %s::%s", _logTag, idx, frames.LineNumber, file, func);
            }

            for(int client = 1; client <= MaxClients; ++client)
            {
                if( ! IsClientInGame(client) || ! _AdminAccess(client) )
                    continue;

                if( location & LogLocation_AdminConsoleAll )
                {
                    PrintToConsole(client, "%s%s  [%d] Line %d, %s::%s", timeFmt, _logTag, idx, frames.LineNumber, file, func);
                }

                if( location & LogLocation_AdminChatAll )
                {
                    PrintToChat(client, "%s  [%d] Line %d, %s::%s", _logTag, idx, frames.LineNumber, file, func);
                }
            }

            if( location & LogLocation_File )
            {
                LogToFileEx(_logFilePath, "%s  [%d] Line %d, %s::%s", _logTag, idx, frames.LineNumber, file, func);
            }
        }
        else if( func[0] )
        {
            if( location & LogLocation_ServerConsole )
            {
                PrintToServer("%s%s  [%d] %s", timeFmt, _logTag, idx, func);
            }

            if( location & LogLocation_ClientConsoleAll )
            {
                PrintToConsoleAll("%s%s  [%d] %s", timeFmt, _logTag, idx, func);
            }

            if( location & LogLocation_ClientChatAll )
            {
                PrintToChatAll("%s  [%d] %s", _logTag, idx, func);
            }

            for(int client = 1; client <= MaxClients; ++client)
            {
                if( ! IsClientInGame(client) || ! _AdminAccess(client) )
                    continue;

                if( location & LogLocation_AdminConsoleAll )
                {
                    PrintToConsole(client, "%s%s  [%d] %s", timeFmt, _logTag, idx, func);
                }

                if( location & LogLocation_AdminChatAll )
                {
                    PrintToChat(client, "%s  [%d] %s", _logTag, idx, func);
                }
            }

            if( location & LogLocation_File )
            {
                LogToFileEx(_logFilePath, "%s  [%d] %s", _logTag, idx, func);
            }
        }
    }
    frames.Close();
}


static bool _LocationAccess()
{
    if( _cvCustomGlobalContral )
        return _cvGlobalLocation != LogLocation_OFF;

    return _cvCustomLocation != LogLocation_OFF;
}

static bool _LevelAccess(int level)
{
    if( _cvCustomGlobalContral )
        return ( level & _cvGlobalLevel ) != 0;

    return ( level & _cvCustomLevel ) != 0;
}

static bool _PartsAcess(int parts)
{
    if( _cvCustomGlobalContral )
        return ( parts & _cvGlobalParts ) != 0;

    return ( parts & _cvCustomParts ) != 0;
}

static bool _AdminAccess(int client)
{
    if( _cvCustomGlobalContral )
        return CheckCommandAccess(client, NULL_STRING, _cvGlobalAdminFlags, true);

    return CheckCommandAccess(client, NULL_STRING, _cvCustomAdminFlags, true);
}

static void _GetCallerFileName(char[] file, int maxlength)
{
    char buffer[LOG_MAX_FILE];

    FrameIterator frames = new FrameIterator();

    frames.Next();  // 跳出 0 -  :: FrameIterator.FrameIterator
    frames.Next();  // 跳出 1 - ***\include\log_methodmap.inc :: _GetCallerFile
    frames.Next();  // 跳出 2 - ***\include\log_methodmap.inc :: Logger.GetLogger

    frames.GetFilePath(buffer, sizeof(buffer));

    frames.Close();

    buffer[ strlen(buffer) - 3 ] = '\0';                    // 除去文件名后缀 .sp
    int sepIndex = FindCharInString(buffer, '\\', true);    // 除去首部多余的路径
    if( sepIndex == -1 )                                    // 如果是 Linux 则查找 '/'
        sepIndex = FindCharInString(buffer, '/', true);

    strcopy(file, maxlength, buffer[sepIndex + 1]);
}

static void _GetCallerDesc(char[] callerFile, int maxlength, char[] callerFunc, int maxlength2, int &line)
{
    char buffer[LOG_MAX_FILE];

    FrameIterator frames = new FrameIterator();

    frames.Next();  // 跳出 0 -  :: FrameIterator.FrameIterator
    frames.Next();  // 跳出 1 - ***\include\log_methodmap.inc :: _GetCallerDesc
    frames.Next();  // 跳出 2 - ***\include\log_methodmap.inc :: _OutputMessageToLocation
    frames.Next();  // 跳出 3 - ***\include\log_methodmap.inc :: _OutputPretty
    frames.Next();  // 跳出 4 - ***\include\log_methodmap.inc :: Logger.***

    // Stack caller file path
    frames.GetFilePath(buffer, sizeof(buffer));

    // Stack caller function name
    frames.GetFunctionName(callerFunc, maxlength2);

    // Stack caller function line
    line = frames.LineNumber;

    frames.Close();

    // clip File path to file name
    int sepIndex = FindCharInString(buffer, '\\', true);// 除去首部多余的路径
    if( sepIndex == -1 )                                // 如果是 Linux 则查找 '/'
        sepIndex = FindCharInString(buffer, '/', true);

    Format(callerFile, maxlength, "%s", buffer[sepIndex + 1]);
}


// 定义 ConVar 信息, 方便后期修改
#define LOG_CONVAR_LEVEL_NAME                       "sm_log_level"
#define LOG_CONVAR_LEVEL_DEFAULT                    "62"
#define LOG_CONVAR_LEVEL_DESC                       "Add up values to enable debug logging to those level\n  0  = off\n  1  = trace\n  2  = debug\n  4  = info\n  8  = warn\n  16 = error\n  32 = fatal\n  63 = all\n"

#define LOG_CONVAR_LOCATION_NAME                    "sm_log_location"
#define LOG_CONVAR_LOCATION_DEFAULT                 "37"
#define LOG_CONVAR_LOCATION_DESC                    "Add up values to enable debug logging to those locations\n  0  = off\n  1  = server console\n  2  = all clients' consoles\n  4  = consoles of admins\n  8  = all clients' chat\n  16 = chat of admins\n  32 = written to the 'logs/{pluginName}.log' file\n  63 = all\n"

#define LOG_CONVAR_PARTS_NAME                       "sm_log_parts"
#define LOG_CONVAR_PARTS_DEFAULT                    "13"
#define LOG_CONVAR_PARTS_DESC                       "Add up values to set up additional information included in the logs\n  0  = only user message\n  1  = time\n  2  = tick count\n  4  = log level\n  8  = stack caller location in the following syntax sourcefile\n  16 = stack caller location in the following syntax sourcefile::function\n  32 = stack caller location in the following syntax sourcefile::function:line\n  39 = all"

#define LOG_CONVAR_ADMIN_FLAGS_NAME                 "sm_log_admin_flags"
#define LOG_CONVAR_ADMIN_FLAGS_DEFAULT              "2"
#define LOG_CONVAR_ADMIN_FLAGS_DESC                 "One or more admin flagbits which define whether a user is an \"admin\". If you pass multiple flags, users will need ALL flags."

#define LOG_CONVAR_CUSTOM_LEVEL                     "sm_%s_log_level"
#define LOG_CONVAR_CUSTOM_LEVEL_DEFAULT             LOG_CONVAR_LEVEL_DEFAULT
#define LOG_CONVAR_CUSTOM_LEVEL_DESC                LOG_CONVAR_LEVEL_DESC

#define LOG_CONVAR_CUSTOM_LOCATION                  "sm_%s_log_location"
#define LOG_CONVAR_CUSTOM_LOCATION_DEFAULT          LOG_CONVAR_LOCATION_DEFAULT
#define LOG_CONVAR_CUSTOM_LOCATION_DESC             LOG_CONVAR_LOCATION_DESC

#define LOG_CONVAR_CUSTOM_PARTS                     "sm_%s_log_parts"
#define LOG_CONVAR_CUSTOM_PARTS_DEFAULT             LOG_CONVAR_PARTS_DEFAULT
#define LOG_CONVAR_CUSTOM_PARTS_DESC                LOG_CONVAR_PARTS_DESC

#define LOG_CONVAR_CUSTOM_ADMIN_FLAGS               "sm_%s_log_admin_flags"
#define LOG_CONVAR_CUSTOM_ADMIN_FLAGS_DEFAULT       LOG_CONVAR_ADMIN_FLAGS_DEFAULT
#define LOG_CONVAR_CUSTOM_ADMIN_FLAGS_DESC          LOG_CONVAR_ADMIN_FLAGS_DESC

#define LOG_CONVAR_CUSTOM_GLOBAL_CONTRAL            "sm_%s_log_global_contral"
#define LOG_CONVAR_CUSTOM_GLOBAL_CONTRAL_DEFAULT    "1"
#define LOG_CONVAR_CUSTOM_GLOBAL_CONTRAL_DESC       "是否使用全局 log convar 控制日志输出"

#define LOG_CONVAR_VERSION_NAME                     "sm_%s_log_version"
#define LOG_CONVAR_VERSION_DEFAULT                  "1.0.2"
#define LOG_CONVAR_VERSION_DESC                     "A simple sourcemod logging framework"

static void _InitConVar(const char[] tag, bool setFail)
{
    ConVar convar;

    // global level
    convar = _FindConVarOrCreate(LOG_CONVAR_LEVEL_NAME, LOG_CONVAR_LEVEL_DEFAULT, LOG_CONVAR_LEVEL_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarGlobalLevelChange);
    _cvGlobalLevel = convar.IntValue;

    // global location
    convar = _FindConVarOrCreate(LOG_CONVAR_LOCATION_NAME, LOG_CONVAR_LOCATION_DEFAULT, LOG_CONVAR_LOCATION_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarGlobalLocationChange);
    _cvGlobalLocation = convar.IntValue;

    // global parts
    convar = _FindConVarOrCreate(LOG_CONVAR_PARTS_NAME, LOG_CONVAR_PARTS_DEFAULT, LOG_CONVAR_PARTS_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarGlobalPartsChange);
    _cvGlobalParts = convar.IntValue;

    // global admin flags
    convar = _FindConVarOrCreate(LOG_CONVAR_ADMIN_FLAGS_NAME, LOG_CONVAR_ADMIN_FLAGS_DEFAULT, LOG_CONVAR_ADMIN_FLAGS_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarGlobalAdminFlagsChange);
    _cvGlobalAdminFlags = convar.IntValue;


    char buffer[LOG_MAX_CONVAR];

    // custom level
    FormatEx(buffer, sizeof(buffer), LOG_CONVAR_CUSTOM_LEVEL, tag);
    convar = _CreateConVarOrSetFail(setFail, buffer, LOG_CONVAR_CUSTOM_LEVEL_DEFAULT, LOG_CONVAR_CUSTOM_LEVEL_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarCustomLevelChange);
    _cvCustomLevel = convar.IntValue;

    // custom location
    FormatEx(buffer, sizeof(buffer), LOG_CONVAR_CUSTOM_LOCATION, tag);
    convar = _CreateConVarOrSetFail(setFail, buffer, LOG_CONVAR_CUSTOM_LOCATION_DEFAULT, LOG_CONVAR_CUSTOM_LOCATION_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarCustomLocationChange);
    _cvCustomLocation = convar.IntValue;

    // custom parts
    FormatEx(buffer, sizeof(buffer), LOG_CONVAR_CUSTOM_PARTS, tag);
    convar = _CreateConVarOrSetFail(setFail, buffer, LOG_CONVAR_CUSTOM_PARTS_DEFAULT, LOG_CONVAR_CUSTOM_PARTS_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarCustomPartsChange);
    _cvCustomParts = convar.IntValue;

    // custom admin flags
    FormatEx(buffer, sizeof(buffer), LOG_CONVAR_CUSTOM_ADMIN_FLAGS, tag);
    convar = _CreateConVarOrSetFail(setFail, buffer, LOG_CONVAR_CUSTOM_ADMIN_FLAGS_DEFAULT, LOG_CONVAR_CUSTOM_ADMIN_FLAGS_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarCustomAdminFlagsChange);
    _cvCustomAdminFlags = convar.IntValue;

    // custom global contral
    FormatEx(buffer, sizeof(buffer), LOG_CONVAR_CUSTOM_GLOBAL_CONTRAL, tag);
    convar = _CreateConVarOrSetFail(setFail, buffer, LOG_CONVAR_CUSTOM_GLOBAL_CONTRAL_DEFAULT, LOG_CONVAR_CUSTOM_GLOBAL_CONTRAL_DESC, FCVAR_DONTRECORD);
    convar.AddChangeHook(_OnConVarCustomGlobalContralChange);
    _cvCustomGlobalContral = convar.BoolValue;

    // log version
    FormatEx(buffer, sizeof(buffer), LOG_CONVAR_VERSION_NAME, tag);
    convar = _CreateConVarOrSetFail(setFail, buffer, LOG_CONVAR_VERSION_DEFAULT, LOG_CONVAR_VERSION_DESC, FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
}

static ConVar _FindConVarOrCreate(
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

static ConVar _CreateConVarOrSetFail(
    bool setFail,
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

    if( convar != null )
    {
        if( setFail )
        {
            SetFailState("[%s] %s ConVar '%s' is already exists!", LOG_LEVEL_NAME_FATAL, _logTag, name);
        }
    }
    else
    {
        convar = CreateConVar(name, defaultValue, description, flags, hasMin, min, hasMax, max);
    }

    return convar;
}

static void _OnConVarGlobalLevelChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvGlobalLevel = convar.IntValue;
}

static void _OnConVarGlobalLocationChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvGlobalLocation = convar.IntValue;
}

static void _OnConVarGlobalPartsChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvGlobalParts = convar.IntValue;
}

static void _OnConVarGlobalAdminFlagsChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvGlobalAdminFlags = convar.BoolValue;
}


static void _OnConVarCustomLevelChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvCustomLevel = convar.IntValue;
}

static void _OnConVarCustomLocationChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvCustomLocation = convar.IntValue;
}

static void _OnConVarCustomPartsChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvCustomParts = convar.IntValue;
}

static void _OnConVarCustomAdminFlagsChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvCustomAdminFlags = convar.BoolValue;
}

static void _OnConVarCustomGlobalContralChange(ConVar convar, char[] old_value, char[] new_value)
{
    _cvCustomGlobalContral = convar.BoolValue;
}
