"""Indonesian license plate normalization and parsing helpers."""

import re


_NON_ALNUM = re.compile(r"[^A-Z0-9]+")
_NUMBER_SUBSTITUTIONS = str.maketrans({
    "O": "0",
    "Q": "0",
    "D": "0",
    "I": "1",
    "L": "1",
    "Z": "2",
    "S": "5",
    "G": "6",
    "B": "8",
})


def _empty_plate(raw_text: str = "") -> dict:
    return {
        "raw_text": raw_text,
        "normalized_plate": "",
        "prefix_letters": "",
        "middle_numbers": "",
        "suffix_letters": "",
        "plate_type": "unknown",
        "is_valid": False,
    }


def _build_plate(
    raw_text: str,
    prefix_letters: str,
    middle_numbers: str,
    suffix_letters: str = "",
    plate_type: str = "standard",
) -> dict:
    parts = [prefix_letters, middle_numbers, suffix_letters]
    normalized = " ".join(part for part in parts if part)
    return {
        "raw_text": raw_text,
        "normalized_plate": normalized,
        "prefix_letters": prefix_letters,
        "middle_numbers": middle_numbers,
        "suffix_letters": suffix_letters,
        "plate_type": plate_type,
        "is_valid": True,
    }


def parse_indonesian_plate(raw_text: str) -> dict:
    """
    Parse OCR output into database-friendly Indonesian plate components.

    Supported common formats:
      - B 1234 ABC
      - AB 12 CD
      - B 1234
      - CD 1234 AB

    OCR engines often omit spaces, so B1234ABC is accepted as well.
    Small expiry-date text after or before the suffix is ignored when detected.
    """
    if not raw_text:
        return _empty_plate()

    text = raw_text.strip().upper()
    compact = _NON_ALNUM.sub("", text)
    if not compact:
        return _empty_plate(text)

    # Military-style plates are retained as a separate type. They cannot use
    # the regular regional prefix lookup without an explicit database rule.
    military = re.fullmatch(r"(\d{4,5})(\d{1,2})?", compact)
    if military:
        number = military.group(1)
        suffix = military.group(2) or ""
        normalized = f"{number}-{suffix}" if suffix else number
        return {
            "raw_text": text,
            "normalized_plate": normalized,
            "prefix_letters": "",
            "middle_numbers": number,
            "suffix_letters": suffix,
            "plate_type": "military",
            "is_valid": True,
        }

    # Standard plate, with an optional expiry date OCR-ed after the suffix.
    standard = re.fullmatch(
        r"([A-Z]{1,2})(\d{1,4})([A-Z]{1,3})(?:\d{2,4})?",
        compact,
    )
    if standard:
        prefix, number, suffix = standard.groups()
        plate_type = "diplomatic" if prefix == "CD" else "standard"
        return _build_plate(text, prefix, number, suffix, plate_type)

    # Sometimes the small expiry date is read before the final suffix.
    expiry_before_suffix = re.fullmatch(
        r"([A-Z]{1,2})(\d{1,4})(?:\d{4})([A-Z]{1,3})",
        compact,
    )
    if expiry_before_suffix:
        prefix, number, suffix = expiry_before_suffix.groups()
        plate_type = "diplomatic" if prefix == "CD" else "standard"
        return _build_plate(text, prefix, number, suffix, plate_type)

    # Temporary plates may not have trailing letters.
    temporary = re.fullmatch(r"([A-Z]{1,2})(\d{1,4})", compact)
    if temporary:
        return _build_plate(text, temporary.group(1), temporary.group(2), "", "temporary")

    # Repair common OCR confusions only inside the numeric segment.
    loose = re.fullmatch(r"([A-Z]{1,2})([A-Z0-9]{1,4})([A-Z]{0,3})", compact)
    if loose:
        prefix, number_candidate, suffix = loose.groups()
        number = number_candidate.translate(_NUMBER_SUBSTITUTIONS)
        if number.isdigit():
            plate_type = "diplomatic" if prefix == "CD" else "standard"
            return _build_plate(text, prefix, number, suffix, plate_type)

    return _empty_plate(text)


def clean_plate_text(raw_text: str) -> str:
    """Return the normalized plate text used for database lookup."""
    return parse_indonesian_plate(raw_text)["normalized_plate"]
