import json, re
from pathlib import Path
payload = json.loads(Path('simulator-devices.json').read_text())
candidates = []
sdk_file = Path('simulator-sdk-version.txt')
sdk = tuple(map(int, sdk_file.read_text().strip().split('.'))) if sdk_file.exists() else None
for runtime, devices in payload['devices'].items():
    if '.iOS-' not in runtime: continue
    match = re.search(r'\.iOS-(\d+(?:-\d+)*)', runtime)
    if not match: continue
    version = tuple(map(int, match.group(1).split('-')))
    if sdk is not None and version[:2] > sdk[:2]: continue
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            candidates.append((device['name'] == 'iPhone 18 Pro', version, device['name'], device['udid']))
if not candidates: raise SystemExit('No iPhone Simulator runtime compatible with the selected Xcode SDK. Install a compatible iOS runtime.')
preferred, version, name, udid = max(candidates)
print('SIMULATOR_ID='+udid)
print('SIMULATOR_NAME='+name+' / iOS '+'.'.join(map(str,version)))
