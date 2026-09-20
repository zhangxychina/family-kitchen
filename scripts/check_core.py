"""Run the XCTest scenarios without XCTest when only Command Line Tools are installed."""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tests/FamilyCoreTests/FamilyCoreTests.swift').read_text().replace('import XCTest','import Foundation').replace('@testable import FamilyCore','')
shim='''
var checks = 0
class XCTestCase {}
func check(_ condition: Bool, _ message: String = "Assertion failed", file: StaticString = #filePath, line: UInt = #line) { checks += 1; if !condition { fatalError("\\(message) at \\(file):\\(line)") } }
func XCTAssertTrue(_ v: Bool) { check(v) }
func XCTAssertFalse(_ v: Bool) { check(!v) }
func XCTAssertNil<T>(_ v: T?) { check(v == nil) }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { check(a == b, "\\(a) != \\(b)") }
func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double) { check(abs(a-b) <= accuracy) }
func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T) { check(a > b) }
func XCTFail(_ message: String) { check(false,message) }
func XCTAssertThrowsError<T>(_ action: @autoclosure () throws -> T) { do { _ = try action(); check(false,"Expected error") } catch { check(true) } }
'''
methods=re.findall(r'func (test\w+)\(\)([^\{]*)\{',source)
runner='\n@main struct CoreCheckRunner { static func main() async throws { let suite = FamilyCoreTests()\n'
for name, flags in methods:
    runner+=f'FileHandle.standardOutput.write(Data("RUN {name}\\n".utf8)); '
    runner+=('try ' if 'throws' in flags else '')+('await ' if 'async' in flags else '')+f'suite.{name}(); print("PASS {name}")\n'
runner+=f'print("{len(methods)} scenarios passed; \\(checks) assertions.")\n}}}}\n'
with tempfile.TemporaryDirectory(prefix='family-core-checks-') as d:
    d=Path(d); testfile=d/'Checks.swift'; testfile.write_text(source+shim+runner)
    subprocess.run(['swiftc','-swift-version','5','-module-cache-path',str(d/'cache'),str(root/'Sources/FamilyCore/Models.swift'),str(root/'Sources/FamilyCore/Catalog.swift'),str(testfile),'-o',str(d/'checks')],check=True)
    subprocess.run([str(d/'checks')],check=True)
