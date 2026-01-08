/*
 * Spawn Point Generator для CS 1.6
 * AMX Mod X 1.9.0
 *
 * Генерация 32 безопасных точек спавна без застреваний
 * Автор: Claude AI
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <hamsandwich>

#define PLUGIN_NAME     "Spawn Generator"
#define PLUGIN_VERSION  "1.2"
#define PLUGIN_AUTHOR   "Claude AI"

#define MAX_SPAWNS      32
#define MIN_SPAWN_DIST  128.0

// Данные спавнов (плоские массивы)
new Float:g_SpawnX[MAX_SPAWNS]
new Float:g_SpawnY[MAX_SPAWNS]
new Float:g_SpawnZ[MAX_SPAWNS]
new Float:g_SpawnYaw[MAX_SPAWNS]
new g_SpawnTeam[MAX_SPAWNS]
new g_SpawnCount

new g_MapName[64]
new g_SpawnFile[128]
new g_BeamSprite

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    register_clcmd("say /spawns", "cmd_spawn_menu", ADMIN_RCON)
    register_clcmd("say_team /spawns", "cmd_spawn_menu", ADMIN_RCON)

    register_concmd("amx_spawn_add", "cmd_add_spawn", ADMIN_RCON)
    register_concmd("amx_spawn_del", "cmd_del_spawn", ADMIN_RCON)
    register_concmd("amx_spawn_save", "cmd_save_spawns", ADMIN_RCON)
    register_concmd("amx_spawn_load", "cmd_load_spawns", ADMIN_RCON)
    register_concmd("amx_spawn_clear", "cmd_clear_spawns", ADMIN_RCON)
    register_concmd("amx_spawn_show", "cmd_show_spawns", ADMIN_RCON)
    register_concmd("amx_spawn_auto", "cmd_auto_generate", ADMIN_RCON)
    register_concmd("amx_spawn_test", "cmd_test_spawns", ADMIN_RCON)

    RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)

    get_mapname(g_MapName, charsmax(g_MapName))
    formatex(g_SpawnFile, charsmax(g_SpawnFile), "addons/amxmodx/configs/spawns/%s.cfg", g_MapName)

    new dir[128]
    formatex(dir, charsmax(dir), "addons/amxmodx/configs/spawns")
    if (!dir_exists(dir)) {
        mkdir(dir)
    }

    set_task(1.0, "task_load_spawns")
}

public plugin_precache() {
    g_BeamSprite = precache_model("sprites/laserbeam.spr")
}

// Расстояние между двумя точками
stock Float:get_dist(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2) {
    return floatsqroot((x1-x2)*(x1-x2) + (y1-y2)*(y1-y2) + (z1-z2)*(z1-z2))
}

/* ================== ЗАГРУЗКА/СОХРАНЕНИЕ ================== */

public task_load_spawns() {
    load_spawns()
}

load_spawns() {
    g_SpawnCount = 0

    if (!file_exists(g_SpawnFile)) {
        server_print("[Spawns] Файл не найден: %s", g_SpawnFile)
        return 0
    }

    new file = fopen(g_SpawnFile, "rt")
    if (!file) return 0

    new line[256], data[7][32]

    while (!feof(file) && g_SpawnCount < MAX_SPAWNS) {
        fgets(file, line, charsmax(line))
        trim(line)

        if (!line[0] || line[0] == ';' || line[0] == '/') continue

        if (parse(line, data[0], 31, data[1], 31, data[2], 31,
                  data[3], 31, data[4], 31, data[5], 31, data[6], 31) >= 6) {

            g_SpawnX[g_SpawnCount] = str_to_float(data[0])
            g_SpawnY[g_SpawnCount] = str_to_float(data[1])
            g_SpawnZ[g_SpawnCount] = str_to_float(data[2])
            g_SpawnYaw[g_SpawnCount] = str_to_float(data[4])
            g_SpawnTeam[g_SpawnCount] = str_to_num(data[6])

            g_SpawnCount++
        }
    }

    fclose(file)
    server_print("[Spawns] Загружено %d спавнов для %s", g_SpawnCount, g_MapName)
    return g_SpawnCount
}

save_spawns() {
    new file = fopen(g_SpawnFile, "wt")
    if (!file) {
        server_print("[Spawns] Ошибка сохранения: %s", g_SpawnFile)
        return 0
    }

    fprintf(file, "; Spawn points for %s^n", g_MapName)
    fprintf(file, "; Format: X Y Z Pitch Yaw Roll Team^n")
    fprintf(file, "; Team: 0=Any, 1=CT, 2=T^n^n")

    for (new i = 0; i < g_SpawnCount; i++) {
        fprintf(file, "%.1f %.1f %.1f 0.0 %.1f 0.0 %d^n",
            g_SpawnX[i], g_SpawnY[i], g_SpawnZ[i],
            g_SpawnYaw[i], g_SpawnTeam[i])
    }

    fclose(file)
    server_print("[Spawns] Сохранено %d спавнов", g_SpawnCount)
    return 1
}

/* ================== ПРОВЕРКА БЕЗОПАСНОСТИ ================== */

bool:is_spawn_safe(Float:x, Float:y, Float:z) {
    new Float:origin[3]
    origin[0] = x
    origin[1] = y
    origin[2] = z

    // Проверка на земле
    new Float:end[3]
    end[0] = x
    end[1] = y
    end[2] = z - 64.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, 0, tr)
    new Float:fraction
    get_tr2(tr, TR_flFraction, fraction)
    free_tr2(tr)

    if (fraction >= 1.0) return false // Не на земле

    // Hull check
    tr = create_tr2()
    engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, HULL_HUMAN, 0, tr)
    new solid, startsolid
    get_tr2(tr, TR_AllSolid, solid)
    get_tr2(tr, TR_StartSolid, startsolid)
    free_tr2(tr)

    if (solid || startsolid) return false // Застрял

    // Headroom check
    end[2] = z + 72.0
    tr = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, 0, tr)
    get_tr2(tr, TR_flFraction, fraction)
    free_tr2(tr)

    if (fraction < 1.0) return false // Нет места над головой

    // Water/solid check
    new contents = point_contents(origin)
    if (contents == CONTENTS_WATER || contents == CONTENTS_SOLID)
        return false

    return true
}

bool:check_spawn_distance(Float:x, Float:y, Float:z, Float:minDist) {
    for (new i = 0; i < g_SpawnCount; i++) {
        if (get_dist(x, y, z, g_SpawnX[i], g_SpawnY[i], g_SpawnZ[i]) < minDist) {
            return false
        }
    }
    return true
}

bool:find_safe_position(Float:inX, Float:inY, Float:inZ, &Float:outX, &Float:outY, &Float:outZ) {
    if (is_spawn_safe(inX, inY, inZ)) {
        outX = inX
        outY = inY
        outZ = inZ
        return true
    }

    new Float:offsets[7]
    offsets[0] = 0.0
    offsets[1] = 16.0
    offsets[2] = -16.0
    offsets[3] = 32.0
    offsets[4] = -32.0
    offsets[5] = 48.0
    offsets[6] = -48.0

    for (new ox = 0; ox < 7; ox++) {
        for (new oy = 0; oy < 7; oy++) {
            for (new oz = 0; oz < 5; oz++) {
                new Float:tx = inX + offsets[ox]
                new Float:ty = inY + offsets[oy]
                new Float:tz = inZ + float(oz * 16)

                if (is_spawn_safe(tx, ty, tz)) {
                    outX = tx
                    outY = ty
                    outZ = tz
                    return true
                }
            }
        }
    }

    return false
}

drop_to_floor(&Float:x, &Float:y, &Float:z) {
    new Float:origin[3], Float:end[3]
    origin[0] = x
    origin[1] = y
    origin[2] = z
    end[0] = x
    end[1] = y
    end[2] = z - 1000.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, 0, tr)

    new Float:endpos[3]
    get_tr2(tr, TR_vecEndPos, endpos)
    free_tr2(tr)

    z = endpos[2] + 36.0
}

/* ================== МЕНЮ ================== */

public cmd_spawn_menu(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    new menu = menu_create("\yГенератор Спавнов", "menu_handler")

    new info[64]
    formatex(info, charsmax(info), "Добавить спавн [%d/%d]", g_SpawnCount, MAX_SPAWNS)
    menu_additem(menu, info, "1")
    menu_additem(menu, "Удалить ближайший спавн", "2")
    menu_additem(menu, "Авто-генерация (32 точки)", "3")
    menu_additem(menu, "Показать все спавны", "4")
    menu_additem(menu, "Тестировать спавны", "5")
    menu_additem(menu, "Сохранить спавны", "6")
    menu_additem(menu, "Загрузить спавны", "7")
    menu_additem(menu, "\rОчистить все спавны", "8")

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu)
    return PLUGIN_HANDLED
}

public menu_handler(id, menu, item) {
    if (item == MENU_EXIT) {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch (item) {
        case 0: cmd_add_spawn(id, 0, 0)
        case 1: cmd_del_spawn(id, 0, 0)
        case 2: cmd_auto_generate(id, 0, 0)
        case 3: cmd_show_spawns(id, 0, 0)
        case 4: cmd_test_spawns(id, 0, 0)
        case 5: cmd_save_spawns(id, 0, 0)
        case 6: cmd_load_spawns(id, 0, 0)
        case 7: cmd_clear_spawns(id, 0, 0)
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

/* ================== КОМАНДЫ ================== */

public cmd_add_spawn(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount >= MAX_SPAWNS) {
        client_print(id, print_chat, "[Spawns] Лимит: %d", MAX_SPAWNS)
        return PLUGIN_HANDLED
    }

    new Float:origin[3], Float:angles[3]
    pev(id, pev_origin, origin)
    pev(id, pev_v_angle, angles)

    new Float:safeX, Float:safeY, Float:safeZ
    if (!find_safe_position(origin[0], origin[1], origin[2], safeX, safeY, safeZ)) {
        client_print(id, print_chat, "[Spawns] Позиция небезопасна!")
        return PLUGIN_HANDLED
    }

    if (!check_spawn_distance(safeX, safeY, safeZ, MIN_SPAWN_DIST)) {
        client_print(id, print_chat, "[Spawns] Слишком близко к другому спавну!")
        return PLUGIN_HANDLED
    }

    g_SpawnX[g_SpawnCount] = safeX
    g_SpawnY[g_SpawnCount] = safeY
    g_SpawnZ[g_SpawnCount] = safeZ
    g_SpawnYaw[g_SpawnCount] = angles[1]
    g_SpawnTeam[g_SpawnCount] = 0

    g_SpawnCount++

    client_print(id, print_chat, "[Spawns] Спавн #%d добавлен", g_SpawnCount)
    draw_spawn_marker(id, safeX, safeY, safeZ, 0)

    return PLUGIN_HANDLED
}

public cmd_del_spawn(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount <= 0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов")
        return PLUGIN_HANDLED
    }

    new Float:origin[3]
    pev(id, pev_origin, origin)

    new nearest = -1
    new Float:nearestDist = 9999.0

    for (new i = 0; i < g_SpawnCount; i++) {
        new Float:dist = get_dist(origin[0], origin[1], origin[2],
                                  g_SpawnX[i], g_SpawnY[i], g_SpawnZ[i])
        if (dist < nearestDist) {
            nearestDist = dist
            nearest = i
        }
    }

    if (nearest == -1 || nearestDist > 200.0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов рядом")
        return PLUGIN_HANDLED
    }

    for (new i = nearest; i < g_SpawnCount - 1; i++) {
        g_SpawnX[i] = g_SpawnX[i+1]
        g_SpawnY[i] = g_SpawnY[i+1]
        g_SpawnZ[i] = g_SpawnZ[i+1]
        g_SpawnYaw[i] = g_SpawnYaw[i+1]
        g_SpawnTeam[i] = g_SpawnTeam[i+1]
    }

    g_SpawnCount--
    client_print(id, print_chat, "[Spawns] Удален. Осталось: %d", g_SpawnCount)

    return PLUGIN_HANDLED
}

public cmd_save_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (save_spawns()) {
        client_print(id, print_chat, "[Spawns] Сохранено %d", g_SpawnCount)
    } else {
        client_print(id, print_chat, "[Spawns] Ошибка сохранения!")
    }

    return PLUGIN_HANDLED
}

public cmd_load_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    new count = load_spawns()
    client_print(id, print_chat, "[Spawns] Загружено %d", count)

    return PLUGIN_HANDLED
}

public cmd_clear_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    g_SpawnCount = 0
    client_print(id, print_chat, "[Spawns] Очищено")

    return PLUGIN_HANDLED
}

public cmd_show_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount == 0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов")
        return PLUGIN_HANDLED
    }

    for (new i = 0; i < g_SpawnCount; i++) {
        draw_spawn_marker(id, g_SpawnX[i], g_SpawnY[i], g_SpawnZ[i], g_SpawnTeam[i])
    }

    client_print(id, print_chat, "[Spawns] Показано %d (5 сек)", g_SpawnCount)

    return PLUGIN_HANDLED
}

public cmd_test_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount == 0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов")
        return PLUGIN_HANDLED
    }

    new safe = 0, unsafe = 0

    for (new i = 0; i < g_SpawnCount; i++) {
        if (is_spawn_safe(g_SpawnX[i], g_SpawnY[i], g_SpawnZ[i])) {
            safe++
        } else {
            unsafe++
            client_print(id, print_console, "[Spawns] #%d небезопасен!", i + 1)
        }
    }

    client_print(id, print_chat, "[Spawns] Тест: %d ок, %d плохих", safe, unsafe)

    return PLUGIN_HANDLED
}

public cmd_auto_generate(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    client_print(id, print_chat, "[Spawns] Генерация...")

    // Собираем спавны карты
    new Float:mapX[64], Float:mapY[64], Float:mapZ[64]
    new mapCount = 0

    new ent = -1
    while ((ent = find_ent_by_class(ent, "info_player_start")) != 0 && mapCount < 64) {
        new Float:origin[3]
        pev(ent, pev_origin, origin)
        mapX[mapCount] = origin[0]
        mapY[mapCount] = origin[1]
        mapZ[mapCount] = origin[2]
        mapCount++
    }

    ent = -1
    while ((ent = find_ent_by_class(ent, "info_player_deathmatch")) != 0 && mapCount < 64) {
        new Float:origin[3]
        pev(ent, pev_origin, origin)
        mapX[mapCount] = origin[0]
        mapY[mapCount] = origin[1]
        mapZ[mapCount] = origin[2]
        mapCount++
    }

    g_SpawnCount = 0
    new generated = 0
    new Float:safeX, Float:safeY, Float:safeZ

    // Добавляем стандартные спавны
    for (new i = 0; i < mapCount && g_SpawnCount < MAX_SPAWNS; i++) {
        if (find_safe_position(mapX[i], mapY[i], mapZ[i], safeX, safeY, safeZ)) {
            if (check_spawn_distance(safeX, safeY, safeZ, MIN_SPAWN_DIST)) {
                g_SpawnX[g_SpawnCount] = safeX
                g_SpawnY[g_SpawnCount] = safeY
                g_SpawnZ[g_SpawnCount] = safeZ
                g_SpawnYaw[g_SpawnCount] = random_float(0.0, 360.0)
                g_SpawnTeam[g_SpawnCount] = 0
                g_SpawnCount++
                generated++
            }
        }
    }

    // Генерируем дополнительные
    new attempts = 0
    while (g_SpawnCount < MAX_SPAWNS && attempts < 5000) {
        attempts++

        new Float:baseX, Float:baseY, Float:baseZ

        if (g_SpawnCount > 0) {
            new idx = random(g_SpawnCount)
            baseX = g_SpawnX[idx]
            baseY = g_SpawnY[idx]
            baseZ = g_SpawnZ[idx]
        } else if (mapCount > 0) {
            new idx = random(mapCount)
            baseX = mapX[idx]
            baseY = mapY[idx]
            baseZ = mapZ[idx]
        } else {
            break
        }

        new Float:angle = random_float(0.0, 360.0)
        new Float:dist = random_float(MIN_SPAWN_DIST, MIN_SPAWN_DIST * 4)

        new Float:testX = baseX + floatcos(angle, degrees) * dist
        new Float:testY = baseY + floatsin(angle, degrees) * dist
        new Float:testZ = baseZ

        drop_to_floor(testX, testY, testZ)

        if (find_safe_position(testX, testY, testZ, safeX, safeY, safeZ)) {
            if (check_spawn_distance(safeX, safeY, safeZ, MIN_SPAWN_DIST)) {
                g_SpawnX[g_SpawnCount] = safeX
                g_SpawnY[g_SpawnCount] = safeY
                g_SpawnZ[g_SpawnCount] = safeZ
                g_SpawnYaw[g_SpawnCount] = random_float(0.0, 360.0)
                g_SpawnTeam[g_SpawnCount] = 0
                g_SpawnCount++
                generated++
            }
        }
    }

    client_print(id, print_chat, "[Spawns] Создано %d спавнов", generated)

    if (g_SpawnCount < MAX_SPAWNS) {
        client_print(id, print_chat, "[Spawns] Внимание: только %d из 32", g_SpawnCount)
    }

    cmd_show_spawns(id, level, cid)

    return PLUGIN_HANDLED
}

/* ================== СПАВН ИГРОКОВ ================== */

public fw_PlayerSpawn_Post(id) {
    if (!is_user_alive(id)) return HAM_IGNORED
    if (g_SpawnCount == 0) return HAM_IGNORED

    new spawnIdx = find_free_spawn(id)

    if (spawnIdx != -1) {
        new Float:origin[3], Float:angles[3]
        origin[0] = g_SpawnX[spawnIdx]
        origin[1] = g_SpawnY[spawnIdx]
        origin[2] = g_SpawnZ[spawnIdx]
        angles[0] = 0.0
        angles[1] = g_SpawnYaw[spawnIdx]
        angles[2] = 0.0

        set_pev(id, pev_origin, origin)
        set_pev(id, pev_angles, angles)
        set_pev(id, pev_v_angle, angles)
        set_pev(id, pev_fixangle, 1)
        set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0})
    }

    return HAM_IGNORED
}

find_free_spawn(id) {
    new team = get_user_team(id)
    new tries[MAX_SPAWNS]
    new tryCount = 0

    for (new i = 0; i < g_SpawnCount; i++) {
        if (g_SpawnTeam[i] == 0 || g_SpawnTeam[i] == team) {
            tries[tryCount++] = i
        }
    }

    if (tryCount == 0) return -1

    // Shuffle
    for (new i = tryCount - 1; i > 0; i--) {
        new j = random(i + 1)
        new temp = tries[i]
        tries[i] = tries[j]
        tries[j] = temp
    }

    // Find free
    new Float:playerOrigin[3]
    for (new i = 0; i < tryCount; i++) {
        new idx = tries[i]
        new bool:isFree = true

        for (new p = 1; p <= MaxClients; p++) {
            if (p == id || !is_user_alive(p)) continue

            pev(p, pev_origin, playerOrigin)
            if (get_dist(g_SpawnX[idx], g_SpawnY[idx], g_SpawnZ[idx],
                        playerOrigin[0], playerOrigin[1], playerOrigin[2]) < 64.0) {
                isFree = false
                break
            }
        }

        if (isFree) return idx
    }

    return tries[random(tryCount)]
}

/* ================== ВИЗУАЛИЗАЦИЯ ================== */

draw_spawn_marker(id, Float:x, Float:y, Float:z, team) {
    new r, g, b
    switch (team) {
        case 0: { r = 0; g = 255; b = 0; }   // Green
        case 1: { r = 0; g = 0; b = 255; }   // Blue CT
        case 2: { r = 255; g = 0; b = 0; }   // Red T
    }

    // Vertical line
    message_begin(MSG_ONE, SVC_TEMPENTITY, _, id)
    write_byte(TE_BEAMPOINTS)
    engfunc(EngFunc_WriteCoord, x)
    engfunc(EngFunc_WriteCoord, y)
    engfunc(EngFunc_WriteCoord, z - 20.0)
    engfunc(EngFunc_WriteCoord, x)
    engfunc(EngFunc_WriteCoord, y)
    engfunc(EngFunc_WriteCoord, z + 60.0)
    write_short(g_BeamSprite)
    write_byte(0)
    write_byte(0)
    write_byte(50)
    write_byte(10)
    write_byte(0)
    write_byte(r)
    write_byte(g)
    write_byte(b)
    write_byte(200)
    write_byte(0)
    message_end()

    // Circle
    message_begin(MSG_ONE, SVC_TEMPENTITY, _, id)
    write_byte(TE_BEAMCYLINDER)
    engfunc(EngFunc_WriteCoord, x)
    engfunc(EngFunc_WriteCoord, y)
    engfunc(EngFunc_WriteCoord, z - 20.0)
    engfunc(EngFunc_WriteCoord, x)
    engfunc(EngFunc_WriteCoord, y)
    engfunc(EngFunc_WriteCoord, z + 20.0)
    write_short(g_BeamSprite)
    write_byte(0)
    write_byte(0)
    write_byte(50)
    write_byte(10)
    write_byte(0)
    write_byte(r)
    write_byte(g)
    write_byte(b)
    write_byte(200)
    write_byte(0)
    message_end()
}
