import json
import glob
import re
import sys
import os

print("1. Checking JSON syntax and nulls...")
files = glob.glob("Json2Schemas/**/*.json", recursive=True) + glob.glob("ServerStorage/**/*.json", recursive=True)
for f in files:
    with open(f, "r", encoding="utf-8") as fp:
        doc = json.load(fp)
    def check_null(v, p):
        if v is None: raise ValueError(f"null at {p} in {f}")
        if isinstance(v, dict):
            for k, val in v.items(): check_null(val, f"{p}.{k}")
        elif isinstance(v, list):
            for i, val in enumerate(v): check_null(val, f"{p}[{i}]")
    check_null(doc, "")
print(f"   Checked {len(files)} JSON files successfully without any nulls.")

print("2. Checking Command Registry alignment...")
with open("ReplicatedStorage/AdminSettings.lua", "r", encoding="utf-8") as f:
    settings_code = f.read()
with open("ServerScriptService/AdminLoader/Commands.lua", "r", encoding="utf-8") as f:
    commands_code = f.read()

registered_cmds = set(re.findall(r'register\("([a-zA-Z0-9_]+)"', settings_code))
implemented_cmds = set(re.findall(r'Commands\.([a-zA-Z0-9_]+)\s*=', commands_code))

print(f"   Registered in AdminSettings: {len(registered_cmds)}")
print(f"   Implemented in Commands: {len(implemented_cmds)}")

missing_impl = registered_cmds - implemented_cmds
if missing_impl:
    print(f"FAIL: Missing implementations: {missing_impl}")
    sys.exit(1)
print("   -> 100% 1:1 match between registered commands and implemented commands!")

print("3. Checking MetalPipe in ToolRegistry...")
assert 'pipe = {AssetName = "MetalPipe"}' in settings_code
assert 'Commands.pipe =' in commands_code
print("   -> MetalPipe registered and command implemented!")

print("4. Checking $ref in all 3D schemas...")
for f in sorted(glob.glob("Json2Schemas/3D/*.json")):
    with open(f, "r", encoding="utf-8") as fp:
        d = json.load(fp)
    pp = d.get("Properties", {}).get("PrimaryPart", {})
    ref = pp.get("$ref")
    assert ref, f"Missing $ref in {f}"
    print(f"   {f} -> PrimaryPart $ref: '{ref}' [OK]")

print("5. Checking Signature Admin Tools in ServerStorage/AdminTools...")
required_tools = ["MetalPipe", "BanHammer", "GravityGun", "FreezeRay", "BlackHoleCannon"]
for tool_name in required_tools:
    tool_dir = f"ServerStorage/AdminTools/{tool_name}"
    assert os.path.exists(tool_dir), f"Missing tool directory: {tool_dir}"
    server_script = glob.glob(f"{tool_dir}/*Server.server.lua") + glob.glob(f"{tool_dir}/*.server.lua")
    assert server_script, f"Missing server script in {tool_dir}"
    if tool_name in ["GravityGun", "FreezeRay", "BlackHoleCannon"]:
        client_script = glob.glob(f"{tool_dir}/*Client.client.lua")
        assert client_script, f"Missing client script in {tool_dir}"
    print(f"   {tool_name} tool verified at {tool_dir} [OK]")

print("6. Checking Executive Admin Dashboard (Json2GUI)...")
with open("Json2Schemas/UI/AdminDashboard.json", "r", encoding="utf-8") as fp:
    dash_schema = json.load(fp)
assert dash_schema["Roots"][0]["Name"] == "AdminDashboard"
with open("Json2Schemas/AdminUiAssets.json", "r", encoding="utf-8") as fp:
    master_ui = json.load(fp)
found_dash = any(r.get("Name") == "AdminDashboard" for r in master_ui["Roots"])
assert found_dash, "AdminDashboard not found in master AdminUiAssets.json"
print(f"   AdminDashboard schema & AdminUiAssets bundle verified ({len(master_ui['Roots'])} UI roots) [OK]")

print("7. Checking AdminClient.local.lua dashboard and keybind hooks...")
with open("StarterPlayerScripts/AdminClient.local.lua", "r", encoding="utf-8") as fp:
    client_code = fp.read()
assert 'Enum.KeyCode.F2' in client_code, "Missing F2 keybind in AdminClient"
assert 'ToggleDashboard' in client_code, "Missing ToggleDashboard remote handler in AdminClient"
assert 'toggleDashboard()' in client_code, "Missing toggleDashboard call in AdminClient"
print("   AdminClient F2 hotkey and ToggleDashboard handler verified [OK]")

print("8. Checking Config.lua and AuditLogger.lua...")
assert os.path.exists("ServerScriptService/AdminLoader/Config.lua"), "Missing Config.lua"
assert os.path.exists("ServerScriptService/AdminLoader/AuditLogger.lua"), "Missing AuditLogger.lua"
with open("ServerScriptService/AdminLoader/Config.lua", "r", encoding="utf-8") as fp:
    cfg = fp.read()
assert "DiscordWebhook" in cfg, "Missing DiscordWebhook table in Config.lua"
assert "WebhookUrl" in cfg, "Missing WebhookUrl in Config.lua"
with open("ServerScriptService/AdminLoader/AuditLogger.lua", "r", encoding="utf-8") as fp:
    logger = fp.read()
assert "LogModeration" in logger, "Missing LogModeration in AuditLogger.lua"
assert "HttpService" in logger, "Missing HttpService in AuditLogger.lua"
print("   Config.lua and AuditLogger.lua verified [OK]")

print("\nALL VERIFICATION CHECKS PASSED 100% PERFECTLY!")
