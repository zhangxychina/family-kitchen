"""Regenerate the README and App Store screenshots from the running app.

Seeds a simulator with a real-looking kitchen, runs the screenshot UI test against
it, and pulls the pictures out of the result bundle. The pictures are never touched
by hand: a screenshot that no longer matches the app is worse than none.

    python3 scripts/screenshots.py ["iPhone 18 Pro Max"]

The default device is a 6.9-inch iPhone, which is the size the App Store asks for
(1320 x 2868). Nothing here is part of the app.
"""
from pathlib import Path
import json, os, re, shutil, subprocess, sys, tempfile

root = Path(__file__).resolve().parents[1]
device = sys.argv[1] if len(sys.argv) > 1 else "iPhone 18 Pro Max"
xcode = {"DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer"}
out = root / "Screenshots"
bundle = "com.familykitchen.app"


def run(args, **kw):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kw).stdout


def sim(*args):
    return run(["xcrun", "simctl", *args])


def seed():
    """Write a kitchen worth photographing into both of the app's storage folders."""
    with tempfile.TemporaryDirectory() as tmp:
        state = Path(tmp) / "family.json"
        core = sorted(str(f) for f in (root / "Sources/FamilyCore").glob("*.swift"))
        binary = Path(tmp) / "seed"
        run(["swiftc", "-swift-version", "5", *core, str(root / "scripts/seed_state.swift"),
             "-o", str(binary)])
        print(run([str(binary), str(state)]).strip())
        container = Path(sim("get_app_container", device, bundle, "data").strip())
        for folder in ("FamilyKitchen", "FamilyKitchenUITests"):
            target = container / "Library/Application Support" / folder
            target.mkdir(parents=True, exist_ok=True)
            shutil.copy(state, target / "family.json")
        print(f"seeded {container}")


def capture():
    result = root / "build/screenshots.xcresult"
    if result.exists():
        shutil.rmtree(result)
    result.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["xcodebuild", "-project", "FamilyKitchen.xcodeproj", "-scheme", "FamilyKitchen",
                    "-destination", f"platform=iOS Simulator,name={device}",
                    "-resultBundlePath", str(result),
                    "-only-testing:FamilyKitchenUITests/FamilyKitchenScreenshots", "test"],
                   cwd=root, env={**os.environ, **xcode}, check=True)
    return result


def extract(result):
    """Pull the named attachments out of the result bundle."""
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments",
                        "--path", str(result), "--output-path", tmp],
                       env={**os.environ, **xcode}, check=True,
                       capture_output=True, text=True)
        manifest = json.loads((Path(tmp) / "manifest.json").read_text())
        out.mkdir(exist_ok=True)
        saved = []
        for entry in manifest:
            for attachment in entry.get("attachments", []):
                name = attachment.get("suggestedHumanReadableName") or attachment.get("exportedFileName")
                source = Path(tmp) / attachment["exportedFileName"]
                if not name or not source.exists() or not name[:2].isdigit():
                    continue
                # The bundle appends a run id; the README wants a stable filename.
                stem = re.sub(r"_\d+_[A-F0-9-]+$", "", name.removesuffix(".png"))
                destination = out / (stem + ".png")
                shutil.copy(source, destination)
                saved.append(destination)
        return sorted(saved)


if __name__ == "__main__":
    sim("bootstatus", device, "-b")
    seed()
    pictures = extract(capture())
    for picture in pictures:
        print(f"  {picture.relative_to(root)}  {picture.stat().st_size // 1024} KB")
    print(f"{len(pictures)} screenshots in {out.relative_to(root)}")
