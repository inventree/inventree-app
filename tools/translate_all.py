#!/usr/bin/env python3
"""
Global Translation Tool for InvenTree App
Uses Gemini Flash API to translate missing strings for ALL locales.

Features:
- Auto-detects all locales in lib/l10n/
- Identifies target language from locale code (e.g. de_DE -> German)
- Global progress tracking to allow resuming
- Batch processing with rate limiting
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
import socket
from pathlib import Path

# Paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
L10N_DIR = PROJECT_ROOT / "lib" / "l10n"
EN_FILE = L10N_DIR / "app_en.arb"
PROGRESS_FILE = SCRIPT_DIR / ".global_translation_progress.json"

# Gemini API
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
DEFAULT_MODEL = "gemini-3-flash-preview"

# Locale Map (Code -> Language Name)
LOCALE_NAMES = {
    "ar_SA": "Arabic (Saudi Arabia)",
    "bg_BG": "Bulgarian",
    "cs_CZ": "Czech",
    "da_DK": "Danish",
    "de_DE": "German (Germany)",
    "el_GR": "Greek",
    "es_ES": "Spanish (Spain)",
    "es_MX": "Spanish (Mexico)",
    "et_EE": "Estonian",
    "fa_IR": "Persian",
    "fi_FI": "Finnish",
    "fr_FR": "French (France)",
    "he_IL": "Hebrew",
    "hi_IN": "Hindi",
    "hu_HU": "Hungarian",
    "id_ID": "Indonesian",
    "it_IT": "Italian",
    "ja_JP": "Japanese",
    "ko_KR": "Korean",
    "lt_LT": "Lithuanian",
    "lv_LV": "Latvian",
    "nl_NL": "Dutch",
    "no_NO": "Norwegian",
    "pl_PL": "Polish",
    "pt_BR": "Portuguese (Brazil)",
    "pt_PT": "Portuguese (Portugal)",
    "ro_RO": "Romanian",
    "ru_RU": "Russian",
    "sk_SK": "Slovak",
    "sl_SI": "Slovenian",
    "sr_CS": "Serbian",
    "sv_SE": "Swedish",
    "th_TH": "Thai",
    "tr_TR": "Turkish",
    "uk_UA": "Ukrainian",
    "vi_VN": "Vietnamese",
    "zh_CN": "Chinese (Simplified)",
    "zh_TW": "Chinese (Traditional)",
}

def get_language_name(locale_code: str) -> str:
    """Get readable language name from locale code (e.g. 'es_MX' -> 'Spanish (Mexico)')."""
    if locale_code in LOCALE_NAMES:
        return LOCALE_NAMES[locale_code]
    
    # Fallback to base language
    base = locale_code.split("_")[0]
    return LOCALE_NAMES.get(base, f"Language ({locale_code})")

def load_arb(path: Path) -> dict:
    """Load ARB file as JSON."""
    if not path.exists():
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def save_arb(path: Path, data: dict):
    """Save ARB file."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def load_progress() -> dict:
    """Load global progress state."""
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, "r") as f:
            return json.load(f)
    return {}

def save_progress(progress: dict):
    """Save global progress state."""
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)

def get_translation_keys(en_data: dict, target_data: dict, processed_keys: list, limit: int = None) -> list:
    """Find keys that need translation."""
    keys_to_translate = []
    already_done = set(processed_keys)
    
    for key in en_data.keys():
        if key.startswith("@") or key == "@@locale":
            continue
        
        if key in already_done:
            continue
        
        # Check if needs translation
        target_val = target_data.get(key, "")
        en_val = en_data.get(key, "")
        
        # Criteria: 
        # 1. Missing in target
        # 2. Key exists but value is empty
        # 3. Value equals English (untranslated) - ONLY if English value is not empty
        needs_trans = False
        if key not in target_data:
            needs_trans = True
        elif not target_val:
            needs_trans = True
        elif target_val == en_val and en_val: # Avoid false positives on empty strings
            needs_trans = True
            
        if needs_trans:
            keys_to_translate.append(key)
        
        if limit and len(keys_to_translate) >= limit:
            break
            
    return keys_to_translate

def translate_with_gemini(text: str, key: str, target_lang: str, model: str) -> str:
    """Translate text using Gemini API."""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GEMINI_API_KEY}"
    
    prompt = f"""Translate this UI text to {target_lang} for an inventory management mobile app.

Context: Key "{key}"
Rules:
- Concise and professional
- Use common terminology for {target_lang}
- Maintain technical terms if appropriate (e.g. API, URL)
- Return ONLY the translation
- No quotes

English: {text}
{target_lang}:"""

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.3, "maxOutputTokens": 256}
    }
    
    # Retry logic (simplified)
    for attempt in range(3):
        try:
            req = urllib.request.Request(
                url, 
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=30) as response:
                res = json.loads(response.read().decode("utf-8"))
                trans = res["candidates"][0]["content"]["parts"][0]["text"].strip()
                return trans.strip('"\'')
        except urllib.error.HTTPError as e:
            error_body = e.read().decode("utf-8")
            if attempt < 2:
                time.sleep(2 * (attempt + 1))
            else:
                print(f"    ❌ API Error: {e.code} - {error_body}")
                return None
        except Exception as e:
            if attempt < 2:
                time.sleep(2 * (attempt + 1))
            else:
                print(f"    ❌ Error: {e}")
                return None
    return None

def process_locale(locale_dir: Path, en_data: dict, global_progress: dict, args):
    """Process a single locale directory."""
    locale_code = locale_dir.name
    lang_name = get_language_name(locale_code)
    arb_file = locale_dir / f"app_{locale_code}.arb"
    
    if not arb_file.exists():
        return

    # Initialize progress for this locale
    if locale_code not in global_progress:
        global_progress[locale_code] = {"translated": [], "failed": []}
    
    target_data = load_arb(arb_file)
    processed = global_progress[locale_code]["translated"]
    
    # Determine limit (None means unlimited)
    limit = args.limit
    
    keys = get_translation_keys(en_data, target_data, processed, limit)
    
    if not keys:
        return

    print(f"\n🌍 {locale_code} ({lang_name}): Found {len(keys)} missing keys")
    
    # Process batch
    batch_size = args.batch
    batch = keys[:batch_size] if limit is None else keys[:min(batch_size, limit)] 
    # If no limit (None), proceed with batch unless explicit limit prevents it. 
    # Actually if limit is None, keys contains ALL missing keys.
    # We should stick to batch size for API safety, but iterate until done if user wants "no limit" behavior?
    # User said "run everything without limits". 
    # So if args.limit is None, we process ALL keys.
    
    if args.limit is None:
        batch = keys # Process ALL
    else:
        batch = keys[:args.limit]

    # Chunking for API calls (process in chunks of 'batch_size' to save progress frequently)
    chunk_size = args.batch 
    
    total_processed = 0
    
    for i in range(0, len(batch), chunk_size):
        chunk = batch[i:i+chunk_size]
        
        print(f"  📦 Processing chunk {i//chunk_size + 1} ({len(chunk)} keys)...")
        
        if args.dry_run:
            for k in chunk:
                print(f"    [DRY] {k} -> {lang_name}")
            continue

        for key in chunk:
            en_text = en_data[key]
            trans = translate_with_gemini(en_text, key, lang_name, args.model)
            
            if trans:
                target_data[key] = trans
                global_progress[locale_code]["translated"].append(key)
                print(f"    ✅ {key}: {trans}")
            else:
                global_progress[locale_code]["failed"].append(key)
                print(f"    ❌ {key}: FAILED")
            
            time.sleep(0.5) # Slight delay
        
        # Save after chunk
        save_arb(arb_file, target_data)
        save_progress(global_progress)
        total_processed += len(chunk)

    print(f"  💾 Saved {locale_code}")

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch", type=int, default=10, help="Chunk size for saving")
    parser.add_argument("--limit", type=int, default=None, help="Limit total keys per locale (default: None = all)")
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--locale", type=str, help="Run for specific locale only")
    args = parser.parse_args()

    print("🚀 Global Translation Tool Starting...")
    if not GEMINI_API_KEY:
        print("❌ GEMINI_API_KEY not set!")
        sys.exit(1)

    en_data = load_arb(EN_FILE)
    global_progress = load_progress()

    locales = [d for d in L10N_DIR.iterdir() if d.is_dir() and d.name != "collected"]
    locales.sort()

    for locale_dir in locales:
        if args.locale and args.locale != locale_dir.name:
            continue
            
        process_locale(locale_dir, en_data, global_progress, args)

    print("\n✨ All Done!")

if __name__ == "__main__":
    main()
