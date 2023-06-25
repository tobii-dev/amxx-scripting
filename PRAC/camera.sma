#include <amxmodx>
#include <engine>
#include <reapi>

#pragma semicolon 1

new HookChain:g_hookUseEmpty;
new g_cvarEnabled;
new g_camType[33];


public plugin_init() {
	register_plugin("Thirdperson-ReAPI", "0.1", "tobii");
	g_hookUseEmpty = RegisterHookChain(RG_CBasePlayer_UseEmpty, "CBasePlayer_UseEmpty");
	new cvarEnabled = create_cvar("sv_allowthirdperson", "1", FCVAR_NONE, "Enables <1> or disables <0> third person by USE+RELOAD", true, 0.0, true, 1.0);
	hook_cvar_change(cvarEnabled, "hook_cvar_enabled");
	bind_pcvar_num(cvarEnabled, g_cvarEnabled);
}


public hook_cvar_enabled() {
	if (g_cvarEnabled) {
		EnableHookChain(g_hookUseEmpty);
	} else {
		DisableHookChain(g_hookUseEmpty);
	}
}

public plugin_precache() {
	precache_model("models/rpgrocket.mdl"); // Required for set_view() call
}

public client_authorized(id) {
	g_camType[id] = CAMERA_NONE;
}

public CBasePlayer_UseEmpty(id) {
	new k = (get_user_button(id) & IN_RELOAD) ? 1 : -1;
	new c = (g_camType[id] + k) % 4;
	set_view(id, c);
	g_camType[id] = c;
}
