"""Run the XCTest scenarios without XCTest when only Command Line Tools are installed."""
from pathlib import Path
import re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
source=(root/'Tests/FamilyCoreTests/FamilyCoreTests.swift').read_text().replace('import XCTest','import Foundation').replace('@testable import FamilyCore','')
shim='''
var checks = 0
class XCTestCase {}
func check(_ condition: Bool, _ message: String = "Assertion failed", file: StaticString = #filePath, line: UInt = #line) { checks += 1; if !condition { fatalError("\\(message) at \\(file):\\(line)") } }
func XCTAssertTrue(_ v: Bool, _ message: String = "Expected true") { check(v,message) }
func XCTAssertFalse(_ v: Bool, _ message: String = "Expected false") { check(!v,message) }
func XCTAssertNotNil<T>(_ v: T?, _ message: String = "Expected a value") { check(v != nil,message) }
func XCTAssertNil<T>(_ v: T?) { check(v == nil) }
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T) { check(a == b, "\\(a) != \\(b)") }
func XCTAssertEqual(_ a: Double, _ b: Double, accuracy: Double) { check(abs(a-b) <= accuracy) }
func XCTAssertGreaterThan<T: Comparable>(_ a: T, _ b: T, _ message: String = "") { check(a > b, message.isEmpty ? "\(a) <= \(b)" : message) }
func XCTAssertGreaterThanOrEqual<T: Comparable>(_ a: T, _ b: T, _ message: String = "") { check(a >= b, message.isEmpty ? "\(a) < \(b)" : message) }
func XCTAssertLessThan<T: Comparable>(_ a: T, _ b: T, _ message: String = "") { check(a < b, message.isEmpty ? "\(a) >= \(b)" : message) }
func XCTAssertLessThanOrEqual<T: Comparable>(_ a: T, _ b: T, _ message: String = "") { check(a <= b, message.isEmpty ? "\(a) > \(b)" : message) }
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
    core=sorted(str(f) for f in (root/'Sources/FamilyCore').glob('*.swift'))
    subprocess.run(['swiftc','-swift-version','5','-module-cache-path',str(d/'cache'),*core,str(testfile),'-o',str(d/'checks')],check=True)
    subprocess.run([str(d/'checks')],check=True)
