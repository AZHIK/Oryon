class DomainError(Exception):
    """Base class for service-layer validation errors."""


class InvalidTokenError(DomainError):
    """Raised when a JWT access token is invalid (bad signature, malformed, or wrong type)."""


class ExpiredTokenError(InvalidTokenError):
    """Raised when a JWT access token has expired."""
