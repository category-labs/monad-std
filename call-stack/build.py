#!/usr/bin/env python3
"""Build reproducible helper artifacts with stock solc and cast's Keccak-256."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
COMPILER = "0.8.35+commit.47b9dedd"
SOLC = os.environ.get("SOLC", "solc")
CAST = os.environ.get("CAST", "cast")


def run(*args, stdin=None):
    return subprocess.run(args, input=stdin, text=True, capture_output=True, check=True).stdout.strip()


def compile_sources(language, sources, optimized=True):
    settings = {
        "evmVersion": "cancun",
        "optimizer": {"enabled": optimized, "runs": 200},
        "outputSelection": {"*": {"*": ["abi", "evm.bytecode.object", "evm.deployedBytecode.object"]}},
    }
    if language == "Solidity":
        settings.update(viaIR=False, metadata={"bytecodeHash": "none", "appendCBOR": False})
    request = {"language": language, "sources": sources, "settings": settings}
    response = json.loads(run(SOLC, "--standard-json", stdin=json.dumps(request)))
    errors = [e["formattedMessage"] for e in response.get("errors", []) if e["severity"] == "error"]
    if errors:
        raise SystemExit("\n".join(errors))
    return response["contracts"], settings


def source(path):
    return {"content": (ROOT / path).read_text()}


def write_or_check(path, content, check):
    if check:
        if not path.exists() or path.read_text() != content:
            raise SystemExit(f"Stale artifact: {path.relative_to(ROOT)}; run python3 call-stack/build.py")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed artifacts without rewriting")
    parser.add_argument("--fixtures", action="store_true", help="also compile real-runtime test fixtures")
    args = parser.parse_args()
    version = run(SOLC, "--version")
    if not re.search(rf"Version: {re.escape(COMPILER)}(?:\.|$)", version):
        raise SystemExit(f"Expected stock solc {COMPILER}; got {version}")

    path = "call-stack/CallStack.yul"
    for optimized, name in [(True, "CallStack"), (False, "CallStack.unoptimized")]:
        contracts, settings = compile_sources("Yul", {path: source(path)}, optimized)
        evm = contracts[path]["CallStack"]["evm"]
        runtime = "0x" + evm["deployedBytecode"]["object"]
        code_hash = run(CAST, "keccak", runtime)
        artifact = {
            "compiler": COMPILER,
            "language": "Yul",
            "settings": settings,
            "source": path,
            "sourceSha256": hashlib.sha256((ROOT / path).read_bytes()).hexdigest(),
            "initcode": "0x" + evm["bytecode"]["object"],
            "runtime": runtime,
            "runtimeCodeHash": code_hash,
        }
        write_or_check(ROOT / f"call-stack/artifacts/{name}.json", json.dumps(artifact, indent=2) + "\n", args.check)
        if optimized:
            library = ROOT / "src/CallStack.sol"
            updated = re.sub(r"HELPER_CODE_HASH = [^;]+;", f"HELPER_CODE_HASH = {code_hash};", library.read_text())
            write_or_check(library, updated, args.check)
        print(f"{name}: {(len(runtime) - 2) // 2} runtime bytes, {code_hash}")

    if args.fixtures:
        paths = ["src/CallStack.sol", "src/interfaces/ICallStack.sol", "call-stack/test/Fixtures.sol"]
        contracts, _ = compile_sources("Solidity", {p: source(p) for p in paths})
        fixtures = contracts[paths[-1]]
        reference = "call-stack/test/Reference.yul"
        for optimized, suffix in [(True, ""), (False, ".unoptimized")]:
            contracts, _ = compile_sources("Yul", {reference: source(reference)}, optimized)
            fixtures["Reference" + suffix] = contracts[reference]["Reference"]
        destination = ROOT / "out/call-stack-fixtures.json"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(json.dumps(fixtures, indent=2) + "\n")


if __name__ == "__main__":
    main()
