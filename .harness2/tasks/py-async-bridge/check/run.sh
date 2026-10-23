#!/usr/bin/env bash
# Hidden acceptance check for py-async-bridge. cwd = workspace; package in output/async_bridge.
source "$(dirname "$0")/ac.sh"
cd output/async_bridge || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/async_bridge missing"}'; exit 1; }
export PYTHONPATH="$PWD" PYTHONDONTWRITEBYTECODE=1
ac "flake8 E/W/F clean (max-line-length 100)" python3 -m flake8 --select E,W,F --max-line-length 100 async_bridge
ac "mypy --strict clean" python3 -m mypy --strict --no-incremental --cache-dir=/dev/null async_bridge
ac "own pytest suite passes" timeout 300 python3 -m pytest -q -p no:cacheprovider tests
ac "own tests >= 5" bash -c '[ "$(python3 -m pytest -q -p no:cacheprovider --collect-only tests 2>/dev/null | grep -c "::")" -ge 5 ]'
ac "hidden behaviour tests pass (x3)" bash -c "for i in 1 2 3; do timeout 120 python3 -m pytest -q -p no:cacheprovider '$OLDPWD/check/test_hidden.py' || exit 1; done"
ac "no time.sleep" absent 'time\.sleep' async_bridge tests
ac_done
