#!/usr/bin/env python3
"""REA Wiki Vault skill helper. Offline first; safe default = preview / read-only.

Python 3.9+ stdlib. Human/agent checks approval before --apply side effects.
"""
from __future__ import annotations

import argparse
import datetime as dt
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

REPO_SSH = "git@github.com:ipa-vsp/rea-wiki-vault.git"
REPO_HTTPS = "https://github.com/ipa-vsp/rea-wiki-vault.git"
SKILL_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_VAULT = Path(os.environ.get("REA_WIKI_VAULT", "~/rea-wiki-vault")).expanduser()


def cmdline(args):
    return " ".join(__import__("shlex").quote(str(a)) for a in args)


def run(args, *, cwd=None, check=True):
    print("$", cmdline(args), f"(cwd={cwd})" if cwd else "", flush=True)
    return subprocess.run([str(x) for x in args], cwd=cwd, check=check, text=True)


def vault_path(args):
    return Path(args.vault).expanduser().resolve()


def is_vault(path):
    return all((path / f).is_file() for f in ("CLAUDE.md", "AGENTS.md", "index.md", "tools/scan_ros_ws.py"))


def display_help(_args):
    print((SKILL_ROOT / "references/help.md").read_text(encoding="utf-8"))
    print("\nMechanical subcommands: help, doctor, status, bootstrap, setup, dashboard")
    print("To use natural-language operations (ingest, trace, debug, experiment, etc.), invoke the agent skill.")
    return 0


def check_program(name):
    p = shutil.which(name)
    print(f"  {name:12}: {p or 'not found'}")
    return bool(p)


def doctor(args):
    vault = vault_path(args)
    ws = Path(args.workspace).expanduser().resolve()
    print(f"Vault:     {vault}")
    print(f"Workspace: {ws} {'(exists)' if ws.is_dir() else '(MISSING)'}")
    print(f"Vault exists: {vault.exists()} | initialized: {is_vault(vault)}")
    if vault.exists() and not is_vault(vault):
        print("WARNING: path exists but isn't a recognized REA Wiki Vault. Never replace it automatically.")
    if is_vault(vault):
        print(f"Vault writable by OS user: {os.access(vault, os.W_OK)} (agent sandbox may still deny)")
        cmd = ["git", "-C", str(vault), "remote", "get-url", "origin"]
        if shutil.which("git"):
            x = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            print("Git origin:", x.stdout.strip() if x.returncode == 0 else "unknown")
        targets = vault / "targets"
        ts = sorted(p.stem for p in targets.glob("*.md")) if targets.exists() else []
        print("Known targets:", ", ".join(ts) or "none")
        matched=[]
        for p in targets.glob("*.md") if targets.exists() else []:
            try:
                txt=p.read_text(encoding="utf-8")
                if str(ws) in txt or f'"{ws.as_posix()}"' in txt:
                    matched.append(p.stem)
            except OSError:
                pass
        print("Current-workspace target matches:", ", ".join(matched) or "none located (paths may use ~)")
        for t in matched:
            print(f"  {t}: scan={(vault/'raw'/t/'workspace-map.json').exists()}, "
                  f"dashboard={(vault/'dashboard/data'/f'{t}.js').exists()}, "
                  f"graph={(vault/'generated/graphify'/t).exists()}")
    print("Programs:")
    for p in ("python3", "git", "claude", "codex", "agy", "uv", "graphify", "npx", "node"):
        check_program(p)
    print("Host-agent workspace permissions cannot be verified by an external Python helper.")
    print("Claude: claude --add-dir ~/rea-wiki-vault")
    print("Codex: codex --sandbox workspace-write --add-dir ~/rea-wiki-vault (verify codex --help)")
    print("agy: /add-dir ~/rea-wiki-vault then /permissions")
    return 0


def bootstrap(args):
    vault = vault_path(args)
    if is_vault(vault):
        print(f"Already initialized: {vault}. No clone needed.")
        return 0
    if vault.exists() or vault.is_symlink():
        print(f"BLOCKED: {vault} already exists but is not this vault. Won't overwrite it.", file=sys.stderr)
        return 2
    transport = REPO_HTTPS if args.transport == "https" else REPO_SSH
    command = ["git", "clone", "--", transport, str(vault)]
    print("Clone destination:", vault)
    print("Git remote:", transport)
    if not args.apply:
        print("PREVIEW ONLY. To clone, run: " + cmdline([sys.executable, __file__, "bootstrap", "--vault", vault, "--transport", args.transport, "--apply"]))
        return 0
    if not shutil.which("git"):
        print("git not installed", file=sys.stderr)
        return 3
    try:
        vault.parent.mkdir(parents=True, exist_ok=True)
        run(command)
    except (subprocess.CalledProcessError, OSError) as e:
        print(f"Clone failed (likely private-repo authentication): {e}", file=sys.stderr)
        print("Configure GitHub SSH or rerun with --transport https; no checkout is deleted automatically.")
        return 3
    print("Cloned successfully." if is_vault(vault) else "Clone returned, but expected vault files are missing!")
    return 0 if is_vault(vault) else 4


def slugify(name):
    return re.sub(r"^-+|-+$", "", re.sub(r"[^a-z0-9]+", "-", name.lower()))


def safe_target(name):
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,48}", name):
        raise ValueError("Target id must have 2-49 lowercase letters, numbers or hyphens, starting with a letter")
    return name


def append_once(file, marker, entry):
    if not file.exists():
        print("WARNING: missing", file, "— won't recreate structural vault file")
        return
    content=file.read_text(encoding="utf-8")
    if marker not in content:
        with file.open("a", encoding="utf-8") as f:
            f.write("\n" + entry.rstrip() + "\n")
        print("Updated:", file)


def setup(args):
    vault=vault_path(args)
    ws=Path(args.workspace).expanduser().resolve()
    if not is_vault(vault):
        print(f"Vault not initialized at {vault}. Run bootstrap --apply first.", file=sys.stderr)
        return 2
    if not ws.is_dir():
        print(f"Current workspace not found: {ws}", file=sys.stderr)
        return 2
    if ws==vault:
        print("Workspace equals vault; register an external workspace, not the vault itself.", file=sys.stderr)
        return 2
    name=args.target or slugify(ws.name)
    try: safe_target(name)
    except ValueError as e:
        print(e, file=sys.stderr);return 2
    src=args.src or ("src" if (ws/"src").is_dir() else ".")
    source=(ws/src).resolve()
    if not source.is_dir() or not source.is_relative_to(ws):
        print("Invalid source root within workspace:", src, file=sys.stderr);return 2
    target_file=vault/"targets"/f"{name}.md"
    raw_file=vault/"raw"/name/"workspace-map.json"
    dashboard_file=vault/"dashboard/data"/f"{name}.js"
    print(f"Workspace: {ws}\nVault: {vault}\nTarget: {name}\nScan source: {src} ({source})")
    print("Target note:", target_file, "EXISTS" if target_file.exists() else "NEW")
    print("Map:", raw_file, "EXISTS" if raw_file.exists() else "NEW")
    print("Dashboard:", dashboard_file, "EXISTS" if dashboard_file.exists() else "NEW")
    print("Graphify:", "requested" if args.with_graphify else "optional; not run")
    if src==".":
        print("NOTE: no src/ folder detected. For non-colcon monorepos, specify --src <repo-relative-dir> if relevant.")
    if target_file.exists():
        old=target_file.read_text(encoding="utf-8")
        # Cautious: prevent assigning a different workspace to existing target name.
        workspace_line=re.search(r"(?m)^workspace:\s*['\"]?([^'\"\n]+)", old)
        if workspace_line:
            old_root=Path(workspace_line.group(1).strip()).expanduser()
            if old_root.is_absolute() and old_root.resolve()!=ws:
                print("BLOCKED: this target is registered to", old_root, "not", ws, file=sys.stderr)
                return 2
    if not args.apply:
        print("PREVIEW ONLY. To initialize, rerun with --apply (after granting your agent write access to the vault).")
        return 0
    # Never overwrite existing target info unless a separate refresh was requested.
    target_file.parent.mkdir(parents=True, exist_ok=True)
    raw_file.parent.mkdir(parents=True, exist_ok=True)
    if not target_file.exists():
        today=dt.date.today().isoformat()
        target_file.write_text(
            '---\n'
            f'title: "{name}"\n'
            f'tags: [target, {name}]\n'
            f'domain: [{args.domain}]\n'
            f'workspace: "{ws}"\n'
            '---\n\n'
            f'# Target: {name}\n\nWorkspace: `{ws}`\n'
            f'Source root: `{src}`\n'
            f'Initial registration: {today}\n\n'
            '## Compatibility matrix\n\n'
            '| Dimension | Value | Proof |\n|---|---|---|\n'
            '| ROS distro / host | UNKNOWN | Inspect raw environment snapshot |\n'
            '| RMW / simulation | UNKNOWN | To be filled |\n'
            '| Hardware safety | sim-only until operator-approved | No hardware test run |\n\n'
            '## Map and documentation\n\n'
            f'- Source map: `raw/{name}/workspace-map.json` (may be pending)\n'
            f'- Graphify: `generated/graphify/{name}/` (optional)\n'
            '- Note status: mapped, not runtime-verified\n',encoding="utf-8")
        print("Created:",target_file)
    else:
        print("Preserved existing target note:",target_file)
    if args.refresh or not raw_file.exists():
        scanner=[sys.executable,"-I","tools/scan_ros_ws.py",str(ws),str(raw_file),"--src",src]
        for s in args.first_party_host:scanner.extend(["--first-party-host",s])
        try:run(scanner,cwd=vault)
        except subprocess.CalledProcessError as e:
            print("Scanner failed:",e,"; target note kept. Investigate the workspace layout.", file=sys.stderr)
    else: print("Preserved existing workspace map. Use --refresh to re-map.")
    if args.refresh or not list((vault/"raw"/name).glob("env-*.json")):
        try:run([sys.executable,"-I","tools/env_snapshot.py",".",name,"--ws",str(ws)],cwd=vault)
        except subprocess.CalledProcessError as e:print("Environment snapshot failed:",e,file=sys.stderr)
    else:print("Environment snapshot exists. Use --refresh to record a new one.")
    if args.with_graphify:
        if not shutil.which("graphify"):
            print("Graphify CLI absent. Install with `uv tool install graphifyy`; cannot graph yet.")
        else:
            try:
                run(["graphify","update",str(source)],cwd=ws)
                outputs=[ws/"graphify-out",source/"graphify-out"]
                found=next((p for p in outputs if p.is_dir()),None)
                if found:
                    link=vault/"generated/graphify"/name
                    link.parent.mkdir(parents=True,exist_ok=True)
                    if not link.exists() and not link.is_symlink():
                        link.symlink_to(found.resolve(),target_is_directory=True)
                        print("Linked Graphify graph:",link,"->",found)
                    else:print("Preserved existing Graphify link/dir:",link)
                else:print("Graphify finished but graphify-out not located: inspect its output path before linking.")
            except subprocess.CalledProcessError as e:print("Graphify update failed:",e,file=sys.stderr)
    if raw_file.is_file():
        try:run([sys.executable,"-I","tools/build_dashboard.py",".",name],cwd=vault)
        except subprocess.CalledProcessError as e:print("Dashboard build failed:",e,file=sys.stderr)
    append_once(vault/"index.md",f"[[{name}]]",f"- [[{name}]] — target workspace `{ws}`")
    marker=f"| {name} | Target initialized"
    today=dt.date.today().isoformat()
    # A single initial entry; future refreshes should not regenerate this.
    append_once(vault/"log.md",marker,
                f"## [{today}] map | {name} | Target initialized\n\n"
                f"- Workspace `{ws}`; source root `{src}`.\n"
                f"- {marker}; status not verified by runtime testing.\n")
    try:
        run([sys.executable,"-I","tools/check_notes.py","."],cwd=vault)
    except subprocess.CalledProcessError as e:
        print("Note gate reports errors; fix unresolved links/frontmatter before claiming complete:",e, file=sys.stderr)
    print(f"Target ready to inspect: targets/{name}.md")
    print(f"Dashboard: http://127.0.0.1:4180/?t={name} (start `rea-wiki-vault dashboard --target {name} --serve`)")
    return 0


def dashboard(args):
    vault=vault_path(args)
    if not is_vault(vault):
        print("Vault not initialized",file=sys.stderr);return 2
    try: name=safe_target(args.target)
    except ValueError as e:print(e,file=sys.stderr);return 2
    if args.apply:
        try:run([sys.executable,"-I","tools/build_dashboard.py",".",name],cwd=vault)
        except subprocess.CalledProcessError as e:return e.returncode
    else:
        print("Preview: dashboard data refresh not run. Use --apply.")
    print(f"Dashboard: http://127.0.0.1:{args.port}/?t={name}")
    if args.serve:
        os.chdir(vault)
        run([sys.executable,"-m","http.server",str(args.port),"--bind","127.0.0.1","--directory","dashboard"],cwd=vault)
    return 0


def main(argv=None):
    parser=argparse.ArgumentParser(description="REA Wiki Vault cross-agent helper (safe defaults)")
    parser.add_argument("--version", action="version",version="rea-wiki-vault-skill 0.1.0")
    sub=parser.add_subparsers(dest="operation")
    sub.add_parser("help",help="Full capabilities reference (read-only)")
    for k in ("doctor","status"):
        p=sub.add_parser(k,help="Report local tools and vault/workspace state (read-only)")
        p.add_argument("--vault",default=str(DEFAULT_VAULT))
        p.add_argument("--workspace",default=os.getcwd())
    p=sub.add_parser("bootstrap",help="Preview/clone the private vault repo if missing")
    p.add_argument("--vault",default=str(DEFAULT_VAULT))
    p.add_argument("--transport",choices=("ssh","https"),default="ssh")
    p.add_argument("--apply",action="store_true",help="Actually clone; preview otherwise")
    p=sub.add_parser("setup",help="Preview/register the current source workspace as target")
    p.add_argument("--vault",default=str(DEFAULT_VAULT))
    p.add_argument("--workspace",default=os.getcwd())
    p.add_argument("--target",help="Target slug; defaults to current directory name")
    p.add_argument("--src",help="Relative source root; auto-detect src/ else .")
    p.add_argument("--domain",choices=("ros2","robot-control","rl","vla","canopen","ethercat","general","web"),default="ros2")
    p.add_argument("--first-party-host",action="append",default=[])
    p.add_argument("--with-graphify",action="store_true",help="Run Graphify update if installed and link output")
    p.add_argument("--refresh",action="store_true",help="Re-scan and snapshot existing target")
    p.add_argument("--apply",action="store_true",help="Write target and run tools")
    p=sub.add_parser("dashboard",help="Rebuild/serve local visualization")
    p.add_argument("--vault",default=str(DEFAULT_VAULT))
    p.add_argument("--target",required=True)
    p.add_argument("--apply",action="store_true",help="Rebuild data")
    p.add_argument("--serve",action="store_true",help="Run local HTTP server (foreground)")
    p.add_argument("--port",type=int,default=4180)
    a=parser.parse_args(argv)
    try:
        if a.operation in (None,"help"):return display_help(a)
        return {"doctor":doctor,"status":doctor,"bootstrap":bootstrap,
                "setup":setup,"dashboard":dashboard}[a.operation](a)
    except (OSError,ValueError) as e:
        print(f"ERROR: {e}",file=sys.stderr)
        return 3


if __name__=="__main__":sys.exit(main())
