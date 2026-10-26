from __future__ import annotations

import json
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[1]
INPUT = Path(r"C:\Users\Mary Jasmine\Downloads\Drive File Links.xlsx")
DATA_DIR = ROOT / "backend" / "data"


def read_sheet_rows(path: Path) -> list[tuple[str, str]]:
    ns = {"a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(path) as zf:
        shared = []
        if "xl/sharedStrings.xml" in zf.namelist():
            tree = ElementTree.fromstring(zf.read("xl/sharedStrings.xml"))
            for item in tree.findall("a:si", ns):
                shared.append("".join(t.text or "" for t in item.findall(".//a:t", ns)))

        sheet = ElementTree.fromstring(zf.read("xl/worksheets/sheet1.xml"))
        rows = []
        for row in sheet.findall(".//a:sheetData/a:row", ns):
            values = {}
            for cell in row.findall("a:c", ns):
                ref = cell.attrib.get("r", "")
                col = re.sub(r"\d+", "", ref)
                value_node = cell.find("a:v", ns)
                if value_node is None:
                    value = ""
                elif cell.attrib.get("t") == "s":
                    value = shared[int(value_node.text or "0")]
                else:
                    value = value_node.text or ""
                values[col] = value
            rows.append((values.get("A", "").strip(), values.get("B", "").strip()))
    return rows[1:]


def drive_download(url: str) -> str:
    match = re.search(r"/d/([^/]+)", url) or re.search(r"[?&]id=([^&]+)", url)
    if not match:
        return url.strip()
    file_id = match.group(1)
    return (
        "https://drive.usercontent.google.com/download"
        f"?id={file_id}&export=download&confirm=t"
    )


def title_case(value: str) -> str:
    clean = re.sub(r"[_-]+", " ", value)
    clean = re.sub(r"\s+", " ", clean).strip()
    return " ".join(part[:1].upper() + part[1:].lower() for part in clean.split(" "))


def key_for(value: str, index: int) -> str:
    key = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return key or f"word_{index}"


def main() -> None:
    rows = [
        (name.strip(), drive_download(url))
        for name, url in read_sheet_rows(INPUT)
        if name.strip() and url.strip()
    ]

    alpha_urls = {name.upper(): url for name, url in rows if re.fullmatch(r"[A-Za-z]", name)}
    number_urls = {}
    for name, url in rows:
        match = re.fullmatch(r"no\.\s*(\d+)(?:\.mp4)?", name, flags=re.IGNORECASE)
        if match:
            number_urls[int(match.group(1))] = url

    alphabet_signs = [
        {
            "id": letter,
            "letter": letter,
            "title": f"Letter {letter}",
            "image_asset": f"assets/images/alphabets/{letter}.png",
            "image_url": "",
            "video_asset": "",
            "video_url": alpha_urls.get(letter, ""),
            "description": f"ASL hand sign for letter {letter}.",
            "sort_order": index + 1,
            "is_active": True,
        }
        for index, letter in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    ]

    number_signs = [
        {
            "id": str(number),
            "number": number,
            "title": f"Number {number}",
            "image_asset": f"assets/images/numbers/{number}.png",
            "image_url": "",
            "video_asset": "",
            "video_url": number_urls.get(number, ""),
            "description": f"ASL hand sign for number {number}.",
            "sort_order": number,
            "is_active": True,
        }
        for number in range(1, 21)
    ]

    used_keys: dict[str, int] = {}
    basic_words = []
    for name, url in rows:
        if re.fullmatch(r"[A-Za-z]", name):
            continue
        if re.fullmatch(r"no\.\s*\d+(?:\.mp4)?", name, flags=re.IGNORECASE):
            continue

        raw_title = re.sub(r"\.mp4$", "", name, flags=re.IGNORECASE).strip()
        title = title_case(raw_title)
        base_key = key_for(raw_title, len(basic_words) + 1)
        used_keys[base_key] = used_keys.get(base_key, 0) + 1
        key = base_key if used_keys[base_key] == 1 else f"{base_key}_{used_keys[base_key]}"
        basic_words.append(
            {
                "id": key,
                "key": key,
                "title": title,
                "category": "Basic Words",
                "image_asset": "",
                "image_url": "",
                "video_asset": "",
                "video_url": url,
                "description": f"ASL sign tutorial for {title}.",
                "sort_order": len(basic_words) + 1,
                "is_active": True,
            }
        )

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    (DATA_DIR / "alphabet-signs.json").write_text(json.dumps(alphabet_signs, indent=2), encoding="utf-8")
    (DATA_DIR / "number-signs.json").write_text(json.dumps(number_signs, indent=2), encoding="utf-8")
    (DATA_DIR / "basic-words.json").write_text(json.dumps(basic_words, indent=2), encoding="utf-8")

    print(
        json.dumps(
            {
                "alphabet_videos": sum(1 for item in alphabet_signs if item["video_url"]),
                "number_videos": sum(1 for item in number_signs if item["video_url"]),
                "basic_word_videos": len(basic_words),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
