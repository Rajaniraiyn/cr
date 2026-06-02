#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handles */
typedef struct cr_browser_s cr_browser_t;
typedef struct cr_tab_s     cr_tab_t;

/* Callback signatures */
typedef void (*cr_load_callback_t)(cr_tab_t* tab, int success, void* userdata);
typedef void (*cr_title_callback_t)(cr_tab_t* tab, const char* title, void* userdata);

typedef struct cr_browser_config_s {
    int         headless;    /* 1 = headless, 0 = headed */
    int         width;       /* 0 → 800 */
    int         height;      /* 0 → 600 */
    const char* user_agent;  /* NULL → Chromium default */
    void*       userdata;
} cr_browser_config_t;

#ifdef __cplusplus
}
#endif
