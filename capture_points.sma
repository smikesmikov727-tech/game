/*
 * CAPTURE POINTS v22 - Полностью переработанный плагин
 * - Умный респавн по всей карте без застреваний
 * - Новая логика захвата точек
 * - Ограничение спавна на захваченных точках
 * - Автоматическое исправление застревания
 */

#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <engine>
#include <xs>

// Попытка подключить внешние модули (если есть)
#tryinclude <level_system>
#tryinclude <stats_system>

// Если модулей нет - заглушки
#if !defined _level_system_included
    #define lvl_can_reward() true
    #define lvl_show_low_players(%1)
    #define lvl_add_money(%1,%2) rg_add_account(%1, %2)
    #define lvl_block_sound(%1,%2)
    #define lvl_give_xp(%1,%2)
    #define lvl_get_xp_point_recapture() 50
    #define lvl_get_xp_point_capture() 30
#endif

#if !defined _stats_system_included
    #define stats_add_point(%1)
#endif

#define PLUGIN_NAME     "Capture Points"
#define PLUGIN_VERSION  "22"
#define PLUGIN_AUTHOR   "AI"

// Константы
#define MAX_POINTS          16
#define MAX_SPAWN_POINTS    64
#define MAX_CLIENTS         32

// Настройки проверки позиций
#define MIN_WALL_DISTANCE       48.0    // Мин. расстояние от стен
#define MIN_GROUND_CLEARANCE    10.0    // Мин. высота над полом
#define MAX_DROP_HEIGHT         300.0   // Макс. высота падения при поиске пола
#define PLAYER_HEIGHT           72.0    // Высота игрока
#define PLAYER_WIDTH            32.0    // Ширина игрока
#define MIN_PLAYER_DISTANCE     80.0    // Мин. расстояние между игроками
#define POINT_MODEL_RADIUS      40.0    // Радиус модели точки захвата

// Модели точек
new const MODELS[][] = {
    "models/player/vip/vip.mdl",        // Нейтральная
    "models/player/terror/terror.mdl",  // Террористы
    "models/player/urban/urban.mdl"     // Спецназ
}

// === КВАРЫ ===
new pCvarPointsCount        // Количество точек
new pCvarCapTime            // Время захвата
new pCvarReward             // Награда команде
new pCvarMinDist            // Мин. расстояние между точками
new pCvarBaseDist           // Мин. расстояние от баз
new pCvarCapRadius          // Радиус захвата
new pCvarShowHud            // Показывать HUD
new pCvarSound              // Звук захвата
new pCvarEffect             // Эффекты захвата
new pCvarRecapBonus         // Бонус за отбитие
new pCvarSpawnPerPoint      // Макс. игроков на точку спавна
new pCvarContestTime        // Время для оспаривания точки
new pCvarWinPoints          // Очков для победы раунда

// === ДАННЫЕ ТОЧЕК ===
enum _:PointData {
    PT_ENT,                 // Entity точки
    Float:PT_X,             // Позиция X
    Float:PT_Y,             // Позиция Y
    Float:PT_Z,             // Позиция Z
    PT_STATE,               // 0 - нейтральная, 1 - T, 2 - CT
    PT_CONTEST,             // Оспаривается ли
    Float:PT_CONTEST_TIME,  // Время начала оспаривания
    PT_CONTEST_TEAM,        // Какая команда оспаривает
    PT_SPAWN_COUNT          // Сколько игроков заспавнилось здесь
}
new g_Points[MAX_POINTS][PointData]
new g_PointCount

// === ДАННЫЕ СПАВНОВ КАРТЫ ===
enum _:SpawnData {
    Float:SP_X,
    Float:SP_Y,
    Float:SP_Z,
    SP_TEAM,                // 1 - T, 2 - CT, 0 - найденный
    bool:SP_VALID           // Валидный ли спавн
}
new g_MapSpawns[MAX_SPAWN_POINTS][SpawnData]
new g_MapSpawnCount

// === ДАННЫЕ ИГРОКОВ ===
new bool:g_IsCapturing[MAX_CLIENTS + 1]
new Float:g_CapEndTime[MAX_CLIENTS + 1]
new g_CapPointIndex[MAX_CLIENTS + 1]
new g_LastSpawnPoint[MAX_CLIENTS + 1]
new g_SpawnedOnPoint[MAX_CLIENTS + 1]  // На какой точке заспавнился (-1 = база)

// === ГРАНИЦЫ КАРТЫ ===
new Float:g_MapBounds[6]  // MinX, MaxX, MinY, MaxY, MinZ, MaxZ
new Float:g_TeamBase[2][2]  // [team][x/y] - центры баз команд

// === РЕСУРСЫ ===
new g_SprBeam
new g_MsgSayText

// === СИНХРОНИЗАЦИЯ HUD ===
new g_HudSync

public plugin_precache()
{
    for(new i = 0; i < sizeof(MODELS); i++)
        precache_model(MODELS[i])

    g_SprBeam = precache_model("sprites/shockwave.spr")
    precache_sound("buttons/bell1.wav")
    precache_sound("buttons/blip1.wav")
    precache_sound("ambience/warn1.wav")
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    // Регистрация кваров
    pCvarPointsCount    = register_cvar("cp_points_count", "7")
    pCvarCapTime        = register_cvar("cp_capture_time", "8")
    pCvarReward         = register_cvar("cp_capture_reward", "500")
    pCvarMinDist        = register_cvar("cp_min_distance", "400")
    pCvarBaseDist       = register_cvar("cp_base_distance", "200")
    pCvarCapRadius      = register_cvar("cp_capture_radius", "120")
    pCvarShowHud        = register_cvar("cp_show_hud", "1")
    pCvarSound          = register_cvar("cp_capture_sound", "1")
    pCvarEffect         = register_cvar("cp_capture_effect", "1")
    pCvarRecapBonus     = register_cvar("cp_recapture_bonus", "700")
    pCvarSpawnPerPoint  = register_cvar("cp_spawn_per_point", "2")     // Макс 2 игрока на точку
    pCvarContestTime    = register_cvar("cp_contest_time", "3")       // 3 сек для оспаривания
    pCvarWinPoints      = register_cvar("cp_win_points", "5")         // 5 очков для победы

    // Хуки
    RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn_Pre", false)
    RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn_Post", true)
    RegisterHookChain(RG_CSGameRules_RestartRound, "OnRoundRestart", false)
    RegisterHookChain(RG_RoundEnd, "OnRoundEnd", false)

    // Команда для показа информации о точках
    register_clcmd("say /cp", "CmdShowPoints")
    register_clcmd("say_team /cp", "CmdShowPoints")

    g_MsgSayText = get_user_msgid("SayText")
    g_HudSync = CreateHudSyncObj()

    // Загрузка конфига
    new cfgDir[128]
    get_localinfo("amxx_configsdir", cfgDir, charsmax(cfgDir))
    server_cmd("exec %s/capture_points.cfg", cfgDir)
    server_exec()

    // Инициализация с задержкой
    set_task(2.0, "TaskInitialize")
}

// ============================================================================
// ИНИЦИАЛИЗАЦИЯ
// ============================================================================

public TaskInitialize()
{
    LogMessage("=== Инициализация Capture Points v%s ===", PLUGIN_VERSION)

    // Сбор спавнов карты и определение границ
    CollectMapSpawns()

    // Поиск дополнительных точек спавна по карте
    FindAdditionalSpawnPoints()

    // Создание точек захвата
    CreateCapturePoints()

    if(g_PointCount > 0)
    {
        LogMessage("Создано %d точек захвата", g_PointCount)
        set_task(3.0, "TaskAnnounce")
        set_task(1.0, "TaskCaptureThink", 0, _, _, "b")
    }
    else
    {
        LogMessage("ОШИБКА: Не удалось создать точки!")
    }
}

// Сбор всех спавнов карты
CollectMapSpawns()
{
    new Float:pos[3]
    new ent = -1
    new ctCount = 0, tCount = 0

    g_TeamBase[0][0] = 0.0; g_TeamBase[0][1] = 0.0  // T base
    g_TeamBase[1][0] = 0.0; g_TeamBase[1][1] = 0.0  // CT base

    new bool:firstPos = true

    // CT спавны (info_player_start)
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_start")) > 0)
    {
        if(g_MapSpawnCount >= MAX_SPAWN_POINTS) break

        get_entvar(ent, var_origin, pos)

        g_MapSpawns[g_MapSpawnCount][SP_X] = pos[0]
        g_MapSpawns[g_MapSpawnCount][SP_Y] = pos[1]
        g_MapSpawns[g_MapSpawnCount][SP_Z] = pos[2]
        g_MapSpawns[g_MapSpawnCount][SP_TEAM] = 2
        g_MapSpawns[g_MapSpawnCount][SP_VALID] = true
        g_MapSpawnCount++

        g_TeamBase[1][0] += pos[0]
        g_TeamBase[1][1] += pos[1]
        ctCount++

        UpdateMapBounds(pos, firstPos)
        firstPos = false
    }

    // T спавны (info_player_deathmatch)
    ent = -1
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_deathmatch")) > 0)
    {
        if(g_MapSpawnCount >= MAX_SPAWN_POINTS) break

        get_entvar(ent, var_origin, pos)

        g_MapSpawns[g_MapSpawnCount][SP_X] = pos[0]
        g_MapSpawns[g_MapSpawnCount][SP_Y] = pos[1]
        g_MapSpawns[g_MapSpawnCount][SP_Z] = pos[2]
        g_MapSpawns[g_MapSpawnCount][SP_TEAM] = 1
        g_MapSpawns[g_MapSpawnCount][SP_VALID] = true
        g_MapSpawnCount++

        g_TeamBase[0][0] += pos[0]
        g_TeamBase[0][1] += pos[1]
        tCount++

        UpdateMapBounds(pos, firstPos)
        firstPos = false
    }

    // Вычисляем центры баз
    if(ctCount > 0)
    {
        g_TeamBase[1][0] /= float(ctCount)
        g_TeamBase[1][1] /= float(ctCount)
    }
    if(tCount > 0)
    {
        g_TeamBase[0][0] /= float(tCount)
        g_TeamBase[0][1] /= float(tCount)
    }

    // Расширяем границы карты
    new Float:expandX = (g_MapBounds[1] - g_MapBounds[0]) * 0.15
    new Float:expandY = (g_MapBounds[3] - g_MapBounds[2]) * 0.15
    g_MapBounds[0] -= expandX
    g_MapBounds[1] += expandX
    g_MapBounds[2] -= expandY
    g_MapBounds[3] += expandY

    LogMessage("Найдено спавнов: CT=%d, T=%d", ctCount, tCount)
    LogMessage("Границы карты: X[%.0f..%.0f] Y[%.0f..%.0f] Z[%.0f..%.0f]",
        g_MapBounds[0], g_MapBounds[1], g_MapBounds[2], g_MapBounds[3], g_MapBounds[4], g_MapBounds[5])
}

UpdateMapBounds(Float:pos[3], bool:first)
{
    if(first)
    {
        g_MapBounds[0] = g_MapBounds[1] = pos[0]
        g_MapBounds[2] = g_MapBounds[3] = pos[1]
        g_MapBounds[4] = g_MapBounds[5] = pos[2]
    }
    else
    {
        if(pos[0] < g_MapBounds[0]) g_MapBounds[0] = pos[0]
        if(pos[0] > g_MapBounds[1]) g_MapBounds[1] = pos[0]
        if(pos[1] < g_MapBounds[2]) g_MapBounds[2] = pos[1]
        if(pos[1] > g_MapBounds[3]) g_MapBounds[3] = pos[1]
        if(pos[2] < g_MapBounds[4]) g_MapBounds[4] = pos[2]
        if(pos[2] > g_MapBounds[5]) g_MapBounds[5] = pos[2]
    }
}

// Поиск дополнительных валидных точек спавна по карте
FindAdditionalSpawnPoints()
{
    new gridSize = 10  // Сетка 10x10
    new Float:stepX = (g_MapBounds[1] - g_MapBounds[0]) / float(gridSize)
    new Float:stepY = (g_MapBounds[3] - g_MapBounds[2]) / float(gridSize)
    new Float:baseDist = get_pcvar_float(pCvarBaseDist)

    new foundCount = 0

    for(new gx = 1; gx < gridSize; gx++)
    {
        for(new gy = 1; gy < gridSize; gy++)
        {
            if(g_MapSpawnCount >= MAX_SPAWN_POINTS) break

            new Float:testX = g_MapBounds[0] + stepX * float(gx) + random_float(-stepX*0.3, stepX*0.3)
            new Float:testY = g_MapBounds[2] + stepY * float(gy) + random_float(-stepY*0.3, stepY*0.3)

            // Проверяем расстояние от баз
            new Float:distT = GetDistance2D(testX, testY, g_TeamBase[0][0], g_TeamBase[0][1])
            new Float:distCT = GetDistance2D(testX, testY, g_TeamBase[1][0], g_TeamBase[1][1])

            if(distT < baseDist || distCT < baseDist)
                continue

            // Ищем пол и проверяем позицию
            new Float:foundPos[3]
            if(FindValidGroundPosition(testX, testY, foundPos))
            {
                // Проверяем что не слишком близко к существующим спавнам
                new bool:tooClose = false
                for(new i = 0; i < g_MapSpawnCount; i++)
                {
                    new Float:dist = GetDistance2D(foundPos[0], foundPos[1],
                        g_MapSpawns[i][SP_X], g_MapSpawns[i][SP_Y])
                    if(dist < 150.0)
                    {
                        tooClose = true
                        break
                    }
                }

                if(!tooClose)
                {
                    g_MapSpawns[g_MapSpawnCount][SP_X] = foundPos[0]
                    g_MapSpawns[g_MapSpawnCount][SP_Y] = foundPos[1]
                    g_MapSpawns[g_MapSpawnCount][SP_Z] = foundPos[2]
                    g_MapSpawns[g_MapSpawnCount][SP_TEAM] = 0  // Нейтральный
                    g_MapSpawns[g_MapSpawnCount][SP_VALID] = true
                    g_MapSpawnCount++
                    foundCount++
                }
            }
        }
    }

    LogMessage("Найдено дополнительных точек спавна: %d", foundCount)
}

// Поиск валидной позиции на земле
bool:FindValidGroundPosition(Float:x, Float:y, Float:outPos[3])
{
    new Float:startZ = g_MapBounds[5] + 100.0
    new Float:endZ = g_MapBounds[4] - 100.0

    new Float:start[3], Float:end[3]
    start[0] = x
    start[1] = y
    start[2] = startZ
    end[0] = x
    end[1] = y
    end[2] = endZ

    // Трассировка вниз для поиска пола
    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

    new Float:fraction
    get_tr2(0, TR_flFraction, fraction)

    if(fraction >= 1.0)
        return false

    new Float:hitPos[3]
    get_tr2(0, TR_vecEndPos, hitPos)

    // Позиция игрока над полом
    outPos[0] = hitPos[0]
    outPos[1] = hitPos[1]
    outPos[2] = hitPos[2] + MIN_GROUND_CLEARANCE + 36.0

    // Проверяем валидность позиции
    return IsPositionValid(outPos, 0)
}

// ============================================================================
// СОЗДАНИЕ ТОЧЕК ЗАХВАТА
// ============================================================================

CreateCapturePoints()
{
    new maxPoints = get_pcvar_num(pCvarPointsCount)
    new Float:minDist = get_pcvar_float(pCvarMinDist)
    new Float:baseDist = get_pcvar_float(pCvarBaseDist)

    new attempts = 0
    new maxAttempts = 1000

    while(g_PointCount < maxPoints && attempts < maxAttempts)
    {
        attempts++

        new Float:testX = random_float(g_MapBounds[0], g_MapBounds[1])
        new Float:testY = random_float(g_MapBounds[2], g_MapBounds[3])

        // Проверка расстояния от баз
        new Float:distT = GetDistance2D(testX, testY, g_TeamBase[0][0], g_TeamBase[0][1])
        new Float:distCT = GetDistance2D(testX, testY, g_TeamBase[1][0], g_TeamBase[1][1])

        if(distT < baseDist || distCT < baseDist)
            continue

        // Проверка расстояния от других точек
        new bool:tooClose = false
        for(new i = 0; i < g_PointCount; i++)
        {
            new Float:dist = GetDistance2D(testX, testY, g_Points[i][PT_X], g_Points[i][PT_Y])
            if(dist < minDist)
            {
                tooClose = true
                break
            }
        }
        if(tooClose) continue

        // Поиск позиции на земле
        new Float:foundPos[3]
        if(FindValidGroundPosition(testX, testY, foundPos))
        {
            CreatePointEntity(foundPos)
        }
    }

    LogMessage("Создание точек: %d попыток, %d успешно", attempts, g_PointCount)
}

CreatePointEntity(Float:pos[3])
{
    if(g_PointCount >= MAX_POINTS) return

    new ent = rg_create_entity("info_target")
    if(!ent) return

    // Корректируем позицию для модели
    pos[2] -= 36.0  // Модель ставим на пол

    engfunc(EngFunc_SetOrigin, ent, pos)
    engfunc(EngFunc_SetModel, ent, MODELS[0])
    engfunc(EngFunc_SetSize, ent, Float:{-20.0, -20.0, 0.0}, Float:{20.0, 20.0, 72.0})

    set_entvar(ent, var_classname, "cp_point")
    set_entvar(ent, var_movetype, MOVETYPE_FLY)
    set_entvar(ent, var_solid, SOLID_TRIGGER)
    set_entvar(ent, var_sequence, 1)
    set_entvar(ent, var_framerate, 1.0)

    // Нейтральный белый цвет
    SetPointColor(ent, 255, 255, 255, 30)

    SetTouch(ent, "OnPointTouch")

    // Сохраняем данные
    g_Points[g_PointCount][PT_ENT] = ent
    g_Points[g_PointCount][PT_X] = pos[0]
    g_Points[g_PointCount][PT_Y] = pos[1]
    g_Points[g_PointCount][PT_Z] = pos[2]
    g_Points[g_PointCount][PT_STATE] = 0
    g_Points[g_PointCount][PT_CONTEST] = 0
    g_Points[g_PointCount][PT_SPAWN_COUNT] = 0

    g_PointCount++
}

SetPointColor(ent, r, g, b, alpha)
{
    new Float:clr[3]
    clr[0] = float(r)
    clr[1] = float(g)
    clr[2] = float(b)

    set_entvar(ent, var_renderfx, kRenderFxGlowShell)
    set_entvar(ent, var_rendercolor, clr)
    set_entvar(ent, var_rendermode, kRenderTransAlpha)
    set_entvar(ent, var_renderamt, float(alpha))
}

// ============================================================================
// ПРОВЕРКА ПОЗИЦИЙ (КЛЮЧЕВАЯ ФУНКЦИЯ)
// ============================================================================

// Полная проверка валидности позиции для спавна
bool:IsPositionValid(Float:pos[3], id)
{
    // 1. Проверка TraceHull - не в твёрдом объекте
    if(!IsHullClear(pos, id))
        return false

    // 2. Проверка расстояния до стен
    if(!CheckWallClearance(pos, MIN_WALL_DISTANCE))
        return false

    // 3. Проверка что есть пол под ногами
    if(!HasGroundBelow(pos))
        return false

    // 4. Проверка что есть пространство над головой
    if(!HasHeadroom(pos))
        return false

    // 5. Проверка расстояния до моделей точек захвата
    if(!CheckPointModelClearance(pos))
        return false

    // 6. Проверка расстояния до других игроков (если id != 0)
    if(id != 0 && !CheckPlayerClearance(pos, id))
        return false

    return true
}

// Проверка Hull (стандартная проверка коллизии)
bool:IsHullClear(Float:pos[3], id)
{
    engfunc(EngFunc_TraceHull, pos, pos, DONT_IGNORE_MONSTERS, HULL_HUMAN, id)

    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
        return false

    return true
}

// Проверка расстояния до стен во всех направлениях
bool:CheckWallClearance(Float:pos[3], Float:minDist)
{
    // 8 горизонтальных направлений
    static Float:angles[8] = { 0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0 }
    // 3 высоты: ноги, пояс, голова
    static Float:heights[3] = { 10.0, 36.0, 64.0 }

    for(new h = 0; h < sizeof(heights); h++)
    {
        new Float:checkPos[3]
        checkPos[0] = pos[0]
        checkPos[1] = pos[1]
        checkPos[2] = pos[2] + heights[h]

        for(new a = 0; a < sizeof(angles); a++)
        {
            new Float:rad = angles[a] * M_PI / 180.0
            new Float:endPos[3]
            endPos[0] = checkPos[0] + floatcos(rad) * minDist
            endPos[1] = checkPos[1] + floatsin(rad) * minDist
            endPos[2] = checkPos[2]

            engfunc(EngFunc_TraceLine, checkPos, endPos, IGNORE_MONSTERS, 0, 0)

            new Float:fraction
            get_tr2(0, TR_flFraction, fraction)

            if(fraction < 1.0)
                return false
        }
    }

    return true
}

// Проверка наличия пола
bool:HasGroundBelow(Float:pos[3])
{
    new Float:start[3], Float:end[3]
    start[0] = pos[0]
    start[1] = pos[1]
    start[2] = pos[2]
    end[0] = pos[0]
    end[1] = pos[1]
    end[2] = pos[2] - 100.0

    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

    new Float:fraction
    get_tr2(0, TR_flFraction, fraction)

    return (fraction < 1.0)
}

// Проверка пространства над головой
bool:HasHeadroom(Float:pos[3])
{
    new Float:start[3], Float:end[3]
    start[0] = pos[0]
    start[1] = pos[1]
    start[2] = pos[2]
    end[0] = pos[0]
    end[1] = pos[1]
    end[2] = pos[2] + PLAYER_HEIGHT

    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

    new Float:fraction
    get_tr2(0, TR_flFraction, fraction)

    return (fraction >= 1.0)
}

// Проверка расстояния до моделей точек захвата
bool:CheckPointModelClearance(Float:pos[3])
{
    for(new i = 0; i < g_PointCount; i++)
    {
        new Float:dx = pos[0] - g_Points[i][PT_X]
        new Float:dy = pos[1] - g_Points[i][PT_Y]
        new Float:dz = pos[2] - g_Points[i][PT_Z]
        new Float:dist = floatsqroot(dx*dx + dy*dy + dz*dz)

        if(dist < POINT_MODEL_RADIUS + PLAYER_WIDTH)
            return false
    }
    return true
}

// Проверка расстояния до других игроков
bool:CheckPlayerClearance(Float:pos[3], exceptId)
{
    new Float:playerPos[3]

    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        if(i == exceptId) continue
        if(!is_user_connected(i) || !is_user_alive(i)) continue

        get_entvar(i, var_origin, playerPos)

        new Float:dist = GetDistance3D(pos, playerPos)
        if(dist < MIN_PLAYER_DISTANCE)
            return false
    }

    return true
}

// Проверка застревания игрока
bool:IsPlayerStuck(id)
{
    if(!is_user_alive(id))
        return false

    new Float:origin[3]
    get_entvar(id, var_origin, origin)

    // Проверка TraceHull
    engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, HULL_HUMAN, id)

    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
        return true

    // Проверка застревания в модели точки
    for(new i = 0; i < g_PointCount; i++)
    {
        new Float:pointPos[3]
        pointPos[0] = g_Points[i][PT_X]
        pointPos[1] = g_Points[i][PT_Y]
        pointPos[2] = g_Points[i][PT_Z]

        new Float:dist = GetDistance3D(origin, pointPos)
        if(dist < 50.0)
            return true
    }

    // Проверка блокировки со всех сторон
    new blockedSides = 0
    static Float:testAngles[4] = { 0.0, 90.0, 180.0, 270.0 }

    for(new i = 0; i < 4; i++)
    {
        new Float:rad = testAngles[i] * M_PI / 180.0
        new Float:endPos[3]
        endPos[0] = origin[0] + floatcos(rad) * 24.0
        endPos[1] = origin[1] + floatsin(rad) * 24.0
        endPos[2] = origin[2]

        engfunc(EngFunc_TraceLine, origin, endPos, IGNORE_MONSTERS, id, 0)

        new Float:fraction
        get_tr2(0, TR_flFraction, fraction)

        if(fraction < 1.0)
            blockedSides++
    }

    return (blockedSides >= 3)
}

// ============================================================================
// СИСТЕМА СПАВНА
// ============================================================================

public OnPlayerSpawn_Pre(id)
{
    g_IsCapturing[id] = false
    g_CapPointIndex[id] = -1
    g_SpawnedOnPoint[id] = -1
    g_LastSpawnPoint[id] = -1
    remove_task(id)
}

public OnPlayerSpawn_Post(id)
{
    if(!is_user_alive(id)) return

    new TeamName:team = get_member(id, m_iTeam)
    if(team != TEAM_TERRORIST && team != TEAM_CT) return

    // Определяем где спавнить игрока
    new Float:spawnPos[3]
    new spawnResult = DetermineSpawnPosition(id, team, spawnPos)

    if(spawnResult >= 0)
    {
        // Телепортируем на новую позицию
        set_entvar(id, var_origin, spawnPos)

        // Проверка через короткий промежуток - автоматическое исправление застревания
        set_task(0.1, "TaskCheckSpawnStuck", id)
    }
}

// Определение позиции спавна
// Возвращает: -1 = стандартный спавн, >= 0 = индекс точки
DetermineSpawnPosition(id, TeamName:team, Float:outPos[3])
{
    new teamIndex = (team == TEAM_CT) ? 2 : 1
    new maxPerPoint = get_pcvar_num(pCvarSpawnPerPoint)

    // Считаем точки команды
    new teamPoints[MAX_POINTS], teamPointCount = 0
    for(new i = 0; i < g_PointCount; i++)
    {
        if(g_Points[i][PT_STATE] == teamIndex)
            teamPoints[teamPointCount++] = i
    }

    // Если нет захваченных точек - спавн на базе или рандом по карте
    if(teamPointCount == 0)
    {
        // 50% шанс рандомного спавна по карте
        if(random(100) < 50)
        {
            if(FindRandomMapSpawn(id, outPos))
            {
                g_SpawnedOnPoint[id] = -1
                return 0  // Возвращаем 0 чтобы активировать телепорт
            }
        }
        return -1  // Стандартный спавн на базе
    }

    // Выбираем точку для спавна с учётом лимита
    new availablePoints[MAX_POINTS], availableCount = 0

    for(new i = 0; i < teamPointCount; i++)
    {
        new ptIdx = teamPoints[i]
        if(g_Points[ptIdx][PT_SPAWN_COUNT] < maxPerPoint)
            availablePoints[availableCount++] = ptIdx
    }

    // Если все точки заняты - рандомный спавн по карте
    if(availableCount == 0)
    {
        if(FindRandomMapSpawn(id, outPos))
        {
            g_SpawnedOnPoint[id] = -1
            return 0
        }
        return -1  // Стандартный спавн
    }

    // Выбираем случайную доступную точку
    new selectedPoint = availablePoints[random(availableCount)]

    // Ищем безопасную позицию около точки
    if(FindSafeSpawnNearPoint(id, selectedPoint, outPos))
    {
        g_Points[selectedPoint][PT_SPAWN_COUNT]++
        g_SpawnedOnPoint[id] = selectedPoint
        g_LastSpawnPoint[id] = selectedPoint
        return selectedPoint
    }

    // Не нашли место около точки - рандомный спавн
    if(FindRandomMapSpawn(id, outPos))
    {
        g_SpawnedOnPoint[id] = -1
        return 0
    }

    return -1
}

// Поиск безопасной позиции около точки захвата
bool:FindSafeSpawnNearPoint(id, pointIndex, Float:outPos[3])
{
    new Float:ptX = g_Points[pointIndex][PT_X]
    new Float:ptY = g_Points[pointIndex][PT_Y]
    new Float:ptZ = g_Points[pointIndex][PT_Z]

    // Расстояния и углы для поиска (начинаем дальше от модели)
    static Float:distances[] = { 100.0, 130.0, 160.0, 190.0, 220.0, 250.0 }
    static Float:angles[] = { 0.0, 30.0, 60.0, 90.0, 120.0, 150.0, 180.0, 210.0, 240.0, 270.0, 300.0, 330.0 }

    for(new d = 0; d < sizeof(distances); d++)
    {
        // Перемешиваем углы для разнообразия
        new startAngle = random(sizeof(angles))

        for(new a = 0; a < sizeof(angles); a++)
        {
            new angleIdx = (startAngle + a) % sizeof(angles)
            new Float:rad = angles[angleIdx] * M_PI / 180.0

            new Float:testX = ptX + floatcos(rad) * distances[d]
            new Float:testY = ptY + floatsin(rad) * distances[d]

            // Ищем пол
            new Float:foundPos[3]
            if(FindValidGroundPositionEx(testX, testY, ptZ, foundPos))
            {
                if(IsPositionValid(foundPos, id))
                {
                    outPos[0] = foundPos[0]
                    outPos[1] = foundPos[1]
                    outPos[2] = foundPos[2]
                    return true
                }
            }
        }
    }

    return false
}

// Расширенный поиск позиции на земле
bool:FindValidGroundPositionEx(Float:x, Float:y, Float:baseZ, Float:outPos[3])
{
    new Float:start[3], Float:end[3]
    start[0] = x
    start[1] = y
    start[2] = baseZ + 200.0
    end[0] = x
    end[1] = y
    end[2] = baseZ - 200.0

    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

    new Float:fraction
    get_tr2(0, TR_flFraction, fraction)

    if(fraction >= 1.0)
        return false

    new Float:hitPos[3]
    get_tr2(0, TR_vecEndPos, hitPos)

    outPos[0] = hitPos[0]
    outPos[1] = hitPos[1]
    outPos[2] = hitPos[2] + 36.0

    return true
}

// Поиск случайного спавна по карте
bool:FindRandomMapSpawn(id, Float:outPos[3])
{
    // Собираем доступные спавны
    new available[MAX_SPAWN_POINTS], availCount = 0

    for(new i = 0; i < g_MapSpawnCount; i++)
    {
        if(!g_MapSpawns[i][SP_VALID]) continue

        new Float:testPos[3]
        testPos[0] = g_MapSpawns[i][SP_X]
        testPos[1] = g_MapSpawns[i][SP_Y]
        testPos[2] = g_MapSpawns[i][SP_Z] + 10.0

        // Проверяем только расстояние до игроков (остальное уже проверено)
        if(CheckPlayerClearance(testPos, id))
            available[availCount++] = i
    }

    if(availCount == 0)
        return false

    // Выбираем случайный
    new selected = available[random(availCount)]
    outPos[0] = g_MapSpawns[selected][SP_X]
    outPos[1] = g_MapSpawns[selected][SP_Y]
    outPos[2] = g_MapSpawns[selected][SP_Z] + 10.0

    return true
}

// Автоматическая проверка и исправление застревания после спавна
public TaskCheckSpawnStuck(id)
{
    if(!is_user_alive(id)) return

    if(IsPlayerStuck(id))
    {
        // Пробуем автоматически исправить застревание
        if(!AutoFixStuck(id))
        {
            // Если не получилось - телепортируем на базу
            TeleportToBase(id)
            SendMessage(id, "^4[CP]^1 Автоматический телепорт на базу (обнаружено застревание)")
        }
    }
}

// Автоматическое исправление застревания
bool:AutoFixStuck(id)
{
    new Float:pos[3]
    get_entvar(id, var_origin, pos)

    static Float:distances[] = { 48.0, 80.0, 112.0, 144.0, 176.0 }
    static Float:angles[] = { 0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0 }
    static Float:zOffsets[] = { 0.0, 32.0, 64.0, -16.0, 96.0 }

    // Сначала пробуем смещение по вертикали
    for(new z = 0; z < sizeof(zOffsets); z++)
    {
        new Float:testPos[3]
        testPos[0] = pos[0]
        testPos[1] = pos[1]
        testPos[2] = pos[2] + zOffsets[z]

        if(IsHullClear(testPos, id) && CheckWallClearance(testPos, 32.0))
        {
            set_entvar(id, var_origin, testPos)
            return true
        }
    }

    // Затем пробуем разные направления
    for(new d = 0; d < sizeof(distances); d++)
    {
        for(new a = 0; a < sizeof(angles); a++)
        {
            new Float:rad = angles[a] * M_PI / 180.0

            for(new z = 0; z < 3; z++)
            {
                new Float:testPos[3]
                testPos[0] = pos[0] + floatcos(rad) * distances[d]
                testPos[1] = pos[1] + floatsin(rad) * distances[d]
                testPos[2] = pos[2] + zOffsets[z]

                if(IsHullClear(testPos, id) && CheckWallClearance(testPos, 32.0))
                {
                    set_entvar(id, var_origin, testPos)
                    return true
                }
            }
        }
    }

    return false
}

// Телепорт на базовый спавн команды
TeleportToBase(id)
{
    new TeamName:team = get_member(id, m_iTeam)
    new spawnClass[32]

    if(team == TEAM_CT)
        copy(spawnClass, charsmax(spawnClass), "info_player_start")
    else if(team == TEAM_TERRORIST)
        copy(spawnClass, charsmax(spawnClass), "info_player_deathmatch")
    else
        return

    new Float:spawns[32][3], spawnCount = 0
    new ent = -1

    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", spawnClass)) > 0 && spawnCount < 32)
    {
        new Float:pos[3]
        get_entvar(ent, var_origin, pos)
        spawns[spawnCount][0] = pos[0]
        spawns[spawnCount][1] = pos[1]
        spawns[spawnCount][2] = pos[2]
        spawnCount++
    }

    if(spawnCount == 0)
        return

    for(new attempt = 0; attempt < spawnCount; attempt++)
    {
        new idx = random(spawnCount)
        new Float:testPos[3]
        testPos[0] = spawns[idx][0]
        testPos[1] = spawns[idx][1]
        testPos[2] = spawns[idx][2] + 10.0

        if(IsHullClear(testPos, id))
        {
            set_entvar(id, var_origin, testPos)
            return
        }
    }

    // Fallback
    new Float:fallback[3]
    fallback[0] = spawns[0][0]
    fallback[1] = spawns[0][1]
    fallback[2] = spawns[0][2] + 10.0
    set_entvar(id, var_origin, fallback)
}

// ============================================================================
// СИСТЕМА ЗАХВАТА
// ============================================================================

public OnPointTouch(ent, id)
{
    if(!is_user_connected(id) || !is_user_alive(id)) return

    new TeamName:team = get_member(id, m_iTeam)
    if(team != TEAM_TERRORIST && team != TEAM_CT) return

    // Находим индекс точки
    new pointIndex = GetPointIndex(ent)
    if(pointIndex == -1) return

    new teamIndex = (team == TEAM_CT) ? 2 : 1
    new capTime = get_pcvar_num(pCvarCapTime)
    new Float:gameTime = get_gametime()

    // Если точка уже наша
    if(g_Points[pointIndex][PT_STATE] == teamIndex)
    {
        ShowPointStatus(id, pointIndex, teamIndex)
        return
    }

    // Если уже захватываем эту точку
    if(g_IsCapturing[id] && g_CapPointIndex[id] == pointIndex)
    {
        // Проверка времени захвата
        if(gameTime >= g_CapEndTime[id])
        {
            CompleteCapture(id, pointIndex, teamIndex)
        }
        return
    }

    // Начинаем захват
    StartCapture(id, pointIndex, teamIndex, capTime)

    // Запускаем проверку захвата
    new data[2]
    data[0] = pointIndex
    data[1] = ent
    set_task(0.3, "TaskCaptureProgress", id, data, 2, "b")
}

StartCapture(id, pointIndex, teamIndex, capTime)
{
    g_IsCapturing[id] = true
    g_CapEndTime[id] = get_gametime() + float(capTime)
    g_CapPointIndex[id] = pointIndex

    new name[32]
    get_user_name(id, name, charsmax(name))

    // Оповещение о начале захвата
    if(get_pcvar_num(pCvarSound))
        client_cmd(0, "spk buttons/blip1")

    new TeamName:team = (teamIndex == 2) ? TEAM_CT : TEAM_TERRORIST
    SendTeamMessage(team, "^4[CP]^3 %s^1 начал захват точки^4 #%d", name, pointIndex + 1)

    // Оповещение врагов если точка их
    new enemyState = (teamIndex == 2) ? 1 : 2
    if(g_Points[pointIndex][PT_STATE] == enemyState)
    {
        new TeamName:enemyTeam = (teamIndex == 2) ? TEAM_TERRORIST : TEAM_CT
        SendTeamMessage(enemyTeam, "^4[CP]^1 ВНИМАНИЕ! Враг захватывает вашу точку^4 #%d^1!", pointIndex + 1)

        // Звуковое предупреждение для защитников
        if(get_pcvar_num(pCvarSound))
        {
            for(new i = 1; i <= MAX_CLIENTS; i++)
            {
                if(is_user_connected(i) && get_member(i, m_iTeam) == enemyTeam)
                    client_cmd(i, "spk ambience/warn1")
            }
        }
    }
}

public TaskCaptureProgress(data[], id)
{
    if(!is_user_connected(id) || !is_user_alive(id))
    {
        StopCapture(id)
        return
    }

    if(!g_IsCapturing[id])
    {
        remove_task(id)
        return
    }

    new pointIndex = data[0]
    new ent = data[1]

    if(!pev_valid(ent) || pointIndex < 0 || pointIndex >= g_PointCount)
    {
        StopCapture(id)
        return
    }

    // Проверка расстояния до точки
    new Float:playerPos[3], Float:pointPos[3]
    get_entvar(id, var_origin, playerPos)
    pointPos[0] = g_Points[pointIndex][PT_X]
    pointPos[1] = g_Points[pointIndex][PT_Y]
    pointPos[2] = g_Points[pointIndex][PT_Z]

    new Float:capRadius = get_pcvar_float(pCvarCapRadius)
    if(GetDistance3D(playerPos, pointPos) > capRadius)
    {
        StopCapture(id)
        SendMessage(id, "^4[CP]^1 Захват прерван - ты вышел из зоны!")
        return
    }

    // Показываем прогресс
    if(get_pcvar_num(pCvarShowHud))
    {
        ShowCaptureProgress(id, pointIndex)
    }
}

ShowCaptureProgress(id, pointIndex)
{
    new capTime = get_pcvar_num(pCvarCapTime)
    if(capTime <= 0) capTime = 1

    new Float:timeLeft = g_CapEndTime[id] - get_gametime()
    new percent = 100 - floatround(timeLeft * 100.0 / float(capTime))
    if(percent < 0) percent = 0
    if(percent > 100) percent = 100

    new TeamName:team = get_member(id, m_iTeam)
    new teamIndex = (team == TEAM_CT) ? 2 : 1
    new enemyState = (teamIndex == 2) ? 1 : 2

    new reward = get_pcvar_num(pCvarReward)
    new xpReward = (g_Points[pointIndex][PT_STATE] == enemyState) ? lvl_get_xp_point_recapture() : lvl_get_xp_point_capture()
    new captureType[32]

    if(g_Points[pointIndex][PT_STATE] == enemyState)
        copy(captureType, charsmax(captureType), "ВРАЖЕСКАЯ")
    else
        copy(captureType, charsmax(captureType), "НЕЙТРАЛЬНАЯ")

    // Цвет прогресс-бара
    new r, g, b
    if(percent < 33) { r = 255; g = 50; b = 50; }
    else if(percent < 66) { r = 255; g = 200; b = 0; }
    else { r = 50; g = 255; b = 50; }

    // Прогресс-бар
    new bar[21]
    new filled = percent / 5
    for(new i = 0; i < 20; i++)
        bar[i] = (i < filled) ? '|' : '.'
    bar[20] = 0

    set_hudmessage(r, g, b, -1.0, 0.65, 0, 0.0, 0.4, 0.0, 0.0, 2)
    ShowSyncHudMsg(id, g_HudSync, ">>> ЗАХВАТ ТОЧКИ #%d (%s) <<<^n[ %s ] %d%%^n^nНаграда: $%d команде | XP: +%d",
        pointIndex + 1, captureType, bar, percent, reward, xpReward)
}

ShowPointStatus(id, pointIndex, teamIndex)
{
    if(!get_pcvar_num(pCvarShowHud)) return

    new r = (teamIndex == 2) ? 100 : 255
    new b = (teamIndex == 2) ? 255 : 100
    new teamName[16]
    copy(teamName, charsmax(teamName), (teamIndex == 2) ? "СПЕЦНАЗ" : "ТЕРРОРИСТЫ")

    set_hudmessage(r, 150, b, -1.0, 0.65, 0, 0.0, 0.4, 0.0, 0.0, 2)
    ShowSyncHudMsg(id, g_HudSync, "~ ТОЧКА #%d ~^n[ %s ]", pointIndex + 1, teamName)
}

CompleteCapture(id, pointIndex, teamIndex)
{
    new oldState = g_Points[pointIndex][PT_STATE]
    g_Points[pointIndex][PT_STATE] = teamIndex
    g_Points[pointIndex][PT_SPAWN_COUNT] = 0  // Сброс счётчика спавна

    StopCapture(id)

    // Обновляем модель и цвет точки
    new ent = g_Points[pointIndex][PT_ENT]
    if(teamIndex == 2)
    {
        engfunc(EngFunc_SetModel, ent, MODELS[2])
        SetPointColor(ent, 0, 100, 255, 50)
    }
    else
    {
        engfunc(EngFunc_SetModel, ent, MODELS[1])
        SetPointColor(ent, 255, 50, 50, 50)
    }

    // Награды
    new reward = get_pcvar_num(pCvarReward)
    new TeamName:team = (teamIndex == 2) ? TEAM_CT : TEAM_TERRORIST
    new enemyState = (teamIndex == 2) ? 1 : 2

    new bool:canReward = bool:lvl_can_reward()
    if(!canReward)
        lvl_show_low_players(id)

    // Выдаём награду команде
    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        if(!is_user_connected(i)) continue
        if(get_member(i, m_iTeam) == team && canReward)
            lvl_add_money(i, reward)
    }

    // XP и бонусы захватчику
    if(canReward)
    {
        if(oldState == enemyState)
        {
            lvl_give_xp(id, lvl_get_xp_point_recapture())
            lvl_add_money(id, get_pcvar_num(pCvarRecapBonus))
        }
        else
        {
            lvl_give_xp(id, lvl_get_xp_point_capture())
        }
        stats_add_point(id)
    }

    // Звук и эффекты
    if(get_pcvar_num(pCvarSound))
    {
        for(new i = 1; i <= MAX_CLIENTS; i++)
        {
            if(is_user_connected(i))
                lvl_block_sound(i, 2.0)
        }
        client_cmd(0, "spk buttons/bell1")
    }

    if(get_pcvar_num(pCvarEffect))
        CreateCaptureEffect(pointIndex, teamIndex)

    // Сообщения
    new name[32]
    get_user_name(id, name, charsmax(name))

    if(oldState == enemyState)
    {
        SendTeamMessage(team, "^4[CP]^3 %s^1 отбил вражескую точку^4 #%d^1! [^3+$%d бонус^1]",
            name, pointIndex + 1, get_pcvar_num(pCvarRecapBonus))

        new TeamName:enemyTeam = (teamIndex == 2) ? TEAM_TERRORIST : TEAM_CT
        SendTeamMessage(enemyTeam, "^4[CP]^3 %s^1 захватил вашу точку^4 #%d^1!", name, pointIndex + 1)
    }
    else
    {
        SendAll("^4[CP]^3 %s^1 захватил нейтральную точку^4 #%d", name, pointIndex + 1)
    }

    // Счёт
    new ctPoints = 0, tPoints = 0
    for(new i = 0; i < g_PointCount; i++)
    {
        if(g_Points[i][PT_STATE] == 2) ctPoints++
        else if(g_Points[i][PT_STATE] == 1) tPoints++
    }

    SendAll("^4[CP]^1 Команда^3 %s^1 получила^4 +$%d", teamIndex == 2 ? "CT" : "T", reward)
    SendAll("^4[CP]^1 Счёт: CT:^3%d^1 | T:^3%d^1 | Нейтр:^3%d", ctPoints, tPoints, g_PointCount - ctPoints - tPoints)

    // Проверка победы
    CheckVictoryCondition()
}

CreateCaptureEffect(pointIndex, teamIndex)
{
    new Float:pos[3]
    pos[0] = g_Points[pointIndex][PT_X]
    pos[1] = g_Points[pointIndex][PT_Y]
    pos[2] = g_Points[pointIndex][PT_Z]

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMCYLINDER)
    write_coord(floatround(pos[0]))
    write_coord(floatround(pos[1]))
    write_coord(floatround(pos[2]))
    write_coord(floatround(pos[0]))
    write_coord(floatround(pos[1]))
    write_coord(floatround(pos[2] + 400.0))
    write_short(g_SprBeam)
    write_byte(0)
    write_byte(0)
    write_byte(10)
    write_byte(60)
    write_byte(0)
    write_byte(teamIndex == 2 ? 0 : 255)
    write_byte(0)
    write_byte(teamIndex == 2 ? 255 : 0)
    write_byte(255)
    write_byte(0)
    message_end()
}

StopCapture(id)
{
    g_IsCapturing[id] = false
    g_CapPointIndex[id] = -1
    remove_task(id)
}

GetPointIndex(ent)
{
    for(new i = 0; i < g_PointCount; i++)
    {
        if(g_Points[i][PT_ENT] == ent)
            return i
    }
    return -1
}

// Проверка условий победы
CheckVictoryCondition()
{
    new winPoints = get_pcvar_num(pCvarWinPoints)
    if(winPoints <= 0) return

    new ctPoints = 0, tPoints = 0
    for(new i = 0; i < g_PointCount; i++)
    {
        if(g_Points[i][PT_STATE] == 2) ctPoints++
        else if(g_Points[i][PT_STATE] == 1) tPoints++
    }

    if(ctPoints >= winPoints)
    {
        SendAll("^4[CP]^1 Спецназ захватил^3 %d точек^1 и побеждает!", ctPoints)
        // Можно добавить rg_round_end здесь
    }
    else if(tPoints >= winPoints)
    {
        SendAll("^4[CP]^1 Террористы захватили^3 %d точек^1 и побеждают!", tPoints)
        // Можно добавить rg_round_end здесь
    }
}

// Периодическая проверка состояния захвата
public TaskCaptureThink()
{
    // Здесь можно добавить логику оспаривания точек,
    // постепенного захвата при нескольких игроках и т.д.
}

// ============================================================================
// КОМАНДЫ ИГРОКОВ
// ============================================================================

public CmdShowPoints(id)
{
    new ctPoints = 0, tPoints = 0, neutral = 0

    for(new i = 0; i < g_PointCount; i++)
    {
        if(g_Points[i][PT_STATE] == 2) ctPoints++
        else if(g_Points[i][PT_STATE] == 1) tPoints++
        else neutral++
    }

    SendMessage(id, "^4[CP]^1 Всего точек:^3 %d", g_PointCount)
    SendMessage(id, "^4[CP]^1 CT:^3 %d^1 | T:^3 %d^1 | Нейтральных:^3 %d", ctPoints, tPoints, neutral)

    return PLUGIN_HANDLED
}

// ============================================================================
// СОБЫТИЯ
// ============================================================================

public OnRoundRestart()
{
    // Сброс данных игроков
    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        g_IsCapturing[i] = false
        g_CapPointIndex[i] = -1
        g_SpawnedOnPoint[i] = -1
        remove_task(i)
    }

    // Сброс счётчиков спавна на точках
    for(new i = 0; i < g_PointCount; i++)
    {
        g_Points[i][PT_SPAWN_COUNT] = 0
    }

    // Счёт
    new ctPoints = 0, tPoints = 0, neutral = 0
    for(new i = 0; i < g_PointCount; i++)
    {
        if(g_Points[i][PT_STATE] == 2) ctPoints++
        else if(g_Points[i][PT_STATE] == 1) tPoints++
        else neutral++
    }

    SendAll("^4[CP]^1 Новый раунд! CT:^3%d^1 | T:^3%d^1 | Нейтр:^3%d", ctPoints, tPoints, neutral)
}

public OnRoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:delay)
{
    // Можно добавить логику окончания раунда
}

public client_disconnected(id)
{
    StopCapture(id)
    g_SpawnedOnPoint[id] = -1
    remove_task(id)
}

public TaskAnnounce()
{
    new reward = get_pcvar_num(pCvarReward)
    new maxPerPoint = get_pcvar_num(pCvarSpawnPerPoint)

    set_dhudmessage(0, 255, 0, -1.0, 0.3, 2, 0.1, 5.0, 0.1, 0.1)
    show_dhudmessage(0, "=== ЗАХВАТ ТОЧЕК ===^nТочек: %d | Награда: $%d^nМакс. игроков на точку: %d",
        g_PointCount, reward, maxPerPoint)

    SendAll("^4[CP]^1 Захвати точку - команда получит^3 $%d", reward)
    SendAll("^4[CP]^1 На каждой точке могут появляться макс.^3 %d^1 игрока", maxPerPoint)
}

// ============================================================================
// УТИЛИТЫ
// ============================================================================

Float:GetDistance2D(Float:x1, Float:y1, Float:x2, Float:y2)
{
    new Float:dx = x1 - x2
    new Float:dy = y1 - y2
    return floatsqroot(dx*dx + dy*dy)
}

Float:GetDistance3D(Float:pos1[3], Float:pos2[3])
{
    new Float:dx = pos1[0] - pos2[0]
    new Float:dy = pos1[1] - pos2[1]
    new Float:dz = pos1[2] - pos2[2]
    return floatsqroot(dx*dx + dy*dy + dz*dz)
}

// Сообщения
SendAll(const msg[], any:...)
{
    new buf[192]
    vformat(buf, charsmax(buf), msg, 2)

    new players[32], num
    get_players(players, num)

    for(new i = 0; i < num; i++)
    {
        message_begin(MSG_ONE_UNRELIABLE, g_MsgSayText, _, players[i])
        write_byte(players[i])
        write_string(buf)
        message_end()
    }
}

SendTeamMessage(TeamName:team, const msg[], any:...)
{
    new buf[192]
    vformat(buf, charsmax(buf), msg, 3)

    new players[32], num
    get_players(players, num)

    for(new i = 0; i < num; i++)
    {
        if(get_member(players[i], m_iTeam) == team)
        {
            message_begin(MSG_ONE_UNRELIABLE, g_MsgSayText, _, players[i])
            write_byte(players[i])
            write_string(buf)
            message_end()
        }
    }
}

SendMessage(id, const msg[], any:...)
{
    new buf[192]
    vformat(buf, charsmax(buf), msg, 3)

    message_begin(MSG_ONE, g_MsgSayText, _, id)
    write_byte(id)
    write_string(buf)
    message_end()
}

LogMessage(const msg[], any:...)
{
    new buf[256]
    vformat(buf, charsmax(buf), msg, 2)
    server_print("[CP] %s", buf)
}
