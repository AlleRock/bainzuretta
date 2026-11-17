import plistlib, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None
    info = plistlib.loads(z.read('Bainzuretta.app/Info.plist'))
    assert info['CFBundleIdentifier'] == 'it.allerock.Bainzuretta'
    assert 'iPhoneSimulator' in info['CFBundleSupportedPlatforms']
    binary = z.read('Bainzuretta.app/'+info['CFBundleExecutable'])
    assert len(binary) > 10000
    assert binary[:4] in [b'\xcf\xfa\xed\xfe',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca']
    assert not any(p.endswith('.swift') for p in z.namelist())
    print('Verified simulator ZIP: compiled Mach-O app, simulator platform, intact archive')
