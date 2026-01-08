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
new bool:g_bPluginEnabled = true;

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
    if(!is_user_alive(id) || !g_bPluginEnabled)
        return HC_CONTINUE;

    if(g_iSpawnCount == 0)
        return HC_CONTINUE;

    // Небольшая задержка для корректного спавна
    set_task(0.1, "TaskRespawnPlayer", id);

    return HC_CONTINUE;
}

public TaskRespawnPlayer(id) {
    if(!is_user_alive(id))
        return;

    new Float:vOrigin[3], Float:vAngles[3];

    if(FindBestSpawnPoint(id, vOrigin, vAngles)) {
        // Телепортируем игрока
        set_entvar(id, var_origin, vOrigin);
        set_entvar(id, var_angles, vAngles);
        set_entvar(id, var_v_angle, vAngles);
        set_entvar(id, var_fixangle, 1);

        // Убираем эффект застревания
        set_entvar(id, var_velocity, Float:{0.0, 0.0, 0.0});
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

        for(new p = 1; p <= MaxClients; p++) {
            if(!is_user_alive(p) || p == id)
                continue;

            new Float:pOrigin[3];
            get_entvar(p, var_origin, pOrigin);

            new Float:distance = vector_distance(g_iSpawnPoints[i][SPAWN_ORIGIN], pOrigin);
            new TeamName:pTeam = get_member(p, m_iTeam);

            // Враги
            if(pTeam != team) {
                if(distance < minDistEnemy) {
                    score -= (minDistEnemy - distance) / 10.0;

                    // Дополнительный штраф если враг видит точку спавна
                    if(IsVisible(g_iSpawnPoints[i][SPAWN_ORIGIN], pOrigin)) {
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
        outOrigin[0] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][0];
        outOrigin[1] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][1];
        outOrigin[2] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][2];
        outAngles[0] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][0];
        outAngles[1] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][1];
        outAngles[2] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][2];
        g_iSpawnPoints[spawnIdx][SPAWN_LAST_USED] = fCurrentTime;
        return true;
    }

    // Выбираем лучшую точку из валидных (с весовой случайностью)
    new bestIdx = SelectWeightedRandom(scores, validSpawns, validCount);
    new spawnIdx = validSpawns[bestIdx];

    outOrigin[0] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][0];
    outOrigin[1] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][1];
    outOrigin[2] = g_iSpawnPoints[spawnIdx][SPAWN_ORIGIN][2];
    outAngles[0] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][0];
    outAngles[1] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][1];
    outAngles[2] = g_iSpawnPoints[spawnIdx][SPAWN_ANGLES][2];

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
            return i;
        }
    }

    return count - 1;
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

    // Получаем существующие точки спавна из карты
    new ent = -1;

    // Ищем info_player_start
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_start")) > 0) {
        AddSpawnFromEntity(ent, 0);
    }

    // Ищем info_player_deathmatch
    ent = -1;
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_deathmatch")) > 0) {
        AddSpawnFromEntity(ent, 0);
    }

    // Ищем точки спавна CT
    ent = -1;
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_ctsoldier")) > 0) {
        AddSpawnFromEntity(ent, 2); // CT = 2
    }

    // Ищем точки спавна T
    ent = -1;
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_terrorist")) > 0) {
        AddSpawnFromEntity(ent, 1); // T = 1
    }

    server_print("[CSDM] Сгенерировано %d точек спавна", g_iSpawnCount);

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

    g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][0] = origin[0];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][1] = origin[1];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][2] = origin[2];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][0] = angles[0];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][1] = angles[1];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][2] = angles[2];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_TEAM] = team;
    g_iSpawnPoints[g_iSpawnCount][SPAWN_LAST_USED] = 0.0;

    g_iSpawnCount++;
}

// Команды
public CmdAddSpawn(id, level, cid) {
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    if(g_iSpawnCount >= MAX_SPAWN_POINTS) {
        client_print(id, print_chat, "[CSDM] Достигнут лимит точек спавна (%d)", MAX_SPAWN_POINTS);
        return PLUGIN_HANDLED;
    }

    new Float:origin[3], Float:angles[3];
    get_entvar(id, var_origin, origin);
    get_entvar(id, var_angles, angles);

    g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][0] = origin[0];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][1] = origin[1];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][2] = origin[2];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][0] = angles[0];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][1] = angles[1];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][2] = angles[2];
    g_iSpawnPoints[g_iSpawnCount][SPAWN_TEAM] = 0;
    g_iSpawnPoints[g_iSpawnCount][SPAWN_LAST_USED] = 0.0;

    g_iSpawnCount++;

    client_print(id, print_chat, "[CSDM] Точка спавна добавлена. Всего: %d", g_iSpawnCount);

    return PLUGIN_HANDLED;
}

public CmdDelSpawn(id, level, cid) {
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    if(g_iSpawnCount == 0) {
        client_print(id, print_chat, "[CSDM] Нет точек спавна для удаления");
        return PLUGIN_HANDLED;
    }

    new Float:origin[3];
    get_entvar(id, var_origin, origin);

    new closest = -1;
    new Float:closestDist = 999999.0;

    for(new i = 0; i < g_iSpawnCount; i++) {
        new Float:dist = vector_distance(origin, g_iSpawnPoints[i][SPAWN_ORIGIN]);
        if(dist < closestDist) {
            closestDist = dist;
            closest = i;
        }
    }

    if(closest != -1) {
        // Сдвигаем массив
        for(new i = closest; i < g_iSpawnCount - 1; i++) {
            g_iSpawnPoints[i] = g_iSpawnPoints[i + 1];
        }
        g_iSpawnCount--;

        client_print(id, print_chat, "[CSDM] Точка спавна удалена (расстояние: %.1f). Всего: %d", closestDist, g_iSpawnCount);
    }

    return PLUGIN_HANDLED;
}

public CmdSaveSpawns(id, level, cid) {
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    SaveSpawnsForMap();
    client_print(id, print_chat, "[CSDM] Точки спавна сохранены (%d)", g_iSpawnCount);

    return PLUGIN_HANDLED;
}

public CmdLoadSpawns(id, level, cid) {
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    LoadSpawnsForMap();
    client_print(id, print_chat, "[CSDM] Точки спавна загружены (%d)", g_iSpawnCount);

    return PLUGIN_HANDLED;
}

public CmdClearSpawns(id, level, cid) {
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    g_iSpawnCount = 0;
    client_print(id, print_chat, "[CSDM] Все точки спавна очищены");

    return PLUGIN_HANDLED;
}

public CmdShowSpawns(id, level, cid) {
    if(!cmd_access(id, level, cid, 1))
        return PLUGIN_HANDLED;

    client_print(id, print_console, "=== CSDM Smart Spawn Info ===");
    client_print(id, print_console, "Всего точек спавна: %d", g_iSpawnCount);
    client_print(id, print_console, "Плагин: %s", g_bPluginEnabled ? "Включен" : "Выключен");
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

    new filePath[256];
    formatex(filePath, charsmax(filePath), "%s/csdm_spawns/%s.spawns", configDir, mapName);

    // Создаем директорию если не существует
    new dir[256];
    formatex(dir, charsmax(dir), "%s/csdm_spawns", configDir);

    if(!dir_exists(dir)) {
        mkdir(dir);
    }

    new file = fopen(filePath, "wt");
    if(!file) {
        server_print("[CSDM] Ошибка создания файла: %s", filePath);
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
    formatex(filePath, charsmax(filePath), "%s/csdm_spawns/%s.spawns", configDir, mapName);

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

        new Float:ox, Float:oy, Float:oz, Float:ax, Float:ay, Float:az, team;

        if(parse(buffer,
            ox, oy, oz,
            ax, ay, az,
            team) >= 6) {

            g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][0] = ox;
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][1] = oy;
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ORIGIN][2] = oz;
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][0] = ax;
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][1] = ay;
            g_iSpawnPoints[g_iSpawnCount][SPAWN_ANGLES][2] = az;
            g_iSpawnPoints[g_iSpawnCount][SPAWN_TEAM] = team;
            g_iSpawnPoints[g_iSpawnCount][SPAWN_LAST_USED] = 0.0;

            g_iSpawnCount++;
        }
    }

    fclose(file);
    server_print("[CSDM] Загружено %d точек спавна из %s", g_iSpawnCount, filePath);
}

// Вспомогательные функции
stock Float:parse(const string[], &Float:arg1, &Float:arg2, &Float:arg3, &Float:arg4, &Float:arg5, &Float:arg6, &arg7) {
    new s[7][32];
    new count = argparse(string, 7, s[0], 31, s[1], 31, s[2], 31, s[3], 31, s[4], 31, s[5], 31, s[6], 31);

    if(count >= 1) arg1 = str_to_float(s[0]);
    if(count >= 2) arg2 = str_to_float(s[1]);
    if(count >= 3) arg3 = str_to_float(s[2]);
    if(count >= 4) arg4 = str_to_float(s[3]);
    if(count >= 5) arg5 = str_to_float(s[4]);
    if(count >= 6) arg6 = str_to_float(s[5]);
    if(count >= 7) arg7 = str_to_num(s[6]);

    return count;
}
