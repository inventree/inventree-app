"""Invoke tasks for building the app"""

import sys
from invoke import task


@task
def clean(c):
    """Clean flutter build"""
    c.run("flutter clean")


@task
def translate(c):
    """Update translation files"""
    python = 'python3' if sys.platform.lower() == 'darwin' else 'python'
    c.run(f"cd lib/l10n && {python} collect_translations.py")


@task(pre=[clean, translate])
def ios(c):
    """Build iOS app"""
    c.run("flutter build ipa --release --no-tree-shake-icons")


@task(pre=[clean, translate])
def android(c):
    """Build Android app"""
    c.run("flutter build appbundle --release --no-tree-shake-icons")
