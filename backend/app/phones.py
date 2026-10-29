def normalize_phone(raw: str) -> str:
    """Store Nigerian numbers as +234 and 10 digits, whatever way they were typed."""
    digits = "".join(ch for ch in raw if ch.isdigit())
    if digits.startswith("234"):
        digits = digits[3:]
    if digits.startswith("0"):
        digits = digits[1:]
    if len(digits) != 10:
        raise ValueError("Enter a valid Nigerian phone number")
    return "+234" + digits
