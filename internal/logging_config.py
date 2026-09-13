"""Centralized logging configuration for the service."""

import logging


def configure_logging(log_level: str) -> None:
    """Configure the root logger with a consistent format.

    Args:
        log_level: Logging level name, e.g. "INFO" or "DEBUG".
    """
    logging.basicConfig(
        level=log_level.upper(),
        format='%(asctime)s %(levelname)s %(name)s: %(message)s',
    )
