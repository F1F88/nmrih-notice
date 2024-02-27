/** Double-include prevention */
#if defined _nmrih_notice_included_
  #endinput
#endif
#define _nmrih_notice_included_


/**
 * Return True when the client is bleeding, otherwise return False.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              Return True when the client is bleeding, otherwise return False.
 * @error               Invalid client index.
 */
native bool NMR_Notice_IsBleedingOut(int client);

/**
 * Return True when the client is vaccinated, otherwise return False.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              Return True when the client is vaccinated, otherwise return False.
 * @error               Invalid client index.
 */
native bool NMR_Notice_IsVaccinated(int client);

/**
 * Return True when the client is infected, otherwise return False.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              Return True when the client is infected, otherwise return False.
 * @error               Invalid client index.
 */
native bool NMR_Notice_IsInfected(int client);

/**
 * Return the client Infection Time.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              Return the client Infection Time.
 * @error               Invalid client index.
 */
native float NMR_Notice_GetInfectionTime(int client);

/**
 * Return the client Infection Death Time.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              Return the client Infection Death Time.
 * @error               Invalid client index.
 */
native float NMR_Notice_GetInfectionDeathTime(int client);


/**
 * Called when a client bleed out.
 *
 * @param client        Entity index of the bleed out client.
 * @return              Plugin_Handled or Plugin_Stop to skip real function.
 */
forward Action NMR_Notice_OnPlayerBleedOut(int client);

/**
 * Called before a client stop bleeding out.
 * Note1: 死亡不会触发
 * Note2: 复活不会触发
 * Note3: 使用 绷带、医疗包 后会连续触发两次
 * Note4: 使用 医疗箱治疗后 只会触发一次
 * Note5: 玩家 撤离后 只会触发一次
 *
 * @param client        Entity index of the bleed out client.
 * @return              Plugin_Handled or Plugin_Stop to skip real function.
 */
forward Action NMR_Notice_OnPlayerStopBleedingOut(int client);

/**
 * Called before a client become infected.
 *
 * @param client        Entity index of the bleed out client.
 * @return              Plugin_Handled or Plugin_Stop to skip real function.
 */
forward Action NMR_Notice_OnPlayerBecomeInfected(int client);

/**
 * Called before client cure infection.
 * Note1: 死亡不会触发
 * Note2: 复活会连续触发两次
 * Note3: 使用 疫苗 后只会触发一次
 *
 * @param client        Entity index of the bleed out client.
 * @return              Plugin_Handled or Plugin_Stop to skip real function.
 */
forward Action NMR_Notice_OnPlayerCureInfection(int client);



#define NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_BLEEDING   (1 << 0)
#define NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_INFECTED   (1 << 1)
#define NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_FF         (1 << 2)
#define NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_FK         (1 << 3)
#define NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_PASSWD     (1 << 4)
#define NMR_NOTICE_CLIENT_PREFS_BIT_ALL             NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_BLEEDING | NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_INFECTED | \
                                                    NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_FF | NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_FK | NMR_NOTICE_CLIENT_PREFS_BIT_SHOW_PASSWD
#define NMR_NOTICE_CLIENT_PREFS_BIT_DEFAULT         NMR_NOTICE_CLIENT_PREFS_BIT_ALL
