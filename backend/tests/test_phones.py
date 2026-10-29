import pytest

from app.phones import normalize_phone


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("08031234567", "+2348031234567"),
        ("+234 803 123 4567", "+2348031234567"),
        ("2348031234567", "+2348031234567"),
        ("8031234567", "+2348031234567"),
    ],
)
def test_nigerian_numbers(raw, expected):
    assert normalize_phone(raw) == expected


def test_rejects_short_numbers():
    with pytest.raises(ValueError):
        normalize_phone("12345")
