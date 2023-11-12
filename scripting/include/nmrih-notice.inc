/** Double-include prevention */
#if defined _nmrih_notice_included_
  #endinput
#endif
#define _nmrih_notice_included_



/**
 * Returns if a certain player is bleeding out.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              True if player has entered the game, false otherwise.
 * @error               Invalid client index.
 */
native bool NMR_Notice_IsBleedingOut(int client);

/**
 * Returns if a certain player is infected.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              True if player has entered the game, false otherwise.
 * @error               Invalid client index.
 */
native bool NMR_Notice_IsInfected(int client);

/**
 * Returns if a certain player Infection Time.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              True if player has entered the game, false otherwise.
 * @error               Invalid client index.
 */
native float NMR_Notice_GetInfectionTime(int client);

/**
 * Returns if a certain player Infection Death Time.
 *
 * @param client        Player index (index does not have to be connected).
 * @return              True if player has entered the game, false otherwise.
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
