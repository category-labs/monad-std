#!/usr/bin/env python3
"""Deploy and verify the helper on a loopback JSON-RPC node with an unlocked account."""

import argparse
import ipaddress
import json
from pathlib import Path
import time
from urllib.parse import urlparse
from urllib.request import Request, urlopen


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rpc-url", default="http://127.0.0.1:8545")
    parser.add_argument("--sender", help="unlocked local account; defaults to eth_accounts[0]")
    args = parser.parse_args()
    url = urlparse(args.rpc_url)
    try:
        loopback = ipaddress.ip_address(url.hostname).is_loopback
    except ValueError:
        loopback = False
    if url.scheme not in ("http", "https") or not loopback or url.username or url.password:
        parser.error("use a numeric loopback RPC address, such as http://127.0.0.1:8545")

    def rpc(method, params):
        body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
        request = Request(args.rpc_url, data=body, headers={"Content-Type": "application/json"})
        with urlopen(request, timeout=10) as response:
            result = json.load(response)
        if "error" in result:
            raise SystemExit(f"{method}: {result['error']}")
        return result["result"]

    artifact = json.loads((Path(__file__).parent / "artifacts/CallStack.json").read_text())
    accounts = [args.sender] if args.sender else rpc("eth_accounts", [])
    if not accounts:
        raise SystemExit("The local node has no unlocked accounts; pass --sender.")
    tx = rpc("eth_sendTransaction", [{"from": accounts[0], "data": artifact["initcode"], "gas": "0x7a120"}])
    deadline = time.monotonic() + 30
    receipt = None
    while time.monotonic() < deadline:
        receipt = rpc("eth_getTransactionReceipt", [tx])
        if receipt:
            break
        time.sleep(0.1)
    if not receipt or int(receipt["status"], 16) != 1:
        raise SystemExit(f"Deployment did not succeed: {tx}; receipt={receipt}")
    address = receipt["contractAddress"]
    code = rpc("eth_getCode", [address, "latest"])
    if code.lower() != artifact["runtime"]:
        raise SystemExit(f"Unexpected deployed runtime at {address}")
    print(json.dumps({"helper": address, "runtimeCodeHash": artifact["runtimeCodeHash"], "transactionHash": tx}, indent=2))


if __name__ == "__main__":
    main()
