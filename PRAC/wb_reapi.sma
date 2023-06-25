#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <xs>


#pragma semicolon 1


#define X 0
#define Y 1
#define Z 2

new g_sprLine;

new g_cvarLife;
new g_cvarSize;
new g_cvarGlow;
new g_cvarR;
new g_cvarG;
new g_cvarB;

new g_cvarHitLife;
new g_cvarHitSize;
new g_cvarHitGlow;
new g_cvarHitR;
new g_cvarHitG;
new g_cvarHitB;

new g_cvarTraceLife;
new g_cvarTraceSize;
new g_cvarTraceGlow;
new g_cvarTraceR;
new g_cvarTraceG;
new g_cvarTraceB;


new Float:g_flTime[MAX_PLAYERS+1];
new Float:g_flTimeBreakable[MAX_PLAYERS+1];
new g_iWb[MAX_PLAYERS+1];
new g_bShot[MAX_PLAYERS+1];

new HookChain:g_hookTraceAttack;
new HookChain:g_hookIsPenetrableEntity;

new g_cvarEnabled;
new g_cvarBreakable;



stock _draw_line(id, Float:src[3], Float:dst[3], life, size, glow, r,g,b) {
	message_begin(MSG_ONE, SVC_TEMPENTITY, _, id);
	write_byte(TE_BEAMPOINTS);
	write_coord_f(src[X]);
	write_coord_f(src[Y]);
	write_coord_f(src[Z]);
	write_coord_f(dst[X]);
	write_coord_f(dst[Y]);
	write_coord_f(dst[Z]);
	write_short(g_sprLine);
	write_byte(0);
	write_byte(0);
	write_byte(life);
	write_byte(size);
	write_byte(0);
	write_byte(r);
	write_byte(g);
	write_byte(b);
	write_byte(glow);
	write_byte(0);
	message_end();
}


public plugin_precache() {
	g_sprLine = precache_model("sprites/dot.spr");
}


public plugin_init() {
	// This is a ReAPI version of: https://forums.alliedmods.net/showthread.php?t=228564 Wallbangs-Helper by Phant
	register_plugin("WB-ReAPI", "0.1", "tobii");

	g_hookTraceAttack = RegisterHookChain(RG_CBasePlayer_TraceAttack, "TraceAttack", false);
	g_hookIsPenetrableEntity = RegisterHookChain(RG_IsPenetrableEntity, "IsPenetrableEntity", true);

	new cvarEnabled = create_cvar("sv_wallbangs", "1", FCVAR_NONE, "Display wallbang tracers", true, 0.0, true, 1.0);
	hook_cvar_change(cvarEnabled, "hook_cvar_enabled");
	bind_pcvar_num(cvarEnabled, g_cvarEnabled);

	new cvarBreakable = create_cvar("sv_wallbangs_breakable", "1", FCVAR_NONE, "Allow breaking func_breakable walls.", true, 0.0, true, 1.0);
	hook_cvar_change(cvarBreakable, "hook_cvar_breakable");
	bind_pcvar_num(cvarBreakable, g_cvarBreakable);

	new ent = -1;
	while ((ent = rg_find_ent_by_class(ent, "func_breakable"))) {
		if (!(get_entvar(ent, var_spawnflags) & SF_BREAK_TRIGGER_ONLY)) {
			set_entvar(ent, var_max_health, Float:get_entvar(ent, var_health));
			set_entvar(ent, var_iuser1, get_entvar(ent, var_solid));
			set_entvar(ent, var_iuser2, get_entvar(ent, var_spawnflags));
		}
	}

	new cvarLife = create_cvar("sv_wallbangs_life", "128", FCVAR_NONE, "Wallbangs line life", true, 0.0, true, 255.0);
	new cvarSize = create_cvar("sv_wallbangs_size", "1", FCVAR_NONE, "Wallbangs line size", true, 0.0, true, 255.0);
	new cvarGlow = create_cvar("sv_wallbangs_glow", "200", FCVAR_NONE, "Wallbangs line glow", true, 0.0, true, 255.0);
	new cvarR = create_cvar("sv_wallbangs_r", "200", FCVAR_NONE, "Wallbangs line red colour", true, 0.0, true, 255.0);
	new cvarG = create_cvar("sv_wallbangs_g", "200", FCVAR_NONE, "Wallbangs line green colour", true, 0.0, true, 255.0);
	new cvarB = create_cvar("sv_wallbangs_b", "200", FCVAR_NONE, "Wallbangs line blue colour", true, 0.0, true, 255.0);

	new cvarHitLife = create_cvar("sv_wallbangs_hit_life", "196", FCVAR_NONE, "Wallbangs Hit line life", true, 0.0, true, 255.0);
	new cvarHitSize = create_cvar("sv_wallbangs_hit_size", "2", FCVAR_NONE, "Wallbangs Hit line size", true, 0.0, true, 255.0);
	new cvarHitGlow = create_cvar("sv_wallbangs_hit_glow", "230", FCVAR_NONE, "Wallbangs Hit line glow", true, 0.0, true, 255.0);
	new cvarHitR = create_cvar("sv_wallbangs_hit_r", "255", FCVAR_NONE, "Wallbangs Hit line red colour", true, 0.0, true, 255.0);
	new cvarHitG = create_cvar("sv_wallbangs_hit_g", "100", FCVAR_NONE, "Wallbangs Hit line green colour", true, 0.0, true, 255.0);
	new cvarHitB = create_cvar("sv_wallbangs_hit_b", "112", FCVAR_NONE, "Wallbangs Hit line blue colour", true, 0.0, true, 255.0);

	new cvarTraceLife = create_cvar("sv_wallbangs_trace_life", "168", FCVAR_NONE, "Wallbangs Trace line life", true, 0.0, true, 255.0);
	new cvarTraceSize = create_cvar("sv_wallbangs_trace_size", "1", FCVAR_NONE, "Wallbangs Trace line size", true, 0.0, true, 255.0);
	new cvarTraceGlow = create_cvar("sv_wallbangs_trace_glow", "230", FCVAR_NONE, "Wallbangs Trace line glow", true, 0.0, true, 255.0);
	new cvarTraceR = create_cvar("sv_wallbangs_trace_r", "100", FCVAR_NONE, "Wallbangs Trace line red colour", true, 0.0, true, 255.0);
	new cvarTraceG = create_cvar("sv_wallbangs_trace_g", "230", FCVAR_NONE, "Wallbangs Trace line green colour", true, 0.0, true, 255.0);
	new cvarTraceB = create_cvar("sv_wallbangs_trace_b", "200", FCVAR_NONE, "Wallbangs Trace line blue colour", true, 0.0, true, 255.0);

	bind_pcvar_num(cvarLife, g_cvarLife);
	bind_pcvar_num(cvarSize, g_cvarSize);
	bind_pcvar_num(cvarGlow, g_cvarGlow);
	bind_pcvar_num(cvarR, g_cvarR);
	bind_pcvar_num(cvarG, g_cvarG);
	bind_pcvar_num(cvarB, g_cvarB);

	bind_pcvar_num(cvarHitLife, g_cvarHitLife);
	bind_pcvar_num(cvarHitSize, g_cvarHitSize);
	bind_pcvar_num(cvarHitGlow, g_cvarHitGlow);
	bind_pcvar_num(cvarHitR, g_cvarHitR);
	bind_pcvar_num(cvarHitG, g_cvarHitG);
	bind_pcvar_num(cvarHitB, g_cvarHitB);

	bind_pcvar_num(cvarTraceLife, g_cvarHitLife);
	bind_pcvar_num(cvarTraceSize, g_cvarHitSize);
	bind_pcvar_num(cvarTraceGlow, g_cvarHitGlow);
	bind_pcvar_num(cvarTraceR, g_cvarHitR);
	bind_pcvar_num(cvarTraceG, g_cvarHitG);
	bind_pcvar_num(cvarTraceB, g_cvarHitB);

	register_concmd("wallbangs_restore", "concmd_wallbangs_restore");
}


public hook_cvar_enabled() {
	if (g_cvarEnabled) {
		EnableHookChain(g_hookTraceAttack);
		EnableHookChain(g_hookIsPenetrableEntity);
	} else {
		DisableHookChain(g_hookTraceAttack);
		DisableHookChain(g_hookIsPenetrableEntity);
	}
}


public hook_cvar_breakable() {
	new ent = -1;
	if (g_cvarBreakable) {
		while ((ent = rg_find_ent_by_class(ent, "func_breakable"))) {
			if (!(get_entvar(ent, var_iuser2) & SF_BREAK_TRIGGER_ONLY)) {
				set_entvar(ent, var_health, Float:get_entvar(ent, var_max_health));
				set_entvar(ent, var_solid, get_entvar(ent, var_iuser1));
				set_entvar(ent, var_effects, 0);
				set_entvar(ent, var_deadflag, 0);
				set_entvar(ent, var_takedamage, 1.0);
				set_entvar(ent, var_spawnflags, get_entvar(ent, var_iuser2));
			}
		}
	} else {
		while ((ent = rg_find_ent_by_class(ent, "func_breakable"))) {
			if (!(get_entvar(ent, var_iuser2) & SF_BREAK_TRIGGER_ONLY)) {
				set_entvar(ent, var_health, Float:get_entvar(ent, var_max_health));
				set_entvar(ent, var_solid, get_entvar(ent, var_iuser1));
				set_entvar(ent, var_effects, 0);
				set_entvar(ent, var_deadflag, 0);
				set_entvar(ent, var_takedamage, 0.0);
				//set_entvar(ent, var_takedamage, 1.0);
				set_entvar(ent, var_spawnflags, SF_BREAK_TRIGGER_ONLY);
			}
		}
	}
}


public OnConfigsExecuted() {
	hook_cvar_enabled();
	hook_cvar_breakable();
}


public client_putinserver(id) {
	g_iWb[id] = false;
}



public concmd_wallbangs_restore(id) {
	new ent = -1;
	while ((ent = rg_find_ent_by_class(ent, "func_breakable"))) {
		if (!(get_entvar(ent, var_iuser2) & SF_BREAK_TRIGGER_ONLY)) {
			set_entvar(ent, var_health, Float:get_entvar(ent, var_max_health));
			set_entvar(ent, var_solid, get_entvar(ent, var_iuser1));
			set_entvar(ent, var_effects, 0);
			set_entvar(ent, var_deadflag, 0);
			if (g_cvarBreakable) {
				set_entvar(ent, var_takedamage, 1.0);
				set_entvar(ent, var_spawnflags, get_entvar(ent, var_iuser2));
			} else {
				set_entvar(ent, var_takedamage, 0.0);
				set_entvar(ent, var_spawnflags, SF_BREAK_TRIGGER_ONLY);
			}
		}
	}
	return PLUGIN_HANDLED;
}

public TraceAttack(const id, attacker, Float:flDmg, Float:vecDir[3], tr, bitsDamageType) {
	new Float:src[3], Float:dst[3];
	get_entvar(attacker, var_origin, src);
	get_entvar(attacker, var_view_ofs, dst);
	xs_vec_add(dst, src, src);
	get_pmtrace(tr, pmt_endpos, dst);
	_draw_line(id, src, dst, g_cvarTraceLife, g_cvarTraceSize, g_cvarTraceGlow, g_cvarTraceR, g_cvarTraceG, g_cvarTraceB);
	_draw_line(attacker, src, dst, g_cvarTraceLife, g_cvarTraceSize, g_cvarTraceGlow, g_cvarTraceR, g_cvarTraceG, g_cvarTraceB);
}


public IsPenetrableEntity(Float:src[3], Float:dst[3], id, ent) {
	new Float:t = get_gametime();
	new Float:flTime = g_flTime[id];
	new bool:b = (g_flTimeBreakable[id] == t);
	new bool:s = !g_bShot[id];
	if (!b) {
		new szClassname[32];
		get_entvar(ent, var_classname, szClassname, charsmax(szClassname));
		b = equal(szClassname, "func_breakable", charsmax(szClassname)) && !(get_entvar(ent, var_iuser2) & SF_BREAK_TRIGGER_ONLY);
	}

	if ((t == flTime)) {
		new x = ++g_iWb[id];
		new Float:view_src[3], Float:view_ofs[3];
		get_entvar(id, var_origin, view_src);
		get_entvar(id, var_view_ofs, view_ofs);
		xs_vec_add(view_src, view_ofs, view_src);
		if (x == 1) {
			if (b) {
				client_print(id, print_center, s ? "<< >>^nfunc_breakable" : "<<   >>^nfunc_breakable");
			} else {
				client_print(id, print_center, s ? "<< >>" : "<<   >>");
			}
		} else {
			if (b) {
				if (s) {
					client_print(id, print_center, "<<+>>^n%d^nfunc_breakable", x);
				} else {
					client_print(id, print_center, "<< + >>^n%d^nfunc_breakable", x);
				}
			} else {
				if (s) {
					client_print(id, print_center, "<<+>>^n%d", x);
				} else {
					client_print(id, print_center, "<< + >>^n%d", x);
				}
			}
		}
		_draw_line(id, view_src, dst, g_cvarHitLife, g_cvarHitSize, g_cvarHitGlow, g_cvarHitR, g_cvarHitG, g_cvarHitB);
	} else {
		g_bShot[id] = s;
		g_iWb[id] = 0;
		g_flTime[id] = t;
		_draw_line(id, src, dst, g_cvarLife, g_cvarSize, g_cvarGlow, g_cvarR, g_cvarG, g_cvarB);
		if (b) {
			g_flTimeBreakable[id] = t;
			client_print(id, print_center, "^nfunc_breakable");
		} else {
			client_print(id, print_center, " ");
		}
	}
}

