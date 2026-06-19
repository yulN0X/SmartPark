"""
Plate number normalization — single source of truth.

Every part of the system (vehicle registration, ANPR result, DB lookup,
session lookup) MUST call ``normalize_plate()`` so that
"B 1234 ABC", "B-1234-ABC", "b1234abc" all resolve to "B1234ABC".
"""

import re

_STRIP_RE = re.compile(r"[^A-Z0-9]")


def normalize_plate(raw: str) -> str:
    """Normalize an Indonesian license plate string.

    Steps:
        1. Upper-case
        2. Strip every non-alphanumeric character (spaces, dashes, dots …)

    Returns the canonical form, e.g. ``"B1234ABC"``.
    Returns an empty string when *raw* is ``None`` or blank.
    """
    if not raw:
        return ""
    return _STRIP_RE.sub("", raw.upper())
