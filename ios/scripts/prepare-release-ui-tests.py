"""Reuse the compiled UI runner while testing the exact Release app to be shipped."""
import pathlib
import plistlib
import sys

products = pathlib.Path(sys.argv[1]).resolve()
templates = [p for p in products.glob('*.xctestrun') if p.name != 'ReleaseSmoke.xctestrun']
assert len(templates) == 1, f'Expected one compiled test configuration, found {templates}'
app = products / 'Release-iphonesimulator/Bainzuretta.app'
assert (app / 'Info.plist').is_file() and (app / 'Bainzuretta').is_file()
configuration = plistlib.loads(templates[0].read_bytes())
ui_targets = 0

def retarget(value):
    global ui_targets
    if isinstance(value, dict):
        result = {}
        for key, item in value.items():
            if key == 'UITargetAppPath' and isinstance(item, str) and item.endswith('/Bainzuretta.app'):
                result[key] = str(app)
                ui_targets += 1
            else:
                result[key] = retarget(item)
        return result
    if isinstance(value, list):
        return [retarget(item) for item in value]
    if isinstance(value, str):
        return value.replace('/Debug-iphonesimulator/Bainzuretta.app', '/Release-iphonesimulator/Bainzuretta.app')
    return value

configuration = retarget(configuration)
assert ui_targets == 1, f'Expected exactly one UI target app, found {ui_targets}'
output = products / 'ReleaseSmoke.xctestrun'
output.write_bytes(plistlib.dumps(configuration))
print(f'UI smoke runner targets the packaged Release app: {app}')
