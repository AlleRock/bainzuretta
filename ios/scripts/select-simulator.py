import json, re
from pathlib import Path
payload = json.loads(Path('simulator-devices.json').read_text())
candidates = []
for runtime, devices in payload['devices'].items():
    if '.iOS-' not in runtime: continue
    match = re.search(r'\.iOS-(\d+(?:-\d+)*)', runtime)
    if not match: continue
    version = tuple(map(int, match.group(1).split('-')))
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            candidates.append((version, device['name'] == 'iPhone 18 Pro', device['name'], device['udid']))
if not candidates: raise SystemExit('No available iPhone Simulator. Install an iOS runtime on the runner.')
version, preferred, name, udid = max(candidates)
print('SIMULATOR_ID='+udid)
print('SIMULATOR_NAME='+name+' / iOS '+'.'.join(map(str,version)))
