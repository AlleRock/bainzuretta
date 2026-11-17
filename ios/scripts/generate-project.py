#!/usr/bin/env python3
"""Deterministic Xcode project without generator dependencies. Run after adding Swift files."""
from pathlib import Path
import hashlib, json, plistlib
root = Path(__file__).resolve().parent.parent
objects = {}
def ident(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def obj(key, value): objects[ident(key)] = value; return ident(key)
def q(s): return json.dumps(str(s))
def arr(values): return '(' + ','.join(values) + ',)' if values else '()'
app_sources = sorted((root/'Bainzuretta').rglob('*.swift'))
test_sources = sorted((root/'UITests').glob('*.swift'))
native_sources = sorted((root/'NativeTests').glob('*.swift'))
refs, app_builds, test_builds, native_builds = [], [], [], []
for file in app_sources + test_sources + native_sources:
    name = file.relative_to(root).as_posix()
    ref = obj(name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(name)}; sourceTree = "<group>";')
    refs.append(ref)
    build = obj(name+'-build', f'isa = PBXBuildFile; fileRef = {ref};')
    (app_builds if file in app_sources else test_builds if file in test_sources else native_builds).append(build)
for name, filetype in [('Bainzuretta/Assets.xcassets','folder.assetcatalog'),('Bainzuretta/PrivacyInfo.xcprivacy','text.xml'),('Bainzuretta/Info.plist','text.plist.xml'),('Bainzuretta/Simulator.entitlements','text.plist.entitlements')]:
    ref = obj(name,f'isa = PBXFileReference; lastKnownFileType = {filetype}; path = {q(name)}; sourceTree = "<group>";'); refs.append(ref)
resource_builds = [obj(name+'-build',f'isa = PBXBuildFile; fileRef = {ident(name)};') for name in ['Bainzuretta/Assets.xcassets','Bainzuretta/PrivacyInfo.xcprivacy']]
app_product = obj('app-product','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Bainzuretta.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = obj('test-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = BainzurettaUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
native_product = obj('native-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = BainzurettaNativeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products',f'isa = PBXGroup; children = {arr([app_product,test_product,native_product])}; name = Products; sourceTree = "<group>";')
main = obj('main-group',f'isa = PBXGroup; children = {arr(refs+[products])}; sourceTree = "<group>";')
package = obj('package','isa = XCLocalSwiftPackageReference; relativePath = .;')
package_product = obj('package-product',f'isa = XCSwiftPackageProductDependency; package = {package}; productName = BainzurettaCore;')
framework_build = obj('framework-build',f'isa = PBXBuildFile; productRef = {package_product};')
app_src = obj('app-src',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(app_builds)}; runOnlyForDeploymentPostprocessing = 0;')
app_resources = obj('app-resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;')
app_frameworks = obj('app-frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {arr([framework_build])}; runOnlyForDeploymentPostprocessing = 0;')
test_src = obj('test-src',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(test_builds)}; runOnlyForDeploymentPostprocessing = 0;')
test_frameworks = obj('test-frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
native_src = obj('native-src',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(native_builds)}; runOnlyForDeploymentPostprocessing = 0;')
native_framework_build = obj('native-framework-build',f'isa = PBXBuildFile; productRef = {package_product};')
native_frameworks = obj('native-frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {arr([native_framework_build])}; runOnlyForDeploymentPostprocessing = 0;')
def configs(prefix, settings):
    ids = []
    for mode in ['Debug','Release']:
        opts = dict(settings)
        if prefix == 'project': opts.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','ONLY_ACTIVE_ARCH':'YES' if mode=='Debug' else 'NO','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO','DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG $(inherited)' if mode=='Debug' else '$(inherited)'})
        ids.append(obj(prefix+mode,'isa = XCBuildConfiguration; buildSettings = {' + ''.join(f'{q(k)} = {q(v)};' for k,v in opts.items()) + f'}}; name = {mode};'))
    return obj(prefix+'configs',f'isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project_configs = configs('project',{'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'18.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES','GCC_C_LANGUAGE_STANDARD':'gnu17'})
app_configs = configs('app',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'it.allerock.Bainzuretta','INFOPLIST_FILE':'Bainzuretta/Info.plist','GENERATE_INFOPLIST_FILE':'NO','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]':'Bainzuretta/Simulator.entitlements','CODE_SIGN_IDENTITY[sdk=iphonesimulator*]':'-','CODE_SIGN_STYLE[sdk=iphonesimulator*]':'Manual','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'1.0','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'})
test_configs = configs('test',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'it.allerock.BainzurettaUITests','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2','TEST_TARGET_NAME':'Bainzuretta','CODE_SIGN_STYLE':'Automatic'})
native_configs = configs('native',{'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'it.allerock.BainzurettaNativeTests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Bainzuretta.app/Bainzuretta','BUNDLE_LOADER':'$(TEST_HOST)','CODE_SIGN_STYLE':'Automatic'})
native_id = ident('native-target')
app_id, test_id, project_id = ident('app-target'), ident('test-target'), ident('project')
proxy = obj('test-proxy',f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {app_id}; remoteInfo = Bainzuretta;')
dep = obj('test-dep',f'isa = PBXTargetDependency; target = {app_id}; targetProxy = {proxy};')
obj('app-target',f'isa = PBXNativeTarget; buildConfigurationList = {app_configs}; buildPhases = {arr([app_src,app_frameworks,app_resources])}; buildRules = (); dependencies = (); name = Bainzuretta; packageProductDependencies = {arr([package_product])}; productName = Bainzuretta; productReference = {app_product}; productType = "com.apple.product-type.application";')
obj('test-target',f'isa = PBXNativeTarget; buildConfigurationList = {test_configs}; buildPhases = {arr([test_src,test_frameworks])}; buildRules = (); dependencies = {arr([dep])}; name = BainzurettaUITests; productName = BainzurettaUITests; productReference = {test_product}; productType = "com.apple.product-type.bundle.ui-testing";')
obj('native-target',f'isa = PBXNativeTarget; buildConfigurationList = {native_configs}; buildPhases = {arr([native_src,native_frameworks])}; buildRules = (); dependencies = {arr([dep])}; name = BainzurettaNativeTests; productName = BainzurettaNativeTests; productReference = {native_product}; packageProductDependencies = {arr([package_product])}; productType = "com.apple.product-type.bundle.unit-test";')
obj('project',f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2700; TargetAttributes = {{{app_id} = {{CreatedOnToolsVersion = 27.0;}}; {test_id} = {{CreatedOnToolsVersion = 27.0; TestTargetID = {app_id};}};}};}}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = it; hasScannedForEncodings = 0; knownRegions = (it,en,Base); mainGroup = {main}; productRefGroup = {products}; packageReferences = {arr([package])}; projectDirPath = ""; projectRoot = ""; targets = {arr([app_id,test_id,native_id])};')
project = root/'Bainzuretta.xcodeproj'; project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+ '\n'.join(f'{key} = {{{value}}};' for key,value in sorted(objects.items())) + f'\n}}; rootObject = {project_id};}}\n')
scheme_dir = project/'xcshareddata/xcschemes'; scheme_dir.mkdir(parents=True,exist_ok=True)
def buildable(target,name,product): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Bainzuretta.xcodeproj"/>'
native_ref = buildable(native_id,'BainzurettaNativeTests','BainzurettaNativeTests.xctest')
app_ref, test_ref = buildable(app_id,'Bainzuretta','Bainzuretta.app'), buildable(test_id,'BainzurettaUITests','BainzurettaUITests.xctest')
(scheme_dir/'Bainzuretta.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{native_ref}</TestableReference><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(f'Generated {project.name}: {len(app_sources)} app sources, {len(test_sources)} UI test sources')
