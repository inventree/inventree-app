"""Invoke tasks for building the InvenTree mobile app."""

import os
import sys
from invoke import task


@task
def format(c):
    """Code formatting using dart format."""
    c.run("fvm dart format lib")

@task
def clean(c):
    """Clean flutter build."""
    c.run("fvm flutter clean")

@task
def update(c):
    """Update flutter dependencies."""
    c.run("flutter pub get")

@task
def translate(c):
    """Update translation files."""

    here = os.path.dirname(__file__)
    l10_dir = os.path.join(here, "lib", "l10n")
    l10_dir = os.path.abspath(l10_dir)

    python = "python3" if sys.platform.lower() == "darwin" else "python"
    c.run(f"cd {l10_dir} && {python} collect_translations.py")


@task(pre=[clean, update, translate])
def ios(c):
    """Build iOS app in release configuration."""
    c.run("fvm flutter build ipa --release --no-tree-shake-icons")


@task(pre=[clean, update, translate])
def android(c):
    """Build Android app in release configuration."""
    c.run("fvm flutter build appbundle --release --no-tree-shake-icons")
