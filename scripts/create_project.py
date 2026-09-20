from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
def ident(s):return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def q(s):return '"'+s+'"'
objects=[]
def obj(key,content):objects.append(f'{ident(key)} = {{ {content} }};');return ident(key)
sources=['FamilyKitchen/FamilyKitchenApp.swift','FamilyKitchen/KitchenViews.swift','FamilyKitchen/Brand.swift','FamilyKitchen/HistoryView.swift','FamilyKitchen/AddDishView.swift','Sources/FamilyCore/Models.swift','Sources/FamilyCore/Catalog.swift','Sources/FamilyCore/Nutrition.swift','Sources/FamilyCore/Dietary.swift','Sources/FamilyCore/Seasons.swift','Sources/FamilyCore/StepsEN.swift','Sources/FamilyCore/RecipeImport.swift']
refs=[]; builds=[]
for file in sources:
    refs.append(obj(file,'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = '+q(file)+'; sourceTree = "<group>";'))
    builds.append(obj('build'+file,'isa = PBXBuildFile; fileRef = '+ident(file)+';'))
asset='FamilyKitchen/Assets.xcassets'
refs.append(obj(asset,'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = '+q(asset)+'; sourceTree = "<group>";'))
assetbuild=obj('assetbuild','isa = PBXBuildFile; fileRef = '+ident(asset)+';')
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = FamilyKitchen.app; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products','isa = PBXGroup; children = ('+product+',); name = Products; sourceTree = "<group>";')
main=obj('main','isa = PBXGroup; children = ('+','.join(refs+[products])+',); sourceTree = "<group>";')
phase=obj('sources','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+','.join(builds)+',); runOnlyForDeploymentPostprocessing = 0;')
resources=obj('resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ('+assetbuild+',); runOnlyForDeploymentPostprocessing = 0;')
frameworks=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
base='CLANG_ENABLE_MODULES = YES; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SDKROOT = iphoneos; SWIFT_VERSION = 5.0;'
app='CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; INFOPLIST_KEY_CFBundleDisplayName = "Family Kitchen"; INFOPLIST_KEY_NSCameraUsageDescription = "Photograph pantry items for manual review. Photos stay on your iPhone."; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait"; PRODUCT_BUNDLE_IDENTIFIER = com.familykitchen.app; PRODUCT_NAME = "$(TARGET_NAME)"; TARGETED_DEVICE_FAMILY = 1; SUPPORTS_MACCATALYST = NO; SWIFT_EMIT_LOC_STRINGS = YES; CURRENT_PROJECT_VERSION = 1; MARKETING_VERSION = 0.3;'
for scope in ['project','app']:
    configs=[]
    for mode in ['Debug','Release']:
        settings=base+(app if scope=='app' else '')+('SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf;' if mode=='Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
        configs.append(obj(scope+mode,f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {mode};'))
    obj(scope+'configs','isa = XCConfigurationList; buildConfigurations = ('+','.join(configs)+',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=obj('target','isa = PBXNativeTarget; buildConfigurationList = '+ident('appconfigs')+'; buildPhases = ('+','.join([phase,frameworks,resources])+',); buildRules = (); dependencies = (); name = FamilyKitchen; productName = FamilyKitchen; productReference = '+product+'; productType = "com.apple.product-type.application";')
uiTestSource='Tests/FamilyKitchenUITests/FamilyKitchenUITests.swift'
uiRef=obj('uiRef','isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = '+q(uiTestSource)+'; sourceTree = "<group>";')
uiBuild=obj('uiBuild','isa = PBXBuildFile; fileRef = '+uiRef+';')
uiProduct=obj('uiProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = FamilyKitchenUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
uiPhase=obj('uiPhase','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ('+uiBuild+',); runOnlyForDeploymentPostprocessing = 0;')
uiConfigs=[]
for mode in ['Debug','Release']:
    uiConfigs.append(obj('ui'+mode,'isa = XCBuildConfiguration; buildSettings = { '+base+' GENERATE_INFOPLIST_FILE = YES; CODE_SIGN_STYLE = Automatic; PRODUCT_BUNDLE_IDENTIFIER = com.familykitchen.app.uitests; PRODUCT_NAME = "$(TARGET_NAME)"; TEST_TARGET_NAME = FamilyKitchen; TARGETED_DEVICE_FAMILY = 1; }; name = '+mode+';'))
uiConfigList=obj('uiConfigs','isa = XCConfigurationList; buildConfigurations = ('+','.join(uiConfigs)+',); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
uiProxy=obj('uiProxy','isa = PBXContainerItemProxy; containerPortal = '+ident('project')+'; proxyType = 1; remoteGlobalIDString = '+target+'; remoteInfo = FamilyKitchen;')
uiDependency=obj('uiDependency','isa = PBXTargetDependency; target = '+target+'; targetProxy = '+uiProxy+';')
uiTarget=obj('uiTarget','isa = PBXNativeTarget; buildConfigurationList = '+uiConfigList+'; buildPhases = ('+uiPhase+',); buildRules = (); dependencies = ('+uiDependency+',); name = FamilyKitchenUITests; productName = FamilyKitchenUITests; productReference = '+uiProduct+'; productType = "com.apple.product-type.bundle.ui-testing";')
objects[:]=[entry.replace('children = (','children = ('+uiRef+',',1) if entry.startswith(ident('main')+' =') else entry for entry in objects]
objects[:]=[entry.replace('children = (','children = ('+uiProduct+',',1) if entry.startswith(ident('products')+' =') else entry for entry in objects]
project=obj('project','isa = PBXProject; attributes = { BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }; buildConfigurationList = '+ident('projectconfigs')+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, "zh-Hans", Base); mainGroup = '+main+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; targets = ('+target+','+uiTarget+',);')
p=root/'FamilyKitchen.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+project+'; }\n')
scheme=p/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
(scheme/'FamilyKitchen.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FamilyKitchen.app" BlueprintName="FamilyKitchen" ReferencedContainer="container:FamilyKitchen.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uiTarget}" BuildableName="FamilyKitchenUITests.xctest" BlueprintName="FamilyKitchenUITests" ReferencedContainer="container:FamilyKitchen.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="FamilyKitchen.app" BlueprintName="FamilyKitchen" ReferencedContainer="container:FamilyKitchen.xcodeproj"/></BuildableProductRunnable></LaunchAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
(root/'FamilyKitchen/Assets.xcassets/Contents.json').write_text('{"info":{"author":"xcode","version":1}}')
