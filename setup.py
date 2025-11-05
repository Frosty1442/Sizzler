"""Setup script for Sizzler (for backward compatibility)."""

from setuptools import setup, find_packages
from pathlib import Path

# Read the version from __version__.py
version = {}
with open("sizzler/__version__.py") as fp:
    exec(fp.read(), version)

# Read the README
this_directory = Path(__file__).parent
long_description = (this_directory / "README.md").read_text(encoding='utf-8')

setup(
    name="sizzler-fuzzer",
    version=version['__version__'],
    author=version['__author__'],
    description=version['__description__'],
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/Frosty1442/Sizzler",
    packages=find_packages(exclude=["tests", "tests.*", "Fuzzing", "Ladder Diagram Testbed"]),
    python_requires=">=3.6",
    install_requires=[
        "torch>=1.0.0",
        "numpy>=1.15.0",
    ],
    extras_require={
        "dev": [
            "pytest>=6.0",
            "pytest-cov>=2.10",
            "black>=21.0",
            "flake8>=3.9",
        ],
    },
    entry_points={
        "console_scripts": [
            "sizzler=sizzler.main:main",
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "Topic :: Security",
        "Topic :: Software Development :: Testing",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
    ],
    keywords="fuzzing PLC ladder-logic GAN security vulnerability-detection AFL",
)
