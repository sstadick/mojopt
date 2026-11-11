"""Exercise the installed package in a fresh, source-independent consumer."""

import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import tomllib


root = Path(__file__).resolve().parents[1]
manifest = tomllib.loads((root / "pixi.toml").read_text())
target = {
    ("Linux", "x86_64"): "linux-64",
    ("Linux", "aarch64"): "linux-aarch64",
    ("Darwin", "arm64"): "osx-arm64",
}[(platform.system(), platform.machine())]
features = []
if target == "linux-64":
    features = ["--target-features=" + ",".join(
        "-" + name for name in (
            "avx512f", "avx512bw", "avx512cd", "avx512dq", "avx512vl",
            "avx512ifma", "avx512vbmi", "avx512vbmi2", "avx512vnni",
            "avx512bitalg", "avx512vpopcntdq", "avx512fp16", "avx512bf16",
        )
    )]
env = os.environ.copy()
for name in ("MOJO_PATH", "MOJO_INCLUDE_PATH", "MODULAR_MOJO_IMPORT_PATH",
             "PIXI_PROJECT_MANIFEST", "PIXI_WORKSPACE_MANIFEST"):
    env.pop(name, None)

with tempfile.TemporaryDirectory(prefix="mojopt-consumer-") as directory:
    consumer = Path(directory)
    artifacts = consumer / "artifacts"
    artifacts.mkdir()
    subprocess.run(
        ["pixi", "build", "--path", str(root / "pixi.toml"), "--output-dir", str(artifacts)],
        cwd=consumer, env=env, check=True, timeout=300,
    )
    archives = list(artifacts.glob("mojopt-*.conda"))
    assert len(archives) == 1, archives
    archive = archives[0]
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    print(f"Installing {archive.name} sha256={digest}", flush=True)
    (consumer / "pixi.toml").write_text(f'''[workspace]
name = "mojopt-consumer"
channels = {json.dumps(manifest["workspace"]["channels"])}
platforms = ["{target}"]
preview = ["pixi-build"]
[dependencies]
mojo = {json.dumps(manifest["dependencies"]["mojo"])}
mojopt = {{ url = {json.dumps(archive.as_uri())}, sha256 = "{digest}" }}
''')
    pixi = ["pixi", "run", "--manifest-path", str(consumer / "pixi.toml")]

    def run(command, *, code=0, contains=None):
        result = subprocess.run(command, cwd=consumer, env=env, text=True,
                                capture_output=True, timeout=300)
        if result.returncode != code or (
            contains is not None and contains not in result.stdout + result.stderr
        ):
            raise RuntimeError(f"{command}\nexit: {result.returncode}\n"
                               f"{result.stdout}\n{result.stderr}")
        return result

    tests = sorted((root / "tests").glob("test_*.mojo"))
    assert tests, "no tests discovered"
    for test in tests:
        shutil.copyfile(test, consumer / test.name)
        result = run([*pixi, "mojo", "run", *features, "-D", "ASSERT=all", test.name])
        print(result.stdout, end="", flush=True)
    installed = list((consumer / ".pixi/envs/default/lib/mojo").glob("mojopt.*"))
    assert installed, "built module missing from consumer prefix"

    shutil.copyfile(root / "examples/options.mojo", consumer / "options.mojo")
    binary = consumer / "options"
    run([*pixi, "mojo", "build", *features, "options.mojo", "-o", str(binary)])
    for command in ([*pixi, "mojo", "run", *features, "options.mojo"], [str(binary)]):
        run([*command, "input.txt", "-nAda", "-vc-3", "-fCSV", "-Isrc", "--include=src"],
            contains="input.txt Ada -3 True\n[src, src]\nname supplied: True")
        run([*command, "-n", "--help", "--", "--verbose=false"],
            contains="--verbose=false --help 1 False")
        run([*command, "--count"], code=2, contains="Missing option value")
        run([*command, "--verbose=False"], code=2, contains="expected bool (true or false)")
        run([*command, "--format=csv"], code=2, contains="[json, plain_text, CSV]")
        run([*command, "-vxh"], code=2, contains="Unknown option: -x")
        help_text = run([*command, "--help"]).stdout
        assert run([*command, "-vhx"]).stdout == help_text
        for text in ("--name=NAME", "--count=COUNT", "--format=FORMAT",
                     "--include=INCLUDE...", "-v, --verbose", "-h, --help"):
            assert text in help_text, help_text
        assert "--verbose=" not in help_text
    print("PASS installed example via mojo run and native executable", flush=True)

    readme = (root / "README.md").read_text()
    program = re.findall(r"```mojo\n(.*?)```", readme, re.S)[0]
    (consumer / "readme.mojo").write_text(program)
    run([*pixi, "mojo", "run", *features, "readme.mojo", "input.txt", "-nAda", "-vc3"],
        contains="input.txt Ada 3 True\nname supplied: True")
    print("PASS README program", flush=True)

    (consumer / "payload.mojo").write_text('''from mojopt.deserialize import MojOptDeserializable, Opt
from mojopt.parser import Parser

__enum Choice(ImplicitlyCopyable):
    case plain
    case payload(Int)

@fieldwise_init
struct Args(Defaultable, MojOptDeserializable):
    var choice: Opt[Choice]
    def __init__(out self):
        self.choice = {Choice.plain}

def main() raises:
    var args = Parser.parse[Args](["--choice=plain"])
''')
    run([*pixi, "mojo", "build", *features, "payload.mojo"], code=1,
        contains="MojOpt enum choices cannot have payloads")
    print("PASS payload enum compile rejection", flush=True)

    zsh = shutil.which("zsh")
    if zsh:
        run([zsh, str(root / "tests/completion.zsh"), str(binary), zsh],
            contains="PASS GNU completion")
        print("PASS zsh _gnu_generic completion", flush=True)
    else:
        print("SKIP zsh completion: zsh not installed", flush=True)
    print(f"Clean consumer installed {installed[0].name} and passed", flush=True)
