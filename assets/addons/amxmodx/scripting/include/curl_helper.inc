#if defined _curl_helper_included
    #endinput
#endif
#define _curl_helper_included

#if !defined CURL_HELPER_RESPONSE_MAX_LENGTH
    #define CURL_HELPER_RESPONSE_MAX_LENGTH 2048
#endif

#if !defined CURL_HELPER_TESTS
    #define PRIVATE_FUNC static
#else
    #define PRIVATE_FUNC 
#endif

#include <curl>

enum any:CurlHelperResponseData
{
    bool:RP_IsTruncated,
    RP_Length, // exclude zero terminator
    RP_Response[CURL_HELPER_RESPONSE_MAX_LENGTH + 1] // plus one for null terminator, for easiest non-binary data handling
};

static Trie:g_responses; // CurlHelperResponseData

static CURL:g_cached_response_curl;
static g_cached_response[CurlHelperResponseData];

stock curl_helper_set_write_options(const CURL:curl, const buffer_size = 2048)
{
    init_response_for_curl(curl);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, "__curl_helper_on_write");
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, curl);

    if (buffer_size > 0)
        curl_easy_setopt(curl, CURLOPT_BUFFERSIZE, buffer_size);
}

stock curl_helper_get_response(const CURL:curl, response[], const len)
{
    update_cached_response(curl);

    new copy_len = min(len, g_cached_response[RP_Length]);

    copy_cells(response, g_cached_response[RP_Response], copy_len);
    response[copy_len] = 0;

    return copy_len;
}

stock curl_helper_get_response_len(const CURL:curl)
{
    update_cached_response(curl);

    return g_cached_response[RP_Length];
}

stock bool:curl_helper_is_response_trunc(const CURL:curl)
{
    update_cached_response(curl);

    return g_cached_response[RP_IsTruncated];
}

stock curl_helper_init()
{
    if (g_responses == Invalid_Trie)
        g_responses = TrieCreate();
}

stock curl_helper_free()
{
    TrieDestroy(g_responses);
}

PRIVATE_FUNC init_response_for_curl(const CURL:curl)
{
    new response_data[CurlHelperResponseData];
    set_response_for_curl(curl, response_data);
}

static set_response_for_curl(const CURL:curl, const response_data[CurlHelperResponseData])
{
    new curl_str[16];
    num_to_str(_:curl, curl_str, charsmax(curl_str));

    curl_helper_init();
    TrieSetArray(g_responses, curl_str, response_data, sizeof(response_data), .replace = true);
}

static force_update_cached_response(const CURL:curl)
{
    g_cached_response_curl = CURL:0;
    update_cached_response(curl);
}

static update_cached_response(const CURL:curl)
{
    if (curl == g_cached_response_curl)
        return;

    new curl_str[16];
    num_to_str(_:curl, curl_str, charsmax(curl_str));

    curl_helper_init();
    if (TrieKeyExists(g_responses, curl_str))
        TrieGetArray(g_responses, curl_str, g_cached_response, sizeof(g_cached_response));
    else
        arrayset(g_cached_response, 0, sizeof(g_cached_response));
    
    g_cached_response_curl = curl;
}

static copy_cells(dest[], const src[], const copy_len)
{
    for (new i = 0; i < copy_len; i++)
        dest[i] = src[i];
}

public __curl_helper_on_write(const response[], size, const nmemb, const CURL:curl)
{
    if ((size *= nmemb) == 0)
        return size;

    force_update_cached_response(curl);

    new copy_size;
    if (g_cached_response[RP_Length] + size > charsmax(g_cached_response[RP_Response]))
    {
        copy_size = charsmax(g_cached_response[RP_Response]) - g_cached_response[RP_Length];
        g_cached_response[RP_IsTruncated] = true;
    }
    else
        copy_size = size;

    copy_cells(g_cached_response[RP_Response][g_cached_response[RP_Length]], response, copy_size);
    g_cached_response[RP_Length] += copy_size;

    set_response_for_curl(curl, g_cached_response);

    return size;
}

#undef PRIVATE_FUNC