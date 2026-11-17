import json
from pathlib import Path
payload = json.loads(Path('simulator-devices.json').read_text())
candidates = []
for runtime, devices in payload['devices'].items():
    if '.iOS-' not in runtime: continue
    version = tuple(map(int, runtime.split('.iOS-')[1].split('-')))
    for device in devices:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            candidates.append((version, '18 Pro' in device['name'], device['name'], device['udid']))
if not candidates: raise SystemExit('No available iPhone Simulator. Install an iOS runtime on the runner.')
version, preferred, name, udid = max(candidates)
print('SIMULATOR_ID='+udid)
print('SIMULATOR_NAME='+name+' / iOS '+'.'.join(map(str,version)))
