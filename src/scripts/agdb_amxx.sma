#include <amxmodx>
#include <amxmisc>
#include <easy_http>
#include <json>

#pragma semicolon 1

#define PLUGIN      "AG Database"
#define VERSION     "1.0.2"
#define AUTHOR      "7mochi"

enum (+=394) {
    TASK_CHECKBANSTATUS = 86723
};

new g_cvarBaseApiUrl;
new g_cvarApiKey;
new g_cvarCheckBanStatusInterval;

new g_szPublicIP[16];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_dictionary("agdb_amxx.txt");

    create_cvar("agdb_version", VERSION, FCVAR_SERVER);
    
    g_cvarBaseApiUrl = create_cvar("agdb_base_api_url", "http://agdb.7mochi.ru");
    g_cvarApiKey = create_cvar("agdb_api_key", "");
    g_cvarCheckBanStatusInterval = create_cvar("agdb_check_ban_status_interval", "30.0");

    get_server_public_ip();

    set_task(floatmax(15.0, get_pcvar_float(g_cvarCheckBanStatusInterval)), "check_all_players_ban_status", TASK_CHECKBANSTATUS);

    hook_cvar_change(g_cvarCheckBanStatusInterval, "cvar_check_all_players_ban_status_hook");
}

public client_authorized(id) {
    if (!is_user_bot(id) && !is_user_hltv(id)) {
        register_player(id);
        check_if_player_banned(id);
    }
}

public client_putinserver(id) {
    set_task(15.0, "show_advertisement", id);
}

public get_server_public_ip() {
    new url[128];
    formatex(url, charsmax(url), "http://api.ipify.org?format=json");
    
    ezhttp_get(url, "get_server_public_ip_done");
}

public get_server_public_ip_done(EzHttpRequest:request) {
    if (ezhttp_get_error_code(request) != EZH_OK)
    {
        new error[64];
        ezhttp_get_error_message(request, error, charsmax(error));
        server_print("%L", LANG_SERVER, "EZHTTP_DONE_ERROR");
        return;
    }

    new response[512];
    ezhttp_get_data(request, response, charsmax(response));

    new JSON:json;
    json = json_parse(response);
    json_object_get_string(json, "ip", g_szPublicIP, charsmax(g_szPublicIP));
}

public check_all_players_ban_status() {
    new players[MAX_PLAYERS], numPlayers;
    get_players(players, numPlayers);
    
    new player;
    for (new i; i < numPlayers; i++) {
        player = players[i];
        
        if (!is_user_bot(player) && !is_user_hltv(player)) {
            check_if_player_banned(player);
        }
    }

    set_task(floatmax(15.0, get_pcvar_float(g_cvarCheckBanStatusInterval)), "check_all_players_ban_status", TASK_CHECKBANSTATUS);
}

public cvar_check_all_players_ban_status_hook(pcvar, const oldValue[], const newValue[]) {
    remove_task(TASK_CHECKBANSTATUS);
    set_task(floatmax(15.0, get_pcvar_float(g_cvarCheckBanStatusInterval)), "check_all_players_ban_status", TASK_CHECKBANSTATUS);
}

public register_player(id) {
    new url[128], apiKey[64];
    get_pcvar_string(g_cvarBaseApiUrl, url, charsmax(url));
    formatex(url, charsmax(url), "%s/players", url);

    get_pcvar_string(g_cvarApiKey, apiKey, charsmax(apiKey));
    
    new EzHttpOptions:options = ezhttp_create_options();
    ezhttp_option_set_header(options, "Content-Type", "application/json");
    ezhttp_option_set_header(options, "User-Agent", "AGDB_AMXX_PLUGIN/1.0");
    ezhttp_option_set_header(options, "ip", g_szPublicIP);
    ezhttp_option_set_header(options, "token", apiKey);

    new steamId[32], nickname[64], ip[64], JSON:json, playerData[1024];
    get_user_authid(id, steamId, charsmax(steamId));
    get_user_name(id, nickname, charsmax(nickname));
    get_user_ip(id, ip, charsmax(ip), 1);

    json = json_init_object();
    json_object_set_string(json, "steamID", steamId);
    json_object_set_string(json, "nickname", nickname);
    json_object_set_string(json, "ip", ip);
    json_serial_to_string(json, playerData, charsmax(playerData));

    ezhttp_option_set_body(options, playerData);

    ezhttp_post(url, "register_player_done", options);
}

public register_player_done(EzHttpRequest:request) {
    if (ezhttp_get_error_code(request) != EZH_OK)
    {
        new error[64];
        ezhttp_get_error_message(request, error, charsmax(error));
        server_print("%L", LANG_SERVER, "EZHTTP_DONE_ERROR");
        return;
    }

    new response[256], JSON:json;
    ezhttp_get_data(request, response, charsmax(response));

    json = json_parse(response);

    switch (ezhttp_get_http_code(request)) {
        case 201: {
            new steamID[32];
            json_object_get_string(json, "steamID", steamID, charsmax(steamID));
            server_print("%L", LANG_SERVER, "PLAYER_REG_SUCCESS", steamID);
        }
        case 401: {
            new message[128];
            json_object_get_string(json, "message", message, charsmax(message));
            server_print("%L", LANG_SERVER, "PLAYER_REG_401", message);
        }
    }
}

public check_if_player_banned(id) {
    new url[128], apiKey[64], steamId[32], szId[2];
    get_pcvar_string(g_cvarBaseApiUrl, url, charsmax(url));
    get_user_authid(id, steamId, charsmax(steamId));
    formatex(url, charsmax(url), "%s/players/%s", url, steamId);

    get_pcvar_string(g_cvarApiKey, apiKey, charsmax(apiKey));

    num_to_str(id, szId, charsmax(szId));
    
    new EzHttpOptions:options = ezhttp_create_options();
    ezhttp_option_set_header(options, "Content-Type", "application/json");
    ezhttp_option_set_header(options, "User-Agent", "AGDB_AMXX_PLUGIN/1.0");
    ezhttp_option_set_user_data(options, szId, charsmax(szId));

    ezhttp_get(url, "check_if_player_banned_done", options);
}

public check_if_player_banned_done(EzHttpRequest:request) {
    if (ezhttp_get_error_code(request) != EZH_OK)
    {
        new error[64];
        ezhttp_get_error_message(request, error, charsmax(error));
        server_print("%L", LANG_SERVER, "EZHTTP_DONE_ERROR");
        return;
    }

    new response[2048], szId[2], JSON:json;
    ezhttp_get_data(request, response, charsmax(response));
    ezhttp_get_user_data(request, szId);

    json = json_parse(response);

    switch (ezhttp_get_http_code(request)) {
        case 200: {
            new bool:isBanned = json_object_get_bool(json, "isBanned");
            if (isBanned) {
                new steamId[32];
                json_object_get_string(json, "steamID", steamId, charsmax(steamId));

                server_cmd("kick #%d ^"%L^"", get_user_userid(str_to_num(szId)), str_to_num(szId), "PLAYER_BANNED");
                server_print("%L", LANG_SERVER, "PLAYER_BANNED_LOG", steamId);
            }
        }
        case 401: {
            new message[128];
            json_object_get_string(json, "message", message, charsmax(message));
            server_print("%L", LANG_SERVER, "PLAYER_BANNED_401", message);
        }
    }
}

public show_advertisement(id) {
    client_print(id, print_chat, "%l", "AGDB_INFO");
}