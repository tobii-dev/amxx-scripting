#include <amxmodx>
#include <amxmisc>
#include <sockets>


//https://github.com/dreamstalker/rehlds/tree/master/rehlds/HLTV

/***
	hltv_demo_start		:: start demo
	hltv_demo_stop		:: stop demo
	hltv_demo_stop_s	:: stop demo when it reaches this moment (take hdelay into acount) [might be odd on map changes but ok...]
***/


#define PLUGIN	"Mix-HLTV"
#define VERSION "0.11"
#define AUTHOR	"tobii"


#define LEN_IP 16
#define LEN_PORT 6
#define LEN_PW 64
#define LEN_HLTV_CHALLENGE 32
#define LEN_HLTV_CMD 256
#define LEN_HLTV_RESPONSE 2048
#define TRIES 20


const TASK_ID = 127;
const Float:RETRIEVE_INTERVAL = 0.02;


enum hltv_cmd {
	NONE = 0,
	START_DEMO,
	STOP_DEMO
}

enum hltv_status {
	CLOSED = 0,
	AUTH,
	EXECUTING,
	UNKNOWN
}

enum _:hltv_stuffs {
	s, //socket
	hltv_status:status, //current connection status
	challenge[LEN_HLTV_CHALLENGE], //rcon id (used to exec rcon cmds)
	hltv_cmd:cmd, //current cmd in execution
	t, //current tries
	pw[LEN_PW], //rcon_password == adminpassword
	ip[LEN_IP], //hltv ip
	port, //hltv port
	Float:delay,
};


new g_hltv[hltv_stuffs];

new g_cvarRconPassword;


public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_concmd("hltv_demo_start", "concmd_hltv_demo_start");
	register_concmd("hltv_demo_stop", "concmd_hltv_demo_stop");
	register_concmd("hltv_demo_stop_s", "concmd_hltv_demo_stop_s");

	g_cvarRconPassword = register_cvar("rcon_password", ""); //hltv instance must have same adminpass as server rcon_password

	g_hltv[s] = 0;
	g_hltv[status] = CLOSED;
	g_hltv[cmd] = NONE;
	g_hltv[challenge][0] = 0;
	g_hltv[t] = 0;
}


/** Get connected HLTV client id */
getHLTV() {
	new hltv = 0;
	new players[MAX_PLAYERS], n, p = 0;
	get_players_ex(players, n, GetPlayers_IncludeConnecting);
	while (--n >= 0) {
		p = players[n];
		if (is_user_hltv(p)) {
			hltv = p;
			break;
		}
	}
	return hltv;
}

/** Get connected HLTV IP+Port */
getIP(id, szIP[]) {
	new p = 0;
	new szTmp[LEN_IP+LEN_PORT+2]; //"255.255.255.255:65535"
	get_user_ip(id, szTmp, sizeof(szTmp));
	new szPort[6]; //65535
	strtok(szTmp, szIP, LEN_IP, szPort, sizeof(szPort), ':', true);
	if (szIP[0] && szPort[0]) {
		p = str_to_num(szPort);
	}
	return p;
}

Float:getDelay(id) {
	new szTmp[6] = "0";
	get_user_info(id, "hdelay", szTmp, charsmax(szTmp));
	return str_to_float(szTmp);
}

/** Reset g_hltv vars */
_resetHLTV() {
	socket_close(g_hltv[s]);
	g_hltv[s] = 0;
	g_hltv[status] = CLOSED;
	g_hltv[cmd] = NONE;
	g_hltv[challenge] = 0;
	g_hltv[t] = 0;
}

/** try to get & set challenge */
bool:_authHLTV(tv) {
	new r = 0;
	new bool:ok = false;
	g_hltv[port] = getIP(tv, g_hltv[ip]);
	get_pcvar_string(g_cvarRconPassword, g_hltv[pw], LEN_PW);
	g_hltv[s] = socket_open(g_hltv[ip], g_hltv[port], SOCKET_UDP, r, SOCK_NON_BLOCKING);
	if (r == SOCK_ERROR_OK) {
		new data[LEN_HLTV_CMD];
		new l = formatex(data, sizeof(data), "%c%c%c%cchallenge rcon^n^0", 0xFF, 0xFF, 0xFF, 0xFF); //TODO ^n
		socket_send2(g_hltv[s], data, l);
		g_hltv[status] = AUTH;
		ok = true;
	} else {
		socket_close(g_hltv[s]);
		g_hltv[s] = 0;
		g_hltv[status] = CLOSED;
		g_hltv[cmd] = NONE;
	}
	return ok;
}

/** auth and then exec an rcon cmd on hltv */
public _execHLTV(hltv_cmd:c) {
	if (g_hltv[cmd] == NONE) {
		g_hltv[cmd] = c;
		new tv = getHLTV();
		if (tv) {
			client_print(0, print_console, "[MixHLTV] CONNECTED - AUTHORIZING");
			if(_authHLTV(tv)) {
				g_hltv[delay] = getDelay(tv);
				set_task_ex(RETRIEVE_INTERVAL, "_task_recv", TASK_ID, _,_, SetTask_Repeat);
				client_print(0, print_console, "[MixHLTV] >> REQUESTING RCON CHALLENGE...");
			} else {
				client_print(0, print_console, "[MixHLTV] ERROR: socket_open() failed.");
				_resetHLTV();
			}
		} else {
			client_print(0, print_console, "[MixHLTV] HLTV IS NOT CONNECTED.");
			_resetHLTV();
		}
	} else {
		client_print(0, print_console, "[MixHLTV] SERVER IS ALREADY EXECUTING RCON COMMAND (%d)[status:%d, cmd=%d]", g_hltv[t], g_hltv[status], g_hltv[cmd]);
	}
}


/** the magic spaghetti that makes it all work (kind of) 
* Repeating task untill too many tries
* If status == auth -> Waits for challenge reply and then sends cmd
* If status == executing -> Waits for rcon reply and prints it
*/
public _task_recv(task) {
	if (g_hltv[status] == AUTH) {
		if (socket_is_readable(g_hltv[s])) {
			new buff[LEN_HLTV_RESPONSE], tmp[2];
			socket_recv(g_hltv[s], buff, sizeof(buff));
			parse(buff, tmp,1, tmp,1, g_hltv[challenge], charsmax(g_hltv[challenge]));
			if (g_hltv[challenge][0]) {
				client_print(0, print_console, "[MixHLTV] >> AUTHORIZED (%d)", g_hltv[t]);
				if (g_hltv[cmd] == START_DEMO) {
					client_print(0, print_console, "[MixHLTV] >> SENDING RCON COMMAND TO START DEMO RECORDING...");
					new szCMD[LEN_HLTV_CMD];
					new q_len = formatex(szCMD, LEN_HLTV_CMD, "%c%c%c%crcon %s ^"%s^" %s", 255,255,255,255, g_hltv[challenge], g_hltv[pw], "stoprecording;record demos/HLTV"); //2 cmds in 1 rcon cmd
					socket_send2(g_hltv[s], szCMD, q_len);
					client_print(0, print_chat, "%s", szCMD);
				} else if (g_hltv[cmd] == STOP_DEMO) {
					client_print(0, print_console, "[MixHLTV] >> SENDING RCON COMMAND TO END DEMO RECORDING...");
					new szCMD[LEN_HLTV_CMD];
					new q_len = formatex(szCMD, LEN_HLTV_CMD, "%c%c%c%crcon %s ^"%s^" %s", 255,255,255,255, g_hltv[challenge], g_hltv[pw], "stoprecording"); //2cmds!
					socket_send2(g_hltv[s], szCMD, q_len);
				}
				g_hltv[status] = EXECUTING;
			} else {
				client_print(0, print_console, "[MixHLTV] >> BAD AUTH RESPONSE (%d)", g_hltv[t]);
				_resetHLTV();
				remove_task(TASK_ID);
			}
		} else if (g_hltv[t] > TRIES) {
			client_print(0, print_console, "[MixHLTV] >> AUTH RESPONSE TIMED OUT (%d)", g_hltv[t]);
			_resetHLTV();
			remove_task(TASK_ID);
		}
	} else if (g_hltv[status] == EXECUTING) {
		if (socket_is_readable(g_hltv[s])) {
			new buff[LEN_HLTV_RESPONSE];
			socket_recv(g_hltv[s], buff, sizeof(buff));
			client_print(0, print_console, "[MixHLTV] HLTV RESPONSE: [^n%s]", buff[5]);
			_resetHLTV();
			remove_task(TASK_ID);
		} else if (g_hltv[t] > TRIES) {
			client_print(0, print_console, "[MixHLTV] >> RCON RESPONSE TIMED OUT (%d tries)", g_hltv[t]);
			_resetHLTV();
			remove_task(TASK_ID);
		}
	}
	g_hltv[t]++;
}


public concmd_hltv_demo_start(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		_execHLTV(START_DEMO);
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
	}
	return PLUGIN_HANDLED;
}


public concmd_hltv_demo_stop(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		_execHLTV(STOP_DEMO);
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
	}
	return PLUGIN_HANDLED;
}


public concmd_hltv_demo_stop_s(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_hltv[delay] > 0.1) {
			set_task(g_hltv[delay], "_execHLTV", STOP_DEMO);
		} else {
			_execHLTV(STOP_DEMO);
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
	}
	return PLUGIN_HANDLED;
}


#pragma semicolon 1
