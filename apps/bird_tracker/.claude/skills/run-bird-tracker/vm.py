#!/usr/bin/env python3
"""Evaluate a Dart expression in the running debug app over the VM service.

usage: vm.py <ws-uri> <expression> [library-uri]

The expression is compiled in the scope of the given library (default: the
Flutter widgets library, which sees FocusManager, EditableTextState,
TextEditingValue, ...). Use package:tracker_core/service/data_service.dart to
reach DataService(). Prints valueAsString, or the error message.
"""
import json
import sys

import websocket

uri, expression = sys.argv[1], sys.argv[2]
library = sys.argv[3] if len(sys.argv) > 3 else \
    "package:flutter/src/widgets/editable_text.dart"

ws = websocket.create_connection(uri)
_id = 0


def call(method, **params):
    global _id
    _id += 1
    ws.send(json.dumps({"jsonrpc": "2.0", "id": str(_id),
                        "method": method, "params": params}))
    while True:
        r = json.loads(ws.recv())
        if r.get("id") == str(_id):
            return r


isolates = call("getVM")["result"]["isolates"]
iso = next(i for i in isolates if i["name"] == "main")["id"]
libs = call("getIsolate", isolateId=iso)["result"]["libraries"]
target = next((l["id"] for l in libs if l["uri"] == library), None)
if target is None:
    sys.exit(f"library not loaded: {library}")
r = call("evaluate", isolateId=iso, targetId=target, expression=expression)
res = r.get("result") or r.get("error") or {}
if res.get("type") == "@Error" or "error" in r:
    data = r.get("error", {}).get("data", {})
    sys.exit(f"{res.get('message')}: {data.get('details', '')}".strip())
print(res.get("valueAsString", res.get("class", {}).get("name", json.dumps(res)[:400])))
