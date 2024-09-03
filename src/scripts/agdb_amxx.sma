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
        return;
    }

    new response[512];
    ezhttp_get_data(request, response, charsmax(response));

    new JSON:json;
    json = json_parse(response);
    json_object_get_string(json, "ip", g_szPublicIP, charsmax(g_szPublicIP));
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