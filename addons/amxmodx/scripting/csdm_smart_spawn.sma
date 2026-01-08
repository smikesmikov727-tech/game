/*
 * CSDM Smart Spawn Distribution Plugin
 *
 * Description: Умное рандомное распределение игроков по карте
 * - Автоматическая генерация точек спавна
 * - Учет расстояния до других игроков
 * - Проверка видимости
 * - Равномерное распределение по карте
 * - Защита от спавна в недавно использованных точках
 */

#include <amxmodx>
#include <reapi>
#include <fakemeta>

#define PLUGIN "CSDM Smart Spawn"
#define VERSION "1.0"
#define AUTHOR "Claude"

// Настройки
#define MAX_SPAWN_POINTS 128
#define MIN_DISTANCE_TO_PLAYER 300.0
#define MIN_DISTANCE_TO_ENEMY 500.0
#define SPAWN_REUSE_TIME 5.0
#define AUTO_GENERATE_SPAWNS true

// Структура точки спавна
enum _:SpawnData {
    Float:SPAWN_ORIGIN[3],
    Float:SPAWN_ANGLES[3],
    Float:SPAWN_LAST_USED,
    SPAWN_TEAM
}

new g_iSpawnPoints[MAX_SPAWN_POINTS][SpawnData];
new g_iSpawnCount = 0;

// CVars
new g_pCvarEnabled;
new g_pCvarMinDistPlayer;
new g_pCvarMinDistEnemy;
new g_pCvarReuseTime;
new g_pCvarAutoGenerate;

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    // Регистрация CVars
    g_pCvarEnabled = register_cvar("csdm_smart_spawn", "1");
    g_pCvarMinDistPlayer = register_cvar("csdm_spawn_min_dist_player", "300.0");
    g_pCvarMinDistEnemy = register_cvar("csdm_spawn_min_dist_enemy", "500.0");
    g_pCvarReuseTime = register_cvar("csdm_spawn_reuse_time", "5.0");
    g_pCvarAutoGenerate = register_cvar("csdm_spawn_autogenerate", "1");

    // Хуки REAPI
    RegisterHookChain(RG_CSGameRules_RestartRound, "RestartRound_Post", true);
    RegisterHookChain(RG_CBasePlayer_Spawn, "Player_Spawn_Post", true);

    // Команды
    register_concmd("csdm_addspawn", "CmdAddSpawn", ADMIN_MAP, "- Добавить точку спавна");
    register_concmd("csdm_delspawn", "CmdDelSpawn", ADMIN_MAP, "- Удалить ближайшую точку спавна");
    register_concmd("csdm_savespawns", "CmdSaveSpawns", ADMIN_MAP, "- Сохранить точки спавна");
    register_concmd("csdm_loadspawns", "CmdLoadSpawns", ADMIN_MAP, "- Загрузить точки спавна");
    register_concmd("csdm_clearspawns", "CmdClearSpawns", ADMIN_MAP, "- Очистить все точки спавна");
    register_concmd("csdm_showspawns", "CmdShowSpawns", ADMIN_MAP, "- Показать информацию о спавнах");
}

public plugin_cfg() {
    // Автозагрузка точек спавна для карты
    LoadSpawnsForMap();

    // Если точек нет и включена автогенерация - создаем
    if(g_iSpawnCount == 0 && get_pcvar_num(g_pCvarAutoGenerate)) {
        AutoGenerateSpawns();
    }
}

public RestartRound_Post() {
    // Сброс времени использования точек при рестарте раунда
    for(new i = 0; i < g_iSpawnCount; i++) {
        g_iSpawnPoints[i][SPAWN_LAST_USED] = 0.0;
    }
}

public Player_Spawn_Post(id) {
    if(!is_user_alive(id) || !get_pcvar_num(g_pCvarEnabled))
        return HC_CONTINUE;

    if(g_iSpawnCount == 0) {
        server_print("[CSDM DEBUG] Нет точек спавна для игрока %n", id);
        return HC_CONTINUE;
    }

    // Небольшая задержка для корректного спавна
    set_task(0.1, "TaskRespawnPlayer", id);

    return HC_CONTINUE;
}

public TaskRespawnPlayer(id) {
    // Удаляем предыдущую задачу если есть
    remove_task(id);

    if(!is_user_alive(id)) {
        server_print("[CSDM DEBUG] Игрок %d не жив при телепортации", id);
        return;
    }

    new Float:vOrigin[3], Float:vAngles[3];

    if(FindBestSpawnPoint(id, vOrigin, vAngles)) {
        server_print("[CSDM DEBUG] Телепортация игрока %d на точку (%.1f, %.1f, %.1f)",
            id, vOrigin[0], vOrigin[1], vOrigin[2]);

        // Устанавливаем новую позицию
        engfunc(EngFunc_SetOrigin, id, vOrigin);
        set_entvar(id, var_angles, vAngles);
        set_entvar(id, var_v_angle, vAngles);
        set_entvar(id, var_fixangle, 1);

        // Убираем velocity
        new Float:zero[3] = {0.0, 0.0, 0.0};
        set_entvar(id, var_velocity, zero);
        set_entvar(id, var_basevelocity, zero);
    } else {
        server_print("[CSDM DEBUG] Не удалось найти точку спавна для игрока %d", id);
    }
}

// Поиск лучшей точки спавна
bool:FindBestSpawnPoint(id, Float:outOrigin[3], Float:outAngles[3]) {
    if(g_iSpawnCount == 0)
        return false;

    new TeamName:team = get_member(id, m_iTeam);
    new Float:fCurrentTime = get_gametime();
    new Float:fReuseTime = get_pcvar_float(g_pCvarReuseTime);

    // Массив для хранения оценок точек спавна
    new Float:scores[MAX_SPAWN_POINTS];
    new validSpawns[MAX_SPAWN_POINTS];
    new validCount = 0;

    // Оцениваем каждую точку спавна
    for(new i = 0; i < g_iSpawnCount; i++) {
        // Пропускаем если точка для другой команды (если указана)
        if(g_iSpawnPoints[i][SPAWN_TEAM] != 0 && g_iSpawnPoints[i][SPAWN_TEAM] != _:team)
            continue;

        new Float:score = 100.0;

        // Штраф за недавнее использование
        new Float:timeSinceUse = fCurrentTime - g_iSpawnPoints[i][SPAWN_LAST_USED];
        if(timeSinceUse < fReuseTime) {
            score -= (fReuseTime - timeSinceUse) * 10.0;
        }

        // Проверяем расстояние до других игроков
        new Float:minDistPlayer = get_pcvar_float(g_pCvarMinDistPlayer);
        new Float:minDistEnemy = get_pcvar_float(g_pCvarMinDistEnemy);

        new Float:spawnPos[3];
        spawnPos[0] = g_iSpawnPoints[i][SPAWN_ORIGIN][0];
        spawnPos[1] = g_iSpawnPoints[i][SPAWN_ORIGIN][1];
        spawnPos[2] = g_iSpawnPoints[i][SPAWN_ORIGIN][2];

        for(new p = 1; p <= MaxClients; p++) {
            if(!is_user_alive(p) || p == id)
                continue;

            new Float:pOrigin[3];
            get_entvar(p, var_origin, pOrigin);

            new Float:distance = vector_distance(spawnPos, pOrigin);
            new TeamName:pTeam = get_member(p, m_iTeam);

            // Враги
            if(pTeam != team) {
                if(distance < minDistEnemy) {
                    score -= (minDistEnemy - distance) / 10.0;

                    // Дополнительный штраф если враг видит точку спавна
                    if(IsVisible(spawnPos, pOrigin)) {
                        score -= 50.0;
                    }
                }
            }
            // Союзники
            else {
                if(distance < minDistPlayer) {
                    score -= (minDistPlayer - distance) / 20.0;
                }
            }
        }

        // Если точка все еще приемлема - добавляем в список
        if(score > 0.0) {
            scores[validCount] = score;
            validSpawns[validCount] = i;
            validCount++;
        }
    }

    // Если нет валидных точек - берем любую
    if(validCount == 0) {
        new spawnIdx = random(g_iSpawnCount);
        for(new i = 0; i < 3; i++) {
            outOrigin[i] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][i];
            outAngles[i] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][i];
        }
        g_iSpawnPoints[spawnIdx][SPAWN_LAST_USED] = fCurrentTime;
        return true;
    }

    // Выбираем лучшую точку из валидных (с весовой случайностью)
    new spawnIdx = SelectWeightedRandom(scores, validSpawns, validCount);

    for(new i = 0; i < 3; i++) {
        outOrigin[i] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][i];
        outAngles[i] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][i];
    }

    g_iSpawnPoints[spawnIdx][SPAWN_LAST_USED] = fCurrentTime;

    return true;
}

// Взвешенный случайный выбор
SelectWeightedRandom(const Float:weights[], const indices[], count) {
    new Float:totalWeight = 0.0;
    for(new i = 0; i < count; i++) {
        totalWeight += weights[i];
    }

    new Float:randomValue = random_float(0.0, totalWeight);
    new Float:currentWeight = 0.0;

    for(new i = 0; i < count; i++) {
        currentWeight += weights[i];
        if(randomValue <= currentWeight) {
            return indices[i];
        }
    }

    return indices[count - 1];
}

// Проверка видимости
bool:IsVisible(const Float:start[3], const Float:end[3]) {
    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0);

    new Float:fraction;
    get_tr2(0, TR_flFraction, fraction);

    return (fraction >= 0.9);
}

// Автогенерация точек спавна
AutoGenerateSpawns() {
    new mapName[32];
    get_mapname(mapName, charsmax(mapName));

    server_print("[CSDM] Автогенерация точек спавна для карты %s...", mapName);

    g_iSpawnCount = 0; // Сбрасываем счетчик
    new ent = -1;
    new countT = 0, countCT = 0, countDM = 0;

    // Ищем точки спавна T (info_player_terrorist)
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_terrorist")) > 0) {
        AddSpawnFromEntity(ent, 0); // 0 = любая команда для CSDM
        countT++;
    }

    // Ищем точки спавна CT (info_player_counterterrorist)
    ent = -1;
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_counterterrorist")) > 0) {
        AddSpawnFromEntity(ent, 0); // 0 = любая команда для CSDM
        countCT++;
    }

    // Ищем точки DM (info_player_deathmatch)
    ent = -1;
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_deathmatch")) > 0) {
        AddSpawnFromEntity(ent, 0);
        countDM++;
    }

    server_print("[CSDM] Найдено точек: T=%d, CT=%d, DM=%d", countT, countCT, countDM);
    server_print("[CSDM] Всего сгенерировано %d точек спавна", g_iSpawnCount);

    if(g_iSpawnCount == 0) {
        server_print("[CSDM] ОШИБКА: Не найдено ни одной точки спавна!");
        return;
    }

    // Автосохранение
    SaveSpawnsForMap();
}

// Добавление точки спавна из entity
AddSpawnFromEntity(ent, team) {
    if(g_iSpawnCount >= MAX_SPAWN_POINTS)
        return;

    new Float:origin[3], Float:angles[3];
    get_entvar(ent, var_origin, origin);
    get_entvar(ent, var_angles, angles);

    for(new i = 0; i < 3; i++) {
        g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][i] = origin[i];
        g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][i] = angles[i];
    }
    g_iSpawnPoints[g_iSpawnCount][SPAWN_TEAM] = team;
    g_iSpawnPoints[g_iSpawnCount][SPAWN_LAST_USED] = 0.0;

    g_iSpawnCount++;
}

// Команды
public CmdAddSpawn(id, level, cid) {
    if(!(get_user_flags(id) & ADMIN_MAP)) {
        client_print(id, print_console, "У вас нет доступа к этой команде");
        return PLUGIN_HANDLED;
    }

    if(g_iSpawnCount >= MAX_SPAWN_POINTS) {
        client_print(id, print_chat, "[CSDM] Достигнут лимит точек спавна (%d)", MAX_SPAWN_POINTS);
        return PLUGIN_HANDLED;
    }

    new Float:origin[3], Float:angles[3];
    get_entvar(id, var_origin, origin);
    get_entvar(id, var_angles, angles);

    for(new i = 0; i < 3; i++) {
        g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][i] = origin[i];
        g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][i] = angles[i];
    }
    g_iSpawnPoints[g_iSpawnCount][SPAWN_TEAM] = 0;
    g_iSpawnPoints[g_iSpawnCount][SPAWN_LAST_USED] = 0.0;

    g_iSpawnCount++;

    client_print(id, print_chat, "[CSDM] Точка спавна добавлена. Всего: %d", g_iSpawnCount);

    return PLUGIN_HANDLED;
}

public CmdDelSpawn(id, level, cid) {
    if(!(get_user_flags(id) & ADMIN_MAP)) {
        client_print(id, print_console, "У вас нет доступа к этой команде");
        return PLUGIN_HANDLED;
    }

    if(g_iSpawnCount == 0) {
        client_print(id, print_chat, "[CSDM] Нет точек спавна для удаления");
        return PLUGIN_HANDLED;
    }

    new Float:origin[3];
    get_entvar(id, var_origin, origin);

    new closest = -1;
    new Float:closestDist = 999999.0;

    for(new i = 0; i < g_iSpawnCount; i++) {
        new Float:spawnPos[3];
        for(new j = 0; j < 3; j++) {
            spawnPos[j] = g_iSpawnPoints[i][SPAWN_ORIGIN][j];
        }
        new Float:dist = vector_distance(origin, spawnPos);
        if(dist < closestDist) {
            closestDist = dist;
            closest = i;
        }
    }

    if(closest != -1) {
        // Сдвигаем массив
        for(new i = closest; i < g_iSpawnCount - 1; i++) {
            for(new j = 0; j < 3; j++) {
                g_iSpawnPoints[i][SPAWN_ORIGIN][j] = g_iSpawnPoints[i + 1][SPAWN_ORIGIN][j];
                g_iSpawnPoints[i][SPAWN_ANGLES][j] = g_iSpawnPoints[i + 1][SPAWN_ANGLES][j];
            }
            g_iSpawnPoints[i][SPAWN_TEAM] = g_iSpawnPoints[i + 1][SPAWN_TEAM];
            g_iSpawnPoints[i][SPAWN_LAST_USED] = g_iSpawnPoints[i + 1][SPAWN_LAST_USED];
        }
        g_iSpawnCount--;

        client_print(id, print_chat, "[CSDM] Точка спавна удалена (расстояние: %.1f). Всего: %d", closestDist, g_iSpawnCount);
    }

    return PLUGIN_HANDLED;
}

public CmdSaveSpawns(id, level, cid) {
    if(!(get_user_flags(id) & ADMIN_MAP)) {
        client_print(id, print_console, "У вас нет доступа к этой команде");
        return PLUGIN_HANDLED;
    }

    SaveSpawnsForMap();
    client_print(id, print_chat, "[CSDM] Точки спавна сохранены (%d)", g_iSpawnCount);

    return PLUGIN_HANDLED;
}

public CmdLoadSpawns(id, level, cid) {
    if(!(get_user_flags(id) & ADMIN_MAP)) {
        client_print(id, print_console, "У вас нет доступа к этой команде");
        return PLUGIN_HANDLED;
    }

    LoadSpawnsForMap();
    client_print(id, print_chat, "[CSDM] Точки спавна загружены (%d)", g_iSpawnCount);

    return PLUGIN_HANDLED;
}

public CmdClearSpawns(id, level, cid) {
    if(!(get_user_flags(id) & ADMIN_MAP)) {
        client_print(id, print_console, "У вас нет доступа к этой команде");
        return PLUGIN_HANDLED;
    }

    g_iSpawnCount = 0;
    client_print(id, print_chat, "[CSDM] Все точки спавна очищены");

    return PLUGIN_HANDLED;
}

public CmdShowSpawns(id, level, cid) {
    if(!(get_user_flags(id) & ADMIN_MAP)) {
        client_print(id, print_console, "У вас нет доступа к этой команде");
        return PLUGIN_HANDLED;
    }

    client_print(id, print_console, "=== CSDM Smart Spawn Info ===");
    client_print(id, print_console, "Всего точек спавна: %d", g_iSpawnCount);
    client_print(id, print_console, "Плагин: %s", get_pcvar_num(g_pCvarEnabled) ? "Включен" : "Выключен");
    client_print(id, print_console, "Мин. расст. до игрока: %.1f", get_pcvar_float(g_pCvarMinDistPlayer));
    client_print(id, print_console, "Мин. расст. до врага: %.1f", get_pcvar_float(g_pCvarMinDistEnemy));
    client_print(id, print_console, "Время повтора: %.1f сек", get_pcvar_float(g_pCvarReuseTime));

    client_print(id, print_chat, "[CSDM] Информация выведена в консоль");

    return PLUGIN_HANDLED;
}

// Сохранение точек спавна
SaveSpawnsForMap() {
    new mapName[32];
    get_mapname(mapName, charsmax(mapName));

    new configDir[128];
    get_localinfo("amxx_configsdir", configDir, charsmax(configDir));

    // Создаем директорию если не существует
    new dir[256];
    formatex(dir, charsmax(dir), "%s/csdm_spawns", configDir);

    if(!dir_exists(dir)) {
        if(!mkdir(dir)) {
            server_print("[CSDM] Не удалось создать директорию: %s", dir);
            server_print("[CSDM] Попытка создать в текущей директории...");

            // Пробуем альтернативный путь
            formatex(dir, charsmax(dir), "csdm_spawns");
            if(!dir_exists(dir)) {
                mkdir(dir);
            }
        }
    }

    new filePath[256];
    formatex(filePath, charsmax(filePath), "%s/%s.spawns", dir, mapName);

    new file = fopen(filePath, "wt");
    if(!file) {
        server_print("[CSDM] Ошибка создания файла: %s", filePath);
        server_print("[CSDM] Проверьте права доступа к директории");
        return;
    }

    fprintf(file, "; CSDM Smart Spawn Points^n");
    fprintf(file, "; Карта: %s^n", mapName);
    fprintf(file, "; Точек: %d^n^n", g_iSpawnCount);

    for(new i = 0; i < g_iSpawnCount; i++) {
        fprintf(file, "%.2f %.2f %.2f %.2f %.2f %.2f %d^n",
            g_iSpawnPoints[i][SPAWN_ORIGIN][0],
            g_iSpawnPoints[i][SPAWN_ORIGIN][1],
            g_iSpawnPoints[i][SPAWN_ORIGIN][2],
            g_iSpawnPoints[i][SPAWN_ANGLES][0],
            g_iSpawnPoints[i][SPAWN_ANGLES][1],
            g_iSpawnPoints[i][SPAWN_ANGLES][2],
            g_iSpawnPoints[i][SPAWN_TEAM]
        );
    }

    fclose(file);
    server_print("[CSDM] Сохранено %d точек спавна в %s", g_iSpawnCount, filePath);
}

// Загрузка точек спавна
LoadSpawnsForMap() {
    new mapName[32];
    get_mapname(mapName, charsmax(mapName));

    new configDir[128];
    get_localinfo("amxx_configsdir", configDir, charsmax(configDir));

    new filePath[256];
    new dir[256];

    // Пробуем основной путь
    formatex(dir, charsmax(dir), "%s/csdm_spawns", configDir);
    formatex(filePath, charsmax(filePath), "%s/%s.spawns", dir, mapName);

    // Если не найден - пробуем альтернативный путь
    if(!file_exists(filePath)) {
        formatex(dir, charsmax(dir), "csdm_spawns");
        formatex(filePath, charsmax(filePath), "%s/%s.spawns", dir, mapName);
    }

    if(!file_exists(filePath)) {
        server_print("[CSDM] Файл спавнов не найден: %s", filePath);
        return;
    }

    new file = fopen(filePath, "rt");
    if(!file) {
        server_print("[CSDM] Ошибка открытия файла: %s", filePath);
        return;
    }

    g_iSpawnCount = 0;
    new buffer[256];

    while(!feof(file) && g_iSpawnCount < MAX_SPAWN_POINTS) {
        fgets(file, buffer, charsmax(buffer));
        trim(buffer);

        // Пропускаем комментарии и пустые строки
        if(buffer[0] == ';' || buffer[0] == '/' || buffer[0] == EOS)
            continue;

        new szOriginX[16], szOriginY[16], szOriginZ[16];
        new szAngleX[16], szAngleY[16], szAngleZ[16];
        new szTeam[4];

        if(parse(buffer,
            szOriginX, charsmax(szOriginX),
            szOriginY, charsmax(szOriginY),
            szOriginZ, charsmax(szOriginZ),
            szAngleX, charsmax(szAngleX),
            szAngleY, charsmax(szAngleY),
            szAngleZ, charsmax(szAngleZ),
            szTeam, charsmax(szTeam)) >= 6) {

            g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][0] = str_to_float(szOriginX);
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][1] = str_to_float(szOriginY);
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][2] = str_to_float(szOriginZ);
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][0] = str_to_float(szAngleX);
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][1] = str_to_float(szAngleY);
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][2] = str_to_float(szAngleZ);
            g_iSpawnPoints[g_iSpawnCount][SPAWN_TEAM] = str_to_num(szTeam);
            g_iSpawnPoints[g_iSpawnCount][SPAWN_LAST_USED] = 0.0;

            g_iSpawnCount++;
        }
    }

    fclose(file);
    server_print("[CSDM] Загружено %d точек спавна из %s", g_iSpawnCount, filePath);
}
