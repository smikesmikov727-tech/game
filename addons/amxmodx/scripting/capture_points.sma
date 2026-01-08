/*
 * CAPTURE POINTS v39 - Optimized & Anti-Stuck
 *
 * Изменения v39:
 * - Исправлено застревание игроков (улучшенные проверки TraceHull)
 * - Оптимизация создания спавнов (сетка вместо рандома)
 * - Уменьшено количество попыток создания точек
 * - Увеличена дистанция между игроками при спавне
 * - Добавлена проверка пространства над головой
 */

#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <engine>
#include <level_system>
#include <stats_system>

#define MAX_POINTS 16
#define MAX_RANDOM_SPAWNS 96

#if !defined MAX_CLIENTS
    #define MAX_CLIENTS 32
#endif

// Константы для проверки позиций
#define PLAYER_HEIGHT 72.0
#define PLAYER_CROUCH_HEIGHT 36.0
#define SPAWN_SAFE_DISTANCE 96.0  // Минимальная дистанция между игроками при спавне
#define FLOOR_OFFSET 36.0         // Высота над полом для спавна

new const MODELS[][] = {
    "models/player/vip/vip.mdl",
    "models/player/terror/terror.mdl",
    "models/player/urban/urban.mdl"
}

// Квары
new pCvarPointsCount, pCvarCapTime, pCvarReward
new pCvarMinDist, pCvarBaseDist, pCvarCapRadius
new pCvarSpawnOnPoints, pCvarShowHud, pCvarSound, pCvarEffect, pCvarRecapBonus

// Точки захвата
new g_Ent[MAX_POINTS]
new Float:g_PosX[MAX_POINTS], Float:g_PosY[MAX_POINTS], Float:g_PosZ[MAX_POINTS]
new g_State[MAX_POINTS]
new g_Num

// Захват
new Float:g_CapEnd[33]
new bool:g_Capturing[33]
new g_CapEnt[33]

// Рандомные спавны по карте
new Float:g_RandomSpawns[MAX_RANDOM_SPAWNS][3]
new g_RandomSpawnCount

// Счётчик спавнов на точках (сбрасывается каждый раунд)
new g_SpawnedOnPoint[MAX_POINTS]

// Счётчик ротации спавнов для каждой команды (T=0, CT=1)
new g_SpawnRotation[2]

// Сколько живых игроков сейчас на каждой точке
new g_PlayersOnPoint[MAX_POINTS]

// На какой точке заспавнился игрок (-1 = рандом/база)
new g_PlayerSpawnPoint[33]

#define MAX_PLAYERS_PER_POINT 2

// Границы карты
new Float:g_MinX, Float:g_MaxX
new Float:g_MinY, Float:g_MaxY
new Float:g_MinZ, Float:g_MaxZ

new Float:g_TBaseX, Float:g_TBaseY
new Float:g_CTBaseX, Float:g_CTBaseY

new g_Spr, g_MsgSay

public plugin_precache()
{
    for(new i = 0; i < 3; i++)
        precache_model(MODELS[i])
    g_Spr = precache_model("sprites/shockwave.spr")
    precache_sound("buttons/bell1.wav")
}

public plugin_init()
{
    register_plugin("Capture Points", "39", "AI")

    pCvarPointsCount = register_cvar("cp_points_count", "7")
    pCvarCapTime = register_cvar("cp_capture_time", "8")
    pCvarReward = register_cvar("cp_capture_reward", "500")
    pCvarMinDist = register_cvar("cp_min_distance", "400")
    pCvarBaseDist = register_cvar("cp_base_distance", "200")
    pCvarCapRadius = register_cvar("cp_capture_radius", "120")
    pCvarSpawnOnPoints = register_cvar("cp_spawn_on_points", "1")
    pCvarShowHud = register_cvar("cp_show_hud", "1")
    pCvarSound = register_cvar("cp_capture_sound", "1")
    pCvarEffect = register_cvar("cp_capture_effect", "1")
    pCvarRecapBonus = register_cvar("cp_recapture_bonus", "700")

    RegisterHookChain(RG_CBasePlayer_Spawn, "OnSpawn", true)
    RegisterHookChain(RG_CBasePlayer_Killed, "OnPlayerKilled", true)
    RegisterHookChain(RG_CSGameRules_RestartRound, "OnRound", false)

    g_MsgSay = get_user_msgid("SayText")

    new cfgDir[128]
    get_localinfo("amxx_configsdir", cfgDir, charsmax(cfgDir))
    server_cmd("exec %s/capture_points.cfg", cfgDir)
    server_exec()

    set_task(3.0, "InitPoints")
}

public InitPoints()
{
    server_print("[CP] === Настройки ===")
    server_print("[CP] Точек: %d", get_pcvar_num(pCvarPointsCount))
    server_print("[CP] Время захвата: %d сек", get_pcvar_num(pCvarCapTime))
    server_print("[CP] Награда: $%d", get_pcvar_num(pCvarReward))
    server_print("[CP] Мин. расстояние между точками: %.0f", get_pcvar_float(pCvarMinDist))
    server_print("[CP] Радиус захвата: %.0f", get_pcvar_float(pCvarCapRadius))
    server_print("[CP] =================")

    FindMapBounds()

    server_print("[CP] Границы карты:")
    server_print("[CP] X: %.0f - %.0f", g_MinX, g_MaxX)
    server_print("[CP] Y: %.0f - %.0f", g_MinY, g_MaxY)
    server_print("[CP] Z: %.0f - %.0f", g_MinZ, g_MaxZ)

    // Сначала создаём рандомные спавны по карте (оптимизированно)
    CreateRandomMapSpawns()
    server_print("[CP] Создано рандомных спавнов: %d", g_RandomSpawnCount)

    // Затем создаём точки захвата
    CreateRandomPoints()

    if(g_Num > 0)
    {
        server_print("[CP] Создано точек захвата: %d", g_Num)
        set_task(2.0, "Announce")
    }
    else
    {
        server_print("[CP] ОШИБКА: Точки не созданы!")
    }
}

FindMapBounds()
{
    new Float:pos[3]
    new ent = -1
    new bool:first = true
    new ctCnt = 0, tCnt = 0

    g_CTBaseX = 0.0
    g_CTBaseY = 0.0
    g_TBaseX = 0.0
    g_TBaseY = 0.0

    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_start")) > 0)
    {
        get_entvar(ent, var_origin, pos)

        if(first)
        {
            g_MinX = g_MaxX = pos[0]
            g_MinY = g_MaxY = pos[1]
            g_MinZ = g_MaxZ = pos[2]
            first = false
        }
        else
        {
            if(pos[0] < g_MinX) g_MinX = pos[0]
            if(pos[0] > g_MaxX) g_MaxX = pos[0]
            if(pos[1] < g_MinY) g_MinY = pos[1]
            if(pos[1] > g_MaxY) g_MaxY = pos[1]
            if(pos[2] < g_MinZ) g_MinZ = pos[2]
            if(pos[2] > g_MaxZ) g_MaxZ = pos[2]
        }

        g_CTBaseX += pos[0]
        g_CTBaseY += pos[1]
        ctCnt++
    }

    ent = -1
    while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", "info_player_deathmatch")) > 0)
    {
        get_entvar(ent, var_origin, pos)

        if(first)
        {
            g_MinX = g_MaxX = pos[0]
            g_MinY = g_MaxY = pos[1]
            g_MinZ = g_MaxZ = pos[2]
            first = false
        }
        else
        {
            if(pos[0] < g_MinX) g_MinX = pos[0]
            if(pos[0] > g_MaxX) g_MaxX = pos[0]
            if(pos[1] < g_MinY) g_MinY = pos[1]
            if(pos[1] > g_MaxY) g_MaxY = pos[1]
            if(pos[2] < g_MinZ) g_MinZ = pos[2]
            if(pos[2] > g_MaxZ) g_MaxZ = pos[2]
        }

        g_TBaseX += pos[0]
        g_TBaseY += pos[1]
        tCnt++
    }

    if(ctCnt > 0)
    {
        g_CTBaseX /= float(ctCnt)
        g_CTBaseY /= float(ctCnt)
    }

    if(tCnt > 0)
    {
        g_TBaseX /= float(tCnt)
        g_TBaseY /= float(tCnt)
    }

    new Float:expandX = (g_MaxX - g_MinX) * 0.15
    new Float:expandY = (g_MaxY - g_MinY) * 0.15

    g_MinX -= expandX
    g_MaxX += expandX
    g_MinY -= expandY
    g_MaxY += expandY
}

/*
 * ОПТИМИЗИРОВАННОЕ создание спавнов - использует сетку вместо чистого рандома
 * Уменьшает количество попыток с 5000 до ~1500
 */
CreateRandomMapSpawns()
{
    g_RandomSpawnCount = 0

    new Float:maxAllowedZ = g_MaxZ + 100.0

    // Размер сетки - 128 юнитов (оптимально для CS)
    new Float:gridSize = 128.0
    new Float:mapWidth = g_MaxX - g_MinX
    new Float:mapHeight = g_MaxY - g_MinY

    new gridX = floatround(mapWidth / gridSize) + 1
    new gridY = floatround(mapHeight / gridSize) + 1

    // Создаём массив индексов сетки и перемешиваем
    new totalCells = gridX * gridY
    if(totalCells > 1024) totalCells = 1024  // Ограничение

    new cellIndices[1024]
    for(new i = 0; i < totalCells; i++)
        cellIndices[i] = i

    // Fisher-Yates shuffle
    for(new i = totalCells - 1; i > 0; i--)
    {
        new j = random(i + 1)
        new temp = cellIndices[i]
        cellIndices[i] = cellIndices[j]
        cellIndices[j] = temp
    }

    new attempts = 0

    for(new cell = 0; cell < totalCells && g_RandomSpawnCount < MAX_RANDOM_SPAWNS; cell++)
    {
        new idx = cellIndices[cell]
        new cellX = idx % gridX
        new cellY = idx / gridX

        // Рандомная позиция внутри ячейки сетки
        new Float:baseX = g_MinX + float(cellX) * gridSize
        new Float:baseY = g_MinY + float(cellY) * gridSize

        new Float:testX = baseX + random_float(0.0, gridSize)
        new Float:testY = baseY + random_float(0.0, gridSize)

        attempts++

        // Находим пол
        new Float:floorPos[3]
        if(!FindSafeFloorPosition(testX, testY, floorPos))
            continue

        // Не создавать спавны слишком высоко
        if(floorPos[2] > maxAllowedZ)
            continue

        // Проверяем расстояние от баз (100 юнитов минимум)
        new Float:dxCT = floorPos[0] - g_CTBaseX
        new Float:dyCT = floorPos[1] - g_CTBaseY
        new Float:dxT = floorPos[0] - g_TBaseX
        new Float:dyT = floorPos[1] - g_TBaseY

        if(floatsqroot(dxCT*dxCT + dyCT*dyCT) < 100.0)
            continue
        if(floatsqroot(dxT*dxT + dyT*dyT) < 100.0)
            continue

        // Проверяем расстояние от других рандомных спавнов (минимум 64 юнита)
        new bool:tooClose = false
        for(new i = 0; i < g_RandomSpawnCount; i++)
        {
            new Float:dx = floorPos[0] - g_RandomSpawns[i][0]
            new Float:dy = floorPos[1] - g_RandomSpawns[i][1]
            if(floatsqroot(dx*dx + dy*dy) < 64.0)
            {
                tooClose = true
                break
            }
        }

        if(tooClose)
            continue

        // Сохраняем спавн
        g_RandomSpawns[g_RandomSpawnCount][0] = floorPos[0]
        g_RandomSpawns[g_RandomSpawnCount][1] = floorPos[1]
        g_RandomSpawns[g_RandomSpawnCount][2] = floorPos[2]
        g_RandomSpawnCount++
    }

    server_print("[CP] Рандомные спавны: %d (попыток: %d, сетка: %dx%d)",
        g_RandomSpawnCount, attempts, gridX, gridY)
}

/*
 * УЛУЧШЕННЫЙ поиск безопасной позиции на полу
 * - Проверяет нормаль пола (не рампа)
 * - Проверяет пространство для игрока (hull + высота)
 * - Проверяет что игрок не застрянет в потолке
 */
bool:FindSafeFloorPosition(Float:x, Float:y, Float:outPos[3])
{
    new Float:start[3], Float:end[3]
    start[0] = x
    start[1] = y
    start[2] = g_MaxZ + 200.0
    end[0] = x
    end[1] = y
    end[2] = g_MinZ - 200.0

    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

    new Float:frac
    get_tr2(0, TR_flFraction, frac)

    if(frac >= 1.0)
        return false

    // Проверяем нормаль - не рампа (Z > 0.7 = угол < 45°)
    new Float:planeNormal[3]
    get_tr2(0, TR_vecPlaneNormal, planeNormal)

    if(planeNormal[2] < 0.7)
        return false

    new Float:hitPos[3]
    get_tr2(0, TR_vecEndPos, hitPos)

    // Позиция спавна - над полом
    outPos[0] = hitPos[0]
    outPos[1] = hitPos[1]
    outPos[2] = hitPos[2] + FLOOR_OFFSET

    // Проверяем что есть место для игрока (hull check)
    if(!IsHullClear(outPos))
        return false

    // Проверяем пространство над головой (чтобы не застрять в потолке)
    new Float:headPos[3]
    headPos[0] = outPos[0]
    headPos[1] = outPos[1]
    headPos[2] = outPos[2] + PLAYER_HEIGHT - 10.0

    engfunc(EngFunc_TraceLine, outPos, headPos, IGNORE_MONSTERS, 0, 0)
    get_tr2(0, TR_flFraction, frac)

    if(frac < 1.0)
        return false  // Потолок слишком низко

    return true
}

/*
 * Проверка что hull свободен (игрок может стоять)
 */
bool:IsHullClear(Float:pos[3])
{
    engfunc(EngFunc_TraceHull, pos, pos, IGNORE_MONSTERS, HULL_HUMAN, 0)

    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
        return false

    return true
}

/*
 * ОПТИМИЗИРОВАННОЕ создание точек захвата
 * Уменьшено с 800 до 400 попыток, улучшена логика выбора позиций
 */
CreateRandomPoints()
{
    new maxPoints = get_pcvar_num(pCvarPointsCount)
    new Float:minDist = get_pcvar_float(pCvarMinDist)
    new Float:baseDist = get_pcvar_float(pCvarBaseDist)

    new Float:maxAllowedZ = g_MaxZ + 50.0

    // Используем сетку для более эффективного поиска
    new Float:gridSize = minDist * 0.8  // Немного меньше минимальной дистанции
    new Float:mapWidth = g_MaxX - g_MinX
    new Float:mapHeight = g_MaxY - g_MinY

    new gridX = floatround(mapWidth / gridSize) + 1
    new gridY = floatround(mapHeight / gridSize) + 1
    new totalCells = gridX * gridY
    if(totalCells > 512) totalCells = 512

    new cellIndices[512]
    for(new i = 0; i < totalCells; i++)
        cellIndices[i] = i

    // Перемешиваем
    for(new i = totalCells - 1; i > 0; i--)
    {
        new j = random(i + 1)
        new temp = cellIndices[i]
        cellIndices[i] = cellIndices[j]
        cellIndices[j] = temp
    }

    new attempts = 0
    new maxAttempts = 400

    for(new cell = 0; cell < totalCells && g_Num < maxPoints && attempts < maxAttempts; cell++)
    {
        new idx = cellIndices[cell]
        new cellX = idx % gridX
        new cellY = idx / gridX

        new Float:baseX = g_MinX + float(cellX) * gridSize
        new Float:baseY = g_MinY + float(cellY) * gridSize

        new Float:testX = baseX + random_float(0.0, gridSize)
        new Float:testY = baseY + random_float(0.0, gridSize)

        attempts++

        // Находим пол
        new Float:floorPos[3]
        if(!FindSafeFloorPosition(testX, testY, floorPos))
            continue

        if(floorPos[2] > maxAllowedZ)
            continue

        // Проверяем можно ли создать спавны вокруг точки
        if(!CanCreateSpawnsAroundPoint(floorPos))
            continue

        // Проверяем расстояние от других точек
        new bool:tooClose = false
        for(new i = 0; i < g_Num; i++)
        {
            new Float:dx = floorPos[0] - g_PosX[i]
            new Float:dy = floorPos[1] - g_PosY[i]

            if(floatsqroot(dx*dx + dy*dy) < minDist)
            {
                tooClose = true
                break
            }
        }

        if(tooClose)
            continue

        // Проверяем расстояние от баз
        new Float:dxCT = floorPos[0] - g_CTBaseX
        new Float:dyCT = floorPos[1] - g_CTBaseY
        new Float:dxT = floorPos[0] - g_TBaseX
        new Float:dyT = floorPos[1] - g_TBaseY

        if(floatsqroot(dxCT*dxCT + dyCT*dyCT) < baseDist)
            continue
        if(floatsqroot(dxT*dxT + dyT*dyT) < baseDist)
            continue

        // Создаём точку
        MakePoint(floorPos[0], floorPos[1], floorPos[2])
        server_print("[CP] Точка #%d: %.0f %.0f %.0f", g_Num, floorPos[0], floorPos[1], floorPos[2])
    }

    server_print("[CP] Попыток создания точек: %d", attempts)
}

// Проверяет можно ли создать минимум 3 спавна вокруг точки
bool:CanCreateSpawnsAroundPoint(Float:pointPos[3])
{
    new Float:angles[] = { 0.0, 60.0, 120.0, 180.0, 240.0, 300.0 }
    new Float:distances[] = { 120.0, 180.0 }
    new validSpawns = 0

    for(new d = 0; d < sizeof(distances); d++)
    {
        for(new a = 0; a < sizeof(angles); a++)
        {
            new Float:rad = angles[a] * 3.14159 / 180.0
            new Float:testX = pointPos[0] + floatcos(rad) * distances[d]
            new Float:testY = pointPos[1] + floatsin(rad) * distances[d]

            new Float:spawnPos[3]
            if(!FindFloorPositionNear(testX, testY, pointPos[2], spawnPos))
                continue

            if(IsHullClear(spawnPos))
                validSpawns++

            if(validSpawns >= 3)
                return true
        }
    }

    return false
}

// Находит пол рядом с указанной высотой
bool:FindFloorPositionNear(Float:x, Float:y, Float:baseZ, Float:outPos[3])
{
    new Float:start[3], Float:end[3]
    start[0] = x
    start[1] = y
    start[2] = baseZ + 150.0
    end[0] = x
    end[1] = y
    end[2] = baseZ - 150.0

    engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

    new Float:frac
    get_tr2(0, TR_flFraction, frac)

    if(frac >= 1.0)
        return false

    // Проверяем нормаль - не рампа
    new Float:planeNormal[3]
    get_tr2(0, TR_vecPlaneNormal, planeNormal)

    if(planeNormal[2] < 0.7)
        return false

    new Float:hitPos[3]
    get_tr2(0, TR_vecEndPos, hitPos)

    outPos[0] = hitPos[0]
    outPos[1] = hitPos[1]
    outPos[2] = hitPos[2] + FLOOR_OFFSET

    // Проверяем hull
    if(!IsHullClear(outPos))
        return false

    return true
}

MakePoint(Float:x, Float:y, Float:z)
{
    if(g_Num >= MAX_POINTS) return

    new ent = rg_create_entity("info_target")
    if(!ent) return

    new Float:pos[3]
    pos[0] = x
    pos[1] = y
    pos[2] = z

    engfunc(EngFunc_SetOrigin, ent, pos)
    engfunc(EngFunc_SetModel, ent, MODELS[0])
    engfunc(EngFunc_SetSize, ent, Float:{-20.0, -20.0, 0.0}, Float:{20.0, 20.0, 72.0})

    set_entvar(ent, var_classname, "cp_point")
    set_entvar(ent, var_movetype, MOVETYPE_FLY)
    set_entvar(ent, var_solid, SOLID_TRIGGER)
    set_entvar(ent, var_sequence, 1)

    new Float:clr[3] = {255.0, 255.0, 255.0}
    set_entvar(ent, var_renderfx, kRenderFxGlowShell)
    set_entvar(ent, var_rendercolor, clr)
    set_entvar(ent, var_rendermode, kRenderTransAlpha)
    set_entvar(ent, var_renderamt, 30.0)

    SetTouch(ent, "OnTouch")

    g_Ent[g_Num] = ent
    g_PosX[g_Num] = x
    g_PosY[g_Num] = y
    g_PosZ[g_Num] = z
    g_State[g_Num] = 0
    g_SpawnedOnPoint[g_Num] = 0
    g_Num++
}

public Announce()
{
    new reward = get_pcvar_num(pCvarReward)

    set_dhudmessage(0, 255, 0, -1.0, 0.3, 2, 0.1, 5.0, 0.1, 0.1)
    show_dhudmessage(0, "=== ЗАХВАТ ТОЧЕК ===^nТочек: %d | Награда: $%d", g_Num, reward)
    SayAll("^4[CP]^1 Захвати точку - команда получит^3 $%d", reward)
}

SayAll(const msg[], any:...)
{
    new buf[192]
    vformat(buf, charsmax(buf), msg, 2)

    new pls[32], n
    get_players(pls, n)
    for(new i = 0; i < n; i++)
    {
        message_begin(MSG_ONE_UNRELIABLE, g_MsgSay, _, pls[i])
        write_byte(pls[i])
        write_string(buf)
        message_end()
    }
}

SayTeam(TeamName:team, const msg[], any:...)
{
    new buf[192]
    vformat(buf, charsmax(buf), msg, 3)

    new pls[32], n
    get_players(pls, n)
    for(new i = 0; i < n; i++)
    {
        if(get_member(pls[i], m_iTeam) == team)
        {
            message_begin(MSG_ONE_UNRELIABLE, g_MsgSay, _, pls[i])
            write_byte(pls[i])
            write_string(buf)
            message_end()
        }
    }
}

public OnTouch(ent, id)
{
    if(!is_user_connected(id) || !is_user_alive(id)) return

    new TeamName:tm = get_member(id, m_iTeam)
    if(tm != TEAM_TERRORIST && tm != TEAM_CT) return

    new pt = -1
    for(new i = 0; i < g_Num; i++)
    {
        if(g_Ent[i] == ent)
        {
            pt = i
            break
        }
    }
    if(pt == -1) return

    new my = (tm == TEAM_CT) ? 2 : 1

    if(g_State[pt] == my)
    {
        if(get_pcvar_num(pCvarShowHud))
        {
            new r = (my == 2) ? 100 : 255
            new b = (my == 2) ? 255 : 100
            set_hudmessage(r, 150, b, -1.0, 0.65, 0, 0.0, 0.4, 0.0, 0.0, 2)
            show_hudmessage(id, "~ ТОЧКА #%d ~^n[ %s ]", pt+1, my==2 ? "СПЕЦНАЗ" : "ТЕРРОРИСТЫ")
        }
        return
    }

    new Float:now = get_gametime()
    new capTime = get_pcvar_num(pCvarCapTime)

    if(g_Capturing[id] && g_CapEnt[id] == ent)
    {
        if(g_CapEnd[id] <= now)
        {
            new oldState = g_State[pt]
            g_State[pt] = my
            StopCapture(id)

            if(my == 2)
            {
                engfunc(EngFunc_SetModel, ent, MODELS[2])
                SetColor(ent, 0, 0, 255)
            }
            else
            {
                engfunc(EngFunc_SetModel, ent, MODELS[1])
                SetColor(ent, 255, 0, 0)
            }

            new reward = get_pcvar_num(pCvarReward)
            new pls[32], n
            get_players(pls, n)
            new rewarded = 0

            new bool:bCanReward = bool:lvl_can_reward()

            if(!bCanReward)
                lvl_show_low_players(id)

            for(new i = 0; i < n; i++)
            {
                new pid = pls[i]
                new TeamName:ptm = get_member(pid, m_iTeam)

                if(ptm == tm)
                {
                    if(bCanReward)
                        lvl_add_money(pid, reward)
                    rewarded++
                }
            }

            server_print("[CP] Выдано $%d для %d игроков команды %s", reward, rewarded, my==2 ? "CT" : "T")

            new ct = 0, tt = 0
            for(new i = 0; i < g_Num; i++)
            {
                if(g_State[i] == 2) ct++
                else if(g_State[i] == 1) tt++
            }

            new name[32]
            get_user_name(id, name, charsmax(name))

            new enemy = (my == 2) ? 1 : 2

            if(get_pcvar_num(pCvarSound))
            {
                for(new p = 1; p <= 32; p++)
                {
                    if(is_user_connected(p))
                        lvl_block_sound(p, 2.0)
                }
                client_cmd(0, "spk buttons/bell1")
            }

            if(oldState == enemy)
            {
                if(bCanReward)
                {
                    lvl_give_xp(id, lvl_get_xp_point_recapture())

                    new recapBonus = get_pcvar_num(pCvarRecapBonus)
                    lvl_add_money(id, recapBonus)

                    stats_add_point(id)
                }

                SayTeam(tm, "^4[CP]^3 %s^1 отбил вражескую точку^4 #%d^1! [^3+$%d бонус^1]", name, pt+1, get_pcvar_num(pCvarRecapBonus))

                new TeamName:enemyTeam = (tm == TEAM_CT) ? TEAM_TERRORIST : TEAM_CT
                SayTeam(enemyTeam, "^4[CP]^3 %s^1 захватил вашу точку^4 #%d^1!", name, pt+1)
            }
            else
            {
                if(bCanReward)
                {
                    lvl_give_xp(id, lvl_get_xp_point_capture())
                    stats_add_point(id)
                }
                SayAll("^4[CP]^3 %s^1 захватил нейтральную точку^4 #%d", name, pt+1)
            }

            SayAll("^4[CP]^1 Команда^3 %s^1 получила^4 +$%d", my==2 ? "CT" : "T", reward)
            SayAll("^4[CP]^1 Счёт: CT:^3%d^1 | T:^3%d^1 | Нейтр:^3%d", ct, tt, g_Num - ct - tt)

            if(get_pcvar_num(pCvarEffect))
            {
                new Float:epos[3]
                get_entvar(ent, var_origin, epos)

                message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
                write_byte(TE_BEAMCYLINDER)
                write_coord(floatround(epos[0]))
                write_coord(floatround(epos[1]))
                write_coord(floatround(epos[2]))
                write_coord(floatround(epos[0]))
                write_coord(floatround(epos[1]))
                write_coord(floatround(epos[2] + 400.0))
                write_short(g_Spr)
                write_byte(0)
                write_byte(0)
                write_byte(10)
                write_byte(60)
                write_byte(0)
                write_byte(my==2 ? 0 : 255)
                write_byte(0)
                write_byte(my==2 ? 255 : 0)
                write_byte(255)
                write_byte(0)
                message_end()
            }
        }
        return
    }

    g_Capturing[id] = true
    g_CapEnd[id] = now + float(capTime)
    g_CapEnt[id] = ent

    new data[1]
    data[0] = ent
    set_task(0.3, "CheckCapture", id, data, 1, "b")
}

public CheckCapture(data[], id)
{
    if(!is_user_connected(id) || !is_user_alive(id))
    {
        StopCapture(id)
        return
    }

    if(!g_Capturing[id])
    {
        remove_task(id)
        return
    }

    new ent = data[0]
    if(!pev_valid(ent))
    {
        StopCapture(id)
        return
    }

    new Float:ppos[3], Float:epos[3]
    get_entvar(id, var_origin, ppos)
    get_entvar(ent, var_origin, epos)

    new Float:capRadius = get_pcvar_float(pCvarCapRadius)
    if(get_distance_f(ppos, epos) > capRadius)
    {
        StopCapture(id)
        return
    }

    if(!get_pcvar_num(pCvarShowHud)) return

    new capTime = get_pcvar_num(pCvarCapTime)
    if(capTime <= 0) capTime = 1
    new reward = get_pcvar_num(pCvarReward)

    new pt = FindPointByEnt(ent)
    new TeamName:tm = get_member(id, m_iTeam)
    new my = (tm == TEAM_CT) ? 2 : 1
    new enemy = (my == 2) ? 1 : 2
    new xpReward = (g_State[pt] == enemy) ? lvl_get_xp_point_recapture() : lvl_get_xp_point_capture()
    new xpType[32]
    if(g_State[pt] == enemy)
        copy(xpType, charsmax(xpType), "вражеская")
    else
        copy(xpType, charsmax(xpType), "нейтральная")

    new Float:left = g_CapEnd[id] - get_gametime()
    new pct = 100 - floatround(left * 100.0 / float(capTime))
    if(pct < 0) pct = 0
    if(pct > 100) pct = 100

    new r, g, b
    if(pct < 33) { r = 255; g = 50; b = 50; }
    else if(pct < 66) { r = 255; g = 200; b = 0; }
    else { r = 50; g = 255; b = 50; }

    new bar[21]
    new filled = pct / 5
    for(new i = 0; i < 20; i++)
        bar[i] = (i < filled) ? '|' : '.'
    bar[20] = 0

    set_hudmessage(r, g, b, -1.0, 0.65, 0, 0.0, 0.4, 0.0, 0.0, 2)
    show_hudmessage(id, ">>> ЗАХВАТ ТОЧКИ #%d <<<^n[ %s ] %d%%^n^nНаграда: $%d команде^nОпыт: +%d XP (%s)", pt+1, bar, pct, reward, xpReward, xpType)
}

FindPointByEnt(ent)
{
    for(new i = 0; i < g_Num; i++)
        if(g_Ent[i] == ent) return i
    return 0
}

StopCapture(id)
{
    g_Capturing[id] = false
    g_CapEnt[id] = 0
    remove_task(id)
}

SetColor(ent, r, g, b)
{
    new Float:clr[3]
    clr[0] = float(r)
    clr[1] = float(g)
    clr[2] = float(b)
    set_entvar(ent, var_rendercolor, clr)
}

/*
 * СИСТЕМА СПАВНА С РОТАЦИЕЙ (CSDM)
 *
 * Ротация: T1→T2→(Рандом)→T1→T2→(Рандом)→...
 */
public OnSpawn(id)
{
    StopCapture(id)

    // Сбрасываем предыдущую точку игрока
    new oldPoint = g_PlayerSpawnPoint[id]
    if(oldPoint >= 0 && oldPoint < g_Num)
    {
        g_PlayersOnPoint[oldPoint]--
        if(g_PlayersOnPoint[oldPoint] < 0)
            g_PlayersOnPoint[oldPoint] = 0
    }
    g_PlayerSpawnPoint[id] = -1

    if(!get_pcvar_num(pCvarSpawnOnPoints)) return
    if(!is_user_alive(id) || g_Num == 0) return

    new TeamName:tm = get_member(id, m_iTeam)
    if(tm != TEAM_TERRORIST && tm != TEAM_CT) return

    new my = (tm == TEAM_CT) ? 2 : 1
    new teamIdx = (tm == TEAM_CT) ? 1 : 0

    // Собираем ВСЕ захваченные точки КОМАНДЫ
    new teamPoints[MAX_POINTS], teamPointCount = 0
    for(new i = 0; i < g_Num; i++)
    {
        if(g_State[i] == my)
            teamPoints[teamPointCount++] = i
    }

    // Если нет точек у команды - рандом по карте
    if(teamPointCount == 0)
    {
        SpawnPlayerRandomly(id)
        return
    }

    // Собираем СВОБОДНЫЕ точки команды (< 2 игроков)
    new freePoints[MAX_POINTS], freeCount = 0
    for(new i = 0; i < teamPointCount; i++)
    {
        new pt = teamPoints[i]
        if(g_PlayersOnPoint[pt] < MAX_PLAYERS_PER_POINT)
            freePoints[freeCount++] = pt
    }

    // Ротация: cycleLength = количество точек команды + 1
    new cycleLength = teamPointCount + 1
    new rotationPos = g_SpawnRotation[teamIdx]
    new posInCycle = rotationPos % cycleLength

    // Увеличиваем счётчик
    g_SpawnRotation[teamIdx]++

    // Если позиция = последняя (рандом по карте)
    if(posInCycle >= teamPointCount)
    {
        SpawnPlayerRandomly(id)
        return
    }

    // Если все точки команды заполнены - рандом по карте
    if(freeCount == 0)
    {
        SpawnPlayerRandomly(id)
        return
    }

    // Точка по ротации
    new targetPoint = teamPoints[posInCycle]

    // Если точка свободна - спавним там
    if(g_PlayersOnPoint[targetPoint] < MAX_PLAYERS_PER_POINT)
    {
        if(SpawnPlayerOnPoint(id, targetPoint))
        {
            g_PlayersOnPoint[targetPoint]++
            g_PlayerSpawnPoint[id] = targetPoint
            return
        }
    }

    // Точка занята - выбираем рандомно из свободных
    for(new i = freeCount - 1; i > 0; i--)
    {
        new j = random(i + 1)
        new temp = freePoints[i]
        freePoints[i] = freePoints[j]
        freePoints[j] = temp
    }

    for(new i = 0; i < freeCount; i++)
    {
        new pt = freePoints[i]
        if(SpawnPlayerOnPoint(id, pt))
        {
            g_PlayersOnPoint[pt]++
            g_PlayerSpawnPoint[id] = pt
            return
        }
    }

    // Не удалось - рандом
    SpawnPlayerRandomly(id)
}

// При смерти игрока - освобождаем место на точке
public OnPlayerKilled(victim, killer, shouldgib)
{
    new pt = g_PlayerSpawnPoint[victim]
    if(pt >= 0 && pt < g_Num)
    {
        g_PlayersOnPoint[pt]--
        if(g_PlayersOnPoint[pt] < 0)
            g_PlayersOnPoint[pt] = 0
    }
    g_PlayerSpawnPoint[victim] = -1
}

/*
 * УЛУЧШЕННЫЙ спавн на точке - проверяет больше позиций и дистанцию
 */
bool:SpawnPlayerOnPoint(id, pt)
{
    new Float:angles[] = { 0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0 }
    new Float:distances[] = { 100.0, 150.0, 200.0, 250.0 }

    // Перемешиваем углы для рандомности
    for(new i = sizeof(angles) - 1; i > 0; i--)
    {
        new j = random(i + 1)
        new Float:temp = angles[i]
        angles[i] = angles[j]
        angles[j] = temp
    }

    for(new d = 0; d < sizeof(distances); d++)
    {
        for(new a = 0; a < sizeof(angles); a++)
        {
            new Float:rad = angles[a] * 3.14159 / 180.0
            new Float:testX = g_PosX[pt] + floatcos(rad) * distances[d]
            new Float:testY = g_PosY[pt] + floatsin(rad) * distances[d]

            new Float:spawnPos[3]
            if(!FindFloorPositionNear(testX, testY, g_PosZ[pt], spawnPos))
                continue

            // Полная проверка безопасности включая других игроков
            if(IsSpawnPositionSafe(spawnPos, id))
            {
                set_entvar(id, var_origin, spawnPos)
                return true
            }
        }
    }

    return false
}

// Спавнит игрока рандомно по карте
SpawnPlayerRandomly(id)
{
    if(g_RandomSpawnCount == 0)
    {
        SpawnPlayerOnTeamBase(id)
        return
    }

    // Перемешиваем индексы для рандомного выбора
    new indices[MAX_RANDOM_SPAWNS]
    for(new i = 0; i < g_RandomSpawnCount; i++)
        indices[i] = i

    for(new i = g_RandomSpawnCount - 1; i > 0; i--)
    {
        new j = random(i + 1)
        new temp = indices[i]
        indices[i] = indices[j]
        indices[j] = temp
    }

    // Пробуем найти безопасную позицию
    for(new i = 0; i < g_RandomSpawnCount; i++)
    {
        new idx = indices[i]
        new Float:spawnPos[3]
        spawnPos[0] = g_RandomSpawns[idx][0]
        spawnPos[1] = g_RandomSpawns[idx][1]
        spawnPos[2] = g_RandomSpawns[idx][2]

        if(IsSpawnPositionSafe(spawnPos, id))
        {
            set_entvar(id, var_origin, spawnPos)
            return
        }
    }

    // Если все рандомные спавны заняты - пробуем базовые спавны команды
    SpawnPlayerOnTeamBase(id)
}

// Спавн на базовом спавне команды (fallback)
SpawnPlayerOnTeamBase(id)
{
    new TeamName:tm = get_member(id, m_iTeam)
    new spawnClass[32]

    if(tm == TEAM_CT)
        copy(spawnClass, charsmax(spawnClass), "info_player_start")
    else if(tm == TEAM_TERRORIST)
        copy(spawnClass, charsmax(spawnClass), "info_player_deathmatch")
    else
        return

    new Float:spawns[32][3]
    new spawnCount = 0
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

    // Перемешиваем и ищем свободный
    for(new attempt = 0; attempt < spawnCount; attempt++)
    {
        new idx = random(spawnCount)
        new Float:testPos[3]
        testPos[0] = spawns[idx][0]
        testPos[1] = spawns[idx][1]
        testPos[2] = spawns[idx][2] + 10.0

        if(IsSpawnPositionSafe(testPos, id))
        {
            set_entvar(id, var_origin, testPos)
            return
        }
    }
}

/*
 * УЛУЧШЕННАЯ проверка безопасности позиции для спавна
 * - Проверяет hull (не внутри стены)
 * - Проверяет дистанцию до других игроков (96 юнитов)
 * - Проверяет пространство над головой
 */
bool:IsSpawnPositionSafe(Float:pos[3], id)
{
    // Проверяем hull - не внутри стены
    engfunc(EngFunc_TraceHull, pos, pos, IGNORE_MONSTERS, HULL_HUMAN, id)

    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
        return false

    // Проверяем пространство над головой
    new Float:headPos[3]
    headPos[0] = pos[0]
    headPos[1] = pos[1]
    headPos[2] = pos[2] + PLAYER_HEIGHT - 10.0

    engfunc(EngFunc_TraceLine, pos, headPos, IGNORE_MONSTERS, id, 0)

    new Float:frac
    get_tr2(0, TR_flFraction, frac)
    if(frac < 1.0)
        return false  // Потолок слишком низко

    // Проверяем дистанцию до живых игроков
    new Float:playerPos[3]
    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        if(i == id) continue
        if(!is_user_connected(i) || !is_user_alive(i)) continue

        get_entvar(i, var_origin, playerPos)

        new Float:dx = pos[0] - playerPos[0]
        new Float:dy = pos[1] - playerPos[1]
        new Float:dz = pos[2] - playerPos[2]
        new Float:dist = floatsqroot(dx*dx + dy*dy + dz*dz)

        // Увеличена дистанция с 64 до 96 юнитов
        if(dist < SPAWN_SAFE_DISTANCE)
            return false
    }

    return true
}

public OnRound()
{
    // Сброс захватов
    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        g_Capturing[i] = false
        g_CapEnt[i] = 0
        g_PlayerSpawnPoint[i] = -1
        remove_task(i)
        remove_task(i + 5000)
    }

    // Сброс счётчиков
    for(new i = 0; i < g_Num; i++)
    {
        g_SpawnedOnPoint[i] = 0
        g_PlayersOnPoint[i] = 0
    }

    new ct = 0, tt = 0, neu = 0
    for(new i = 0; i < g_Num; i++)
    {
        if(g_State[i] == 2) ct++
        else if(g_State[i] == 1) tt++
        else neu++
    }

    SayAll("^4[CP]^1 Раунд! CT:^3%d^1 | T:^3%d^1 | Нейтр:^3%d", ct, tt, neu)
}

public client_disconnected(id)
{
    StopCapture(id)

    // Освобождаем место на точке
    new pt = g_PlayerSpawnPoint[id]
    if(pt >= 0 && pt < g_Num)
    {
        g_PlayersOnPoint[pt]--
        if(g_PlayersOnPoint[pt] < 0)
            g_PlayersOnPoint[pt] = 0
    }
    g_PlayerSpawnPoint[id] = -1

    remove_task(id)
    remove_task(id + 5000)
}
