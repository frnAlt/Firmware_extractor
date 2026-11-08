"""
Module 1: Universal Firmware Extractor & Metadata Parser
"""

from .metadata_parser import MetadataParser
from .boot_engine import BootEngine
from .firmware_engine import FirmwareEngine

__all__ = ["MetadataParser", "BootEngine", "FirmwareEngine"]
