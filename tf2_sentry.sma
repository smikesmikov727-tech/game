/*
*   TF2 Sentry Gun для CS 1.6
*   Полная поддержка TF2 моделей с анимациями
*
*   === МОДЕЛИ И АНИМАЦИИ ===
*
*   sentrygun1_heavy.mdl - постройка уровня 1
*     [0] build - 30 fps
*
*   sentrygun1_low.mdl - рабочая модель уровня 1
*     [0] idle_off - 30 fps
*     [1] fire - 30 fps
*
*   sentrygun2_heavy.mdl - апгрейд до уровня 2
*     [0] upgrade - 40 fps
*
*   sentrygun2_low.mdl - рабочая модель уровня 2
*     [0] idle_off - 30 fps
*     [1] fire - 30 fps
*     [2] fire_alt - 30 fps
*
*   sentrygun3_heavy.mdl - апгрейд до уровня 3
*     [0] upgrade - 40 fps
*
*   sentrygun3_low.mdl - рабочая модель уровня 3
*     [0] idle_off - 30 fps
*     [1] fire - 30 fps
*     [2] fire_alt - 30 fps
*     [3] fire_rocket - 60 fps
*
*   sentrygun_blueprint.mdl - чертёж
*     [0] bp_front - можно строить
*     [1] bp_no - нельзя строить
*
*   sentrygun_rockets.mdl - ракета
*     [0] idle - 30 fps
*
*   sentrygun_gibs.mdl - обломки
*     [0] idle - 30 fps
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <xs>

#define DMG_BULLET (1<<1)

// ============== КОНСТАНТЫ ==============
#define PLUGIN_NAME     "TF2 Sentry Gun"
#define PLUGIN_VERSION  "5.2"
#define PLUGIN_AUTHOR   "Smike"

#define SENTRY_CLASSNAME    "tf2_sentry"
#define ROCKET_CLASSNAME    "tf2_rocket"
#define BLUEPRINT_CLASSNAME "tf2_blueprint"

#define MAX_SENTRIES        64
#define MAX_PLAYER_SENTRIES 3

// Уровни
#define LEVEL_1     1
#define LEVEL_2     2
#define LEVEL_3     3

// Состояния
#define STATE_BUILDING      0
#define STATE_UPGRADING     1
#define STATE_IDLE          2
#define STATE_SEARCHING     3
#define STATE_FIRING        4

// Индексы анимаций
#define ANIM_BUILD          0   // sentrygun1_heavy.mdl
#define ANIM_UPGRADE        0   // sentrygun2/3_heavy.mdl
#define ANIM_IDLE           0   // все _low.mdl
#define ANIM_FIRE           1   // все _low.mdl
#define ANIM_FIRE_ALT       2   // level2/3_low.mdl
#define ANIM_FIRE_ROCKET    3   // level3_low.mdl (только у level 3)
#define ANIM_BP_OK          0   // blueprint
#define ANIM_BP_NO          1   // blueprint
#define ANIM_ROCKET_IDLE    0   // rockets
#define ANIM_GIBS_IDLE      0   // gibs

// Настройки
#define BUILD_DISTANCE      80.0
#define UPGRADE_DISTANCE    120.0   // Дистанция для апгрейда
#define DETECT_RANGE        1200.0

// Время (из анализа моделей)
// build: 301 frames / 30 fps = 10.03 sec
// upgrade: 121 frames / 40 fps = 3.02 sec
#define BUILD_TIME          10.0    // Время постройки = длина анимации
#define UPGRADE_TIME        3.0

// Урон (из TF2 Wiki - точные значения)
#define DMG_LEVEL1          16.0
#define DMG_LEVEL2          16.0
#define DMG_LEVEL3          16.0
#define DMG_ROCKET          100.0
#define ROCKET_RADIUS       150.0

// Скорострельность
#define FIRERATE_LEVEL1     0.15
#define FIRERATE_LEVEL2     0.12
#define FIRERATE_LEVEL3     0.10
#define ROCKET_COOLDOWN     3.0

// Качание и поворот
#define TURN_SPEED          15.0    // Скорость поворота к цели (градусы за тик)
#define SCAN_SPEED          2.0     // Скорость сканирования (градусы за тик)
#define SCAN_ANGLE          90.0    // Угол сканирования ±90° (180° всего)

// Смещение модели - TF2 модель смотрит на +90° от angles[1]
#define MODEL_YAW_OFFSET    90.0

// Здоровье по уровням (из TF2 Wiki)
new const Float:g_flHealth[4] = {0.0, 150.0, 180.0, 216.0}

// Цены
new const g_iCostBuild = 500
new const g_iCostUpgrade1 = 300
new const g_iCostUpgrade2 = 400

// ============== МОДЕЛИ ==============
new const g_szModelBuild[]      = "models/error_csdm/sentry/sentrygun1_heavy.mdl"
new const g_szModelLevel1[]     = "models/error_csdm/sentry/sentrygun1_low.mdl"
new const g_szModelUpgrade2[]   = "models/error_csdm/sentry/sentrygun2_heavy.mdl"
new const g_szModelLevel2[]     = "models/error_csdm/sentry/sentrygun2_low.mdl"
new const g_szModelUpgrade3[]   = "models/error_csdm/sentry/sentrygun3_heavy.mdl"
new const g_szModelLevel3[]     = "models/error_csdm/sentry/sentrygun3_low.mdl"
new const g_szModelBlueprint[]  = "models/error_csdm/sentry/sentrygun_blueprint.mdl"
new const g_szModelRocket[]     = "models/error_csdm/sentry/sentrygun_rockets.mdl"
new const g_szModelGibs[]       = "models/error_csdm/sentry/sentrygun_gibs.mdl"

// ============== ЗВУКИ ==============
new const g_szSndBuild[]    = "error_csdm/sentry/building.wav"
new const g_szSndDeploy[]   = "error_csdm/sentry/turrset.wav"
new const g_szSndIdle[]     = "error_csdm/sentry/turridle.wav"
new const g_szSndSpot[]     = "error_csdm/sentry/turrspot.wav"
new const g_szSndFire[]     = "error_csdm/sentry/fire.wav"
new const g_szSndScan[]     = "error_csdm/sentry/turridle.wav"  // Звук сканирования
new const g_szSndRocket[]   = "weapons/rocketfire1.wav"  // Одиночный звук запуска
new const g_szSndExplode[]  = "debris/bustmetal1.wav"

// ============== ПЕРЕМЕННЫЕ ==============
new g_iMaxPlayers
new g_iMsgDeathMsg
new g_iMsgBarTime
new g_iSprExplode
new g_iSprTrail
new g_iSprSmoke
new g_iSprLaser

// Данные игроков
new g_iPlayerSentries[33]
new g_iPlayerSentryEnts[33][MAX_PLAYER_SENTRIES]
new bool:g_bIsBuilding[33]
new g_iBlueprint[33]           // Entity blueprint
new bool:g_bBlueprintActive[33] // Активен ли режим размещения
new Float:g_flBlueprintPos[33][3] // Позиция blueprint
new Float:g_flBlueprintAng[33]    // Угол blueprint
new Float:g_flBuildStartTime[33]  // Время начала постройки (0 = не строится)
new bool:g_bValidPosition[33]     // Валидная ли позиция
new bool:g_bHamRegistered = false // Ham зарегистрирован

// ============== ENTITY DATA ==============
#define SENTRY_OWNER        EV_INT_iuser1
#define SENTRY_LEVEL        EV_INT_iuser2
#define SENTRY_STATE        EV_INT_iuser3
#define SENTRY_TEAM         EV_INT_iuser4
#define SENTRY_TARGET       EV_ENT_euser1
#define SENTRY_FIRETIME     EV_FL_fuser1
#define SENTRY_ROCKETTIME   EV_FL_fuser2
#define SENTRY_BASEANGLE    EV_FL_fuser3
#define SENTRY_SCANDIR      EV_FL_fuser4
#define SENTRY_BUILDEND     EV_FL_ltime
#define SENTRY_HEADYAW      EV_FL_frags  // Угол головы относительно базы
#define SENTRY_BARREL       EV_INT_button // Чередование стволов (0/1)
#define SENTRY_SCANPAUSE    EV_FL_dmgtime // Время паузы сканирования

// ============== PLUGIN INIT ==============
public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)

    // Команды
    register_clcmd("sentry", "cmd_Sentry")
    register_clcmd("say /sentry", "cmd_Sentry")
    register_clcmd("say_team /sentry", "cmd_Sentry")
    register_clcmd("say /delsentry", "cmd_DeleteSentry")
    register_clcmd("say_team /delsentry", "cmd_DeleteSentry")
    register_clcmd("+attack", "cmd_Attack")
    register_clcmd("+attack2", "cmd_CancelBlueprint")

    // События
    register_event("DeathMsg", "event_DeathMsg", "a")
    RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)

    // Think
    register_think(SENTRY_CLASSNAME, "fw_SentryThink")
    register_think(ROCKET_CLASSNAME, "fw_RocketThink")
    register_think(BLUEPRINT_CLASSNAME, "fw_BlueprintThink")
    register_touch(ROCKET_CLASSNAME, "*", "fw_RocketTouch")

    // Touch для блокировки прохода через пушку
    register_touch(SENTRY_CLASSNAME, "player", "fw_SentryTouch")

    // HUD обновление
    set_task(0.5, "task_SentryHUD", _, _, _, "b")

    // Сообщения
    g_iMsgDeathMsg = get_user_msgid("DeathMsg")
    g_iMsgBarTime = get_user_msgid("BarTime")

    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    // Модели
    precache_model(g_szModelBuild)
    precache_model(g_szModelLevel1)
    precache_model(g_szModelUpgrade2)
    precache_model(g_szModelLevel2)
    precache_model(g_szModelUpgrade3)
    precache_model(g_szModelLevel3)
    precache_model(g_szModelBlueprint)
    precache_model(g_szModelRocket)
    precache_model(g_szModelGibs)

    // Звуки
    precache_sound(g_szSndBuild)
    precache_sound(g_szSndDeploy)
    precache_sound(g_szSndIdle)
    precache_sound(g_szSndSpot)
    precache_sound(g_szSndFire)
    precache_sound(g_szSndScan)
    precache_sound(g_szSndRocket)
    precache_sound(g_szSndExplode)

    // Спрайты
    g_iSprExplode = precache_model("sprites/zerogxplode.spr")
    g_iSprTrail = precache_model("sprites/smoke.spr")
    g_iSprSmoke = precache_model("sprites/steam1.spr")
    g_iSprLaser = precache_model("sprites/laserbeam.spr")
}

// ============== КОМАНДА ПОСТРОЙКИ ==============
public cmd_Sentry(id)
{
    if (!is_user_alive(id))
    {
        client_print(id, print_center, "Мёртвые не могут строить!")
        return PLUGIN_HANDLED
    }

    // Если blueprint уже активен - отменяем его
    if (g_bBlueprintActive[id])
    {
        RemoveBlueprint(id)
        client_print(id, print_center, "Постройка отменена")
        return PLUGIN_HANDLED
    }

    // Создаём blueprint для выбора места
    CreateBlueprint(id)
    return PLUGIN_HANDLED
}

// Подтверждение постройки по ЛКМ - убрано, постройка автоматическая
public cmd_Attack(id)
{
    // Не используется для blueprint - постройка автоматическая
    return PLUGIN_CONTINUE
}

// Отмена blueprint по ПКМ
public cmd_CancelBlueprint(id)
{
    if (g_bBlueprintActive[id])
    {
        RemoveBlueprint(id)
        client_print(id, print_center, "Постройка отменена")
        return PLUGIN_HANDLED
    }
    return PLUGIN_CONTINUE
}

// Удалить все свои пушки
public cmd_DeleteSentry(id)
{
    if (g_iPlayerSentries[id] == 0)
    {
        client_print(id, print_center, "У вас нет пушек!")
        return PLUGIN_HANDLED
    }

    for (new i = 0; i < g_iPlayerSentries[id]; i++)
    {
        new iEnt = g_iPlayerSentryEnts[id][i]
        if (is_valid_ent(iEnt))
        {
            new Float:flOrigin[3]
            entity_get_vector(iEnt, EV_VEC_origin, flOrigin)

            // Небольшой эффект
            message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
            write_byte(TE_SPARKS)
            write_coord(floatround(flOrigin[0]))
            write_coord(floatround(flOrigin[1]))
            write_coord(floatround(flOrigin[2]) + 20)
            message_end()

            remove_entity(iEnt)
        }
    }

    g_iPlayerSentries[id] = 0
    arrayset(g_iPlayerSentryEnts[id], 0, MAX_PLAYER_SENTRIES)
    g_bIsBuilding[id] = false

    client_print(id, print_center, "Все пушки удалены!")
    return PLUGIN_HANDLED
}

// ============== BLUEPRINT ==============
CreateBlueprint(id)
{
    // Проверки
    if (g_bIsBuilding[id])
    {
        client_print(id, print_center, "Подождите, идёт постройка...")
        return
    }

    if (g_iPlayerSentries[id] >= MAX_PLAYER_SENTRIES)
    {
        client_print(id, print_center, "Максимум %d пушки!", MAX_PLAYER_SENTRIES)
        return
    }

    if (cs_get_user_money(id) < g_iCostBuild)
    {
        client_print(id, print_center, "Нужно $%d для постройки!", g_iCostBuild)
        return
    }

    // Удаляем старый blueprint если есть
    RemoveBlueprint(id)

    // Создаём blueprint
    new iEnt = create_entity("info_target")
    if (!iEnt)
        return

    entity_set_string(iEnt, EV_SZ_classname, BLUEPRINT_CLASSNAME)
    entity_set_model(iEnt, g_szModelBlueprint)
    entity_set_int(iEnt, EV_INT_solid, SOLID_NOT)
    entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_NOCLIP)
    entity_set_int(iEnt, EV_INT_rendermode, kRenderTransAdd)
    entity_set_float(iEnt, EV_FL_renderamt, 200.0)
    entity_set_int(iEnt, SENTRY_OWNER, id)

    // Начальное состояние - sequence 0 = bp_front (без крестика), зелёный
    entity_set_int(iEnt, EV_INT_sequence, 0)
    entity_set_int(iEnt, EV_INT_skin, 0)
    entity_set_int(iEnt, EV_INT_body, 0)
    entity_set_float(iEnt, EV_FL_frame, 0.0)
    set_pev(iEnt, pev_animtime, get_gametime())  // Важно для анимации!
    new Float:flGreen[3] = {0.0, 255.0, 0.0}
    entity_set_vector(iEnt, EV_VEC_rendercolor, flGreen)

    g_iBlueprint[id] = iEnt
    g_bBlueprintActive[id] = true
    g_flBuildStartTime[id] = get_gametime()  // Начинаем отсчёт сразу
    g_bValidPosition[id] = true  // Считаем валидным - если нет, think изменит

    // Показываем прогресс-бар сразу
    message_begin(MSG_ONE, g_iMsgBarTime, _, id)
    write_short(floatround(BUILD_TIME))
    message_end()

    // Запускаем think сразу
    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.01)

    client_print(id, print_center, "Выберите место для пушки | ПКМ - отмена")
}

RemoveBlueprint(id)
{
    if (g_iBlueprint[id] > 0 && is_valid_ent(g_iBlueprint[id]))
    {
        remove_entity(g_iBlueprint[id])
    }
    g_iBlueprint[id] = 0
    g_bBlueprintActive[id] = false
    g_flBuildStartTime[id] = 0.0
    g_bValidPosition[id] = false

    // Скрываем прогресс-бар
    message_begin(MSG_ONE, g_iMsgBarTime, _, id)
    write_short(0)
    message_end()
}

// Blueprint следует за прицелом + автоматическая постройка
public fw_BlueprintThink(iEnt)
{
    if (!is_valid_ent(iEnt))
        return

    new id = entity_get_int(iEnt, SENTRY_OWNER)

    if (!is_user_alive(id) || !g_bBlueprintActive[id])
    {
        RemoveBlueprint(id)
        return
    }

    // Позиция перед игроком
    new Float:flOrigin[3], Float:flAngles[3]
    pev(id, pev_origin, flOrigin)
    pev(id, pev_v_angle, flAngles)

    new Float:flForward[3]
    engfunc(EngFunc_MakeVectors, flAngles)
    get_global_vector(GL_v_forward, flForward)

    new Float:flPos[3]
    flPos[0] = flOrigin[0] + flForward[0] * BUILD_DISTANCE
    flPos[1] = flOrigin[1] + flForward[1] * BUILD_DISTANCE
    flPos[2] = flOrigin[2]

    // Трассировка вниз для пола
    new Float:flEnd[3]
    flEnd[0] = flPos[0]
    flEnd[1] = flPos[1]
    flEnd[2] = flPos[2] - 100.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, flPos, flEnd, IGNORE_MONSTERS, id, tr)

    new Float:flFraction
    get_tr2(tr, TR_flFraction, flFraction)

    if (flFraction < 1.0)
    {
        get_tr2(tr, TR_vecEndPos, flPos)
        flPos[2] += 1.0
    }
    free_tr2(tr)

    // Проверяем можно ли строить
    new bool:bCanBuild = CanBuildHere(flPos, id)

    // Сохраняем позицию
    g_flBlueprintPos[id][0] = flPos[0]
    g_flBlueprintPos[id][1] = flPos[1]
    g_flBlueprintPos[id][2] = flPos[2]

    // Угол пушки = угол взгляда игрока (дула смотрят туда же куда игрок)
    new Float:flEntAngles[3]
    flEntAngles[0] = 0.0
    flEntAngles[1] = flAngles[1]  // Пушка смотрит туда куда игрок
    flEntAngles[2] = 0.0
    g_flBlueprintAng[id] = flEntAngles[1]

    // Устанавливаем позицию и угол
    entity_set_origin(iEnt, flPos)
    entity_set_vector(iEnt, EV_VEC_angles, flEntAngles)

    // ВСЕГДА обновляем визуал каждый кадр
    if (bCanBuild)
    {
        // Зелёный без крестика - можно строить
        entity_set_int(iEnt, EV_INT_sequence, 0)  // bp_front
        entity_set_float(iEnt, EV_FL_frame, 0.0)
        set_pev(iEnt, pev_animtime, get_gametime())  // Важно для смены анимации!
        new Float:flGreen[3] = {0.0, 255.0, 0.0}
        entity_set_vector(iEnt, EV_VEC_rendercolor, flGreen)

        // Начинаем/продолжаем отсчёт
        if (!g_bValidPosition[id])
        {
            g_bValidPosition[id] = true
            g_flBuildStartTime[id] = get_gametime()

            // Показываем прогресс-бар
            message_begin(MSG_ONE, g_iMsgBarTime, _, id)
            write_short(floatround(BUILD_TIME))
            message_end()
        }

        // Проверяем прошло ли время (защита от 0.0)
        if (g_flBuildStartTime[id] > 0.0 && get_gametime() - g_flBuildStartTime[id] >= BUILD_TIME)
        {
            AutoBuildSentry(id)
            return
        }
    }
    else
    {
        // Красный с крестиком - нельзя строить
        entity_set_int(iEnt, EV_INT_sequence, 1)  // bp_no
        entity_set_float(iEnt, EV_FL_frame, 0.0)
        set_pev(iEnt, pev_animtime, get_gametime())  // Важно для смены анимации!
        new Float:flRed[3] = {255.0, 0.0, 0.0}
        entity_set_vector(iEnt, EV_VEC_rendercolor, flRed)

        // Сбрасываем отсчёт
        if (g_bValidPosition[id])
        {
            g_bValidPosition[id] = false
            g_flBuildStartTime[id] = 0.0

            // Скрываем прогресс-бар
            message_begin(MSG_ONE, g_iMsgBarTime, _, id)
            write_short(0)
            message_end()
        }
    }

    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.05)
}

// Автоматическая постройка когда прогресс-бар заполнился
AutoBuildSentry(id)
{
    if (!g_bBlueprintActive[id])
        return

    // Проверяем деньги
    if (cs_get_user_money(id) < g_iCostBuild)
    {
        client_print(id, print_center, "Нужно $%d!", g_iCostBuild)
        RemoveBlueprint(id)
        return
    }

    // Удаляем blueprint
    new Float:flPos[3], Float:flAng
    flPos[0] = g_flBlueprintPos[id][0]
    flPos[1] = g_flBlueprintPos[id][1]
    flPos[2] = g_flBlueprintPos[id][2]
    flAng = g_flBlueprintAng[id]

    RemoveBlueprint(id)

    // Создаём пушку
    BuildSentryAt(id, flPos, flAng)
}

// Проверка возможности постройки
bool:CanBuildHere(Float:flPos[3], id)
{
    // 1. Проверяем что точка в воздухе (не в стене)
    if (engfunc(EngFunc_PointContents, flPos) != CONTENTS_EMPTY)
        return false

    // 2. Проверяем есть ли пол под пушкой (на расстоянии до 50 юнитов)
    new Float:flDown[3]
    flDown[0] = flPos[0]
    flDown[1] = flPos[1]
    flDown[2] = flPos[2] - 50.0

    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, flPos, flDown, IGNORE_MONSTERS, id, tr)
    new Float:flFraction
    get_tr2(tr, TR_flFraction, flFraction)
    free_tr2(tr)

    // Должен быть пол
    if (flFraction >= 1.0)
        return false

    // 3. Проверяем достаточно места сверху (минимум 40 юнитов)
    new Float:flUp[3]
    flUp[0] = flPos[0]
    flUp[1] = flPos[1]
    flUp[2] = flPos[2] + 40.0

    tr = create_tr2()
    engfunc(EngFunc_TraceLine, flPos, flUp, IGNORE_MONSTERS, id, tr)
    get_tr2(tr, TR_flFraction, flFraction)
    free_tr2(tr)

    if (flFraction < 1.0)
        return false

    // 4. Проверяем нет ли других пушек рядом (80 юнитов)
    new iEnt = -1
    new Float:flEntOrigin[3]

    while ((iEnt = find_ent_by_class(iEnt, SENTRY_CLASSNAME)) != 0)
    {
        entity_get_vector(iEnt, EV_VEC_origin, flEntOrigin)

        if (vector_distance(flPos, flEntOrigin) < 80.0)
            return false
    }

    return true
}

// HUD информация о пушках - только при наведении курсором
public task_SentryHUD()
{
    for (new id = 1; id <= g_iMaxPlayers; id++)
    {
        if (!is_user_alive(id))
            continue

        // Получаем позицию и направление взгляда игрока
        new Float:flEyePos[3], Float:flAngles[3], Float:flForward[3]
        pev(id, pev_origin, flEyePos)
        pev(id, pev_v_angle, flAngles)
        flEyePos[2] += 17.0  // Уровень глаз

        engfunc(EngFunc_MakeVectors, flAngles)
        get_global_vector(GL_v_forward, flForward)

        // Ищем пушку на которую смотрит игрок
        new iBestSentry = 0
        new Float:flBestDot = 0.95  // Минимальный угол (косинус ~18 градусов)
        new Float:flBestDist = 500.0

        new iEnt = -1
        while ((iEnt = find_ent_by_class(iEnt, SENTRY_CLASSNAME)) != 0)
        {
            new Float:flSentryPos[3]
            entity_get_vector(iEnt, EV_VEC_origin, flSentryPos)
            flSentryPos[2] += 25.0  // Центр пушки

            // Вектор к пушке
            new Float:flToSentry[3]
            flToSentry[0] = flSentryPos[0] - flEyePos[0]
            flToSentry[1] = flSentryPos[1] - flEyePos[1]
            flToSentry[2] = flSentryPos[2] - flEyePos[2]

            new Float:flDist = floatsqroot(flToSentry[0]*flToSentry[0] + flToSentry[1]*flToSentry[1] + flToSentry[2]*flToSentry[2])

            if (flDist > flBestDist || flDist < 10.0)
                continue

            // Нормализуем
            flToSentry[0] /= flDist
            flToSentry[1] /= flDist
            flToSentry[2] /= flDist

            // Dot product - насколько точно смотрим на пушку
            new Float:flDot = flForward[0]*flToSentry[0] + flForward[1]*flToSentry[1] + flForward[2]*flToSentry[2]

            if (flDot > flBestDot)
            {
                flBestDot = flDot
                flBestDist = flDist
                iBestSentry = iEnt
            }
        }

        // Показываем HUD если нашли пушку
        if (iBestSentry > 0)
        {
            new iOwner = entity_get_int(iBestSentry, SENTRY_OWNER)
            new iLevel = entity_get_int(iBestSentry, SENTRY_LEVEL)
            new iState = entity_get_int(iBestSentry, SENTRY_STATE)
            new Float:flHealth = entity_get_float(iBestSentry, EV_FL_health)
            new Float:flMaxHealth = g_flHealth[iLevel]

            new szOwnerName[32]
            if (is_user_connected(iOwner))
                get_user_name(iOwner, szOwnerName, charsmax(szOwnerName))
            else
                szOwnerName = "???"

            new szState[32]
            switch (iState)
            {
                case STATE_BUILDING: szState = "Постройка..."
                case STATE_UPGRADING: szState = "Улучшение..."
                case STATE_IDLE: szState = "Ожидание"
                case STATE_SEARCHING: szState = "Поиск"
                case STATE_FIRING: szState = "Огонь!"
            }

            if (iOwner == id)
            {
                set_hudmessage(0, 255, 100, -1.0, 0.60, 0, 0.0, 0.6, 0.0, 0.0, 2)
                show_hudmessage(id, "[ ТВОЯ ПУШКА ]^nУровень: %d | HP: %.0f/%.0f^nСтатус: %s^n^nКоснись для улучшения",
                    iLevel, flHealth, flMaxHealth, szState)
            }
            else
            {
                new iSentryTeam = entity_get_int(iBestSentry, SENTRY_TEAM)
                new CsTeams:iPlayerTeam = cs_get_user_team(id)

                if (_:iPlayerTeam == iSentryTeam)
                {
                    set_hudmessage(100, 150, 255, -1.0, 0.60, 0, 0.0, 0.6, 0.0, 0.0, 2)
                    show_hudmessage(id, "[ СОЮЗНАЯ ПУШКА ]^nВладелец: %s^nУровень: %d | HP: %.0f/%.0f",
                        szOwnerName, iLevel, flHealth, flMaxHealth)
                }
                else
                {
                    set_hudmessage(255, 50, 50, -1.0, 0.60, 0, 0.0, 0.6, 0.0, 0.0, 2)
                    show_hudmessage(id, "[ ВРАЖЕСКАЯ ПУШКА ]^nВладелец: %s^nУровень: %d | HP: %.0f/%.0f",
                        szOwnerName, iLevel, flHealth, flMaxHealth)
                }
            }
        }
    }
}

// ============== ПОСТРОЙКА ==============
BuildSentryAt(id, Float:flPos[3], Float:flYaw)
{
    // Создаём пушку - info_target для think
    new iEnt = create_entity("info_target")
    if (!iEnt)
    {
        g_bIsBuilding[id] = false
        return
    }

    // Определяем команду и skin
    new CsTeams:iTeam = cs_get_user_team(id)
    new iSkin = (iTeam == CS_TEAM_CT) ? 1 : 0  // CT = синий (1), T = красный (0)

    // Базовые настройки
    entity_set_string(iEnt, EV_SZ_classname, SENTRY_CLASSNAME)
    entity_set_model(iEnt, g_szModelBuild)  // Модель постройки!
    entity_set_int(iEnt, EV_INT_skin, iSkin)  // Цвет команды!

    // Рендер - полностью непрозрачная на любом расстоянии
    entity_set_int(iEnt, EV_INT_rendermode, 0)  // kRenderNormal
    entity_set_int(iEnt, EV_INT_renderfx, 0)    // kRenderFxNone
    entity_set_float(iEnt, EV_FL_renderamt, 255.0)

    // Размеры - больше для блокировки прохода
    new Float:flMins[3] = {-20.0, -20.0, 0.0}
    new Float:flMaxs[3] = {20.0, 20.0, 55.0}
    entity_set_size(iEnt, flMins, flMaxs)

    // Позиция
    entity_set_origin(iEnt, flPos)

    // Углы - только YAW
    new Float:flEntAngles[3]
    flEntAngles[0] = 0.0  // pitch = 0
    flEntAngles[1] = flYaw
    flEntAngles[2] = 0.0
    entity_set_vector(iEnt, EV_VEC_angles, flEntAngles)

    // Физика - SOLID_SLIDEBOX блокирует всех игроков (как в оригинале)
    entity_set_int(iEnt, EV_INT_solid, SOLID_SLIDEBOX)
    entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_TOSS)  // TOSS для статичных объектов
    entity_set_float(iEnt, EV_FL_takedamage, DAMAGE_AIM)
    entity_set_float(iEnt, EV_FL_health, g_flHealth[LEVEL_1])

    // Данные пушки
    entity_set_int(iEnt, SENTRY_OWNER, id)
    entity_set_int(iEnt, SENTRY_LEVEL, LEVEL_1)
    entity_set_int(iEnt, SENTRY_STATE, STATE_BUILDING)
    entity_set_int(iEnt, SENTRY_TEAM, _:iTeam)
    entity_set_float(iEnt, SENTRY_BASEANGLE, flYaw)
    entity_set_float(iEnt, SENTRY_SCANDIR, 1.0)
    entity_set_float(iEnt, SENTRY_FIRETIME, 0.0)
    entity_set_float(iEnt, SENTRY_ROCKETTIME, 0.0)
    entity_set_edict(iEnt, SENTRY_TARGET, 0)
    entity_set_float(iEnt, SENTRY_HEADYAW, 0.0)
    entity_set_int(iEnt, SENTRY_BARREL, 0)
    entity_set_float(iEnt, SENTRY_SCANPAUSE, 0.0)

    // Время окончания постройки (как в модели - 10 сек)
    entity_set_float(iEnt, SENTRY_BUILDEND, get_gametime() + BUILD_TIME)

    // Bone controllers для головы пушки
    entity_set_byte(iEnt, EV_BYTE_controller1, 128)
    entity_set_byte(iEnt, EV_BYTE_controller2, 128)

    // Анимация постройки - framerate 1.0 как в оригинале
    set_entity_anim(iEnt, ANIM_BUILD, 1.0)

    // Звук постройки
    emit_sound(iEnt, CHAN_BODY, g_szSndBuild, 1.0, ATTN_NORM, 0, PITCH_NORM)

    // Деньги
    cs_set_user_money(id, cs_get_user_money(id) - g_iCostBuild)

    // Добавляем в список
    g_iPlayerSentryEnts[id][g_iPlayerSentries[id]] = iEnt
    g_iPlayerSentries[id]++

    // Регистрируем Ham для урона (один раз)
    if (!g_bHamRegistered)
    {
        RegisterHamFromEntity(Ham_TakeDamage, iEnt, "fw_TakeDamage")
        RegisterHamFromEntity(Ham_TraceAttack, iEnt, "fw_TraceAttack")
        g_bHamRegistered = true
    }

    // Think - ВАЖНО!
    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.1)

    g_bIsBuilding[id] = false
    client_print(id, print_center, "Постройка пушки...")
}

// ============== АПГРЕЙД ==============
UpgradeSentry(id, iEnt)
{
    new iLevel = entity_get_int(iEnt, SENTRY_LEVEL)
    new iState = entity_get_int(iEnt, SENTRY_STATE)

    // Нельзя апгрейдить во время постройки/апгрейда
    if (iState == STATE_BUILDING || iState == STATE_UPGRADING)
    {
        client_print(id, print_center, "Подождите, пушка ещё строится!")
        return
    }

    if (iLevel >= LEVEL_3)
    {
        client_print(id, print_center, "Максимальный уровень!")
        return
    }

    new iCost = (iLevel == LEVEL_1) ? g_iCostUpgrade1 : g_iCostUpgrade2

    if (cs_get_user_money(id) < iCost)
    {
        client_print(id, print_center, "Нужно $%d для апгрейда!", iCost)
        return
    }

    // Списываем деньги
    cs_set_user_money(id, cs_get_user_money(id) - iCost)

    // СОХРАНЯЕМ ВСЁ перед сменой модели
    new Float:flAngles[3]
    entity_get_vector(iEnt, EV_VEC_angles, flAngles)
    new iSkin = entity_get_int(iEnt, EV_INT_skin)

    // Устанавливаем состояние
    entity_set_int(iEnt, SENTRY_STATE, STATE_UPGRADING)
    entity_set_int(iEnt, SENTRY_LEVEL, iLevel + 1)

    // Меняем модель на heavy для анимации апгрейда
    if (iLevel == LEVEL_1)
        entity_set_model(iEnt, g_szModelUpgrade2)
    else
        entity_set_model(iEnt, g_szModelUpgrade3)

    // ВОССТАНАВЛИВАЕМ углы и skin
    entity_set_vector(iEnt, EV_VEC_angles, flAngles)
    entity_set_int(iEnt, EV_INT_skin, iSkin)

    // ВАЖНО: После entity_set_model нужно заново установить размеры и физику!
    new Float:flMins[3] = {-20.0, -20.0, 0.0}
    new Float:flMaxs[3] = {20.0, 20.0, 55.0}
    entity_set_size(iEnt, flMins, flMaxs)
    entity_set_int(iEnt, EV_INT_solid, SOLID_SLIDEBOX)
    entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_TOSS)

    // Рендер - полностью непрозрачная
    entity_set_int(iEnt, EV_INT_rendermode, 0)
    entity_set_int(iEnt, EV_INT_renderfx, 0)
    entity_set_float(iEnt, EV_FL_renderamt, 255.0)

    // Анимация апгрейда
    set_entity_anim(iEnt, ANIM_UPGRADE, 1.0)

    // Звук
    emit_sound(iEnt, CHAN_BODY, g_szSndBuild, 1.0, ATTN_NORM, 0, PITCH_NORM)

    // Обновляем здоровье
    entity_set_float(iEnt, EV_FL_health, g_flHealth[iLevel + 1])

    // Сохраняем время окончания апгрейда
    entity_set_float(iEnt, SENTRY_BUILDEND, get_gametime() + UPGRADE_TIME)

    // Think каждые 0.1 сек
    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.1)

    client_print(id, print_center, "Улучшение до уровня %d...", iLevel + 1)
}

// ============== SENTRY THINK ==============
public fw_SentryThink(iEnt)
{
    if (!pev_valid(iEnt))
        return

    new iOwner = entity_get_int(iEnt, SENTRY_OWNER)
    if (!is_user_connected(iOwner))
    {
        remove_entity(iEnt)
        return
    }

    new iState = entity_get_int(iEnt, SENTRY_STATE)

    // Если строится или апгрейдится - обрабатываем отдельно
    if (iState == STATE_BUILDING)
    {
        FinishBuilding(iEnt)
        return
    }
    if (iState == STATE_UPGRADING)
    {
        FinishUpgrade(iEnt)
        return
    }

    // Обычная работа пушки
    new iLevel = entity_get_int(iEnt, SENTRY_LEVEL)
    new iTeam = entity_get_int(iEnt, SENTRY_TEAM)
    new iOldTarget = entity_get_edict(iEnt, SENTRY_TARGET)
    new Float:flNow = get_gametime()

    // Ищем цель
    new iTarget = FindTarget(iEnt, iTeam)

    if (iTarget > 0)
    {
        // Звук обнаружения при новой цели
        if (iOldTarget != iTarget)
        {
            emit_sound(iEnt, CHAN_VOICE, g_szSndSpot, 1.0, ATTN_NORM, 0, PITCH_NORM)
            entity_set_edict(iEnt, SENTRY_TARGET, iTarget)
        }

        // Поворачиваем ГОЛОВУ к цели (не базу!)
        TrackTarget(iEnt, iTarget)

        // Стреляем
        new Float:flLastShot = entity_get_float(iEnt, SENTRY_FIRETIME)
        new Float:flFireRate = 0.3 - float(iLevel) * 0.05

        if (flNow - flLastShot >= flFireRate)
        {
            ShootTarget(iEnt, iTarget, iLevel)
            entity_set_float(iEnt, SENTRY_FIRETIME, flNow)
        }

        // Ракеты (уровень 3)
        if (iLevel == LEVEL_3)
        {
            new Float:flLastRocket = entity_get_float(iEnt, SENTRY_ROCKETTIME)
            if (flNow - flLastRocket >= ROCKET_COOLDOWN)
            {
                FireRocket(iEnt, iTarget)
                entity_set_float(iEnt, SENTRY_ROCKETTIME, flNow)
            }
        }
    }
    else
    {
        // Нет цели - сбрасываем
        entity_set_edict(iEnt, SENTRY_TARGET, 0)

        // ГОЛОВА сканирует через bone controller (база НЕ крутится!)
        new Float:flHeadYaw = entity_get_float(iEnt, SENTRY_HEADYAW)
        new Float:flScanDir = entity_get_float(iEnt, SENTRY_SCANDIR)

        flHeadYaw += SCAN_SPEED * flScanDir  // Скорость сканирования

        // Границы ±90° (180° всего)
        if (flHeadYaw > SCAN_ANGLE)
        {
            flHeadYaw = SCAN_ANGLE
            entity_set_float(iEnt, SENTRY_SCANDIR, -1.0)
        }
        else if (flHeadYaw < -SCAN_ANGLE)
        {
            flHeadYaw = -SCAN_ANGLE
            entity_set_float(iEnt, SENTRY_SCANDIR, 1.0)
        }

        entity_set_float(iEnt, SENTRY_HEADYAW, flHeadYaw)

        // Применяем bone controller
        // controller2 управляет YAW головы: 0-255, где 128 = центр
        // Диапазон модели примерно ±180°, но ограничиваем до ±90°
        new iYawCtrl = floatround(128.0 + (flHeadYaw / 180.0) * 127.0)
        if (iYawCtrl < 0) iYawCtrl = 0
        if (iYawCtrl > 255) iYawCtrl = 255
        entity_set_byte(iEnt, EV_BYTE_controller2, iYawCtrl)
        entity_set_byte(iEnt, EV_BYTE_controller1, 128)  // Pitch в центре

        // Анимация idle
        set_entity_anim(iEnt, ANIM_IDLE, 1.0)

        // Звук сканирования каждые 3 секунды
        new Float:flLastScan = entity_get_float(iEnt, SENTRY_SCANPAUSE)
        if (flNow - flLastScan >= 3.0)
        {
            emit_sound(iEnt, CHAN_ITEM, g_szSndScan, 0.5, ATTN_NORM, 0, PITCH_NORM)
            entity_set_float(iEnt, SENTRY_SCANPAUSE, flNow)
        }
    }

    entity_set_float(iEnt, EV_FL_nextthink, flNow + 0.05)
}

FinishBuilding(iEnt)
{
    // Проверяем, пришло ли время завершения
    new Float:flBuildEnd = entity_get_float(iEnt, SENTRY_BUILDEND)

    if (get_gametime() < flBuildEnd)
    {
        // Ещё строится - просто ждём
        entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.1)
        return
    }

    // СОХРАНЯЕМ углы и skin перед сменой модели
    new Float:flAngles[3]
    entity_get_vector(iEnt, EV_VEC_angles, flAngles)
    new iSkin = entity_get_int(iEnt, EV_INT_skin)

    // Меняем на рабочую модель
    entity_set_model(iEnt, g_szModelLevel1)

    // ВОССТАНАВЛИВАЕМ углы и skin
    entity_set_vector(iEnt, EV_VEC_angles, flAngles)
    entity_set_int(iEnt, EV_INT_skin, iSkin)

    // ВАЖНО: После entity_set_model нужно заново установить размеры и физику!
    new Float:flMins[3] = {-20.0, -20.0, 0.0}
    new Float:flMaxs[3] = {20.0, 20.0, 55.0}
    entity_set_size(iEnt, flMins, flMaxs)
    entity_set_int(iEnt, EV_INT_solid, SOLID_SLIDEBOX)
    entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_TOSS)  // TOSS лучше для статичных объектов

    // Рендер - полностью непрозрачная
    entity_set_int(iEnt, EV_INT_rendermode, 0)
    entity_set_int(iEnt, EV_INT_renderfx, 0)
    entity_set_float(iEnt, EV_FL_renderamt, 255.0)

    entity_set_int(iEnt, SENTRY_STATE, STATE_IDLE)

    // Инициализируем сканирование
    entity_set_float(iEnt, SENTRY_HEADYAW, 0.0)
    entity_set_float(iEnt, SENTRY_SCANPAUSE, 0.0)
    entity_set_float(iEnt, SENTRY_SCANDIR, 1.0)
    entity_set_byte(iEnt, EV_BYTE_controller1, 128)
    entity_set_byte(iEnt, EV_BYTE_controller2, 128)

    // Анимация idle
    set_entity_anim(iEnt, ANIM_IDLE, 1.0)

    // Звук
    emit_sound(iEnt, CHAN_BODY, g_szSndDeploy, 1.0, ATTN_NORM, 0, PITCH_NORM)

    new iOwner = entity_get_int(iEnt, SENTRY_OWNER)
    if (is_user_connected(iOwner))
    {
        client_print(iOwner, print_center, "Пушка уровня 1 готова!")
        g_bIsBuilding[iOwner] = false
    }

    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.1)
}

FinishUpgrade(iEnt)
{
    // Проверяем, пришло ли время завершения
    new Float:flBuildEnd = entity_get_float(iEnt, SENTRY_BUILDEND)

    if (get_gametime() < flBuildEnd)
    {
        // Ещё апгрейдится - просто ждём
        entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.1)
        return
    }

    // СОХРАНЯЕМ углы и skin перед сменой модели
    new Float:flAngles[3]
    entity_get_vector(iEnt, EV_VEC_angles, flAngles)
    new iLevel = entity_get_int(iEnt, SENTRY_LEVEL)
    new iSkin = entity_get_int(iEnt, EV_INT_skin)

    // Меняем на рабочую модель
    switch (iLevel)
    {
        case LEVEL_2: entity_set_model(iEnt, g_szModelLevel2)
        case LEVEL_3: entity_set_model(iEnt, g_szModelLevel3)
    }

    // ВОССТАНАВЛИВАЕМ углы и skin
    entity_set_vector(iEnt, EV_VEC_angles, flAngles)
    entity_set_int(iEnt, EV_INT_skin, iSkin)

    // ВАЖНО: После entity_set_model нужно заново установить размеры и физику!
    new Float:flMins[3] = {-20.0, -20.0, 0.0}
    new Float:flMaxs[3] = {20.0, 20.0, 55.0}
    entity_set_size(iEnt, flMins, flMaxs)
    entity_set_int(iEnt, EV_INT_solid, SOLID_SLIDEBOX)
    entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_TOSS)

    // Рендер - полностью непрозрачная
    entity_set_int(iEnt, EV_INT_rendermode, 0)
    entity_set_int(iEnt, EV_INT_renderfx, 0)
    entity_set_float(iEnt, EV_FL_renderamt, 255.0)

    entity_set_int(iEnt, SENTRY_STATE, STATE_IDLE)

    // Инициализируем сканирование
    entity_set_float(iEnt, SENTRY_HEADYAW, 0.0)
    entity_set_float(iEnt, SENTRY_SCANPAUSE, 0.0)
    entity_set_float(iEnt, SENTRY_SCANDIR, 1.0)
    entity_set_byte(iEnt, EV_BYTE_controller1, 128)
    entity_set_byte(iEnt, EV_BYTE_controller2, 128)

    // Анимация idle
    set_entity_anim(iEnt, ANIM_IDLE, 1.0)

    // Звук
    emit_sound(iEnt, CHAN_BODY, g_szSndDeploy, 1.0, ATTN_NORM, 0, PITCH_NORM)

    new iOwner = entity_get_int(iEnt, SENTRY_OWNER)
    if (is_user_connected(iOwner))
        client_print(iOwner, print_center, "Пушка улучшена до уровня %d!", iLevel)

    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.1)
}


FindTarget(iEnt, iTeam)
{
    new Float:flOrigin[3]
    entity_get_vector(iEnt, EV_VEC_origin, flOrigin)
    flOrigin[2] += 30.0  // Высота глаз пушки

    new Float:flRange = DETECT_RANGE
    new Float:flMinDist = flRange + 1.0
    new iBest = 0

    for (new i = 1; i <= g_iMaxPlayers; i++)
    {
        if (!is_user_alive(i))
            continue

        // Пропускаем союзников (та же команда)
        if (get_user_team(i) == iTeam)
            continue

        new Float:flTargetPos[3]
        pev(i, pev_origin, flTargetPos)
        flTargetPos[2] += 17.0  // Центр тела игрока

        new Float:flDist = get_distance_f(flOrigin, flTargetPos)
        if (flDist > flRange)
            continue

        // Проверка видимости - трассируем к игроку
        new tr = create_tr2()
        engfunc(EngFunc_TraceLine, flOrigin, flTargetPos, DONT_IGNORE_MONSTERS, iEnt, tr)

        new Float:flFrac
        get_tr2(tr, TR_flFraction, flFrac)
        new iHit = get_tr2(tr, TR_pHit)
        free_tr2(tr)

        // Видим если: луч дошёл полностью ИЛИ попали в этого игрока
        new bool:bVisible = (flFrac >= 1.0) || (iHit == i)

        if (!bVisible)
            continue

        if (flDist < flMinDist)
        {
            flMinDist = flDist
            iBest = i
        }
    }

    return iBest
}

// Поворот ГОЛОВЫ к цели через bone controller
TrackTarget(iEnt, iTarget)
{
    new Float:flOrigin[3], Float:flTargetPos[3]
    entity_get_vector(iEnt, EV_VEC_origin, flOrigin)
    pev(iTarget, pev_origin, flTargetPos)

    flOrigin[2] += 30.0  // Центр пушки
    flTargetPos[2] += 17.0  // Центр тела врага

    // Направление к цели
    new Float:flDir[3]
    flDir[0] = flTargetPos[0] - flOrigin[0]
    flDir[1] = flTargetPos[1] - flOrigin[1]
    flDir[2] = flTargetPos[2] - flOrigin[2]

    // Угол к цели в мировых координатах
    new Float:flTargetWorldYaw = floatatan2(flDir[1], flDir[0], degrees)

    // Базовый угол пушки + смещение модели = реальное направление "вперёд" модели
    new Float:flBaseAngle = entity_get_float(iEnt, SENTRY_BASEANGLE)
    new Float:flModelForward = flBaseAngle + MODEL_YAW_OFFSET

    // Угол головы относительно направления модели
    new Float:flTargetHeadYaw = flTargetWorldYaw - flModelForward

    // Нормализуем -180..+180
    while (flTargetHeadYaw > 180.0) flTargetHeadYaw -= 360.0
    while (flTargetHeadYaw < -180.0) flTargetHeadYaw += 360.0

    // Текущий угол головы
    new Float:flHeadYaw = entity_get_float(iEnt, SENTRY_HEADYAW)

    // Вычисляем кратчайший путь поворота
    new Float:flDiff = flTargetHeadYaw - flHeadYaw
    while (flDiff > 180.0) flDiff -= 360.0
    while (flDiff < -180.0) flDiff += 360.0

    // Плавный поворот головы к цели
    new Float:flHeadSpeed = TURN_SPEED

    if (floatabs(flDiff) <= flHeadSpeed)
        flHeadYaw = flTargetHeadYaw
    else if (flDiff > 0.0)
        flHeadYaw += flHeadSpeed
    else
        flHeadYaw -= flHeadSpeed

    // Нормализуем результат
    while (flHeadYaw > 180.0) flHeadYaw -= 360.0
    while (flHeadYaw < -180.0) flHeadYaw += 360.0

    entity_set_float(iEnt, SENTRY_HEADYAW, flHeadYaw)

    // Применяем YAW через bone controller
    // Диапазон: -180..+180 -> 0..255, где 128 = центр
    new iYawCtrl = floatround(128.0 + (flHeadYaw / 180.0) * 127.0)
    if (iYawCtrl < 0) iYawCtrl = 0
    if (iYawCtrl > 255) iYawCtrl = 255
    entity_set_byte(iEnt, EV_BYTE_controller2, iYawCtrl)

    // PITCH - наклон к цели
    new Float:flDistXY = floatsqroot(flDir[0]*flDir[0] + flDir[1]*flDir[1])
    new Float:flPitch = 0.0
    if (flDistXY > 10.0)
    {
        flPitch = -floatatan2(flDir[2], flDistXY, degrees)
        if (flPitch > 50.0) flPitch = 50.0
        if (flPitch < -50.0) flPitch = -50.0
    }

    new iPitchCtrl = floatround(128.0 + (flPitch / 50.0) * 64.0)
    if (iPitchCtrl < 0) iPitchCtrl = 0
    if (iPitchCtrl > 255) iPitchCtrl = 255
    entity_set_byte(iEnt, EV_BYTE_controller1, iPitchCtrl)
}

// Получить реальное направление дула (база + голова + смещение модели)
Float:GetMuzzleDirection(iEnt)
{
    new Float:flBaseAngle = entity_get_float(iEnt, SENTRY_BASEANGLE)
    new Float:flHeadYaw = entity_get_float(iEnt, SENTRY_HEADYAW)

    // Направление дула = угол базы + угол головы + смещение модели
    new Float:flMuzzleAngle = flBaseAngle + flHeadYaw + MODEL_YAW_OFFSET

    // Нормализуем
    while (flMuzzleAngle > 180.0) flMuzzleAngle -= 360.0
    while (flMuzzleAngle < -180.0) flMuzzleAngle += 360.0

    return flMuzzleAngle
}

// Выстрел - трассер из дула, точно по врагу
ShootTarget(iEnt, iTarget, iLevel)
{
    new Float:flOrigin[3], Float:flTargetPos[3]
    entity_get_vector(iEnt, EV_VEC_origin, flOrigin)
    pev(iTarget, pev_origin, flTargetPos)

    // Угол дула = угол базы + угол головы
    new Float:flMuzzleAngle = GetMuzzleDirection(iEnt)

    // Определяем позицию дула в зависимости от уровня
    new Float:flMuzzle[3]
    new iBarrel = entity_get_int(iEnt, SENTRY_BARREL)

    // Направление вперёд и вправо для расчёта позиции дула
    new Float:flForwardX = floatcos(flMuzzleAngle, degrees)
    new Float:flForwardY = floatsin(flMuzzleAngle, degrees)
    new Float:flRightX = floatcos(flMuzzleAngle - 90.0, degrees)
    new Float:flRightY = floatsin(flMuzzleAngle - 90.0, degrees)

    if (iLevel == LEVEL_1)
    {
        // Level 1 - один ствол по центру
        flMuzzle[0] = flOrigin[0] + flForwardX * 25.0
        flMuzzle[1] = flOrigin[1] + flForwardY * 25.0
        flMuzzle[2] = flOrigin[2] + 28.0
    }
    else
    {
        // Level 2 и 3 - два ствола по бокам, чередуем
        new Float:flSideOffset = (iBarrel == 0) ? 8.0 : -8.0

        flMuzzle[0] = flOrigin[0] + flForwardX * 30.0 + flRightX * flSideOffset
        flMuzzle[1] = flOrigin[1] + flForwardY * 30.0 + flRightY * flSideOffset
        flMuzzle[2] = flOrigin[2] + 32.0

        // Чередуем стволы
        entity_set_int(iEnt, SENTRY_BARREL, (iBarrel + 1) % 2)
    }

    // Целимся ТОЧНО в центр тела врага (без разброса!)
    flTargetPos[2] += 15.0  // Центр тела

    // TraceLine от дула к цели
    new tr = create_tr2()
    engfunc(EngFunc_TraceLine, flMuzzle, flTargetPos, DONT_IGNORE_MONSTERS, iEnt, tr)

    new Float:flEndPos[3]
    get_tr2(tr, TR_vecEndPos, flEndPos)
    new iHit = get_tr2(tr, TR_pHit)
    free_tr2(tr)

    // Жёлтый луч (TE_BEAMPOINTS) - из дула к точке попадания
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMPOINTS)
    write_coord(floatround(flMuzzle[0]))
    write_coord(floatround(flMuzzle[1]))
    write_coord(floatround(flMuzzle[2]))
    write_coord(floatround(flEndPos[0]))
    write_coord(floatround(flEndPos[1]))
    write_coord(floatround(flEndPos[2]))
    write_short(g_iSprLaser)  // laserbeam.spr
    write_byte(0)   // start frame
    write_byte(0)   // framerate
    write_byte(1)   // life
    write_byte(3)   // width
    write_byte(0)   // noise
    write_byte(255) // R
    write_byte(255) // G
    write_byte(0)   // B (жёлтый)
    write_byte(200) // brightness
    write_byte(0)   // scroll
    message_end()

    // Анимация стрельбы
    if (iLevel == LEVEL_1)
    {
        set_entity_anim(iEnt, ANIM_FIRE, 1.0)
    }
    else
    {
        // Для level 2/3 чередуем fire и fire_alt
        if (iBarrel == 0)
            set_entity_anim(iEnt, ANIM_FIRE, 1.0)
        else
            set_entity_anim(iEnt, ANIM_FIRE_ALT, 1.0)
    }

    // Урон если попали в игрока
    if (iHit > 0 && iHit <= 32 && is_user_alive(iHit))
    {
        new Float:flDamage = 10.0 + float(iLevel) * 2.0
        new iOwner = entity_get_int(iEnt, SENTRY_OWNER)

        if (get_user_health(iHit) - floatround(flDamage) <= 0)
        {
            entity_set_edict(iEnt, SENTRY_TARGET, 0)
            KillTarget(iHit, iOwner)
        }
        else
        {
            set_user_health(iHit, get_user_health(iHit) - floatround(flDamage))
        }
    }

    // Звук
    emit_sound(iEnt, CHAN_WEAPON, g_szSndFire, 0.7, ATTN_NORM, 0, PITCH_NORM + random_num(-5, 5))
}

KillTarget(iTarget, iOwner)
{
    // Фраг владельцу
    if (is_user_connected(iOwner))
    {
        set_user_frags(iOwner, get_user_frags(iOwner) + 1)
        cs_set_user_money(iOwner, min(cs_get_user_money(iOwner) + 300, 16000))
    }

    // Убиваем
    user_kill(iTarget)

    // DeathMsg
    message_begin(MSG_ALL, g_iMsgDeathMsg)
    write_byte(iOwner)
    write_byte(iTarget)
    write_byte(0)
    write_string("sentry gun")
    message_end()
}

// ============== РАКЕТЫ ==============
FireRocket(iEnt, iTarget)
{
    new Float:flSentryOrigin[3], Float:flTargetOrigin[3]
    entity_get_vector(iEnt, EV_VEC_origin, flSentryOrigin)
    pev(iTarget, pev_origin, flTargetOrigin)

    // Угол дула
    new Float:flMuzzleAngle = GetMuzzleDirection(iEnt)

    // Направление
    new Float:flForwardX = floatcos(flMuzzleAngle, degrees)
    new Float:flForwardY = floatsin(flMuzzleAngle, degrees)

    // Стартовая позиция ракеты - сверху пушки (из ракетных блоков)
    new Float:flRocketStart[3]
    flRocketStart[0] = flSentryOrigin[0] + flForwardX * 10.0
    flRocketStart[1] = flSentryOrigin[1] + flForwardY * 10.0
    flRocketStart[2] = flSentryOrigin[2] + 50.0  // Ракетные блоки сверху

    // Анимация стрельбы ракетами
    set_entity_anim(iEnt, ANIM_FIRE_ROCKET, 1.0)

    // Создаём ракету
    new iRocket = create_entity("info_target")
    if (!iRocket)
        return

    entity_set_string(iRocket, EV_SZ_classname, ROCKET_CLASSNAME)
    entity_set_model(iRocket, g_szModelRocket)
    entity_set_origin(iRocket, flRocketStart)

    // Направление к цели
    new Float:flDir[3], Float:flVelocity[3]
    xs_vec_sub(flTargetOrigin, flRocketStart, flDir)
    xs_vec_normalize(flDir, flDir)
    xs_vec_mul_scalar(flDir, 800.0, flVelocity)

    entity_set_vector(iRocket, EV_VEC_velocity, flVelocity)

    // Углы ракеты
    new Float:flRocketAngles[3]
    vector_to_angle(flDir, flRocketAngles)
    entity_set_vector(iRocket, EV_VEC_angles, flRocketAngles)

    // Размер - маленький чтобы не застревала
    new Float:flMins[3] = {-2.0, -2.0, -2.0}
    new Float:flMaxs[3] = {2.0, 2.0, 2.0}
    entity_set_size(iRocket, flMins, flMaxs)

    entity_set_int(iRocket, EV_INT_solid, SOLID_BBOX)
    entity_set_int(iRocket, EV_INT_movetype, MOVETYPE_FLY)
    entity_set_int(iRocket, EV_INT_iuser1, entity_get_int(iEnt, SENTRY_OWNER))
    entity_set_int(iRocket, EV_INT_iuser2, entity_get_int(iEnt, SENTRY_TEAM))
    entity_set_edict(iRocket, EV_ENT_euser1, iTarget)
    entity_set_edict(iRocket, EV_ENT_owner, iEnt)  // Владелец = пушка (не сталкивается)

    // Анимация
    set_entity_anim(iRocket, ANIM_ROCKET_IDLE, 1.0)

    // Сохраняем время создания для таймаута
    entity_set_float(iRocket, EV_FL_fuser1, get_gametime())

    // Эффект следа
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_BEAMFOLLOW)
    write_short(iRocket)
    write_short(g_iSprTrail)
    write_byte(10)
    write_byte(5)
    write_byte(255)
    write_byte(255)
    write_byte(255)
    write_byte(200)
    message_end()

    // Звук
    emit_sound(iRocket, CHAN_WEAPON, g_szSndRocket, 1.0, ATTN_NORM, 0, PITCH_NORM)

    entity_set_float(iRocket, EV_FL_nextthink, get_gametime() + 0.1)
}

public fw_RocketThink(iRocket)
{
    if (!is_valid_ent(iRocket))
        return

    // Проверяем время жизни ракеты (макс 5 секунд)
    new Float:flSpawnTime = entity_get_float(iRocket, EV_FL_fuser1)
    if (get_gametime() - flSpawnTime > 5.0)
    {
        // Останавливаем звук и удаляем
        emit_sound(iRocket, CHAN_WEAPON, g_szSndRocket, 0.0, ATTN_NORM, SND_STOP, PITCH_NORM)
        remove_entity(iRocket)
        return
    }

    // Самонаведение
    new iTarget = entity_get_edict(iRocket, EV_ENT_euser1)

    if (is_user_alive(iTarget))
    {
        new Float:flOrigin[3], Float:flTargetOrigin[3]
        entity_get_vector(iRocket, EV_VEC_origin, flOrigin)
        pev(iTarget, pev_origin, flTargetOrigin)

        new Float:flDir[3], Float:flVelocity[3]
        xs_vec_sub(flTargetOrigin, flOrigin, flDir)
        xs_vec_normalize(flDir, flDir)
        xs_vec_mul_scalar(flDir, 800.0, flVelocity)

        entity_set_vector(iRocket, EV_VEC_velocity, flVelocity)

        new Float:flAngles[3]
        vector_to_angle(flDir, flAngles)
        entity_set_vector(iRocket, EV_VEC_angles, flAngles)
    }

    entity_set_float(iRocket, EV_FL_nextthink, get_gametime() + 0.1)
}

public fw_RocketTouch(iRocket, iTouched)
{
    if (!is_valid_ent(iRocket))
        return

    // Игнорируем столкновение с пушкой-владельцем
    new iSentryOwner = entity_get_edict(iRocket, EV_ENT_owner)
    if (iTouched == iSentryOwner)
        return

    // Игнорируем столкновение с другими пушками
    if (is_valid_ent(iTouched))
    {
        new szClass[32]
        entity_get_string(iTouched, EV_SZ_classname, szClass, charsmax(szClass))
        if (equal(szClass, SENTRY_CLASSNAME))
            return
    }

    // Останавливаем звук ракеты
    emit_sound(iRocket, CHAN_WEAPON, g_szSndRocket, 0.0, ATTN_NORM, SND_STOP, PITCH_NORM)

    new Float:flOrigin[3]
    entity_get_vector(iRocket, EV_VEC_origin, flOrigin)

    new iOwner = entity_get_int(iRocket, EV_INT_iuser1)
    new iTeam = entity_get_int(iRocket, EV_INT_iuser2)

    // Взрыв
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_EXPLOSION)
    write_coord(floatround(flOrigin[0]))
    write_coord(floatround(flOrigin[1]))
    write_coord(floatround(flOrigin[2]))
    write_short(g_iSprExplode)
    write_byte(25)
    write_byte(15)
    write_byte(0)
    message_end()

    // Урон в радиусе
    new Float:flTargetOrigin[3], Float:flDist, Float:flDamage

    for (new i = 1; i <= g_iMaxPlayers; i++)
    {
        if (!is_user_alive(i))
            continue

        if (_:cs_get_user_team(i) == iTeam)
            continue

        pev(i, pev_origin, flTargetOrigin)
        flDist = vector_distance(flOrigin, flTargetOrigin)

        if (flDist > ROCKET_RADIUS)
            continue

        flDamage = DMG_ROCKET * (1.0 - (flDist / ROCKET_RADIUS))

        if (get_user_health(i) - floatround(flDamage) <= 0)
        {
            KillTarget(i, iOwner)
        }
        else
        {
            set_user_health(i, get_user_health(i) - floatround(flDamage))
        }
    }

    remove_entity(iRocket)
}

// ============== БЛОКИРОВКА ПРОХОДА ==============
new Float:g_flLastUpgradeTime[33]  // Время последнего апгрейда

public fw_SentryTouch(iEnt, id)
{
    if (!is_valid_ent(iEnt) || !is_user_alive(id))
        return

    new szClass[32]
    entity_get_string(iEnt, EV_SZ_classname, szClass, charsmax(szClass))

    if (!equal(szClass, SENTRY_CLASSNAME))
        return

    new CsTeams:iSentryTeam = CsTeams:entity_get_int(iEnt, SENTRY_TEAM)

    // Апгрейд при касании - союзники И владелец
    if (cs_get_user_team(id) == iSentryTeam)
    {
        new Float:flTime = get_gametime()
        if (flTime - g_flLastUpgradeTime[id] > 0.5)
        {
            g_flLastUpgradeTime[id] = flTime
            UpgradeSentry(id, iEnt)
        }
    }

    // SOLID_SLIDEBOX блокирует всех автоматически
}

// ============== УРОН ПУШКЕ ==============
public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:flDir[3], tr, iDamageBits)
{
    if (!is_valid_ent(iEnt))
        return HAM_IGNORED

    new szClass[32]
    entity_get_string(iEnt, EV_SZ_classname, szClass, charsmax(szClass))

    if (!equal(szClass, SENTRY_CLASSNAME))
        return HAM_IGNORED

    new iOwner = entity_get_int(iEnt, SENTRY_OWNER)
    new iTeam = entity_get_int(iEnt, SENTRY_TEAM)

    // Владелец может ломать свою пушку
    if (iAttacker == iOwner)
        return HAM_IGNORED

    // Тиммейты НЕ могут ломать чужие пушки (кроме владельца)
    if (is_user_connected(iAttacker) && _:cs_get_user_team(iAttacker) == iTeam)
        return HAM_SUPERCEDE

    return HAM_IGNORED
}

public fw_TakeDamage(iEnt, iInflictor, iAttacker, Float:flDamage, iDamageBits)
{
    if (!is_valid_ent(iEnt))
        return HAM_IGNORED

    new szClass[32]
    entity_get_string(iEnt, EV_SZ_classname, szClass, charsmax(szClass))

    if (!equal(szClass, SENTRY_CLASSNAME))
        return HAM_IGNORED

    new iOwner = entity_get_int(iEnt, SENTRY_OWNER)
    new iTeam = entity_get_int(iEnt, SENTRY_TEAM)

    // Тиммейты НЕ могут ломать чужие пушки (кроме владельца)
    if (iAttacker != iOwner && is_user_connected(iAttacker) && _:cs_get_user_team(iAttacker) == iTeam)
    {
        return HAM_SUPERCEDE
    }

    new Float:flHealth = entity_get_float(iEnt, EV_FL_health)

    if (flHealth - flDamage <= 0.0)
    {
        DestroySentry(iEnt, iAttacker)
        return HAM_SUPERCEDE
    }

    entity_set_float(iEnt, EV_FL_health, flHealth - flDamage)

    // Показываем урон владельцу
    if (is_user_connected(iOwner))
    {
        new Float:flNewHealth = flHealth - flDamage
        new Float:flMaxHealth = g_flHealth[entity_get_int(iEnt, SENTRY_LEVEL)]
        client_print(iOwner, print_center, "Пушка: %.0f/%.0f HP", flNewHealth, flMaxHealth)
    }

    // Блокируем стандартный урон func_breakable
    return HAM_SUPERCEDE
}

DestroySentry(iEnt, iAttacker)
{
    new Float:flOrigin[3]
    entity_get_vector(iEnt, EV_VEC_origin, flOrigin)

    new iOwner = entity_get_int(iEnt, SENTRY_OWNER)
    new iLevel = entity_get_int(iEnt, SENTRY_LEVEL)
    new iSkin = entity_get_int(iEnt, EV_INT_skin)  // Получаем skin для обломков

    // Убираем из списка
    if (is_user_connected(iOwner))
    {
        g_bIsBuilding[iOwner] = false

        for (new i = 0; i < g_iPlayerSentries[iOwner]; i++)
        {
            if (g_iPlayerSentryEnts[iOwner][i] == iEnt)
            {
                for (new j = i; j < g_iPlayerSentries[iOwner] - 1; j++)
                {
                    g_iPlayerSentryEnts[iOwner][j] = g_iPlayerSentryEnts[iOwner][j + 1]
                }
                g_iPlayerSentries[iOwner]--
                break
            }
        }

        client_print(iOwner, print_center, "Пушка уровня %d уничтожена!", iLevel)
    }

    // Награда
    if (is_user_connected(iAttacker) && iAttacker != iOwner)
    {
        new iReward = iLevel * 150
        cs_set_user_money(iAttacker, min(cs_get_user_money(iAttacker) + iReward, 16000))
        client_print(iAttacker, print_center, "Пушка уничтожена! +$%d", iReward)
    }

    // Взрыв
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_EXPLOSION)
    write_coord(floatround(flOrigin[0]))
    write_coord(floatround(flOrigin[1]))
    write_coord(floatround(flOrigin[2]) + 20)
    write_short(g_iSprExplode)
    write_byte(40)
    write_byte(15)
    write_byte(0)
    message_end()

    // Дым
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_SMOKE)
    write_coord(floatround(flOrigin[0]))
    write_coord(floatround(flOrigin[1]))
    write_coord(floatround(flOrigin[2]) + 30)
    write_short(g_iSprSmoke)
    write_byte(30)  // размер
    write_byte(10)  // скорость
    message_end()

    // Искры
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_SPARKS)
    write_coord(floatround(flOrigin[0]))
    write_coord(floatround(flOrigin[1]))
    write_coord(floatround(flOrigin[2]) + 10)
    message_end()

    // Обломки с правильным цветом команды
    CreateGibs(flOrigin, iLevel, iSkin)

    // Звук
    emit_sound(iEnt, CHAN_BODY, g_szSndExplode, 1.0, ATTN_NORM, 0, PITCH_NORM)

    remove_entity(iEnt)
}

CreateGibs(Float:flOrigin[3], iLevel, iSkin)
{
    // Больше обломков для высоких уровней
    new iCount = 3 + iLevel

    for (new i = 0; i < iCount; i++)
    {
        new iGib = create_entity("info_target")
        if (!iGib)
            continue

        entity_set_string(iGib, EV_SZ_classname, "tf2_gib")
        entity_set_model(iGib, g_szModelGibs)

        // Устанавливаем skin: 0 = красный (T), 1 = синий (CT)
        entity_set_int(iGib, EV_INT_skin, iSkin)

        new Float:flPos[3]
        flPos[0] = flOrigin[0] + random_float(-20.0, 20.0)
        flPos[1] = flOrigin[1] + random_float(-20.0, 20.0)
        flPos[2] = flOrigin[2] + random_float(10.0, 40.0)
        entity_set_origin(iGib, flPos)

        // Случайные углы для вращения
        new Float:flAngles[3]
        flAngles[0] = random_float(0.0, 360.0)
        flAngles[1] = random_float(0.0, 360.0)
        flAngles[2] = random_float(0.0, 360.0)
        entity_set_vector(iGib, EV_VEC_angles, flAngles)

        // Скорость разлёта
        new Float:flVel[3]
        flVel[0] = random_float(-250.0, 250.0)
        flVel[1] = random_float(-250.0, 250.0)
        flVel[2] = random_float(150.0, 400.0)
        entity_set_vector(iGib, EV_VEC_velocity, flVel)

        // Вращение в полёте
        new Float:flAvel[3]
        flAvel[0] = random_float(-300.0, 300.0)
        flAvel[1] = random_float(-300.0, 300.0)
        flAvel[2] = random_float(-300.0, 300.0)
        entity_set_vector(iGib, EV_VEC_avelocity, flAvel)

        entity_set_int(iGib, EV_INT_solid, SOLID_NOT)
        entity_set_int(iGib, EV_INT_movetype, MOVETYPE_TOSS)
        entity_set_float(iGib, EV_FL_gravity, 0.8)

        set_entity_anim(iGib, ANIM_GIBS_IDLE, 1.0)

        set_task(4.0, "task_RemoveGib", iGib)
    }
}

public task_RemoveGib(iGib)
{
    if (is_valid_ent(iGib))
        remove_entity(iGib)
}

// ============== СОБЫТИЯ ==============
public fw_PlayerSpawn_Post(id)
{
    if (!is_user_alive(id))
        return

    g_bIsBuilding[id] = false
    RemoveBlueprint(id)
}

public event_DeathMsg()
{
    new iVictim = read_data(2)

    g_bIsBuilding[iVictim] = false
    RemoveBlueprint(iVictim)

    // Удаляем пушки
    for (new i = 0; i < g_iPlayerSentries[iVictim]; i++)
    {
        new iEnt = g_iPlayerSentryEnts[iVictim][i]
        if (is_valid_ent(iEnt))
        {
            new Float:flOrigin[3]
            entity_get_vector(iEnt, EV_VEC_origin, flOrigin)
            new iLevel = entity_get_int(iEnt, SENTRY_LEVEL)
            new iSkin = entity_get_int(iEnt, EV_INT_skin)  // Цвет команды

            message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
            write_byte(TE_EXPLOSION)
            write_coord(floatround(flOrigin[0]))
            write_coord(floatround(flOrigin[1]))
            write_coord(floatround(flOrigin[2]) + 20)
            write_short(g_iSprExplode)
            write_byte(30)
            write_byte(15)
            write_byte(0)
            message_end()

            CreateGibs(flOrigin, iLevel, iSkin)
            emit_sound(iEnt, CHAN_BODY, g_szSndExplode, 1.0, ATTN_NORM, 0, PITCH_NORM)
            remove_entity(iEnt)
        }
    }

    g_iPlayerSentries[iVictim] = 0
    arrayset(g_iPlayerSentryEnts[iVictim], 0, MAX_PLAYER_SENTRIES)
}

// ============== УТИЛИТЫ ==============
stock set_entity_anim(iEnt, iSequence, Float:flFrameRate)
{
    entity_set_int(iEnt, EV_INT_sequence, iSequence)
    entity_set_float(iEnt, EV_FL_animtime, get_gametime())
    entity_set_float(iEnt, EV_FL_framerate, flFrameRate)
    entity_set_float(iEnt, EV_FL_frame, 0.0)
}

stock fix_sentry_angles(iEnt)
{
    new Float:flAngles[3]
    entity_get_vector(iEnt, EV_VEC_angles, flAngles)
    flAngles[0] = 0.0   // pitch = 0
    flAngles[2] = 0.0   // roll = 0
    entity_set_vector(iEnt, EV_VEC_angles, flAngles)
}
