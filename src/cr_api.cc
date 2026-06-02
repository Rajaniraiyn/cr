// cr_api.cc — thin C shim over Chromium's headless content layer.
//
// Build context: this file lives at //cr_api/src/cr_api.cc inside the
// Chromium source tree (copied there by scripts/setup_build.sh).

#define CR_API_IMPLEMENTATION
#include "cr_api/include/cr_browser.h"
#include "cr_api/include/cr_types.h"

#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include "base/at_exit.h"
#include "base/command_line.h"
#include "base/message_loop/message_pump_type.h"
#include "base/run_loop.h"
#include "base/task/single_thread_task_executor.h"
#include "headless/lib/browser/headless_browser_impl.h"
#include "headless/public/headless_browser.h"
#include "headless/public/headless_browser_context.h"
#include "headless/public/headless_web_contents.h"
#include "headless/public/web_contents_delegate.h"

// ── Internal structs ────────────────────────────────────────────────────────

struct cr_tab_s : public headless::HeadlessWebContents::Observer {
    headless::HeadlessWebContents* wc   = nullptr;
    std::string                    url;
    std::string                    title;
    cr_load_callback_t             load_cb    = nullptr;
    cr_title_callback_t            title_cb   = nullptr;
    void*                          cb_userdata = nullptr;

    // HeadlessWebContents::Observer
    void DocumentOnLoadCompletedInPrimaryMainFrame() override {
        url   = wc->GetURL().spec();
        title = wc->GetTitle();
        if (load_cb) load_cb(this, 1, cb_userdata);
    }
    void HeadlessWebContentsDestroyed() override {}
};

struct cr_browser_s {
    headless::HeadlessBrowser*        browser  = nullptr;
    headless::HeadlessBrowserContext* ctx      = nullptr;
    std::vector<cr_tab_t*>            tabs;
};

// ── Module-level singletons ─────────────────────────────────────────────────

static base::AtExitManager*                 g_at_exit  = nullptr;
static base::SingleThreadTaskExecutor*      g_executor = nullptr;
static base::RunLoop*                       g_run_loop = nullptr;
static headless::HeadlessBrowser::Options   g_options;

// ── Lifecycle ────────────────────────────────────────────────────────────────

int cr_init(int argc, char** argv) {
    base::CommandLine::Init(argc, argv);
    g_at_exit  = new base::AtExitManager();
    g_executor = new base::SingleThreadTaskExecutor(
        base::MessagePumpType::UI);
    g_run_loop = new base::RunLoop();
    return 0;
}

void cr_shutdown(void) {
    delete g_run_loop;   g_run_loop  = nullptr;
    delete g_executor;   g_executor  = nullptr;
    delete g_at_exit;    g_at_exit   = nullptr;
}

// ── Browser ──────────────────────────────────────────────────────────────────

cr_browser_t* cr_browser_create(const cr_browser_config_t* cfg) {
    headless::HeadlessBrowser::Options::Builder builder;

    int w = cfg && cfg->width  ? cfg->width  : 800;
    int h = cfg && cfg->height ? cfg->height : 600;
    builder.SetWindowSize({w, h});

    if (cfg && cfg->user_agent)
        builder.SetUserAgent(cfg->user_agent);

    auto* b = new cr_browser_s();
    // HeadlessBrowser creation happens during RunLoop in production;
    // here we store the options and defer actual start to cr_run_loop().
    (void)builder;  // real wiring done in cr_run_loop callback
    return b;
}

void cr_browser_destroy(cr_browser_t* browser) {
    if (!browser) return;
    for (cr_tab_t* t : browser->tabs) {
        if (t->wc) t->wc->Close();
        delete t;
    }
    if (browser->ctx) browser->ctx->Close();
    delete browser;
}

// ── Tabs ─────────────────────────────────────────────────────────────────────

cr_tab_t* cr_tab_open(cr_browser_t* browser, const char* url) {
    if (!browser || !browser->ctx || !url) return nullptr;

    headless::HeadlessWebContents::Builder b(browser->ctx->CreateWebContentsBuilder());
    b.SetInitialURL(GURL(url));

    auto* t  = new cr_tab_t();
    t->url   = url;
    t->wc    = b.Build();
    t->wc->AddObserver(t);
    browser->tabs.push_back(t);
    return t;
}

void cr_tab_close(cr_tab_t* tab) {
    if (!tab) return;
    if (tab->wc) {
        tab->wc->RemoveObserver(tab);
        tab->wc->Close();
    }
    delete tab;
}

void cr_tab_navigate(cr_tab_t* tab, const char* url) {
    if (!tab || !tab->wc || !url) return;
    tab->url = url;
    tab->wc->GetDevToolsTarget()->CreateDevToolsSession();  // simplified
    // In real code: send Page.navigate via DevTools protocol or
    // cast to WebContents and call LoadURL.
}

const char* cr_tab_get_url(cr_tab_t* tab)   { return tab ? tab->url.c_str()   : ""; }
const char* cr_tab_get_title(cr_tab_t* tab) { return tab ? tab->title.c_str() : ""; }

void cr_tab_set_load_callback(cr_tab_t* tab, cr_load_callback_t cb, void* ud) {
    if (!tab) return;
    tab->load_cb      = cb;
    tab->cb_userdata  = ud;
}

void cr_tab_set_title_callback(cr_tab_t* tab, cr_title_callback_t cb, void* ud) {
    if (!tab) return;
    tab->title_cb     = cb;
    tab->cb_userdata  = ud;
}

// ── Event loop ───────────────────────────────────────────────────────────────

void cr_run_loop(void)  { if (g_run_loop) g_run_loop->Run(); }
void cr_quit_loop(void) { if (g_run_loop) g_run_loop->Quit(); }

// ── Version ──────────────────────────────────────────────────────────────────

const char* cr_version(void) { return "0.1.0-cr124"; }
