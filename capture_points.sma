#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <engine>
#include <level_system>
#include <stats_system>

#define MAX_POINTS 16
#define MAX_SPAWN_POSITIONS 64
#define POINT_MODEL_RADIUS 40.0

#if !defined MAX_CLIENTS
    #define MAX_CLIENTS 32
#endif

new const MODELS[][] = {
    "models/player/vip/vip.mdl",
    "models/player/terror/terror.mdl",
    "models/player/urban/urban.mdl"
}

new pCvarPointsCount, pCvarCapTime, pCvarReward
new pCvarMinDist, pCvarBaseDist, pCvarCapRadius
new pCvarSpawnOnPoints, pCvarShowHud, pCvarSound, pCvarRecapBonus
new pCvarSpawnMode

new g_Ent[MAX_POINTS]
new Float:g_PosX[MAX_POINTS], Float:g_PosY[MAX_POINTS], Float:g_PosZ[MAX_POINTS]
new g_State[MAX_POINTS]
new g_Num

new Float:g_CapEnd[33]
new bool:g_Capturing[33]
new g_CapEnt[33]

new Float:g_SafeSpawns[MAX_POINTS][MAX_SPAWN_POSITIONS][3]
new g_SafeSpawnCount[MAX_POINTS]
new g_SpawnCountOnPoint[MAX_POINTS]

new Float:g_DeathPos[33][3]
new bool:g_HasDeathPos[33]
new g_LastCapturedPoint[33]

new Float:g_MinX, Float:g_MaxX
new Float:g_MinY, Float:g_MaxY
new Float:g_MinZ, Float:g_MaxZ

new Float:g_TBaseX, Float:g_TBaseY
new Float:g_CTBaseX, Float:g_CTBaseY

new g_MsgSay

public plugin_precache()
{
    for(new i = 0; i < sizeof(MODELS); i++)
        precache_model(MODELS[i])
    precache_sound("buttons/bell1.wav")
}

public plugin_init()
{
    register_plugin("Capture Points", "23", "AI")

    pCvarPointsCount = register_cvar("cp_points_count", "7")
    pCvarCapTime = register_cvar("cp_capture_time", "8")
    pCvarReward = register_cvar("cp_capture_reward", "500")
    pCvarMinDist = register_cvar("cp_min_distance", "400")
    pCvarBaseDist = register_cvar("cp_base_distance", "200")
    pCvarCapRadius = register_cvar("cp_capture_radius", "120")
    pCvarSpawnOnPoints = register_cvar("cp_spawn_on_points", "1")
    pCvarShowHud = register_cvar("cp_show_hud", "1")
    pCvarSound = register_cvar("cp_capture_sound", "1")
    pCvarRecapBonus = register_cvar("cp_recapture_bonus", "700")
    pCvarSpawnMode = register_cvar("cp_spawn_mode", "2")

    RegisterHookChain(RG_CBasePlayer_Spawn, "OnSpawn", true)
    RegisterHookChain(RG_CBasePlayer_Killed, "OnDeath", false)
    RegisterHookChain(RG_CSGameRules_RestartRound, "OnRound", false)

    g_MsgSay = get_user_msgid("SayText")

    new cfgDir[128]
    get_localinfo("amxx_configsdir", cfgDir, charsmax(cfgDir))
    server_cmd("exec %s/capture_points.cfg", cfgDir)
    server_exec()

    set_task(3.0, "InitPoints")
}

public OnDeath(victim, attacker)
{
    if(!is_user_connected(victim))
        return
    get_entvar(victim, var_origin, g_DeathPos[victim])
    g_HasDeathPos[victim] = true
}

public InitPoints()
{
    server_print("[CP] === Capture Points v23 ===")
    server_print("[CP] Spawn mode: %d", get_pcvar_num(pCvarSpawnMode))
    FindMapBounds()
    CreateRandomPoints()
    if(g_Num > 0)
    {
        server_print("[CP] Points: %d", g_Num)
        PrecacheSafeSpawnPositions()
        set_task(2.0, "Announce")
    }
}

PrecacheSafeSpawnPositions()
{
    for(new pt = 0; pt < g_Num; pt++)
    {
        g_SafeSpawnCount[pt] = 0
        for(new Float:radius = 100.0; radius <= 350.0 && g_SafeSpawnCount[pt] < MAX_SPAWN_POSITIONS; radius += 40.0)
        {
            for(new Float:angle = 0.0; angle < 360.0 && g_SafeSpawnCount[pt] < MAX_SPAWN_POSITIONS; angle += 30.0)
            {
                new Float:rad = angle * 3.14159 / 180.0
                new Float:testX = g_PosX[pt] + floatcos(rad) * radius
                new Float:testY = g_PosY[pt] + floatsin(rad) * radius
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
                if(frac >= 1.0) continue
                new Float:hitPos[3]
                get_tr2(0, TR_vecEndPos, hitPos)
                new Float:spawnPos[3]
                spawnPos[0] = hitPos[0]
                spawnPos[1] = hitPos[1]
                spawnPos[2] = hitPos[2] + 36.0
                if(IsPositionSafeForSpawn(spawnPos, pt))
                {
                    g_SafeSpawns[pt][g_SafeSpawnCount[pt]][0] = spawnPos[0]
                    g_SafeSpawns[pt][g_SafeSpawnCount[pt]][1] = spawnPos[1]
                    g_SafeSpawns[pt][g_SafeSpawnCount[pt]][2] = spawnPos[2]
                    g_SafeSpawnCount[pt]++
                }
            }
        }
        server_print("[CP] Point #%d: %d positions", pt+1, g_SafeSpawnCount[pt])
    }
}

bool:IsPositionSafeForSpawn(Float:pos[3], pt)
{
    engfunc(EngFunc_TraceHull, pos, pos, IGNORE_MONSTERS, HULL_HUMAN, 0)
    if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid))
        return false
    new Float:dx = pos[0] - g_PosX[pt]
    new Float:dy = pos[1] - g_PosY[pt]
    if(floatsqroot(dx*dx + dy*dy) < 70.0)
        return false
    return true
}

FindMapBounds()
{
    new Float:pos[3], ent = -1
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

    g_MinX -= (g_MaxX - g_MinX) * 0.1
    g_MaxX += (g_MaxX - g_MinX) * 0.1
    g_MinY -= (g_MaxY - g_MinY) * 0.1
    g_MaxY += (g_MaxY - g_MinY) * 0.1
}

CreateRandomPoints()
{
    new maxPoints = get_pcvar_num(pCvarPointsCount)
    new Float:minDist = get_pcvar_float(pCvarMinDist)
    new Float:baseDist = get_pcvar_float(pCvarBaseDist)
    new attempts = 0

    while(g_Num < maxPoints && attempts < 500)
    {
        attempts++
        new Float:testX = random_float(g_MinX, g_MaxX)
        new Float:testY = random_float(g_MinY, g_MaxY)
        new Float:start[3], Float:end[3]
        start[0] = testX
        start[1] = testY
        start[2] = g_MaxZ + 100.0
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
        if(get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid)) continue

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
    }
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
    show_dhudmessage(0, "=== CAPTURE POINTS ===^nPoints: %d | Reward: $%d", g_Num, reward)
    SayAll("^4[CP]^1 Capture a point - team gets^3 $%d", reward)
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

    if(g_State[pt] == my) return

    new Float:now = get_gametime()
    new capTime = get_pcvar_num(pCvarCapTime)

    if(g_Capturing[id] && g_CapEnt[id] == ent)
    {
        if(g_CapEnd[id] <= now)
        {
            new oldState = g_State[pt]
            g_State[pt] = my
            StopCapture(id)
            g_LastCapturedPoint[id] = pt
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

            new bool:bCanReward = bool:lvl_can_reward()
            if(!bCanReward)
                lvl_show_low_players(id)

            for(new i = 0; i < n; i++)
            {
                new pid = pls[i]
                new TeamName:ptm = get_member(pid, m_iTeam)
                if(ptm == tm && bCanReward)
                    lvl_add_money(pid, reward)
            }

            new name[32]
            get_user_name(id, name, charsmax(name))
            new enemy = (my == 2) ? 1 : 2

            if(get_pcvar_num(pCvarSound))
            {
                for(new p = 1; p <= MAX_CLIENTS; p++)
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
                    lvl_add_money(id, get_pcvar_num(pCvarRecapBonus))
                    stats_add_point(id)
                }
            }
            else
            {
                if(bCanReward)
                {
                    lvl_give_xp(id, lvl_get_xp_point_capture())
                    stats_add_point(id)
                }
            }

            SayAll("^4[CP]^3 %s^1 captured point^4 #%d", name, pt+1)
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

    if(get_distance_f(ppos, epos) > get_pcvar_float(pCvarCapRadius))
    {
        StopCapture(id)
        return
    }

    if(!get_pcvar_num(pCvarShowHud)) return

    new capTime = get_pcvar_num(pCvarCapTime)
    if(capTime <= 0) capTime = 1

    new Float:left = g_CapEnd[id] - get_gametime()
    new pct = 100 - floatround(left * 100.0 / float(capTime))
    if(pct < 0) pct = 0
    if(pct > 100) pct = 100

    new r, g, b
    if(pct < 33) { r = 255; g = 50; b = 50; }
    else if(pct < 66) { r = 255; g = 200; b = 0; }
    else { r = 50; g = 255; b = 50; }

    set_hudmessage(r, g, b, -1.0, 0.65, 0, 0.0, 0.4, 0.0, 0.0, 2)
    show_hudmessage(id, ">>> CAPTURING #%d <<< %d%%", FindPointByEnt(ent)+1, pct)
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

public OnSpawn(id)
{
    StopCapture(id)

    if(!get_pcvar_num(pCvarSpawnOnPoints)) return
    if(!is_user_alive(id) || g_Num == 0) return

    new TeamName:tm = get_member(id, m_iTeam)
    if(tm != TEAM_TERRORIST && tm != TEAM_CT) return

    new spawnMode = get_pcvar_num(pCvarSpawnMode)
    if(spawnMode == 2)
        SpawnMode_Smart(id, tm)
}

SpawnMode_Smart(id, TeamName:tm)
{
    new my = (tm == TEAM_CT) ? 2 : 1
    new name[32]
    get_user_name(id, name, charsmax(name))

    server_print("[CP] SpawnMode_Smart: %s (team %d, my=%d)", name, _:tm, my)

    new teamPoints[MAX_POINTS], teamPointCount = 0
    for(new i = 0; i < g_Num; i++)
    {
        if(g_State[i] == my && g_SafeSpawnCount[i] > 0)
        {
            teamPoints[teamPointCount++] = i
            server_print("[CP]   - Point #%d owned by team (state=%d)", i+1, g_State[i])
        }
    }

    server_print("[CP]   Team points count: %d", teamPointCount)

    new Float:spawnPos[3]

    new lastCap = g_LastCapturedPoint[id]
    server_print("[CP]   LastCapturedPoint: %d", lastCap)

    if(lastCap >= 0 && lastCap < g_Num && g_State[lastCap] == my)
    {
        server_print("[CP]   Trying last captured point #%d", lastCap+1)
        if(FindFreeSpawnPosition(id, lastCap, spawnPos))
        {
            set_entvar(id, var_origin, spawnPos)
            g_SpawnCountOnPoint[lastCap]++
            server_print("[CP]   SUCCESS: Spawned at last captured point #%d", lastCap+1)
            return
        }
        server_print("[CP]   FAILED: No free position at last captured point")
    }

    if(teamPointCount > 0)
    {
        new pt = teamPoints[random(teamPointCount)]
        server_print("[CP]   Trying random team point #%d", pt+1)
        if(FindFreeSpawnPosition(id, pt, spawnPos))
        {
            set_entvar(id, var_origin, spawnPos)
            g_SpawnCountOnPoint[pt]++
            server_print("[CP]   SUCCESS: Spawned at point #%d", pt+1)
        }
        else
        {
            server_print("[CP]   FAILED: No free position, spawning at base")
        }
    }
    else
    {
        server_print("[CP]   No team points, spawning at base")
    }
}

bool:FindFreeSpawnPosition(id, pt, Float:outPos[3])
{
    if(g_SafeSpawnCount[pt] == 0)
        return false

    new order[MAX_SPAWN_POSITIONS]
    new orderCount = g_SafeSpawnCount[pt]

    for(new i = 0; i < orderCount; i++)
        order[i] = i

    for(new i = orderCount - 1; i > 0; i--)
    {
        new j = random(i + 1)
        new temp = order[i]
        order[i] = order[j]
        order[j] = temp
    }

    for(new i = 0; i < orderCount; i++)
    {
        new idx = order[i]
        new Float:pos[3]
        pos[0] = g_SafeSpawns[pt][idx][0]
        pos[1] = g_SafeSpawns[pt][idx][1]
        pos[2] = g_SafeSpawns[pt][idx][2]

        engfunc(EngFunc_TraceHull, pos, pos, DONT_IGNORE_MONSTERS, HULL_HUMAN, id)
        if(!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid))
        {
            outPos[0] = pos[0]
            outPos[1] = pos[1]
            outPos[2] = pos[2]
            return true
        }
    }

    return false
}

public OnRound()
{
    for(new i = 1; i <= MAX_CLIENTS; i++)
    {
        g_Capturing[i] = false
        g_CapEnt[i] = 0
        g_HasDeathPos[i] = false
        remove_task(i)
    }

    for(new i = 0; i < g_Num; i++)
        g_SpawnCountOnPoint[i] = 0
}

public client_disconnected(id)
{
    StopCapture(id)
    g_HasDeathPos[id] = false
    g_LastCapturedPoint[id] = -1
    remove_task(id)
}

public client_putinserver(id)
{
    g_HasDeathPos[id] = false
    g_LastCapturedPoint[id] = -1
}
