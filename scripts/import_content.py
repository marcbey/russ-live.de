#!/usr/bin/env python3
"""Import starter content and assets for the standalone Russ Live prototype.

The script intentionally writes only inside this project. Stuttgart-live is not
read or modified; event integration remains a read-only placeholder.
"""

from __future__ import annotations

import html
import json
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
TMP = Path("/tmp")
BASE_URL = "https://www.michaelrussgmbh.de"

LOCAL_ASSETS = {
    "assets/fonts/NeueRational-Light.woff2": Path("/Users/kathi/Russ-lokal/Arbeiten/2024_RELAUNCH/Fonts/Studio_Rene_Bieder_Order_1702427712586580158/Russ_Fonts/Web/Neue Rational/NeueRational-Light.woff2"),
    "assets/fonts/NeueRational-SemiBold.woff2": Path("/Users/kathi/Russ-lokal/Arbeiten/2024_RELAUNCH/Fonts/Studio_Rene_Bieder_Order_1702427712586580158/Russ_Fonts/Web/Neue Rational/NeueRational-SemiBold.woff2"),
    "assets/fonts/NeueRational-Light.woff": Path("/Users/kathi/Russ-lokal/Arbeiten/2024_RELAUNCH/Fonts/Studio_Rene_Bieder_Order_1702427712586580158/Russ_Fonts/Web/Neue Rational/NeueRational-Light.woff"),
    "assets/fonts/NeueRational-SemiBold.woff": Path("/Users/kathi/Russ-lokal/Arbeiten/2024_RELAUNCH/Fonts/Studio_Rene_Bieder_Order_1702427712586580158/Russ_Fonts/Web/Neue Rational/NeueRational-SemiBold.woff"),
    "assets/keyvisuals/2026_SKS_RUS_Keyvisual_Live_RGB.jpg": Path("/Users/kathi/Russ-lokal/Arbeiten/2024_RELAUNCH/Keyvisuals/Russ-live/JPG/2026_SKS_RUS_Keyvisual_Live_RGB.jpg"),
}

PAGES = {
    "home": "/",
    "about": "/unternehmen/ueber-uns/",
    "team": "/unternehmen/team/",
    "references": "/referenzen/",
    "contact": "/unternehmen/kontakt/",
    "imprint": "/impressum/",
    "privacy": "/datenschutzerklaerung/",
    "youth": "/jugendschutz/",
    "service_local": "/services/oertlicher-veranstalter/",
    "service_production": "/services/produktion-und-technik/",
    "service_marketing": "/services/marketing/",
    "service_personal": "/services/personal/",
}

SERVICE_DEFINITIONS = [
    ("local", "Örtlicher Veranstalter", "service_local"),
    ("production", "Produktion & Technik", "service_production"),
    ("marketing", "Marketing", "service_marketing"),
    ("staff", "Personal", "service_personal"),
    ("ticketing", "Ticketportal", "home"),
]


def fetch_page(key: str, path: str) -> str:
    cached = TMP / f"russ-{key.replace('_', '-')}.html"
    if cached.exists() and cached.stat().st_size > 0:
        return cached.read_text(encoding="utf-8", errors="replace")

    req = urllib.request.Request(
        f"{BASE_URL}{path}",
        headers={"User-Agent": "RussLiveRelaunchImporter/1.0"},
    )
    with urllib.request.urlopen(req, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def clean_markup(value: str) -> str:
    value = re.sub(r"<br\s*/?>", "\n", value, flags=re.I)
    value = re.sub(r"<[^>]+>", "", value)
    value = html.unescape(value)
    value = value.replace("\xa0", " ")
    value = re.sub(r"[ \t]+", " ", value)
    value = re.sub(r"\n\s+", "\n", value)
    return value.strip()


def slugify(value: str) -> str:
    value = html.unescape(value).lower()
    replacements = {
        "ä": "ae",
        "ö": "oe",
        "ü": "ue",
        "ß": "ss",
        "&": "and",
    }
    for old, new in replacements.items():
        value = value.replace(old, new)
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "asset"


def copy_local_assets() -> list[str]:
    copied = []
    for relative, source in LOCAL_ASSETS.items():
        target = ROOT / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if not source.exists():
            print(f"missing local asset: {source}", file=sys.stderr)
            continue
        shutil.copy2(source, target)
        copied.append(relative)
    return copied


def download(url: str, target_dir: Path, label: str) -> str | None:
    parsed = urlparse(html.unescape(url))
    suffix = Path(parsed.path).suffix.lower() or ".jpg"
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / f"{slugify(label)}{suffix}"

    if target.exists() and target.stat().st_size > 0:
        return str(target.relative_to(ROOT))

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "RussLiveRelaunchImporter/1.0"},
        )
        with urllib.request.urlopen(req, timeout=45) as response:
            target.write_bytes(response.read())
    except Exception as error:
        result = subprocess.run(
            ["curl", "-s", "-L", url, "-o", str(target)],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0 or not target.exists() or target.stat().st_size == 0:
            print(f"download failed: {url} ({error}; curl exit {result.returncode})", file=sys.stderr)
            return None

    return str(target.relative_to(ROOT))


def parse_team(page: str) -> list[dict[str, str]]:
    pattern = re.compile(
        r"<figure[^>]*>.*?<img[^>]+src=\"([^\"]+)\"[^>]*>.*?</figure>\s*"
        r".*?<h3[^>]*>(.*?)</h3>\s*<p>(.*?)</p>",
        flags=re.S,
    )
    team = []
    for image_url, raw_name, raw_role in pattern.findall(page):
        name = clean_markup(raw_name)
        role = clean_markup(raw_role)
        if not name or "Logo" in name:
            continue
        asset = download(image_url, ROOT / "assets/team", name)
        team.append({
            "name": name,
            "role": role,
            "image": asset or "",
        })
    return team


def parse_references(page: str) -> list[dict[str, str]]:
    noscript_match = re.search(r"<noscript>(.*?)</noscript>", page, flags=re.S)
    source = noscript_match.group(1) if noscript_match else page
    pattern = re.compile(r"<img[^>]+src='([^']+)'[^>]+alt='([^']*)'", flags=re.S)
    references = []
    seen = set()
    for index, (image_url, raw_title) in enumerate(pattern.findall(source), start=1):
        title = clean_markup(raw_title) or f"Referenz {index}"
        key = (image_url, title)
        if key in seen:
            continue
        seen.add(key)
        asset = download(image_url, ROOT / "assets/references", f"{index:02d}-{title}")
        references.append({
            "title": title,
            "image": asset or "",
            "size": ["large", "medium", "small"][index % 3],
            "year": "",
        })
    return references


def extract_main_text(page: str, max_paragraphs: int = 5) -> list[str]:
    paragraphs = []
    for raw in re.findall(r"<p[^>]*>(.*?)</p>", page, flags=re.S):
        text = clean_markup(raw)
        if not text or text == "\u00a0" or "Aktuelle Veranstaltungen" in text:
            continue
        if "Tickets & mehr Infos" in text or "Das Ticketportal mit allen" in text:
            continue
        if "Alle\nVeranstaltungen" in text or "Alle Veranstaltungen" in text:
            continue
        paragraphs.append(text)
        if len(paragraphs) >= max_paragraphs:
            break
    return paragraphs


def parse_services(pages: dict[str, str]) -> list[dict[str, object]]:
    services = []
    for slug, title, key in SERVICE_DEFINITIONS:
        paragraphs = extract_main_text(pages[key], max_paragraphs=3)
        if slug == "ticketing":
            paragraphs = [
                "Stuttgart-live ist das Ticketportal mit allen wichtigen Veranstaltungen in der Region Stuttgart: online buchen, schnell, unkompliziert und mit perfektem Service.",
                "Die Eventdaten bleiben perspektivisch read-only angebunden. Diese Russ-live-Seite greift später nur auf freigegebene Veranstaltungsdaten zu.",
            ]
        services.append({
            "slug": slug,
            "title": title,
            "kicker": "Servicebereich",
            "summary": paragraphs[0] if paragraphs else "",
            "body": paragraphs,
        })
    return services


def build_content() -> dict[str, object]:
    pages = {key: fetch_page(key, path) for key, path in PAGES.items()}
    logo = download(f"{BASE_URL}/wp-content/themes/michaelrussgmbh/img/logo.svg", ROOT / "assets/logos", "michael-russ-logo")

    return {
        "meta": {
            "source": BASE_URL,
            "generated_note": "Starter content imported for the standalone Russ Live relaunch prototype. Review rights and copy before production.",
            "stuttgart_live_boundary": "No stuttgart-live files, database, routes, or assets are modified by this project.",
        },
        "assets": {
            "logo": logo or "",
            "keyvisual": "assets/keyvisuals/2026_SKS_RUS_Keyvisual_Live_RGB.jpg",
            "font_light": "assets/fonts/NeueRational-Light.woff2",
            "font_semibold": "assets/fonts/NeueRational-SemiBold.woff2",
        },
        "home": {
            "headline": "Kulturproduktionen auf höchstem Niveau",
            "intro": extract_main_text(pages["home"], max_paragraphs=2),
        },
        "about": {
            "title": "Über uns",
            "body": extract_main_text(pages["about"], max_paragraphs=6),
        },
        "services": parse_services(pages),
        "team": parse_team(pages["team"]),
        "references": parse_references(pages["references"]),
        "contact": {
            "title": "Kontakt",
            "body": extract_main_text(pages["contact"], max_paragraphs=5),
        },
        "legal": {
            "imprint": extract_main_text(pages["imprint"], max_paragraphs=8),
            "privacy": extract_main_text(pages["privacy"], max_paragraphs=8),
            "youth": extract_main_text(pages["youth"], max_paragraphs=8),
        },
        "events_placeholder": [
            {
                "title": "Read-only Event-Adapter",
                "date": "später",
                "venue": "Stuttgart-live",
                "url": "https://stuttgart-live.de/",
            }
        ],
    }


def main() -> None:
    copied = copy_local_assets()
    content = build_content()
    content["meta"]["copied_local_assets"] = copied

    target = ROOT / "content/site.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(content, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"wrote {target.relative_to(ROOT)}")
    print(f"team profiles: {len(content['team'])}")
    print(f"references: {len(content['references'])}")
    print(f"local assets: {len(copied)}")


if __name__ == "__main__":
    main()
