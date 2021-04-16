#include <amxmodx>
#include <reapi>
#include <reapi_gamedll>


#define TASK_ID 127
#define TIMEOUT 90
#define DELAY 10

#define SCREENFADE_TIME_UNIT (1<<12)

new g_cvarEnabled;
new HookChain:g_hookChain_CleanUpMap;
new HookChain:g_hookChain_OnRoundFreezeEnd;

new bool:g_bTimeout = false;
new bool:g_bRequested = false;
new bool:g_bFreezeTime = false;

new Float:g_flOrgBuyTime = -2.0;
new g_cvarBuyTime;

new g_msgRoundTime;
new g_msgScreenFade;



public plugin_init() {
	register_plugin("Mix-Timeouts", "0.2", "tobii");

	new cvarEnabled = create_cvar("mp_timeouts", "0", FCVAR_NONE, "Enables <1> or disables <0> timeouts with <say /timeout>", true, 0.0, true, 1.0);
	hook_cvar_change(cvarEnabled, "hook_cvar_enabled");
	bind_pcvar_num(cvarEnabled, g_cvarEnabled);

	register_clcmd("say /timeout", "clcmd_say_timeout");
	register_clcmd("say /skip", "clcmd_say_skip");

	g_hookChain_CleanUpMap = RegisterHookChain(RG_CSGameRules_CleanUpMap, "hook_freezetime_start", true);
	g_hookChain_OnRoundFreezeEnd = RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "hook_freezetime_end", true);

	DisableHookChain(g_hookChain_CleanUpMap);
	DisableHookChain(g_hookChain_OnRoundFreezeEnd);
	
	g_cvarBuyTime = get_cvar_pointer("mp_buytime");

	g_msgRoundTime = get_user_msgid("RoundTime");
	g_msgScreenFade = get_user_msgid("ScreenFade");
}


public hook_cvar_enabled() {
	if (g_cvarEnabled) {
		EnableHookChain(g_hookChain_CleanUpMap);
		EnableHookChain(g_hookChain_OnRoundFreezeEnd);
	} else {
		DisableHookChain(g_hookChain_CleanUpMap);
		DisableHookChain(g_hookChain_OnRoundFreezeEnd);
	}
}


public clcmd_say_timeout(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_cvarEnabled) {
			if (g_bRequested) {
				client_print(id, print_chat, "A timeout was already requested.");
			} else if (g_bTimeout) {
				client_print(id, print_chat, "To request another timeout, first wait for this one to end.");
			} else if (g_bFreezeTime) {
				client_print(0, print_chat, "A timeout was requested, this freezetime will be %i seconds long.", TIMEOUT);
				_timeout();
				return PLUGIN_CONTINUE;
			} else {
				g_bRequested = true;
				client_print(0, print_chat, "A timeout was requested, next freezetime will be %i seconds long.", TIMEOUT);
				return PLUGIN_CONTINUE;
			}
		} else {
			client_print(id, print_chat, "Timeouts are disabled. Enable cvar <mp_timeouts> to allow timeouts.");
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
	}
	return PLUGIN_HANDLED;
}


public clcmd_say_skip(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_cvarEnabled) {
			if (g_bTimeout) {
				remove_task(TASK_ID);
				_alert_resuming();
				_set_remaining_freezetime(DELAY);
				return PLUGIN_CONTINUE;
			} else if (g_bRequested) {
				g_bRequested = false;
				client_print(0, print_chat, "The requested timeout was cancelled.");
				remove_task(TASK_ID);
				return PLUGIN_CONTINUE;
			} else {
				client_print(id, print_chat, "You can only use this command during a timeout, or when one has been requested.");
			}
		} else {
			client_print(id, print_chat, "Timeouts are disabled. Enable <mp_timeouts> to allow timeouts.");
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
	}
	return PLUGIN_HANDLED;
}



public hook_freezetime_start() {
	g_bFreezeTime = true;
	if (g_bRequested) {
		client_print(0, print_chat, "A timeout was requested, this freezetime will be %i seconds long.", TIMEOUT);
		set_task(0.0, "_timeout"); //delay is for the hud stuff
	}
}


public hook_freezetime_end() {
	g_bFreezeTime = false;
	_fade_clear();
	if (g_flOrgBuyTime > -1.0) {
		set_pcvar_float(g_cvarBuyTime, g_flOrgBuyTime);
	}
}


public _timeout() {
	g_bTimeout = true;
	g_bRequested = false;
	new Float:tmp = get_pcvar_float(g_cvarBuyTime);
	if (tmp > -1.0) {
		g_flOrgBuyTime = tmp;
	}
	set_pcvar_float(g_cvarBuyTime, -1.0);
	_set_remaining_freezetime(TIMEOUT);
	_hud_timer(TIMEOUT);
	_fade_timeout();
	set_task(float(TIMEOUT-DELAY), "_alert_resuming", TASK_ID);
}


public _alert_resuming() {
	g_bTimeout = false;
	_hud_timer(DELAY);
	_fade_resuming();
	client_print(0, print_center, "The game will resume in %i seconds.", DELAY);
}


stock _set_remaining_freezetime(seconds) {
	set_member_game(m_fRoundStartTime, (Float:get_gametime()) + float(seconds) - float(get_member_game(m_iIntroRoundTime)));
}


stock _fade_clear() {
	message_begin(MSG_ALL, g_msgScreenFade);
	write_short(0);
	write_short(0);
	write_short(0);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	message_end();
}
stock _fade_resuming() {
	message_begin(MSG_ALL, g_msgScreenFade);
	write_short(SCREENFADE_TIME_UNIT*(DELAY-2));
	write_short(0);
	write_short(0b010);
	write_byte(8);
	write_byte(8);
	write_byte(5);
	write_byte(200);
	message_end();
}
stock _fade_timeout() {
	message_begin(MSG_ALL, g_msgScreenFade);
	write_short(SCREENFADE_TIME_UNIT*(TIMEOUT-1));
	write_short(SCREENFADE_TIME_UNIT*2);
	write_short(0b100);
	write_byte(20);
	write_byte(20);
	write_byte(20);
	write_byte(200);
	message_end();
}

stock _hud_timer(seconds) {
	message_begin(MSG_ALL, g_msgRoundTime);
	write_short(seconds);
	message_end();
}


#pragma semicolon 1
