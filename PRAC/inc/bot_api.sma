#include <amxmodx>
#include <fakemeta>

#define PLUGIN "Bot API"
#define VERSION "0.5.1"
#define AUTHOR "Space Headed"

#define MAX_BOT_INTEGER 2
#define MAX_BOT_FLOAT 3

new INT_OFFSET = 1
new FLOAT_OFFSET = 5

enum {
	bot_int_start,
	bot_buttons,
	bot_impulse,
	bot_int_end,
	bot_float_start,
	bot_forward_move,
	bot_side_move,
	bot_up_move,
	bot_float_end
}

enum INTERN_FLOATS {
	Float:bot_wav_duration,
	Float:bot_wav_delay,
	Float:bot_chat_delay
}

// Misc Data
new maxplayers
new alltalk
new botid
new bot_hp[33]

// Bot Data
new iBotData[33][MAX_BOT_INTEGER]
new Float:fBotData[33][MAX_BOT_FLOAT]
new Float:fData[33][INTERN_FLOATS]
new Float:BotAngles[33][3]
new bool:isBot[33]
new Float:msec

// Bot Forwards
new gForwardBotConnect
new gForwardBotDisconnect
new gForwardBotDamage
new gForwardBotDeath
new gForwardBotSpawn
new gForwardBotThink
new gForwardTrashRet

// Messages
new gmsgBotVoice
new gmsgSayText
new gmsgSendAudio
new gmsgTextMsg

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)

	gmsgBotVoice = get_user_msgid("BotVoice")
	gmsgSayText = get_user_msgid("SayText")
	gmsgSendAudio = get_user_msgid("SendAudio")
	gmsgTextMsg = get_user_msgid("TextMsg")

	register_event("DeathMsg", "Event_DeathMsg", "a")
	register_event("Health", "Event_Health", "be")
	register_event("ResetHUD", "Event_ResetHUD", "be")

	register_forward(FM_ClientDisconnect, "Forward_ClientDisconnect")
	register_forward(FM_ClientPutInServer, "Forward_ClientPutInServer")
	register_forward(FM_StartFrame, "Forward_StartFrame")

	gForwardBotConnect = CreateMultiForward("bot_connect", ET_IGNORE, FP_CELL)
	gForwardBotDisconnect = CreateMultiForward("bot_disconnect", ET_IGNORE, FP_CELL)
	gForwardBotDamage = CreateMultiForward("bot_damage", ET_IGNORE, FP_CELL, FP_CELL)
	gForwardBotDeath = CreateMultiForward("bot_death", ET_IGNORE, FP_CELL)
	gForwardBotSpawn = CreateMultiForward("bot_spawn", ET_IGNORE, FP_CELL)
	gForwardBotThink = CreateMultiForward("bot_think", ET_IGNORE, FP_CELL)

	maxplayers = get_maxplayers()
	alltalk = get_cvar_pointer("sv_alltalk")
}

public plugin_natives() {
	register_library("botapi")
	register_native("create_bot", "Native_create_bot")
	register_native("remove_bot", "Native_remove_bot")
	register_native("is_bot", "Native_is_bot")
	register_native("get_bot_data", "Native_get_bot_data")
	register_native("set_bot_data", "Native_set_bot_data")
	register_native("set_bot_angles", "Native_set_bot_angles")
	register_native("set_bot_voice", "Native_set_bot_voice")
	register_native("set_bot_chat", "Native_set_bot_chat")
}

public Forward_ClientDisconnect(id) {
	if (isBot[id]) {
		ExecuteForward(gForwardBotDisconnect, gForwardTrashRet, id)
		isBot[id] = false
	}
}

public Forward_ClientPutInServer(id) {
	if (isBot[id]) {
		bot_hp[id] = 0
		ExecuteForward(gForwardBotConnect, gForwardTrashRet, id)
	}
}

public Event_DeathMsg() {
	static id
	id = read_data(2)
	if (isBot[id]) ExecuteForward(gForwardBotDeath, gForwardTrashRet, id)
}

public Event_Health(id) {
	if (isBot[id]) {
		new hp = read_data(1)
		if (hp >= bot_hp[id]) // Bot gained health, update and break
		{
			bot_hp[id] = hp
			return PLUGIN_CONTINUE
		}
		new damage = bot_hp[id] - hp
		bot_hp[id] = hp
		ExecuteForward(gForwardBotDamage, gForwardTrashRet, id, damage)
	}
	return PLUGIN_CONTINUE
}

public Event_ResetHUD(id) {
	if (isBot[id]) {
		bot_hp[id] = get_user_health(id)
		ExecuteForward(gForwardBotSpawn, gForwardTrashRet, id)
	}
}

public Forward_StartFrame() {
	for (botid = 1; botid <= maxplayers; ++botid) run_bot(botid)
}

run_bot(id) {
	if (pev_valid(id) && isBot[id]) {
		// Set FL_FAKECLIENT flag
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT)

		// Check Voice Duration
		static Float:gametime
		gametime = get_gametime()
		if (!is_user_alive(id) && fData[id][bot_wav_duration] > 0.0) reset_voice(id)
		else if (fData[id][bot_wav_duration] > 0.0 && gametime > fData[id][bot_wav_duration]) reset_voice(id)

		// Execute bot_think
		if (is_user_alive(id)) {
			ExecuteForward(gForwardBotThink, gForwardTrashRet, id)
			
			if (fBotData[id][bot_forward_move-FLOAT_OFFSET] > 1) {
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_BACK
				iBotData[id][bot_buttons-INT_OFFSET] |= IN_FORWARD
			} else if (fBotData[id][bot_forward_move-FLOAT_OFFSET] < 0) {
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_FORWARD
				iBotData[id][bot_buttons-INT_OFFSET] |= IN_BACK
			} else {
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_FORWARD
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_BACK
			}

			if (fBotData[id][bot_side_move-FLOAT_OFFSET] > 0) {
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVELEFT
				iBotData[id][bot_buttons-INT_OFFSET] |= IN_MOVERIGHT
			} else if (fBotData[id][bot_side_move-FLOAT_OFFSET] < 0) {
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVERIGHT
				iBotData[id][bot_buttons-INT_OFFSET] |= IN_MOVELEFT
			} else {
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVERIGHT
				iBotData[id][bot_buttons-INT_OFFSET] &= ~IN_MOVELEFT
			}
		}
		// msec calculation
		global_get(glb_frametime, msec)
		msec *= 1000.0
		engfunc(EngFunc_RunPlayerMove, id, 
			BotAngles[id],
			fBotData[id][bot_forward_move-FLOAT_OFFSET],
			fBotData[id][bot_side_move-FLOAT_OFFSET],
			fBotData[id][bot_up_move-FLOAT_OFFSET],
			iBotData[id][bot_buttons-INT_OFFSET],
			iBotData[id][bot_impulse-INT_OFFSET],
			floatround(msec)
		)
	}
}

public Native_create_bot() {
	new id, name[32]
	get_string(1, name, 31)
	id = engfunc(EngFunc_CreateFakeClient, name)

	if (pev_valid(id)) {
		engfunc(EngFunc_FreeEntPrivateData, id)
		dllfunc(MetaFunc_CallGameEntity, "player", id)
		set_user_info(id, "rate", "3500")
		set_user_info(id, "cl_updaterate", "25")
		set_user_info(id, "cl_lw", "1")
		set_user_info(id, "cl_lc", "1")
		set_user_info(id, "cl_dlmax", "128")
		set_user_info(id, "cl_righthand", "1")
		set_user_info(id, "_vgui_menus", "0")
		set_user_info(id, "_ah", "0")
		set_user_info(id, "dm", "0")
		set_user_info(id, "tracker", "0")
		set_user_info(id, "friends", "0")
		set_user_info(id, "*bot", "1")
		set_pev(id, pev_flags, pev(id, pev_flags) | FL_FAKECLIENT)
		set_pev(id, pev_colormap, id)
		
		new msg[128]
		dllfunc(DLLFunc_ClientConnect, id, name, "127.0.0.1", msg)
		dllfunc(DLLFunc_ClientPutInServer, id)
		engfunc(EngFunc_RunPlayerMove, id, Float:{0.0,0.0,0.0}, 0.0, 0.0, 0.0, 0, 0, 76)
		ExecuteForward(gForwardBotConnect, gForwardTrashRet, id)

		isBot[id] = true
		return id
	}
	return 0
}

public Native_remove_bot() {
	new id = get_param(1)
	if (pev_valid(id) && id <= maxplayers && isBot[id])
	{
		ExecuteForward(gForwardBotDisconnect, gForwardTrashRet, id)
		isBot[id] = false
		new botname[32]
		pev(id, pev_netname, botname, 31)
		server_cmd("kick ^"%s^"", botname)
	}
}

public Native_is_bot() {
	new id = get_param(1)
	if (pev_valid(id) && id <= maxplayers && isBot[id]) return 1
	return 0
}

public Native_get_bot_data() {
	new id = get_param(1)
	if (pev_valid(id) && id <= maxplayers && isBot[id]) {
		new data = get_param(2)
		// Integers
		if (data > bot_int_start && data < bot_int_end) {
			switch (data) {
				case bot_buttons: return iBotData[id][bot_buttons-INT_OFFSET]
				case bot_impulse: return iBotData[id][bot_impulse-INT_OFFSET]
			}
		}
		// Floats
		else if (data > bot_float_start && data < bot_float_end) {
			switch (data) {
				case bot_forward_move: set_float_byref(3, fBotData[id][bot_forward_move-FLOAT_OFFSET])
				case bot_side_move: set_float_byref(3, fBotData[id][bot_side_move-FLOAT_OFFSET])
				case bot_up_move: set_float_byref(3, fBotData[id][bot_up_move-FLOAT_OFFSET])
			}
		}
	}
	return 0
}

public Native_set_bot_data() {
	new id = get_param(1)
	if (pev_valid(id) && id <= maxplayers && isBot[id]) {
		new data = get_param(2)
		// Integers
		if (data > bot_int_start && data < bot_int_end) {
			new iVal = get_param_byref(3)
			switch (data) {
				case bot_buttons: iBotData[id][bot_buttons-INT_OFFSET] = iVal
				case bot_impulse: iBotData[id][bot_impulse-INT_OFFSET] = iVal
			}
		}
		// Floats
		else if (data > bot_float_start && data < bot_float_end) {
			new Float:fVal = get_float_byref(3)
			switch (data) {
				case bot_forward_move: fBotData[id][bot_forward_move-FLOAT_OFFSET] = fVal
				case bot_side_move: fBotData[id][bot_side_move-FLOAT_OFFSET] = fVal
				case bot_up_move: fBotData[id][bot_up_move-FLOAT_OFFSET] = fVal
			}
		}
	}
}

public Native_set_bot_angles() {
	new id = get_param(1)
	if (pev_valid(id) && id <= maxplayers && isBot[id]) {
		new Float:vVec[3]
		get_array_f(2, vVec, 3)

		new Float:vOrig[3]
		pev(id, pev_origin, vOrig)

		new Float:dOrig[3]
		dOrig[0] = vVec[0] - vOrig[0]
		dOrig[1] = vVec[1] - vOrig[1]
		dOrig[2] = vVec[2] - vOrig[2]

		engfunc(EngFunc_VecToAngles, dOrig, BotAngles[id])
		BotAngles[id][0] = 0.0
		BotAngles[id][2] = 0.0
		set_pev(id, pev_angles, BotAngles[id])
		// Update View
		set_pev(id, pev_v_angle, BotAngles[id])
	}
}

public Native_set_bot_voice() {
	new id = get_param(1)
	if (pev_valid(id) && id <= maxplayers && isBot[id]) {
		new Float:gametime = get_gametime()
		if (is_user_alive(id) && gametime > fData[id][bot_wav_delay]) {
			new wavefile[64]
			get_string(2, wavefile, 63)
			new pitch = get_param(3)
			new Float:duration = get_param_f(4)
			fData[id][bot_wav_duration] = gametime + duration
			fData[id][bot_wav_delay] = fData[id][bot_wav_duration] + 1.0

			new botteam = get_user_team(id)
			for (new pid = 1; pid <= maxplayers; ++pid) {
				if (is_user_connected(pid) && is_user_alive(pid) && (get_user_team(pid) == botteam || get_pcvar_num(alltalk) == 1)) {
					emessage_begin(MSG_ONE_UNRELIABLE, gmsgBotVoice, {0,0,0}, pid)
					ewrite_byte(1)
					ewrite_byte(id)
					emessage_end()
					
					emessage_begin(MSG_ONE_UNRELIABLE, gmsgSendAudio, {0,0,0}, pid)
					ewrite_byte(id)
					ewrite_string(wavefile)
					ewrite_short(pitch)
					emessage_end()
				}
			}
		}
	}
}

public Native_set_bot_chat() {
	new id = get_param(1)
	if (pev_valid(id) && id <= maxplayers && isBot[id]) {
		new Float:gametime = get_gametime()
		if (is_user_alive(id) && gametime > fData[id][bot_chat_delay]) {
			fData[id][bot_chat_delay] = gametime + 1.0

			new msg = get_param(2)
			new text[128], name[32]
			get_string(3, text, 127)
			get_user_name(id, name, 31)

			new botteam = get_user_team(id)
			for (new pid = 1; pid <= maxplayers; ++pid) {
				if (is_user_connected(pid) && is_user_alive(pid)) {
					if (!msg) {
						emessage_begin(MSG_ONE_UNRELIABLE, gmsgSayText, {0,0,0}, pid)
						ewrite_byte(id)
						ewrite_string("#Cstrike_Chat_All")
						ewrite_string("")
						ewrite_string(text)
						emessage_end()
					} else if (msg && get_user_team(pid) == botteam) {
						switch (msg) {
							case 1: {
								emessage_begin(MSG_ONE_UNRELIABLE, gmsgSayText, {0,0,0}, pid)
								ewrite_byte(id)
								ewrite_string(botteam == 2 ? "#Cstrike_Chat_CT" : "#Cstrike_Chat_T")
								ewrite_string("")
								ewrite_string(text)
								emessage_end()
							} case 2: {
								emessage_begin(MSG_ONE_UNRELIABLE, gmsgTextMsg, {0,0,0}, pid)
								ewrite_byte(3)
								ewrite_string("#Game_radio")
								ewrite_string(name)
								ewrite_string(text)
								emessage_end()
							}
						}
					}
				}
			}
		}
	}
}

reset_voice(id) {
	fData[id][bot_wav_duration] = 0.0
	emessage_begin(MSG_BROADCAST, gmsgBotVoice)
	ewrite_byte(0)
	ewrite_byte(id)
	emessage_end()
}
