"""Invoke tasks for building the app"""

import os
import sys
from invoke import task


@task
def clean(c):
    """Clean flutter build"""
    c.run("flutter clean")


@task
def translate(c):
    """Update translation files"""

    here = os.path.dirname(__file__)
    l10_dir = os.path.join(here, 'lib', 'l10n')
    l10_dir = os.path.abspath(l10_dir)

    python = 'python3' if sys.platform.lower() == 'darwin' else 'python'
    c.run(f"cd {l10_dir} && {python} collect_translations.py")


@task(pre=[clean, translate])
def ios(c):
    """Build iOS app"""
    c.run("flutter build ipa --release --no-tree-shake-icons")


@task(pre=[clean, translate])
def android(c):
    """Build Android app"""
    c.run("flutter build appbundle --release --no-tree-shake-icons")
