#!/usr/bin/env python3
"""Assemble a local release without Keychain access or manual signing; keep rollback bundles."""
from pathlib import Path
import datetime
import os
import plistlib
import re
import shutil
import subprocess
import time

root = Path(__file__).resolve().parent.parent
source = (root / 'scripts/build-app.sh').read_text()
version = re.search(r'VERSION="([^"]+)"', source)[1]
subprocess.run(['swift', 'build', '-c', 'release'], cwd=root, check=True)
stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
build = root / 'build/PokeTokenBar.app'
backup = root / 'build/private-backups' / stamp
backup.mkdir(parents=True)
if build.exists():
    shutil.move(str(build), str(backup / 'build-PokeTokenBar.app'))
contents = build / 'Contents'
(contents / 'MacOS').mkdir(parents=True)
(contents / 'Resources').mkdir()
shutil.copy2(root / '.build/release/PokeTokenBar', contents / 'MacOS/PokeTokenBar')
shutil.copy2(root / 'assets/AppIcon.icns', contents / 'Resources/AppIcon.icns')
# Reuse the authoritative bundle and login-agent templates, with no signing operations.
for marker, target in [('PLIST', contents / 'Info.plist'), ('AGENT', contents / 'Library/LaunchAgents/io.github.chattymin.poketokenbar.login.plist')]:
    xml = source.split('<<' + marker + '\n', 1)[1].split('\n' + marker, 1)[0]
    xml = xml.replace('$APP_NAME', 'PokeTokenBar').replace('$VERSION', version)
    plistlib.loads(xml.encode())
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(xml)
installed = Path('/Applications/PokeTokenBar.app')
subprocess.run(['pkill', '-TERM', '-x', 'PokeTokenBar'], check=False)
for _ in range(50):
    if subprocess.run(['pgrep', '-x', 'PokeTokenBar'], stdout=subprocess.DEVNULL).returncode != 0:
        break
    time.sleep(0.1)
else:
    raise RuntimeError('Existing app did not exit; installation not changed')
if installed.exists():
    shutil.move(str(installed), str(backup / 'installed-PokeTokenBar.app'))
try:
    shutil.copytree(build, installed)
    subprocess.run(['open', str(installed)], check=True)
except Exception:
    if installed.exists():
        shutil.move(str(installed), str(backup / 'failed-PokeTokenBar.app'))
    if (backup / 'installed-PokeTokenBar.app').exists():
        shutil.move(str(backup / 'installed-PokeTokenBar.app'), str(installed))
    raise
print(f'Installed PokeTokenBar {version}; backups: {backup}')
