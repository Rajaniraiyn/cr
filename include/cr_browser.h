#pragma once
#include "cr_types.h"

#if defined(_WIN32)
#  ifdef CR_API_IMPLEMENTATION
#    define CR_EXPORT __declspec(dllexport)
#  else
#    define CR_EXPORT __declspec(dllimport)
#  endif
#else
#  define CR_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ── Lifecycle ─────────────────────────────────────────────────────────── */

/* Call once at startup before any other cr_ function.
   Pass the program's argc/argv so Chromium can consume its own flags.
   Returns 0 on success, non-zero on failure. */
CR_EXPORT int  cr_init(int argc, char** argv);

/* Tear down all browsers and free Chromium internals. */
CR_EXPORT void cr_shutdown(void);

/* ── Browser ────────────────────────────────────────────────────────────── */

/* Create an independent browser instance.  config may be NULL for defaults. */
CR_EXPORT cr_browser_t* cr_browser_create(const cr_browser_config_t* config);

/* Destroy browser and all its tabs. */
CR_EXPORT void          cr_browser_destroy(cr_browser_t* browser);

/* ── Tabs / navigation ─────────────────────────────────────────────────── */

/* Open a new tab and begin loading url. Returns NULL on error. */
CR_EXPORT cr_tab_t* cr_tab_open(cr_browser_t* browser, const char* url);

/* Close and free a tab. */
CR_EXPORT void cr_tab_close(cr_tab_t* tab);

/* Navigate an existing tab to url. */
CR_EXPORT void cr_tab_navigate(cr_tab_t* tab, const char* url);

/* Caller must NOT free the returned strings; valid until next navigate/close. */
CR_EXPORT const char* cr_tab_get_url(cr_tab_t* tab);
CR_EXPORT const char* cr_tab_get_title(cr_tab_t* tab);

/* Register callbacks (pass NULL to unregister). */
CR_EXPORT void cr_tab_set_load_callback(cr_tab_t*          tab,
                                        cr_load_callback_t  cb,
                                        void*               userdata);
CR_EXPORT void cr_tab_set_title_callback(cr_tab_t*           tab,
                                         cr_title_callback_t  cb,
                                         void*                userdata);

/* ── Event loop ─────────────────────────────────────────────────────────── */

/* Run the Chromium message loop on the calling thread. Blocks until
   cr_quit_loop() is called from a callback or another thread. */
CR_EXPORT void cr_run_loop(void);
CR_EXPORT void cr_quit_loop(void);

/* ── Version ────────────────────────────────────────────────────────────── */

CR_EXPORT const char* cr_version(void);

#ifdef __cplusplus
}
#endif
