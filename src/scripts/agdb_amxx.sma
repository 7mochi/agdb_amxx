#include <amxmodx>
#include <amxmisc>
#include <curl>
#include <curl_helper>
#include <easy_http>
#include <json>

#pragma semicolon 1

#define PLUGIN      "AG Database"
#define VERSION     "1.0"
#define AUTHOR      "7mochi"

new g_cvarBaseApiUrl;
new g_cvarApiKey;

new g_szPublicIP[16];

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);
    register_dictionary("agdb_amxx.txt");

    g_cvarBaseApiUrl = create_cvar("agdb_base_api_url", "http://agdb.7mochi.ru");
    g_cvarApiKey = create_cvar("agdb_api_key", "");

    get_server_public_ip();
}

public client_authorized(id) {
    if (!is_user_bot(id) && !is_user_hltv(id)) {
        register_player(id);
    }
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
        server_print("%s", error);
        return;
    }
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

    new steamId[32], nickname[64], ip[64], JSON:jsonPlayer, playerData[1024];
    get_user_authid(id, steamId, charsmax(steamId));
    get_user_name(id, nickname, charsmax(nickname));
    get_user_ip(id, ip, charsmax(ip), 1);

    jsonPlayer = json_init_object();
    json_object_set_string(jsonPlayer, "steamID", steamId);
    json_object_set_string(jsonPlayer, "nickname", nickname);
    json_object_set_string(jsonPlayer, "ip", ip);
    json_serial_to_string(jsonPlayer, playerData, charsmax(playerData));

    ezhttp_option_set_body(options, playerData);

    ezhttp_post(url, "register_player_done", options);
}

public register_player_done(EzHttpRequest:request) {
    if (ezhttp_get_error_code(request) != EZH_OK)
    {
        new error[64];
        ezhttp_get_error_message(request, error, charsmax(error));
        server_print("%L", LANG_SERVER, "EZHTTP_DONE_ERROR");
        server_print("%s", error);
        return;
    }
}