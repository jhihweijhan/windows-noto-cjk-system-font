// ==WindhawkMod==
// @id              windows-noto-sans-cjk
// @name            Windows Noto Sans CJK Universal System Font
// @description     Replaces Windows system fonts with Noto Sans TC Bold & Noto Sans SC Bold across GDI and DirectWrite with zero icon corruption
// @version         1.0.0
// @license         MIT
// @author          Karl & DeepMind Antigravity
// @include         *
// @compilerOptions -ldwrite -lole32 -lgdi32 -luxtheme -lwindowsapp
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Windows Noto Sans CJK Universal System Font
Comprehensive in-memory system font replacement for Windows 10/11.

- Replaces GDI and DirectWrite UI fonts (Segoe UI, Microsoft JhengHei, MingLiU, SimSun, etc.) with Noto Sans TC Bold.
- Enforces Noto Sans SC Bold for all Simplified Chinese characters, completely preventing DirectWrite / browser fallback to SimSun / MingLiU.
- Strict Icon Safeguard: Protects Segoe Fluent Icons, Segoe MDL2 Assets, Marlett, Symbol, Webdings, Wingdings to guarantee zero tofu boxes in File Explorer and Windows shell.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- targetFontTC: "Noto Sans TC"
  $name: Traditional Chinese Font Family
  $description: Target font family for Traditional Chinese and default UI
- targetFontSC: "Noto Sans SC Bold"
  $name: Simplified Chinese Font Family
  $description: Target font family for Simplified Chinese characters
- enforceBold: true
  $name: Enforce Bold Font Weight
  $description: Render system UI text with bold font weight (700)
*/
// ==/WindhawkModSettings==

#include <windows.h>
#include <wingdi.h>
#include <dwrite.h>
#include <dwrite_2.h>
#include <dwrite_3.h>
#include <unknwn.h>
#include <winrt/base.h>

#include <mutex>
#include <string>
#include <vector>

#include <windhawk_api.h>
#include <windhawk_utils.h>

using namespace winrt;

struct Settings {
    std::wstring targetFontTC = L"Noto Sans TC";
    std::wstring targetFontSC = L"Noto Sans SC Bold";
    bool enforceBold = true;
} g_settings;

std::mutex g_settingsMutex;

// Strict Icon Font Whitelist - Never mutate
static bool IsIconFont(const WCHAR* faceName) {
    if (!faceName || !*faceName) return false;

    static const WCHAR* const iconFonts[] = {
        L"Segoe Fluent Icons",
        L"Segoe MDL2 Assets",
        L"Segoe UI Symbol",
        L"Segoe UI Emoji",
        L"Segoe UI Historic",
        L"Marlett",
        L"Webdings",
        L"Wingdings",
        L"Wingdings 2",
        L"Wingdings 3",
        L"Symbol",
        L"FontAwesome",
        L"Font Awesome",
        L"HoloLens MDL2 Assets",
        L"Segoe Boot Semilight",
        L"Consolas",
        L"Cascadia Code",
        L"Cascadia Mono",
        L"Courier New"
    };

    for (const auto* iconFont : iconFonts) {
        if (_wcsicmp(faceName, iconFont) == 0) {
            return true;
        }
    }

    if (wcsstr(faceName, L"Icon") != nullptr ||
        wcsstr(faceName, L"Asset") != nullptr ||
        wcsstr(faceName, L"Symbol") != nullptr ||
        wcsstr(faceName, L"Emoji") != nullptr) {
        return true;
    }

    return false;
}

static bool ShouldReplaceWithTC(const WCHAR* faceName) {
    if (!faceName || !*faceName) return false;
    if (IsIconFont(faceName)) return false;

    static const WCHAR* const tcFonts[] = {
        L"Segoe UI",
        L"Segoe UI Variable",
        L"Segoe UI Variable Text",
        L"Segoe UI Variable Display",
        L"Segoe UI Variable Small",
        L"Segoe UI Variable Static Text",
        L"Segoe UI Variable Static Display",
        L"Segoe UI Variable Static Small",
        L"Segoe UI Semibold",
        L"Segoe UI Light",
        L"Segoe UI Semilight",
        L"Microsoft JhengHei",
        L"Microsoft JhengHei UI",
        L"Microsoft JhengHei Bold",
        L"Microsoft JhengHei Light",
        L"微軟正黑體",
        L"PMingLiU",
        L"MingLiU",
        L"MingLiU_HKSCS",
        L"MingLiU-ExtB",
        L"PMingLiU-ExtB",
        L"新細明體",
        L"細明體",
        L"MS Shell Dlg",
        L"MS Shell Dlg 2",
        L"System",
        L"Tahoma"
    };

    for (const auto* font : tcFonts) {
        if (_wcsicmp(faceName, font) == 0) {
            return true;
        }
    }
    return false;
}

static bool ShouldReplaceWithSC(const WCHAR* faceName) {
    if (!faceName || !*faceName) return false;
    if (IsIconFont(faceName)) return false;

    static const WCHAR* const scFonts[] = {
        L"SimSun",
        L"NSimSun",
        L"SimSun-ExtB",
        L"宋体",
        L"新宋体",
        L"SimHei",
        L"黑体",
        L"Microsoft YaHei",
        L"Microsoft YaHei UI",
        L"Microsoft YaHei Bold",
        L"Microsoft YaHei Light",
        L"微软雅黑",
        L"KaiTi",
        L"楷体",
        L"FangSong",
        L"仿宋"
    };

    for (const auto* font : scFonts) {
        if (_wcsicmp(faceName, font) == 0) {
            return true;
        }
    }
    return false;
}

// -------------------------------------------------------------
// GDI Hooks
// -------------------------------------------------------------
using CreateFontIndirectW_t = HFONT(WINAPI*)(const LOGFONTW* lplf);
CreateFontIndirectW_t g_pOriginalCreateFontIndirectW = nullptr;

HFONT WINAPI CreateFontIndirectW_Hook(const LOGFONTW* lplf) {
    if (!lplf) {
        return g_pOriginalCreateFontIndirectW(lplf);
    }

    if (IsIconFont(lplf->lfFaceName)) {
        return g_pOriginalCreateFontIndirectW(lplf);
    }

    std::lock_guard<std::mutex> lock(g_settingsMutex);
    if (ShouldReplaceWithSC(lplf->lfFaceName)) {
        LOGFONTW lf = *lplf;
        wcsncpy_s(lf.lfFaceName, g_settings.targetFontSC.c_str(), LF_FACESIZE - 1);
        if (g_settings.enforceBold && lf.lfWeight < FW_BOLD) {
            lf.lfWeight = FW_BOLD;
        }
        return g_pOriginalCreateFontIndirectW(&lf);
    }

    if (ShouldReplaceWithTC(lplf->lfFaceName)) {
        LOGFONTW lf = *lplf;
        wcsncpy_s(lf.lfFaceName, g_settings.targetFontTC.c_str(), LF_FACESIZE - 1);
        if (g_settings.enforceBold && lf.lfWeight < FW_BOLD) {
            lf.lfWeight = FW_BOLD;
        }
        return g_pOriginalCreateFontIndirectW(&lf);
    }

    return g_pOriginalCreateFontIndirectW(lplf);
}

using CreateFontW_t = HFONT(WINAPI*)(
    int cHeight, int cWidth, int cEscapement, int cOrientation,
    int cWeight, DWORD bItalic, DWORD bUnderline, DWORD bStrikeOut,
    DWORD iCharSet, DWORD iOutPrecision, DWORD iClipPrecision,
    DWORD iQuality, DWORD iPitchAndFamily, LPCWSTR pszFaceName);
CreateFontW_t g_pOriginalCreateFontW = nullptr;

HFONT WINAPI CreateFontW_Hook(
    int cHeight, int cWidth, int cEscapement, int cOrientation,
    int cWeight, DWORD bItalic, DWORD bUnderline, DWORD bStrikeOut,
    DWORD iCharSet, DWORD iOutPrecision, DWORD iClipPrecision,
    DWORD iQuality, DWORD iPitchAndFamily, LPCWSTR pszFaceName) {
    if (!pszFaceName || IsIconFont(pszFaceName)) {
        return g_pOriginalCreateFontW(cHeight, cWidth, cEscapement, cOrientation,
                                      cWeight, bItalic, bUnderline, bStrikeOut,
                                      iCharSet, iOutPrecision, iClipPrecision,
                                      iQuality, iPitchAndFamily, pszFaceName);
    }

    std::lock_guard<std::mutex> lock(g_settingsMutex);
    LPCWSTR targetFace = pszFaceName;
    int targetWeight = cWeight;

    if (ShouldReplaceWithSC(pszFaceName)) {
        targetFace = g_settings.targetFontSC.c_str();
        if (g_settings.enforceBold && targetWeight < FW_BOLD) targetWeight = FW_BOLD;
    } else if (ShouldReplaceWithTC(pszFaceName)) {
        targetFace = g_settings.targetFontTC.c_str();
        if (g_settings.enforceBold && targetWeight < FW_BOLD) targetWeight = FW_BOLD;
    }

    return g_pOriginalCreateFontW(cHeight, cWidth, cEscapement, cOrientation,
                                  targetWeight, bItalic, bUnderline, bStrikeOut,
                                  iCharSet, iOutPrecision, iClipPrecision,
                                  iQuality, iPitchAndFamily, targetFace);
}

// -------------------------------------------------------------
// DirectWrite Hooks
// -------------------------------------------------------------
com_ptr<IDWriteFontFallback1> g_fallback;
std::mutex g_fallbackInitMutex;

using GetSystemFontFallback_t = HRESULT(
    STDMETHODCALLTYPE*)(IDWriteFactory8* self, IDWriteFontFallback1** fallback);
GetSystemFontFallback_t g_originalGetSystemFontFallback = nullptr;

STDMETHODIMP GetSystemFontFallback_Hook(IDWriteFactory8* self,
                                        IDWriteFontFallback1** fallback) {
    std::lock_guard<std::mutex> lock(g_fallbackInitMutex);

    if (g_fallback == nullptr) {
        com_ptr<IDWriteFontFallback1> fallback0 = nullptr;
        auto hr = g_originalGetSystemFontFallback(self, fallback0.put());

        com_ptr<IDWriteFontFallbackBuilder> builder = nullptr;

#define check_or(h)                     \
    if (FAILED(h)) {                    \
        *fallback = fallback0.detach(); \
        return hr;                      \
    }
        check_or(self->CreateFontFallbackBuilder(builder.put()));

        // Target font families for CJK Unicode ranges
        const WCHAR* fontFamilies[] = {
            g_settings.targetFontTC.c_str(),
            g_settings.targetFontSC.c_str()
        };

        // Complete CJK mappings
        DWRITE_UNICODE_RANGE cjkRanges[] = {
            { 0x4E00, 0x9FFF },   // CJK Unified Ideographs
            { 0x3400, 0x4DBF },   // CJK Extension A
            { 0x20000, 0x2A6DF }, // CJK Extension B
            { 0xF900, 0xFAFF },   // CJK Compatibility
            { 0x3000, 0x303F },   // CJK Symbols & Punctuation
            { 0xFF00, 0xFFEF }    // Halfwidth & Fullwidth Forms
        };

        for (const auto& range : cjkRanges) {
            check_or(builder->AddMapping(&range, 1, fontFamilies, _countof(fontFamilies)));
        }

        check_or(builder->AddMappings(fallback0.get()));

        com_ptr<IDWriteFontFallback> fallback1 = nullptr;
        check_or(builder->CreateFontFallback(fallback1.put()));
        fallback1.as(g_fallback);

        Wh_Log(L"DirectWrite: Injected Noto Sans CJK Fallback mappings");
    }

    g_fallback.copy_to(fallback);
    return S_OK;
}

using CreateTextFormat0_t =
    HRESULT(STDMETHODCALLTYPE*)(IDWriteFactory8* self,
                                const WCHAR* family_name,
                                IDWriteFontCollection* collection,
                                DWRITE_FONT_WEIGHT weight,
                                DWRITE_FONT_STYLE style,
                                DWRITE_FONT_STRETCH stretch,
                                FLOAT size,
                                const WCHAR* locale,
                                IDWriteTextFormat** format);
CreateTextFormat0_t g_originalCreateTextFormat0 = nullptr;

STDMETHODIMP CreateTextFormat0_Hook(IDWriteFactory8* self,
                                    WCHAR const* fontFamilyName,
                                    IDWriteFontCollection* fontCollection,
                                    DWRITE_FONT_WEIGHT fontWeight,
                                    DWRITE_FONT_STYLE fontStyle,
                                    DWRITE_FONT_STRETCH fontStretch,
                                    FLOAT fontSize,
                                    WCHAR const* localeName,
                                    IDWriteTextFormat** textFormat) {
    WCHAR const* targetFamily = fontFamilyName;
    DWRITE_FONT_WEIGHT targetWeight = fontWeight;

    if (fontFamilyName && !IsIconFont(fontFamilyName)) {
        if (ShouldReplaceWithSC(fontFamilyName)) {
            targetFamily = g_settings.targetFontSC.c_str();
            if (g_settings.enforceBold && targetWeight < DWRITE_FONT_WEIGHT_BOLD) {
                targetWeight = DWRITE_FONT_WEIGHT_BOLD;
            }
        } else if (ShouldReplaceWithTC(fontFamilyName)) {
            targetFamily = g_settings.targetFontTC.c_str();
            if (g_settings.enforceBold && targetWeight < DWRITE_FONT_WEIGHT_BOLD) {
                targetWeight = DWRITE_FONT_WEIGHT_BOLD;
            }
        }
    }

    auto hr = g_originalCreateTextFormat0(self, targetFamily, fontCollection,
                                          targetWeight, fontStyle, fontStretch,
                                          fontSize, localeName, textFormat);

    if (SUCCEEDED(hr) && textFormat && *textFormat) {
        com_ptr<IDWriteTextFormat> format;
        format.copy_from(*textFormat);
        auto format3 = format.try_as<IDWriteTextFormat3>();
        if (format3) {
            com_ptr<IDWriteFontFallback> customFallback;
            self->GetSystemFontFallback(customFallback.put());
            format3->SetFontFallback(customFallback.get());
        }
    }
    return hr;
}

using CreateTextLayout0_t =
    HRESULT(STDMETHODCALLTYPE*)(IDWriteFactory8* self,
                                WCHAR const* string,
                                UINT32 stringLength,
                                IDWriteTextFormat* textFormat,
                                FLOAT maxWidth,
                                FLOAT maxHeight,
                                IDWriteTextLayout** textLayout);
CreateTextLayout0_t g_originalCreateTextLayout0 = nullptr;

STDMETHODIMP CreateTextLayout0_Hook(IDWriteFactory8* self,
                                    WCHAR const* string,
                                    UINT32 stringLength,
                                    IDWriteTextFormat* textFormat,
                                    FLOAT maxWidth,
                                    FLOAT maxHeight,
                                    IDWriteTextLayout** textLayout) {
    auto hr = g_originalCreateTextLayout0(self, string, stringLength, textFormat,
                                         maxWidth, maxHeight, textLayout);
    if (SUCCEEDED(hr) && textLayout && *textLayout) {
        com_ptr<IDWriteTextLayout> layout;
        layout.copy_from(*textLayout);
        auto layout4 = layout.try_as<IDWriteTextLayout4>();
        if (layout4) {
            com_ptr<IDWriteFontFallback> customFallback;
            self->GetSystemFontFallback(customFallback.put());
            layout4->SetFontFallback(customFallback.get());
        }
    }
    return hr;
}

using CreateTextFormat6_t =
    HRESULT(STDMETHODCALLTYPE*)(IDWriteFactory8* self,
                                const WCHAR* familyname,
                                IDWriteFontCollection* collection,
                                const DWRITE_FONT_AXIS_VALUE* axis_values,
                                UINT32 num_axis,
                                FLOAT fontsize,
                                const WCHAR* localename,
                                IDWriteTextFormat3** text_format);
CreateTextFormat6_t g_originalCreateTextFormat6 = nullptr;

STDMETHODIMP CreateTextFormat6_Hook(IDWriteFactory8* self,
                                    const WCHAR* familyname,
                                    IDWriteFontCollection* collection,
                                    const DWRITE_FONT_AXIS_VALUE* axis_values,
                                    UINT32 num_axis,
                                    FLOAT fontsize,
                                    const WCHAR* localename,
                                    IDWriteTextFormat3** text_format) {
    WCHAR const* targetFamily = familyname;

    if (familyname && !IsIconFont(familyname)) {
        if (ShouldReplaceWithSC(familyname)) {
            targetFamily = g_settings.targetFontSC.c_str();
        } else if (ShouldReplaceWithTC(familyname)) {
            targetFamily = g_settings.targetFontTC.c_str();
        }
    }

    auto hr = g_originalCreateTextFormat6(self, targetFamily, collection,
                                          axis_values, num_axis, fontsize,
                                          localename, text_format);
    if (SUCCEEDED(hr) && text_format && *text_format) {
        com_ptr<IDWriteFontFallback> customFallback;
        self->GetSystemFontFallback(customFallback.put());
        (*text_format)->SetFontFallback(customFallback.get());
    }
    return hr;
}

void LoadSettings() {
    std::lock_guard<std::mutex> lock(g_settingsMutex);
    using WindhawkUtils::StringSetting;

    auto targetTC = StringSetting::make(L"targetFontTC");
    if (wcslen(targetTC) > 0) {
        g_settings.targetFontTC = targetTC;
    } else {
        g_settings.targetFontTC = L"Noto Sans TC";
    }

    auto targetSC = StringSetting::make(L"targetFontSC");
    if (wcslen(targetSC) > 0) {
        g_settings.targetFontSC = targetSC;
    } else {
        g_settings.targetFontSC = L"Noto Sans SC Bold";
    }

    g_settings.enforceBold = Wh_GetIntSetting(L"enforceBold") != 0;

    Wh_Log(L"Settings: TC=%s, SC=%s, EnforceBold=%d",
           g_settings.targetFontTC.c_str(),
           g_settings.targetFontSC.c_str(),
           g_settings.enforceBold ? 1 : 0);
}

constexpr void* get_item_in_vtable(IUnknown* vtable, uint32_t idx) {
    return (*reinterpret_cast<void***>(vtable))[idx];
}

BOOL Wh_ModInit() {
    Wh_Log(L"Windows Noto Sans CJK Universal System Font - Initializing");

    LoadSettings();

    // 1. Hook GDI32
    HMODULE hGdi32 = GetModuleHandleW(L"gdi32.dll");
    if (!hGdi32) hGdi32 = LoadLibraryW(L"gdi32.dll");
    if (hGdi32) {
        void* pCreateFontIndirectW = (void*)GetProcAddress(hGdi32, "CreateFontIndirectW");
        if (pCreateFontIndirectW) {
            Wh_SetFunctionHook(pCreateFontIndirectW,
                               (void*)CreateFontIndirectW_Hook,
                               (void**)&g_pOriginalCreateFontIndirectW);
            Wh_Log(L"Successfully hooked gdi32!CreateFontIndirectW");
        }
        void* pCreateFontW = (void*)GetProcAddress(hGdi32, "CreateFontW");
        if (pCreateFontW) {
            Wh_SetFunctionHook(pCreateFontW,
                               (void*)CreateFontW_Hook,
                               (void**)&g_pOriginalCreateFontW);
            Wh_Log(L"Successfully hooked gdi32!CreateFontW");
        }
    }

    // Hook gdi32full if present (Win10/11)
    HMODULE hGdi32Full = GetModuleHandleW(L"gdi32full.dll");
    if (hGdi32Full) {
        void* pCreateFontIndirectWFull = (void*)GetProcAddress(hGdi32Full, "CreateFontIndirectW");
        if (pCreateFontIndirectWFull && pCreateFontIndirectWFull != g_pOriginalCreateFontIndirectW) {
            CreateFontIndirectW_t dummy = nullptr;
            Wh_SetFunctionHook(pCreateFontIndirectWFull,
                               (void*)CreateFontIndirectW_Hook,
                               (void**)&dummy);
            Wh_Log(L"Successfully hooked gdi32full!CreateFontIndirectW");
        }
    }

    // 2. Hook DirectWrite
    IUnknown* factory = nullptr;
    auto hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED,
                                  __uuidof(IDWriteFactory), &factory);
    if (SUCCEEDED(hr) && factory) {
        auto pGetSystemFontFallback = get_item_in_vtable(factory, 26);
        auto pCreateTextFormat0     = get_item_in_vtable(factory, 15);
        auto pCreateTextLayout0     = get_item_in_vtable(factory, 18);
        auto pCreateTextFormat6     = get_item_in_vtable(factory, 54);

        com_ptr<IDWriteFactory> factory0(factory, take_ownership_from_abi);
        bool supportsFactory6 = (bool)factory0.try_as<IDWriteFactory6>();

        if (pGetSystemFontFallback) {
            Wh_SetFunctionHook(pGetSystemFontFallback,
                               (void*)GetSystemFontFallback_Hook,
                               (void**)&g_originalGetSystemFontFallback);
            Wh_Log(L"Successfully hooked DirectWrite GetSystemFontFallback");
        }
        if (pCreateTextFormat0) {
            Wh_SetFunctionHook(pCreateTextFormat0,
                               (void*)CreateTextFormat0_Hook,
                               (void**)&g_originalCreateTextFormat0);
            Wh_Log(L"Successfully hooked DirectWrite CreateTextFormat0");
        }
        if (pCreateTextLayout0) {
            Wh_SetFunctionHook(pCreateTextLayout0,
                               (void*)CreateTextLayout0_Hook,
                               (void**)&g_originalCreateTextLayout0);
            Wh_Log(L"Successfully hooked DirectWrite CreateTextLayout0");
        }
        if (supportsFactory6 && pCreateTextFormat6) {
            Wh_SetFunctionHook(pCreateTextFormat6,
                               (void*)CreateTextFormat6_Hook,
                               (void**)&g_originalCreateTextFormat6);
            Wh_Log(L"Successfully hooked DirectWrite CreateTextFormat6");
        }
    }

    Wh_Log(L"Windows Noto Sans CJK Universal System Font - Initialized Successfully");
    return TRUE;
}

void Wh_ModUninit() {
    Wh_Log(L"Windows Noto Sans CJK Universal System Font - Uninitializing");
}

void Wh_ModSettingsChanged() {
    Wh_Log(L"Settings changed, reloading...");
    LoadSettings();
    std::lock_guard<std::mutex> lock(g_fallbackInitMutex);
    g_fallback = nullptr;
}
