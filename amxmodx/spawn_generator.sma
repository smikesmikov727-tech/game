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
#include <xs>

#define PLUGIN_NAME     "Spawn Generator"
#define PLUGIN_VERSION  "1.0"
#define PLUGIN_AUTHOR   "Claude AI"

#define MAX_SPAWNS      32
#define MIN_SPAWN_DIST  128.0   // Минимальное расстояние между спавнами
#define HULL_CHECK_Z    36.0    // Высота проверки коллизии (стоя)
#define DUCK_HULL_Z     18.0    // Высота проверки коллизии (присев)
#define SAFE_RADIUS     32.0    // Радиус безопасной зоны

// Типы спавнов
enum _:SpawnData {
    Float:SPAWN_ORIGIN[3],
    Float:SPAWN_ANGLES[3],
    SPAWN_TEAM  // 0 = любая, 1 = CT, 2 = T
}

new g_Spawns[MAX_SPAWNS][SpawnData]
new g_SpawnCount
new g_MapName[64]
new g_SpawnFile[128]

// Цвета для визуализации
new g_BeamSprite
new g_LaserColors[3][3] = {
    {0, 255, 0},    // Зеленый - свободный
    {0, 0, 255},    // Синий - CT
    {255, 0, 0}     // Красный - T
}

// Меню
new g_MenuCallback

public plugin_init() {
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    // Команды администратора
    register_clcmd("say /spawns", "cmd_spawn_menu", ADMIN_RCON, "- Меню спавнов")
    register_clcmd("say_team /spawns", "cmd_spawn_menu", ADMIN_RCON)

    register_concmd("amx_spawn_add", "cmd_add_spawn", ADMIN_RCON, "- Добавить спавн")
    register_concmd("amx_spawn_del", "cmd_del_spawn", ADMIN_RCON, "- Удалить ближайший спавн")
    register_concmd("amx_spawn_save", "cmd_save_spawns", ADMIN_RCON, "- Сохранить спавны")
    register_concmd("amx_spawn_load", "cmd_load_spawns", ADMIN_RCON, "- Загрузить спавны")
    register_concmd("amx_spawn_clear", "cmd_clear_spawns", ADMIN_RCON, "- Очистить все спавны")
    register_concmd("amx_spawn_show", "cmd_show_spawns", ADMIN_RCON, "- Показать спавны")
    register_concmd("amx_spawn_auto", "cmd_auto_generate", ADMIN_RCON, "- Авто-генерация спавнов")
    register_concmd("amx_spawn_test", "cmd_test_spawns", ADMIN_RCON, "- Тест всех спавнов")

    // Хук спавна игроков
    RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)

    // Загрузка карты
    get_mapname(g_MapName, charsmax(g_MapName))
    formatex(g_SpawnFile, charsmax(g_SpawnFile), "addons/amxmodx/configs/spawns/%s.cfg", g_MapName)

    // Создание папки для спавнов
    new dir[128]
    formatex(dir, charsmax(dir), "addons/amxmodx/configs/spawns")
    if (!dir_exists(dir)) {
        mkdir(dir)
    }

    // Загрузка спавнов
    set_task(1.0, "task_load_spawns")

    // Меню callback
    g_MenuCallback = menu_makecallback("menu_callback")
}

public plugin_precache() {
    g_BeamSprite = precache_model("sprites/laserbeam.spr")
}

/* ================== ЗАГРУЗКА/СОХРАНЕНИЕ ================== */

public task_load_spawns() {
    load_spawns()
}

load_spawns() {
    g_SpawnCount = 0

    if (!file_exists(g_SpawnFile)) {
        server_print("[Spawns] Файл спавнов не найден: %s", g_SpawnFile)
        return 0
    }

    new file = fopen(g_SpawnFile, "rt")
    if (!file) return 0

    new line[256], data[7][32]

    while (!feof(file) && g_SpawnCount < MAX_SPAWNS) {
        fgets(file, line, charsmax(line))
        trim(line)

        if (!line[0] || line[0] == ';' || line[0] == '/') continue

        // Формат: x y z pitch yaw roll team
        if (parse(line, data[0], 31, data[1], 31, data[2], 31,
                  data[3], 31, data[4], 31, data[5], 31, data[6], 31) >= 6) {

            g_Spawns[g_SpawnCount][SPAWN_ORIGIN][0] = str_to_float(data[0])
            g_Spawns[g_SpawnCount][SPAWN_ORIGIN][1] = str_to_float(data[1])
            g_Spawns[g_SpawnCount][SPAWN_ORIGIN][2] = str_to_float(data[2])
            g_Spawns[g_SpawnCount][SPAWN_ANGLES][0] = str_to_float(data[3])
            g_Spawns[g_SpawnCount][SPAWN_ANGLES][1] = str_to_float(data[4])
            g_Spawns[g_SpawnCount][SPAWN_ANGLES][2] = str_to_float(data[5])
            g_Spawns[g_SpawnCount][SPAWN_TEAM] = str_to_num(data[6])

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
        fprintf(file, "%.1f %.1f %.1f %.1f %.1f %.1f %d^n",
            g_Spawns[i][SPAWN_ORIGIN][0],
            g_Spawns[i][SPAWN_ORIGIN][1],
            g_Spawns[i][SPAWN_ORIGIN][2],
            g_Spawns[i][SPAWN_ANGLES][0],
            g_Spawns[i][SPAWN_ANGLES][1],
            g_Spawns[i][SPAWN_ANGLES][2],
            g_Spawns[i][SPAWN_TEAM]
        )
    }

    fclose(file)
    server_print("[Spawns] Сохранено %d спавнов", g_SpawnCount)
    return 1
}

/* ================== ПРОВЕРКА БЕЗОПАСНОСТИ ================== */

// Проверка что точка безопасна (нет застреваний)
bool:is_spawn_safe(Float:origin[3]) {
    // Проверка что точка на земле
    if (!is_on_ground(origin))
        return false

    // Проверка hull (размер игрока)
    if (!check_hull(origin, HULL_HUMAN))
        return false

    // Проверка пространства над головой
    if (!check_headroom(origin))
        return false

    // Проверка что не в воде
    if (point_contents(origin) == CONTENTS_WATER)
        return false

    // Проверка что не в твердом объекте
    if (point_contents(origin) == CONTENTS_SOLID)
        return false

    return true
}

// Проверка что точка на земле
bool:is_on_ground(Float:origin[3]) {
    new Float:end[3]
    end[0] = origin[0]
    end[1] = origin[1]
    end[2] = origin[2] - 64.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, 0, tr)

    new Float:fraction
    get_tr2(tr, TR_flFraction, fraction)
    free_tr2(tr)

    return (fraction < 1.0)
}

// Проверка hull коллизии
bool:check_hull(Float:origin[3], hull) {
    new tr = create_tr2()
    engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, hull, 0, tr)

    new solid
    get_tr2(tr, TR_AllSolid, solid)

    new startsolid
    get_tr2(tr, TR_StartSolid, startsolid)

    free_tr2(tr)

    return (!solid && !startsolid)
}

// Проверка пространства над головой
bool:check_headroom(Float:origin[3]) {
    new Float:end[3]
    end[0] = origin[0]
    end[1] = origin[1]
    end[2] = origin[2] + 72.0  // Рост игрока

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, 0, tr)

    new Float:fraction
    get_tr2(tr, TR_flFraction, fraction)
    free_tr2(tr)

    return (fraction >= 1.0)
}

// Проверка минимального расстояния между спавнами
bool:check_spawn_distance(Float:origin[3], Float:minDist) {
    for (new i = 0; i < g_SpawnCount; i++) {
        new Float:dist = get_distance_f(origin, g_Spawns[i][SPAWN_ORIGIN])
        if (dist < minDist) {
            return false
        }
    }
    return true
}

// Найти безопасную позицию около заданной точки
bool:find_safe_position(Float:origin[3], Float:safeOrigin[3]) {
    // Сначала проверяем исходную точку
    if (is_spawn_safe(origin)) {
        xs_vec_copy(origin, safeOrigin)
        return true
    }

    // Пробуем найти безопасную позицию рядом
    new Float:testOrigin[3]
    new Float:offsets[] = { 0.0, 16.0, -16.0, 32.0, -32.0, 48.0, -48.0 }

    for (new x = 0; x < sizeof(offsets); x++) {
        for (new y = 0; y < sizeof(offsets); y++) {
            for (new z = 0; z < 5; z++) {
                testOrigin[0] = origin[0] + offsets[x]
                testOrigin[1] = origin[1] + offsets[y]
                testOrigin[2] = origin[2] + float(z * 16)

                if (is_spawn_safe(testOrigin)) {
                    xs_vec_copy(testOrigin, safeOrigin)
                    return true
                }
            }
        }
    }

    return false
}

// Выровнять позицию по земле
align_to_ground(Float:origin[3]) {
    new Float:end[3]
    end[0] = origin[0]
    end[1] = origin[1]
    end[2] = origin[2] - 1000.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, 0, tr)

    new Float:endpos[3]
    get_tr2(tr, TR_vecEndPos, endpos)
    free_tr2(tr)

    origin[2] = endpos[2] + 1.0  // Немного выше земли
}

/* ================== КОМАНДЫ ================== */

public cmd_spawn_menu(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    show_spawn_menu(id)
    return PLUGIN_HANDLED
}

show_spawn_menu(id) {
    new menu = menu_create("\yГенератор Спавнов", "menu_handler")

    new info[64]
    formatex(info, charsmax(info), "Добавить спавн \d[Всего: %d/%d]", g_SpawnCount, MAX_SPAWNS)
    menu_additem(menu, info, "1", 0, g_MenuCallback)

    menu_additem(menu, "Удалить ближайший спавн", "2")
    menu_additem(menu, "Авто-генерация (32 точки)", "3")
    menu_additem(menu, "Показать все спавны", "4")
    menu_additem(menu, "Тестировать спавны", "5")
    menu_additem(menu, "Сохранить спавны", "6")
    menu_additem(menu, "Загрузить спавны", "7")
    menu_additem(menu, "\rОчистить все спавны", "8")

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)
    menu_display(id, menu)
}

public menu_callback(id, menu, item) {
    if (item == 0 && g_SpawnCount >= MAX_SPAWNS) {
        return ITEM_DISABLED
    }
    return ITEM_ENABLED
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

public cmd_add_spawn(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount >= MAX_SPAWNS) {
        client_print(id, print_chat, "[Spawns] Достигнут лимит спавнов: %d", MAX_SPAWNS)
        return PLUGIN_HANDLED
    }

    new Float:origin[3], Float:angles[3]
    pev(id, pev_origin, origin)
    pev(id, pev_v_angle, angles)

    // Выравниваем по земле
    align_to_ground(origin)

    // Проверяем безопасность
    new Float:safeOrigin[3]
    if (!find_safe_position(origin, safeOrigin)) {
        client_print(id, print_chat, "[Spawns] Позиция небезопасна! Переместитесь.")
        return PLUGIN_HANDLED
    }

    // Проверяем дистанцию
    if (!check_spawn_distance(safeOrigin, MIN_SPAWN_DIST)) {
        client_print(id, print_chat, "[Spawns] Слишком близко к другому спавну! (мин. %.0f)", MIN_SPAWN_DIST)
        return PLUGIN_HANDLED
    }

    // Добавляем спавн
    xs_vec_copy(safeOrigin, g_Spawns[g_SpawnCount][SPAWN_ORIGIN])
    g_Spawns[g_SpawnCount][SPAWN_ANGLES][0] = 0.0
    g_Spawns[g_SpawnCount][SPAWN_ANGLES][1] = angles[1]
    g_Spawns[g_SpawnCount][SPAWN_ANGLES][2] = 0.0
    g_Spawns[g_SpawnCount][SPAWN_TEAM] = 0

    g_SpawnCount++

    client_print(id, print_chat, "[Spawns] Спавн #%d добавлен", g_SpawnCount)
    draw_spawn_marker(id, safeOrigin, 0)

    return PLUGIN_HANDLED
}

public cmd_del_spawn(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount <= 0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов для удаления")
        return PLUGIN_HANDLED
    }

    new Float:origin[3]
    pev(id, pev_origin, origin)

    // Находим ближайший спавн
    new nearest = -1
    new Float:nearestDist = 9999.0

    for (new i = 0; i < g_SpawnCount; i++) {
        new Float:dist = get_distance_f(origin, g_Spawns[i][SPAWN_ORIGIN])
        if (dist < nearestDist) {
            nearestDist = dist
            nearest = i
        }
    }

    if (nearest == -1 || nearestDist > 200.0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов рядом (макс. 200 единиц)")
        return PLUGIN_HANDLED
    }

    // Удаляем спавн (сдвигаем массив)
    for (new i = nearest; i < g_SpawnCount - 1; i++) {
        xs_vec_copy(g_Spawns[i+1][SPAWN_ORIGIN], g_Spawns[i][SPAWN_ORIGIN])
        xs_vec_copy(g_Spawns[i+1][SPAWN_ANGLES], g_Spawns[i][SPAWN_ANGLES])
        g_Spawns[i][SPAWN_TEAM] = g_Spawns[i+1][SPAWN_TEAM]
    }

    g_SpawnCount--
    client_print(id, print_chat, "[Spawns] Спавн удален. Осталось: %d", g_SpawnCount)

    return PLUGIN_HANDLED
}

public cmd_save_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (save_spawns()) {
        client_print(id, print_chat, "[Spawns] Сохранено %d спавнов в %s", g_SpawnCount, g_SpawnFile)
    } else {
        client_print(id, print_chat, "[Spawns] Ошибка сохранения!")
    }

    return PLUGIN_HANDLED
}

public cmd_load_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    new count = load_spawns()
    client_print(id, print_chat, "[Spawns] Загружено %d спавнов", count)

    return PLUGIN_HANDLED
}

public cmd_clear_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    g_SpawnCount = 0
    client_print(id, print_chat, "[Spawns] Все спавны удалены")

    return PLUGIN_HANDLED
}

public cmd_show_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount == 0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов для показа")
        return PLUGIN_HANDLED
    }

    for (new i = 0; i < g_SpawnCount; i++) {
        draw_spawn_marker(id, g_Spawns[i][SPAWN_ORIGIN], g_Spawns[i][SPAWN_TEAM])
    }

    client_print(id, print_chat, "[Spawns] Показано %d спавнов (5 сек)", g_SpawnCount)

    return PLUGIN_HANDLED
}

public cmd_test_spawns(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    if (g_SpawnCount == 0) {
        client_print(id, print_chat, "[Spawns] Нет спавнов для тестирования")
        return PLUGIN_HANDLED
    }

    new safe = 0, unsafe = 0

    for (new i = 0; i < g_SpawnCount; i++) {
        if (is_spawn_safe(g_Spawns[i][SPAWN_ORIGIN])) {
            safe++
        } else {
            unsafe++
            client_print(id, print_console, "[Spawns] Спавн #%d небезопасен!", i + 1)
        }
    }

    client_print(id, print_chat, "[Spawns] Тест: %d безопасных, %d небезопасных", safe, unsafe)

    return PLUGIN_HANDLED
}

public cmd_auto_generate(id, level, cid) {
    if (!cmd_access(id, level, cid, 1)) return PLUGIN_HANDLED

    client_print(id, print_chat, "[Spawns] Начинаю авто-генерацию 32 спавнов...")

    // Собираем существующие спавны на карте
    new Float:mapSpawns[64][3]
    new mapSpawnCount = 0

    // CT спавны
    new ent = -1
    while ((ent = find_ent_by_class(ent, "info_player_start")) != 0 && mapSpawnCount < 64) {
        pev(ent, pev_origin, mapSpawns[mapSpawnCount])
        mapSpawnCount++
    }

    // T спавны
    ent = -1
    while ((ent = find_ent_by_class(ent, "info_player_deathmatch")) != 0 && mapSpawnCount < 64) {
        pev(ent, pev_origin, mapSpawns[mapSpawnCount])
        mapSpawnCount++
    }

    // Очищаем текущие спавны
    g_SpawnCount = 0

    new generated = 0
    new Float:safeOrigin[3]

    // Сначала добавляем стандартные спавны карты
    for (new i = 0; i < mapSpawnCount && g_SpawnCount < MAX_SPAWNS; i++) {
        if (find_safe_position(mapSpawns[i], safeOrigin)) {
            if (check_spawn_distance(safeOrigin, MIN_SPAWN_DIST)) {
                xs_vec_copy(safeOrigin, g_Spawns[g_SpawnCount][SPAWN_ORIGIN])
                g_Spawns[g_SpawnCount][SPAWN_ANGLES][0] = 0.0
                g_Spawns[g_SpawnCount][SPAWN_ANGLES][1] = random_float(0.0, 360.0)
                g_Spawns[g_SpawnCount][SPAWN_ANGLES][2] = 0.0
                g_Spawns[g_SpawnCount][SPAWN_TEAM] = 0
                g_SpawnCount++
                generated++
            }
        }
    }

    // Генерируем дополнительные спавны вокруг существующих
    new attempts = 0
    new maxAttempts = 5000

    while (g_SpawnCount < MAX_SPAWNS && attempts < maxAttempts) {
        attempts++

        // Выбираем случайный существующий спавн
        new baseIdx = random(g_SpawnCount > 0 ? g_SpawnCount : mapSpawnCount)
        new Float:baseOrigin[3]

        if (g_SpawnCount > 0) {
            xs_vec_copy(g_Spawns[baseIdx][SPAWN_ORIGIN], baseOrigin)
        } else if (mapSpawnCount > 0) {
            xs_vec_copy(mapSpawns[baseIdx], baseOrigin)
        } else {
            break
        }

        // Генерируем случайное смещение
        new Float:testOrigin[3]
        new Float:angle = random_float(0.0, 360.0)
        new Float:dist = random_float(MIN_SPAWN_DIST, MIN_SPAWN_DIST * 4)

        testOrigin[0] = baseOrigin[0] + floatcos(angle, degrees) * dist
        testOrigin[1] = baseOrigin[1] + floatsin(angle, degrees) * dist
        testOrigin[2] = baseOrigin[2]

        // Опускаем на землю
        drop_to_floor_pos(testOrigin)

        // Проверяем и добавляем
        if (find_safe_position(testOrigin, safeOrigin)) {
            if (check_spawn_distance(safeOrigin, MIN_SPAWN_DIST)) {
                xs_vec_copy(safeOrigin, g_Spawns[g_SpawnCount][SPAWN_ORIGIN])
                g_Spawns[g_SpawnCount][SPAWN_ANGLES][0] = 0.0
                g_Spawns[g_SpawnCount][SPAWN_ANGLES][1] = random_float(0.0, 360.0)
                g_Spawns[g_SpawnCount][SPAWN_ANGLES][2] = 0.0
                g_Spawns[g_SpawnCount][SPAWN_TEAM] = 0
                g_SpawnCount++
                generated++
            }
        }
    }

    client_print(id, print_chat, "[Spawns] Сгенерировано %d спавнов (попыток: %d)", generated, attempts)

    if (g_SpawnCount < MAX_SPAWNS) {
        client_print(id, print_chat, "[Spawns] Внимание: не удалось создать 32 спавна. Создано: %d", g_SpawnCount)
    }

    // Показываем результат
    cmd_show_spawns(id, level, cid)

    return PLUGIN_HANDLED
}

// Опустить точку на пол
drop_to_floor_pos(Float:origin[3]) {
    new Float:end[3]
    end[0] = origin[0]
    end[1] = origin[1]
    end[2] = origin[2] - 1000.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, origin, end, IGNORE_MONSTERS, 0, tr)

    new Float:endpos[3]
    get_tr2(tr, TR_vecEndPos, endpos)
    free_tr2(tr)

    origin[2] = endpos[2] + 36.0  // Высота центра игрока
}

/* ================== СПАВН ИГРОКОВ ================== */

public fw_PlayerSpawn_Post(id) {
    if (!is_user_alive(id)) return HAM_IGNORED
    if (g_SpawnCount == 0) return HAM_IGNORED

    // Выбираем случайный спавн
    new spawn = find_free_spawn(id)

    if (spawn != -1) {
        // Телепортируем игрока
        set_pev(id, pev_origin, g_Spawns[spawn][SPAWN_ORIGIN])
        set_pev(id, pev_angles, g_Spawns[spawn][SPAWN_ANGLES])
        set_pev(id, pev_v_angle, g_Spawns[spawn][SPAWN_ANGLES])
        set_pev(id, pev_fixangle, 1)
        set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0})
    }

    return HAM_IGNORED
}

// Найти свободный спавн
find_free_spawn(id) {
    new team = get_user_team(id)
    new tries[MAX_SPAWNS]
    new tryCount = 0

    // Собираем подходящие спавны
    for (new i = 0; i < g_SpawnCount; i++) {
        if (g_Spawns[i][SPAWN_TEAM] == 0 || g_Spawns[i][SPAWN_TEAM] == team) {
            tries[tryCount++] = i
        }
    }

    if (tryCount == 0) return -1

    // Перемешиваем
    for (new i = tryCount - 1; i > 0; i--) {
        new j = random(i + 1)
        new temp = tries[i]
        tries[i] = tries[j]
        tries[j] = temp
    }

    // Ищем свободный (без других игроков рядом)
    for (new i = 0; i < tryCount; i++) {
        new spawn = tries[i]
        if (is_spawn_free(g_Spawns[spawn][SPAWN_ORIGIN], id)) {
            return spawn
        }
    }

    // Если все заняты, возвращаем случайный
    return tries[random(tryCount)]
}

// Проверка что спавн свободен от других игроков
bool:is_spawn_free(Float:origin[3], exceptId) {
    for (new i = 1; i <= MaxClients; i++) {
        if (i == exceptId) continue
        if (!is_user_alive(i)) continue

        new Float:playerOrigin[3]
        pev(i, pev_origin, playerOrigin)

        if (get_distance_f(origin, playerOrigin) < 64.0) {
            return false
        }
    }
    return true
}

/* ================== ВИЗУАЛИЗАЦИЯ ================== */

draw_spawn_marker(id, Float:origin[3], team) {
    new Float:start[3], Float:end[3]

    xs_vec_copy(origin, start)
    xs_vec_copy(origin, end)

    start[2] -= 20.0
    end[2] += 60.0

    // Вертикальная линия
    message_begin(MSG_ONE, SVC_TEMPENTITY, _, id)
    write_byte(TE_BEAMPOINTS)
    engfunc(EngFunc_WriteCoord, start[0])
    engfunc(EngFunc_WriteCoord, start[1])
    engfunc(EngFunc_WriteCoord, start[2])
    engfunc(EngFunc_WriteCoord, end[0])
    engfunc(EngFunc_WriteCoord, end[1])
    engfunc(EngFunc_WriteCoord, end[2])
    write_short(g_BeamSprite)
    write_byte(0)   // start frame
    write_byte(0)   // framerate
    write_byte(50)  // life (5 sec)
    write_byte(10)  // width
    write_byte(0)   // noise
    write_byte(g_LaserColors[team][0])
    write_byte(g_LaserColors[team][1])
    write_byte(g_LaserColors[team][2])
    write_byte(200) // brightness
    write_byte(0)   // scroll speed
    message_end()

    // Круг на земле
    message_begin(MSG_ONE, SVC_TEMPENTITY, _, id)
    write_byte(TE_BEAMCYLINDER)
    engfunc(EngFunc_WriteCoord, origin[0])
    engfunc(EngFunc_WriteCoord, origin[1])
    engfunc(EngFunc_WriteCoord, origin[2] - 20.0)
    engfunc(EngFunc_WriteCoord, origin[0])
    engfunc(EngFunc_WriteCoord, origin[1])
    engfunc(EngFunc_WriteCoord, origin[2] + 20.0)
    write_short(g_BeamSprite)
    write_byte(0)
    write_byte(0)
    write_byte(50)
    write_byte(10)
    write_byte(0)
    write_byte(g_LaserColors[team][0])
    write_byte(g_LaserColors[team][1])
    write_byte(g_LaserColors[team][2])
    write_byte(200)
    write_byte(0)
    message_end()
}
