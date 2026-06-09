"""
GPS verification service using the Haversine formula.
Checks if a user's coordinates are within the allowed radius of a gate.
"""

from math import radians, sin, cos, sqrt, atan2


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance (in metres) between two
    latitude/longitude points on Earth.
    """
    R = 6_371_000  # Earth's radius in metres

    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)

    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return R * c


def verify_location(
    user_lat: float,
    user_lon: float,
    gate_lat: float,
    gate_lon: float,
    radius_meters: int = 15,
) -> dict:
    """
    Check whether the user is within *radius_meters* of the gate.

    Returns
    -------
    dict with keys:
        nearby          : bool
        distance_meters : float  (rounded to 1 dp)
        max_radius      : int
    """
    distance = haversine(user_lat, user_lon, gate_lat, gate_lon)
    return {
        "nearby": distance <= radius_meters,
        "distance_meters": round(distance, 1),
        "max_radius": radius_meters,
    }
