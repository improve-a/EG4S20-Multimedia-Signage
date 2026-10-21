#!/usr/bin/env python3
"""Build and verify an isolated lossless two-bank HFXL palette candidate.

This tool never edits its source layers or production media/RTL assets. It
expands each page palette to 1024 words so software goldens can directly
decode page_palette[new_index], while exporting a shared 2048xRGB bank ROM.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path


PAGE_COUNT = 6
WIDTH = 640
HEIGHT = 480
BG_STRIDE = 214
BG_WORDS = BG_STRIDE * HEIGHT
PALETTE_WORDS = 512
EXPANDED_PALETTE_WORDS = 1024
PANEL_BASE_WORDS = 1_843_200


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def rgb_word(rgb: int) -> int:
    return (rgb & 0xFFFFFF) << 8


def parse_page(layers: Path, page_meta: dict, expected_set_id: int) -> dict:
    path = layers / page_meta["path"]
    data = path.read_bytes()
    if len(data) % 4:
        raise ValueError(f"{path.name}: payload is not word aligned")
    words = list(struct.unpack("<" + "I" * (len(data) // 4), data))
    if len(words) < 64:
        raise ValueError(f"{path.name}: short header")
    header = words[:16]
    if (header[0] != 0x4C584648 or header[1] != 1 or header[13] != expected_set_id
            or header[14] != page_meta["global_word_base"]
            or header[15] != page_meta["page_index"]):
        raise ValueError(f"{path.name}: HFXL identity mismatch")
    if (header[4], header[5], header[7], header[10], header[11]) != (64, 8, BG_STRIDE, WIDTH, HEIGHT):
        raise ValueError(f"{path.name}: unsupported HFXL geometry/layout")
    if header[2] != len(words) or page_meta["payload_words"] != len(words):
        raise ValueError(f"{path.name}: payload length mismatch")
    palette_off, palette_entries = header[8], header[9]
    bg_off, tex_off = header[6], header[12]
    desc_count = header[3]
    desc_off = header[4]
    if not (0 <= desc_count <= 16 and 0 < palette_entries <= PALETTE_WORDS):
        raise ValueError(f"{path.name}: invalid descriptor or palette count")
    if palette_off != page_meta["palette_word_offset"] or bg_off != page_meta["bg_word_offset"]:
        raise ValueError(f"{path.name}: manifest offsets mismatch")
    if bg_off != palette_off + PALETTE_WORDS or tex_off < bg_off + BG_WORDS:
        raise ValueError(f"{path.name}: expected 512-entry palette immediately before BG")
    if any(w & 0xFF for w in words[palette_off:palette_off + PALETTE_WORDS]):
        raise ValueError(f"{path.name}: palette low byte must be zero")
    palette = [words[palette_off + i] >> 8 for i in range(palette_entries)]
    if len(set(palette)) != len(palette):
        raise ValueError(f"{path.name}: valid palette entries contain duplicate RGB")
    if any(words[palette_off + i] != 0 for i in range(palette_entries, PALETTE_WORDS)):
        raise ValueError(f"{path.name}: nonzero unused palette padding")
    if any(words[bg_off + i] >> 30 for i in range(BG_WORDS)):
        raise ValueError(f"{path.name}: BG index word top two bits are nonzero")

    used_indices: set[int] = set()
    pixels = bytearray()
    for y in range(HEIGHT):
        row = bg_off + y * BG_STRIDE
        for x in range(WIDTH):
            word = words[row + x // 3]
            index = (word >> ((x % 3) * 10)) & 0x3FF
            if index >= palette_entries:
                raise ValueError(f"{path.name}: BG index {index} outside valid palette at {x},{y}")
            used_indices.add(index)
            rgb = palette[index]
            pixels.extend(((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255))
        if words[row + BG_STRIDE - 1] >> 10:
            raise ValueError(f"{path.name}: unused last-word lanes are not zero at row {y}")

    texel_words = 0
    descriptor_snapshots = []
    for ci in range(desc_count):
        off = desc_off + ci * 8
        desc = words[off:off + 8]
        tex_offset, texels = desc[3], desc[6]
        if tex_offset < tex_off or tex_offset + texels > len(words):
            raise ValueError(f"{path.name}: descriptor {ci} texture extent is invalid")
        texel_words += texels
        descriptor_snapshots.append((off, desc))
    if tex_off > len(words) or bg_off + BG_WORDS > tex_off:
        raise ValueError(f"{path.name}: invalid texture start")

    return dict(
        meta=page_meta, path=path, original=data, words=words, header=header,
        palette=palette, used_indices=used_indices, pixels=bytes(pixels),
        palette_off=palette_off, bg_off=bg_off, tex_off=tex_off,
        desc_count=desc_count, descriptors=descriptor_snapshots,
        rgba_texel_words=texel_words,
    )


def encode_indices(page: dict, rgb_to_slot: dict[int, tuple[int, int]]) -> tuple[list[int], list[dict]]:
    """Return new BG words plus source palette-index mapping records."""
    words = page["words"]
    old_bg = page["bg_off"]
    palette = page["palette"]
    new_bg_words = []
    source_map = []
    seen = set()
    for source_index, rgb in enumerate(palette):
        bank, index = rgb_to_slot[rgb]
        source_map.append(dict(source_index=source_index, rgb=f"{rgb:06x}", bank=bank, index=index))
    for y in range(HEIGHT):
        row_start = old_bg + y * BG_STRIDE
        for group in range(BG_STRIDE):
            value = 0
            for lane in range(3):
                x = group * 3 + lane
                if x >= WIDTH:
                    continue
                old_word = words[row_start + group]
                source_index = (old_word >> (lane * 10)) & 0x3FF
                rgb = palette[source_index]
                bank, index = rgb_to_slot[rgb]
                if index > 1023:
                    raise ValueError("mapped palette index exceeds 10-bit range")
                if bank not in (0, 1):
                    raise ValueError("bank must fit in one bit")
                seen.add((bank, index))
                value |= index << (lane * 10)
            new_bg_words.append(value)
    return new_bg_words, source_map


def make_layout(manifest: dict) -> str:
    lines = [
        "// Candidate-only HFXL layout; generated by html_fidelity_palette_banks.py.",
        "`ifndef HTML_LAYER_LAYOUT_VH", "`define HTML_LAYER_LAYOUT_VH",
        f"`define HTML_LAYER_SET_ID 32'h{manifest['set_id']:08x}",
        "`define HTML_LAYER_PAGE_COUNT 6", "`define HTML_LAYER_MAX_COMPONENTS 16",
        f"`define HTML_LAYER_POOL_WORDS 21'd{manifest['total_words']}",
        f"`define HTML_LAYER_TOTAL_WORDS 21'd{manifest['total_words']}",
        "`define HTML_LAYER_BG_STRIDE_WORDS 214", "`define HTML_LAYER_PALETTE_WORDS 1024",
        "`define HTML_LAYER_DESCRIPTOR_OFFSET_WORDS 64", "`define HTML_LAYER_DESCRIPTOR_WORDS 8",
        "`define HTML_LAYER_PALETTE_BANK_COUNT 2", "`define HTML_LAYER_PALETTE_BANK_ADDR_BITS 10",
    ]
    for page in manifest["pages"]:
        i = page["page_index"]
        for macro, key in (("BASE", "global_word_base"), ("WORDS", "payload_words"),
                           ("BG_OFFSET", "bg_word_offset"), ("PALETTE_OFFSET", "palette_word_offset"),
                           ("COMPONENTS", "component_count")):
            lines.append(f"`define HTML_LAYER_PAGE{i}_{macro} 21'd{page[key]}")
    lines.extend(["`endif", ""])
    return "\n".join(lines)


def build(layers: Path, out: Path) -> dict:
    layers = layers.resolve()
    out = out.resolve()
    if not layers.is_dir():
        raise ValueError(f"source layers directory missing: {layers}")
    if layers == out or layers in out.parents or out in layers.parents:
        raise ValueError("candidate output must be isolated from source layers")
    if out.exists():
        raise FileExistsError(f"candidate output already exists: {out}")

    source_manifest_path = layers / "hfxl_payload_manifest.json"
    source_schema_path = layers / "hfxl_schema.json"
    source_manifest = json.loads(source_manifest_path.read_text(encoding="utf8"))
    source_schema = json.loads(source_schema_path.read_text(encoding="utf8"))
    if len(source_manifest["pages"]) != PAGE_COUNT:
        raise ValueError("expected exactly six HFXL pages")
    set_id = int(source_manifest["set_id"])
    pages = [parse_page(layers, p, set_id) for p in source_manifest["pages"]]
    pages.sort(key=lambda p: p["meta"]["page_index"])
    if [p["meta"]["page_index"] for p in pages] != list(range(PAGE_COUNT)):
        raise ValueError("page manifest is not ordered 0..5")

    colors = [set(p["palette"]) for p in pages]
    shared = colors[0] & colors[5]
    if len(shared) != 125:
        raise ValueError(f"expected 125 UI01/UI06 shared colors, found {len(shared)}")
    for i in range(PAGE_COUNT):
        for j in range(i + 1, PAGE_COUNT):
            overlap = colors[i] & colors[j]
            if (i, j) == (0, 5):
                if overlap != shared:
                    raise ValueError("UI01/UI06 shared-color set changed unexpectedly")
            elif overlap:
                raise ValueError(f"unexpected shared colors between UI{i+1:02d}/UI{j+1:02d}: {len(overlap)}")

    ui1_only = colors[0] - shared
    bank0_union = colors[0] | colors[3] | colors[4]
    bank1_pages = colors[1] | colors[2]
    ui6_only = colors[5] - shared
    if (len(ui1_only), len(bank0_union), len(bank1_pages), len(ui6_only)) != (173, 1060, 887, 47):
        raise ValueError("observed palette cardinalities differ from verified two-bank plan")

    ui1_keep = sorted(ui1_only)[:137]
    ui1_overflow = set(ui1_only) - set(ui1_keep)
    bank0_colors = sorted(shared) + ui1_keep + sorted(bank0_union - shared - ui1_only)
    bank1_colors = sorted(bank1_pages) + sorted(ui6_only) + sorted(ui1_overflow)
    if len(ui1_overflow) != 36 or len(bank0_colors) != 1024 or len(bank1_colors) != 970:
        raise ValueError("bank dimensions differ from expected 1024/970 split")
    if len(set(bank0_colors)) != len(bank0_colors) or len(set(bank1_colors)) != len(bank1_colors):
        raise ValueError("duplicate RGB assignment within a bank")
    bank0_map = {rgb: i for i, rgb in enumerate(bank0_colors)}
    bank1_map = {rgb: i for i, rgb in enumerate(bank1_colors)}

    rgb_to_slot: list[dict[int, tuple[int, int]]] = []
    page_banks = []
    for pi, page in enumerate(pages):
        mapping = {}
        for rgb in colors[pi]:
            if pi == 0:
                mapping[rgb] = (1, bank1_map[rgb]) if rgb in ui1_overflow else (0, bank0_map[rgb])
            elif pi in (1, 2):
                mapping[rgb] = (1, bank1_map[rgb])
            elif pi in (3, 4):
                mapping[rgb] = (0, bank0_map[rgb])
            else:
                mapping[rgb] = (0, bank0_map[rgb]) if rgb in shared else (1, bank1_map[rgb])
        rgb_to_slot.append(mapping)
        page_banks.append(mapping)

    # Output data is constructed fully in memory first; no source files are touched.
    candidate_payloads = []
    mapping_records = []
    page_records = []
    base = 0
    for pi, page in enumerate(pages):
        old_words = page["words"]
        palette_off = page["palette_off"]
        old_bg = page["bg_off"]
        old_tex = page["tex_off"]
        if old_bg != palette_off + PALETTE_WORDS:
            raise ValueError(f"UI{pi+1:02d}: palette/BG gap is not 512 words")
        palette = [0] * EXPANDED_PALETTE_WORDS
        for rgb, (bank, index) in page_banks[pi].items():
            if palette[index] not in (0, rgb_word(rgb)):
                raise ValueError(f"UI{pi+1:02d}: page-local palette collision at {index}")
            palette[index] = rgb_word(rgb)
        # Remap bank selectors are implicit in page/index ranges; page palette remains a direct RGB oracle.
        new_bg_words, source_map = encode_indices(page, page_banks[pi])
        if len(new_bg_words) != BG_WORDS:
            raise ValueError(f"UI{pi+1:02d}: unexpected encoded BG word count")

        # Insert 512 palette words immediately before BG. Everything after BG shifts by 512.
        expanded = old_words[:palette_off] + palette + old_words[old_bg:]
        new_bg = old_bg + 512
        new_tex = old_tex + 512
        expanded[new_bg:new_bg + BG_WORDS] = new_bg_words
        for ci in range(page["desc_count"]):
            desc_at = 64 + ci * 8
            if expanded[desc_at + 3] != old_words[desc_at + 3]:
                raise ValueError(f"UI{pi+1:02d}: texture offset shift failure at component {ci}")
            expanded[desc_at + 3] += 512

        expanded[0] = old_words[0]
        expanded[2] = len(expanded)
        expanded[6] = new_bg
        expanded[7] = BG_STRIDE
        expanded[8] = palette_off
        expanded[9] = EXPANDED_PALETTE_WORDS
        expanded[12] = new_tex
        expanded[13] = 0  # The candidate set ID is sealed after all pages are transformed.
        expanded[14] = base
        expanded[15] = pi
        if len(expanded) % 256:
            raise ValueError(f"UI{pi+1:02d}: expanded payload lost 256-word alignment")
        if new_tex != old_tex + 512 or len(expanded) != len(old_words) + 512:
            raise ValueError(f"UI{pi+1:02d}: extent/offset arithmetic mismatch")

        # Prove every BG pixel round-trips through both page-local golden palette and global bank ROM.
        bank_roms = (bank0_colors, bank1_colors)
        out_pixels = bytearray()
        for y in range(HEIGHT):
            row = new_bg + y * BG_STRIDE
            for x in range(WIDTH):
                word = expanded[row + x // 3]
                index = (word >> ((x % 3) * 10)) & 0x3FF
                rgb = palette[index] >> 8
                bank, bank_index = page_banks[pi][rgb]
                if pi == 0:
                    selected = index >= 934
                elif pi in (1, 2):
                    selected = True
                elif pi in (3, 4):
                    selected = False
                else:
                    selected = index >= 887
                if int(selected) != bank:
                    raise ValueError(f"UI{pi+1:02d}: selector mismatch for index {index}")
                if bank_roms[bank][bank_index] != rgb:
                    raise ValueError(f"UI{pi+1:02d}: global bank RGB mismatch")
                out_pixels.extend(((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255))
            if expanded[row + BG_STRIDE - 1] >> 10:
                raise ValueError(f"UI{pi+1:02d}: expanded BG final padding lane changed")
        if bytes(out_pixels) != page["pixels"]:
            raise ValueError(f"UI{pi+1:02d}: RGB888 BG reconstruction differs")

        # Prove each component texture is identical; only its offset descriptor moves.
        for ci, (desc_at, old_desc) in enumerate(page["descriptors"]):
            start, texels = old_desc[3], old_desc[6]
            old_bytes = struct.pack("<" + "I" * texels, *old_words[start:start + texels])
            new_start = expanded[desc_at + 3]
            new_bytes = struct.pack("<" + "I" * texels, *expanded[new_start:new_start + texels])
            if old_bytes != new_bytes:
                raise ValueError(f"UI{pi+1:02d}: RGBA texture bytes changed at component {ci}")
            if expanded[desc_at:desc_at + 3] != old_desc[:3] or expanded[desc_at + 4:desc_at + 8] != old_desc[4:8]:
                raise ValueError(f"UI{pi+1:02d}: descriptor fields other than texture offset changed")

        raw = struct.pack("<" + "I" * len(expanded), *expanded)
        candidate_payloads.append(bytearray(raw))
        mapping_records.append(dict(page_index=pi, name=f"UI{pi+1:02d}", source_palette_entries=len(page["palette"]),
                                    entries=source_map))
        record = dict(page["meta"])
        record.update(
            source_global_word_base=page["meta"]["global_word_base"],
            source_payload_words=len(old_words), source_payload_sha256=sha(page["original"]),
            global_word_base=base, payload_words=len(expanded), payload_bytes=len(raw),
            sha256=sha(raw), palette_word_offset=palette_off, palette_entries=EXPANDED_PALETTE_WORDS,
            actual_distinct_colors=len(page["palette"]), bg_word_offset=new_bg,
            bg_stride_words=BG_STRIDE, descriptor_word_offset=64,
            rgba_texel_words=page["rgba_texel_words"], bg_pixels_checked=WIDTH * HEIGHT,
            bg_rgb888_sha256=sha(bytes(out_pixels)), rgba_bytes_unchanged=True,
        )
        for component in record.get("components", []):
            component["texture_word_offset"] += 512
        page_records.append(record)
        base += len(expanded)

    # Seal the transformed six-page candidate using the existing content-addressed rule.
    zeroed_digest = hashlib.sha256(b"".join(candidate_payloads)).hexdigest()
    candidate_set_id = int(zeroed_digest[:8], 16)
    if candidate_set_id == 0:
        raise ValueError("derived candidate SET_ID cannot be zero")
    for b in candidate_payloads:
        struct.pack_into("<I", b, 52, candidate_set_id)

    combined = b"".join(candidate_payloads)
    total_words = len(combined) // 4
    if total_words != sum(p["payload_words"] for p in page_records):
        raise ValueError("candidate atlas total word count mismatch")
    if total_words >= PANEL_BASE_WORDS:
        raise ValueError(f"candidate scene atlas overlaps comparison panel base: {total_words}")

    # Validate computed page bases and checksums after sealing.
    word_cursor = 0
    for pi, (buf, rec) in enumerate(zip(candidate_payloads, page_records)):
        words = struct.unpack("<16I", buf[:64])
        if words[13] != candidate_set_id or words[14] != word_cursor or words[15] != pi:
            raise ValueError(f"UI{pi+1:02d}: sealed header values invalid")
        if words[2] != rec["payload_words"] or words[6] != rec["bg_word_offset"] or words[9] != 1024:
            raise ValueError(f"UI{pi+1:02d}: sealed metadata mismatch")
        rec["sha256"] = sha(bytes(buf))
        word_cursor += words[2]

    out.mkdir(parents=True, exist_ok=False)
    for rec, buf in zip(page_records, candidate_payloads):
        (out / rec["path"]).write_bytes(buf)
    (out / "hfxl_global_atlas.bin").write_bytes(combined)
    words_all = struct.unpack("<" + "I" * total_words, combined)
    (out / "hfxl_global_atlas.hex").write_text("".join(f"{w:08x}\n" for w in words_all), encoding="ascii")

    bank0_pad = bank0_colors + [0] * (1024 - len(bank0_colors))
    bank1_pad = bank1_colors + [0] * (1024 - len(bank1_colors))
    bank_rgb = bank0_pad + bank1_pad
    (out / "html_layer_palette_banks.hex").write_text("".join(f"{c:06x}\n" for c in bank_rgb), encoding="ascii")
    (out / "html_layer_palette_banks.hex.bin").write_text("".join(f"{c:024b}\n" for c in bank_rgb), encoding="ascii")
    for channel, shift in (("r", 16), ("g", 8), ("b", 0)):
        values = [(c >> shift) & 255 for c in bank_rgb]
        (out / f"html_layer_palette_banks_{channel}.hex").write_text("".join(f"{v:02x}\n" for v in values), encoding="ascii")
        (out / f"html_layer_palette_banks_{channel}.hex.bin").write_text("".join(f"{v:08b}\n" for v in values), encoding="ascii")

    mapping_obj = dict(
        format="source page palette index -> exact RGB -> {bank,index}; no runtime lookup table",
        bank_address="{bank,index[9:0]}; bank0 addresses 0..1023, bank1 addresses 1024..2047",
        page_selectors={"UI01": "index>=934", "UI02": "bank1", "UI03": "bank1",
                        "UI04": "bank0", "UI05": "bank0", "UI06": "index>=887"},
        banks={"bank0": {"entries": 1024, "used": 1024, "shared_UI01_UI06": [0, 124],
                         "UI01_only_kept": [125, 261], "UI04_UI05_only": [262, 1023]},
               "bank1": {"entries": 1024, "used": 970, "UI02_UI03_only": [0, 886],
                         "UI06_only": [887, 933], "UI01_overflow": [934, 969], "zero_padding": [970, 1023]}},
        shared_rgb_count=125, ui01_overflow_count=36,
        pages=mapping_records,
    )
    mapping_bytes = (json.dumps(mapping_obj, indent=2) + "\n").encode("utf8")
    (out / "palette_remap.json").write_bytes(mapping_bytes)

    schema = dict(source_schema)
    schema["set_id"] = candidate_set_id
    schema["candidate_palette_banks"] = mapping_obj
    schema["header_fields"] = dict(source_schema.get("header_fields", {}))
    schema["header_fields"]["6"] = "bg_word_offset; shifted +512 after expanded 1024-word palette"
    schema["header_fields"]["8"] = "palette_word_offset; fixed 1024-word page-local RGB oracle begins here"
    schema["header_fields"]["9"] = "palette_address_slots=1024; actual distinct color count is manifest metadata"
    schema["header_fields"]["12"] = "first_component_texture_word_offset; shifted +512"
    schema["header_fields"]["14"] = "candidate global_word_base after per-page palette expansion"
    schema["palette"] = "page-local fixed1024-word RRGGBB00 oracle; global bank ROM is 2048xRGB888"
    schema["candidate_scope"] = "Isolated two-bank candidate; no RTL or formal media updated"
    schema["expected_page_regions"] = [
        {"page_index": p["page_index"], "global_word_base": p["global_word_base"],
         "payload_words": p["payload_words"]}
        for p in page_records
    ]
    schema["set_id_derivation"] = dict(
        algorithm="SHA256 over all six complete padded little-endian candidate payloads in page_index order, each header word13 zero; SET_ID is first 8 hex digits",
        zeroed_payload_sha256=zeroed_digest, bytes_hashed=len(combined),
    )
    schema_bytes = (json.dumps(schema, indent=2) + "\n").encode("utf8")
    (out / "hfxl_schema.json").write_bytes(schema_bytes)

    candidate_manifest = dict(source_set_id=source_manifest["set_id"], set_id=candidate_set_id,
                              set_id_hex=f"{candidate_set_id:08x}", source_manifest_sha256=sha(source_manifest_path.read_bytes()),
                              source_schema_sha256=sha(source_schema_path.read_bytes()), schema_sha256=sha(schema_bytes),
                              set_id_derivation=schema["set_id_derivation"], pages=page_records,
                              total_words=total_words, total_payload_bytes=len(combined),
                              existing_six_page_word_budget=PANEL_BASE_WORDS,
                              within_existing_six_page_budget=total_words < PANEL_BASE_WORDS,
                              comparison_panel_base_words=PANEL_BASE_WORDS,
                              words_before_comparison_panel=PANEL_BASE_WORDS - total_words,
                              total_growth_words=total_words - source_manifest["total_words"],
                              total_growth_bytes=len(combined) - source_manifest["total_payload_bytes"],
                              global_sha256=sha(combined), palette_rom=dict(width=2048, bits_per_item=24, bank_depth=1024,
                                                                           bank0_used=1024, bank1_used=970, scope="Two-bank candidate"),
                              mapping_file="palette_remap.json", scope="Isolated candidate only; no formal media/SET_ID/RTL changed")
    manifest_bytes = (json.dumps(candidate_manifest, indent=2) + "\n").encode("utf8")
    (out / "hfxl_payload_manifest.json").write_bytes(manifest_bytes)
    (out / "html_layer_layout.vh").write_text(make_layout(candidate_manifest), encoding="ascii")

    outputs = {}
    for path in sorted(out.iterdir()):
        if path.is_file():
            outputs[path.name] = dict(bytes=path.stat().st_size, sha256=sha(path.read_bytes()))
    verification = dict(
        status="PASS", source_manifest_sha256=candidate_manifest["source_manifest_sha256"],
        source_set_id=source_manifest["set_id"], candidate_set_id=candidate_set_id,
        candidate_set_id_hex=f"{candidate_set_id:08x}", pages=PAGE_COUNT,
        bg_pixels_checked=PAGE_COUNT * WIDTH * HEIGHT, bg_rgb888_byte_exact=True,
        rgba_texture_words_checked=sum(p["rgba_texel_words"] for p in page_records), rgba_texture_bytes_unchanged=True,
        descriptor_coordinate_fields_unchanged=True, per_page_palette_slots=1024,
        palette_banks=dict(bank0_depth=1024, bank0_used=1024, bank1_depth=1024, bank1_used=970,
                           shared_colors=125, moved_UI01_colors=36),
        bank_selector_checks="PASS", index_width_bits=10, palette_rom_depth=2048,
        payload_growth_words=total_words - source_manifest["total_words"],
        payload_growth_bytes=len(combined) - source_manifest["total_payload_bytes"],
        total_words=total_words, panel_base_words=PANEL_BASE_WORDS,
        words_before_panel=PANEL_BASE_WORDS - total_words,
        no_source_or_formal_outputs_modified=True, outputs=outputs,
    )
    (out / "verification.json").write_text(json.dumps(verification, indent=2), encoding="utf8")
    return verification


def main() -> None:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layers", type=Path, default=repo / "output/html_fidelity/layers")
    parser.add_argument("--output", type=Path, default=repo / "output/html_fidelity/palette_two_bank_candidate")
    args = parser.parse_args()
    result = build(args.layers, args.output)
    print(json.dumps({k: v for k, v in result.items() if k != "outputs"}, indent=2))


if __name__ == "__main__":
    main()
