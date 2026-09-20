from pathlib import Path
import json, re, subprocess, sys
root=Path(__file__).resolve().parents[1]
source=(root/'Sources/FamilyCore/Catalog.swift').read_text()
rows=re.findall(r'\.init\(id:\s*"([^"]+)",en:\s*"([^"]+)",zh:\s*"([^"]+)",breakfast:\s*(true|false),minutes:\s*(\d+)',source)
assert len(rows)==76 and sum(r[3]=='false' for r in rows)==56 and sum(r[3]=='true' for r in rows)==20
assets={p.parent.stem for p in (root/'FamilyTable/Assets.xcassets').glob('*.imageset/photo.png')}
missing=[r[0] for r in rows if r[0] not in assets]
print(f'Catalog: 56 dinners + 20 breakfasts; artwork: {76-len(missing)}/76')
print('Pending artwork: '+', '.join(missing))
for manifest in (root/'FamilyTable/Assets.xcassets').glob('*.imageset/Contents.json'):
    data=json.loads(manifest.read_text())
    for image in data['images']: assert (manifest.parent/image['filename']).is_file()
result=subprocess.run(['python3','scripts/check_core.py'],cwd=root,text=True,capture_output=True)
(root/'CATALOG_VALIDATION.txt').write_text(result.stdout+result.stderr)
print(result.stdout);print(result.stderr)
subprocess.run(['swiftc','-frontend','-parse','FamilyTable/FamilyTableApp.swift','FamilyTable/PantryViews.swift','Tests/FamilyTableUITests/FamilyTableUITests.swift'],cwd=root,check=True)
subprocess.run(['plutil','-lint','FamilyTable.xcodeproj/project.pbxproj'],cwd=root,check=True)
text='# 菜单总览 · 56 套晚餐 / 20 套早餐\n\n每套为完整餐食；用量以五人为基准、App 内按人数缩放。时间含准备，为估计值。\n'
for label,kind in [('晚餐','false'),('早餐','true')]:
    text+=f'\n## {label}\n\n| # | 菜单 | English | 总时间 | 配图 |\n|---|---|---|---|---|\n'
    for i,(ident,en,zh,_,minutes) in enumerate([r for r in rows if r[3]==kind],1):
        status='AI 示意图' if ident in assets else '菜系标识，无配图'
        text+=f'| {i} | {zh} | {en} | {minutes} 分钟 | {status} |\n'
(root/'MENU_CATALOG.md').write_text(text)
report=f'# 扩充验证记录\n\n菜单：56 套晚餐 + 20 套早餐。配图 {76-len(missing)}/76。\n\n核心回归：{("PASS" if result.returncode==0 else "FAIL")}\n\n```text\n{result.stdout}{result.stderr}\n```\n\nSwiftUI/UI 测试源码语法解析及工程 plist 检查通过；这不等于 iOS 编译通过。Xcode 27 已安装，许可尚未接受，模拟器/真机构建及 UI 测试仍未执行。详见 DEVICE_ACCEPTANCE.md。\n\n扩充辣菜前的 Mac Release 核心性能（历史记录）：100 次，70 菜谱、68 库存条目、6 人，计划+采购中位 1.92 ms，p95 2.46 ms，最大 7.12 ms。不是 iPhone 设备测量。\n'
(root/'VALIDATION.md').write_text(report)
sys.exit(result.returncode)
