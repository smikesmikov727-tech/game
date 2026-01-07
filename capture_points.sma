/*
 * CAPTURE POINTS v21 - Улучшенная система спавна
 *
 * Изменения:
 * - Убрана система /stuck (больше не нужна)
 * - Новая умная система спавна с разнообразием
 * - Игроки спавнятся на базе + на захваченных точках с балансировкой
 * - Гарантия отсутствия застревания
 */

#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <engine>
#include <level_system>
#include <stats_system>

#define MAX_POINTS 16
#define MAX_SPAWN_POSITIONS 64  // Максимум позиций для спавна на точку
#define MIN_WALL_DISTANCE 48.0  // Минимальное расстояние от стен
#define MIN_PLAYER_DISTANCE 80.0  // Минимальное расстояние между игроками
#define POINT_MODEL_RADIUS 40.0  // Радиус модели точки (не спавнить внутри)

#if !defined MAX_CLIENTS
    #define MAX_CLIENTS 32
#endif

new const MODELS[][] = {
    "models/player/vip/vip.mdl",
    "models/player/terror/terror.mdl",
    "models/player/urban/urban.mdl"
}

// Квары
new pCvarPointsCount, pCvarCapTime, pCvarReward
new pCvarMinDist, pCvarBaseDist, pCvarCapRadius
new pCvarSpawnOnPoints, pCvarShowHud, pCvarSound, pCvarEffect, pCvarRecapBonus
new pCvarSpawnBalance  // Новый квар для баланса спавна

new g_Ent[MAX_POINTS]
new Float:g_PosX[MAX_POINTS], Float:g_PosY[MAX_POINTS], Float:g_PosZ[MAX_POINTS]
new g_State[MAX_POINTS]
new g_Num

new Float:g_CapEnd[33]
new bool:g_Capturing[33]
new g_CapEnt[33]

// Система спавна - прекэшированные безопасные позиции для каждой точки
new Float:g_SafeSpawns[MAX_POINTS][MAX_SPAWN_POSITIONS][3]
new g_SafeSpawnCount[MAX_POINTS]

// Счётчик спавнов на точках (для балансировки)
new g_SpawnCountOnPoint[MAX_POINTS]

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
    register_plugin("Capture Points", "21", "AI")

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

    // Новый квар: баланс спавна (0-100)
    // 0 = всегда на базе, 100 = всегда на точках, 50 = 50/50
    pCvarSpawnBalance = register_cvar("cp_spawn_balance", "60")

    RegisterHookChain(RG_CBasePlayer_Spawn, "OnSpawn", true)
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
    server_print("[CP] Мин. расстояние: %.0f", get_pcvar_float(pCvarMinDist))
    server_print("[CP] От баз: %.0f", get_pcvar_float(pCvarBaseDist))
    server_print("[CP] Радиус захвата: %.0f", get_pcvar_float(pCvarCapRadius))
    server_print("[CP] Баланс спавна: %d%%", get_pcvar_num(pCvarSpawnBalance))
    server_print("[CP] =================")

    FindMapBounds()

    server_print("[CP] Границы карты:")
    server_print("[CP] X: %.0f - %.0f", g_MinX, g_MaxX)
    server_print("[CP] Y: %.0f - %.0f", g_MinY, g_MaxY)
    server_print("[CP] Z: %.0f - %.0f", g_MinZ, g_MaxZ)

    CreateRandomPoints()

    if(g_Num > 0)
    {
        server_print("[CP] Создано точек: %d", g_Num)

        // Прекэшируем безопасные позиции для спавна
        PrecacheSafeSpawnPositions()

        set_task(2.0, "Announce")
    }
    else
    {
        server_print("[CP] ОШИБКА: Точки не созданы!")
    }
}

// Прекэширование безопасных позиций спавна для каждой точки
PrecacheSafeSpawnPositions()
{
    server_print("[CP] Кэширование позиций спавна...")

    for(new pt = 0; pt < g_Num; pt++)
    {
        g_SafeSpawnCount[pt] = 0

        // Генерируем позиции по кругу вокруг точки
        // Начинаем с большего радиуса чтобы не застревать в модели
        new Float:startRadius = POINT_MODEL_RADIUS + 60.0  // 100 единиц от центра
        new Float:maxRadius = 350.0
        new Float:radiusStep = 40.0
        new Float:angleStep = 30.0  // 12 направлений

        for(new Float:radius = startRadius; radius <= maxRadius && g_SafeSpawnCount[pt] < MAX_SPAWN_POSITIONS; radius += radiusStep)
        {
            for(new Float:angle = 0.0; angle < 360.0 && g_SafeSpawnCount[pt] < MAX_SPAWN_POSITIONS; angle += angleStep)
            {
                new Float:rad = angle * 3.14159 / 180.0
                new Float:testX = g_PosX[pt] + floatcos(rad) * radius
                new Float:testY = g_PosY[pt] + floatsin(rad) * radius

                // Трассируем вниз чтобы найти пол
                new Float:start[3], Float:end[3]
                start[0] = testX
                start[1] = testY
                start[2] = g_PosZ[pt] + 200.0
                end[0] = testX
                end[1] = testY
                end[2] = g_PosZ[pt] - 200.0

                engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

                new Float:frac
                get_tr2(0, TR_flFraction, frac)

                if(frac >= 1.0) continue  // Нет пола

                new Float:hitPos[3]
                get_tr2(0, TR_vecEndPos, hitPos)

                new Float:spawnPos[3]
                spawnPos[0] = hitPos[0]
                spawnPos[1] = hitPos[1]
                spawnPos[2] = hitPos[2] + 36.0  // Над полом

                // Проверяем что позиция полностью безопасна
                if(IsPositionSafeForSpawn(spawnPos, pt))
                {
                    g_SafeSpawns[pt][g_SafeSpawnCount[pt]][0] = spawnPos[0]
                    g_SafeSpawns[pt][g_SafeSpawnCount[pt]][1] = spawnPos[1]
                    g_SafeSpawns[pt][g_SafeSpawnCount[pt]][2] = spawnPos[2]
                    g_SafeSpawnCount[pt]++
                }
            }
        }

        server_print("[CP] Точка #%d: найдено %d безопасных позиций", pt + 1, g_SafeSpawnCount[pt])
    }
}

// Проверка что позиция безопасна для спавна (статическая проверка)
bool:IsPositionSafeForSpawn(Float:pos[3], pt)
{
    // 1. Проверяем hull - место должно быть свободно
    engfunc(EngFunc_TraceHull, pos, pos, IGNORE_MONSTERS, HULL_HUMAN, 0)

    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
        return false

    // 2. Проверяем что не слишком близко к модели точки
    new Float:dx = pos[0] - g_PosX[pt]
    new Float:dy = pos[1] - g_PosY[pt]
    new Float:dist2D = floatsqroot(dx*dx + dy*dy)

    if(dist2D < POINT_MODEL_RADIUS + 30.0)  // Минимум 70 единиц от центра точки
        return false

    // 3. Проверяем расстояние до стен (8 направлений на 3 высотах)
    if(!CheckWallClearance(pos, MIN_WALL_DISTANCE))
        return false

    // 4. Проверяем что есть пол под ногами
    new Float:floorCheck[3], Float:floorEnd[3]
    floorCheck[0] = pos[0]
    floorCheck[1] = pos[1]
    floorCheck[2] = pos[2]
    floorEnd[0] = pos[0]
    floorEnd[1] = pos[1]
    floorEnd[2] = pos[2] - 50.0

    engfunc(EngFunc_TraceLine, floorCheck, floorEnd, IGNORE_MONSTERS, 0, 0)

    new Float:floorFrac
    get_tr2(0, TR_flFraction, floorFrac)

    if(floorFrac >= 1.0)  // Нет пола - пропасть
        return false

    // 5. Проверяем что есть место над головой
    new Float:ceilCheck[3], Float:ceilEnd[3]
    ceilCheck[0] = pos[0]
    ceilCheck[1] = pos[1]
    ceilCheck[2] = pos[2]
    ceilEnd[0] = pos[0]
    ceilEnd[1] = pos[1]
    ceilEnd[2] = pos[2] + 72.0  // Высота игрока

    engfunc(EngFunc_TraceLine, ceilCheck, ceilEnd, IGNORE_MONSTERS, 0, 0)

    new Float:ceilFrac
    get_tr2(0, TR_flFraction, ceilFrac)

    if(ceilFrac < 1.0)  // Потолок слишком низко
        return false

    return true
}

// Проверка расстояния до стен
bool:CheckWallClearance(Float:pos[3], Float:minDist)
{
    new Float:angles[] = { 0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0 }
    new Float:heights[] = { 0.0, 36.0, 64.0 }

    for(new h = 0; h < sizeof(heights); h++)
    {
        new Float:checkPos[3]
        checkPos[0] = pos[0]
        checkPos[1] = pos[1]
        checkPos[2] = pos[2] + heights[h]

        for(new a = 0; a < sizeof(angles); a++)
        {
            new Float:rad = angles[a] * 3.14159 / 180.0
            new Float:end[3]
            end[0] = checkPos[0] + floatcos(rad) * minDist
            end[1] = checkPos[1] + floatsin(rad) * minDist
            end[2] = checkPos[2]

            engfunc(EngFunc_TraceLine, checkPos, end, IGNORE_MONSTERS, 0, 0)

            new Float:frac
            get_tr2(0, TR_flFraction, frac)

            if(frac < 1.0)
                return false
        }
    }

    return true
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

    new Float:expandX = (g_MaxX - g_MinX) * 0.1
    new Float:expandY = (g_MaxY - g_MinY) * 0.1

    g_MinX -= expandX
    g_MaxX += expandX
    g_MinY -= expandY
    g_MaxY += expandY
}

CreateRandomPoints()
{
    new maxPoints = get_pcvar_num(pCvarPointsCount)
    new Float:minDist = get_pcvar_float(pCvarMinDist)
    new Float:baseDist = get_pcvar_float(pCvarBaseDist)

    new attempts = 0
    new maxAttempts = 500

    while(g_Num < maxPoints && attempts < maxAttempts)
    {
        attempts++

        new Float:testX = random_float(g_MinX, g_MaxX)
        new Float:testY = random_float(g_MinY, g_MaxY)
        new Float:testZ = g_MaxZ + 100.0

        new Float:start[3], Float:end[3]
        start[0] = testX
        start[1] = testY
        start[2] = testZ
        end[0] = testX
        end[1] = testY
        end[2] = g_MinZ - 100.0

        engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, 0, 0)

        new Float:frac
        get_tr2(0, TR_flFraction, frac)

        if(frac >= 1.0) continue

        new Float:hitPos[3]
        get_tr2(0, TR_vecEndPos, hitPos)

        new Float:finalZ = hitPos[2] + 40.0

        new Float:hullStart[3]
        hullStart[0] = testX
        hullStart[1] = testY
        hullStart[2] = finalZ

        engfunc(EngFunc_TraceHull, hullStart, hullStart, IGNORE_MONSTERS, HULL_HUMAN, 0, 0)

        if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
            continue

        new bool:tooClose = false

        for(new i = 0; i < g_Num; i++)
        {
            new Float:dx = testX - g_PosX[i]
            new Float:dy = testY - g_PosY[i]

            if(floatsqroot(dx*dx + dy*dy) < minDist)
            {
                tooClose = true
                break
            }
        }

        if(tooClose) continue

        new Float:dxCT = testX - g_CTBaseX
        new Float:dyCT = testY - g_CTBaseY
        new Float:dxT = testX - g_TBaseX
        new Float:dyT = testY - g_TBaseY

        if(floatsqroot(dxCT*dxCT + dyCT*dyCT) < baseDist) continue
        if(floatsqroot(dxT*dxT + dyT*dyT) < baseDist) continue

        MakePoint(testX, testY, finalZ)
        server_print("[CP] Точка #%d: %.0f %.0f %.0f", g_Num, testX, testY, finalZ)
    }

    server_print("[CP] Попыток: %d", attempts)
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
    g_SpawnCountOnPoint[g_Num] = 0
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

            // Сбрасываем счётчик спавнов при смене владельца
            g_SpawnCountOnPoint[pt] = 0

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

// ============================================
// НОВАЯ СИСТЕМА СПАВНА
// ============================================

public OnSpawn(id)
{
    StopCapture(id)

    if(!get_pcvar_num(pCvarSpawnOnPoints)) return
    if(!is_user_alive(id) || g_Num == 0) return

    new TeamName:tm = get_member(id, m_iTeam)
    if(tm != TEAM_TERRORIST && tm != TEAM_CT) return

    new my = (tm == TEAM_CT) ? 2 : 1

    // Собираем точки команды с безопасными позициями
    new teamPoints[MAX_POINTS], teamPointCount = 0
    for(new i = 0; i < g_Num; i++)
    {
        if(g_State[i] == my && g_SafeSpawnCount[i] > 0)
            teamPoints[teamPointCount++] = i
    }

    // Если нет захваченных точек - остаёмся на базе
    if(teamPointCount == 0)
        return

    // Решаем: спавн на базе или на точке?
    new spawnBalance = get_pcvar_num(pCvarSpawnBalance)
    new roll = random(100)

    if(roll >= spawnBalance)
    {
        // Остаёмся на базе
        return
    }

    // Выбираем точку с учётом балансировки (меньше спавнов = больше шанс)
    new selectedPoint = SelectBalancedPoint(teamPoints, teamPointCount)

    if(selectedPoint == -1)
        return

    // Ищем свободную позицию на выбранной точке
    new Float:spawnPos[3]
    if(FindFreeSpawnPosition(id, selectedPoint, spawnPos))
    {
        set_entvar(id, var_origin, spawnPos)
        g_SpawnCountOnPoint[selectedPoint]++
    }
}

// Выбор точки с балансировкой (чем меньше спавнов, тем больше шанс)
SelectBalancedPoint(teamPoints[], teamPointCount)
{
    if(teamPointCount == 0)
        return -1

    if(teamPointCount == 1)
        return teamPoints[0]

    // Считаем общее количество спавнов
    new totalSpawns = 0
    for(new i = 0; i < teamPointCount; i++)
        totalSpawns += g_SpawnCountOnPoint[teamPoints[i]] + 1  // +1 чтобы избежать деления на 0

    // Инвертируем веса (меньше спавнов = больше вес)
    new Float:weights[MAX_POINTS]
    new Float:totalWeight = 0.0

    for(new i = 0; i < teamPointCount; i++)
    {
        // Вес = 1 / (спавны + 1)
        weights[i] = float(totalSpawns) / float(g_SpawnCountOnPoint[teamPoints[i]] + 1)
        totalWeight += weights[i]
    }

    // Выбираем случайную точку по весам
    new Float:roll = random_float(0.0, totalWeight)
    new Float:cumulative = 0.0

    for(new i = 0; i < teamPointCount; i++)
    {
        cumulative += weights[i]
        if(roll <= cumulative)
            return teamPoints[i]
    }

    return teamPoints[0]
}

// Поиск свободной позиции для спавна (проверка коллизий с игроками в реальном времени)
bool:FindFreeSpawnPosition(id, pt, Float:outPos[3])
{
    if(g_SafeSpawnCount[pt] == 0)
        return false

    // Перемешиваем порядок проверки для разнообразия
    new order[MAX_SPAWN_POSITIONS]
    new orderCount = g_SafeSpawnCount[pt]

    for(new i = 0; i < orderCount; i++)
        order[i] = i

    // Fisher-Yates shuffle
    for(new i = orderCount - 1; i > 0; i--)
    {
        new j = random(i + 1)
        new temp = order[i]
        order[i] = order[j]
        order[j] = temp
    }

    // Проверяем позиции в случайном порядке
    for(new i = 0; i < orderCount; i++)
    {
        new idx = order[i]
        new Float:pos[3]
        pos[0] = g_SafeSpawns[pt][idx][0]
        pos[1] = g_SafeSpawns[pt][idx][1]
        pos[2] = g_SafeSpawns[pt][idx][2]

        // Проверяем коллизии с другими игроками
        if(IsPositionFreeFromPlayers(pos, id))
        {
            outPos[0] = pos[0]
            outPos[1] = pos[1]
            outPos[2] = pos[2]
            return true
        }
    }

    return false
}

// Проверка что позиция свободна от других игроков
bool:IsPositionFreeFromPlayers(Float:pos[3], excludeId)
{
    // Проверяем hull с учётом игроков
    engfunc(EngFunc_TraceHull, pos, pos, DONT_IGNORE_MONSTERS, HULL_HUMAN, excludeId)

    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
        return false

    // Дополнительная проверка дистанции до игроков
    new Float:playerPos[3]
    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        if(i == excludeId) continue
        if(!is_user_connected(i) || !is_user_alive(i)) continue

        get_entvar(i, var_origin, playerPos)

        new Float:dx = pos[0] - playerPos[0]
        new Float:dy = pos[1] - playerPos[1]
        new Float:dz = pos[2] - playerPos[2]
        new Float:dist = floatsqroot(dx*dx + dy*dy + dz*dz)

        if(dist < MIN_PLAYER_DISTANCE)
            return false
    }

    return true
}

// ============================================

public OnRound()
{
    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        g_Capturing[i] = false
        g_CapEnt[i] = 0
        remove_task(i)
    }

    // Сбрасываем счётчики спавнов на точках каждый раунд
    for(new i = 0; i < g_Num; i++)
        g_SpawnCountOnPoint[i] = 0

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
    remove_task(id)
}
