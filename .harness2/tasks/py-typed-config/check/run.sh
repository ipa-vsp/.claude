#!/usr/bin/env bash
# Hidden acceptance check for py-typed-config. cwd = workspace; deliverable in output/robot_config.
source "$(dirname "$0")/ac.sh"
cd output/robot_config || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/robot_config missing"}'; exit 1; }
export PYTHONPATH="$PWD" PYTHONDONTWRITEBYTECODE=1
ac "flake8 E/W/F clean (max-line-length 100)" python3 -m flake8 --select E,W,F --max-line-length 100 robot_config tests
ac "mypy --strict clean" python3 -m mypy --strict --no-incremental --cache-dir=/dev/null robot_config
ac "own pytest suite passes" python3 -m pytest -q -p no:cacheprovider tests
ac "own tests cover rejections (>=8 tests)" bash -c '[ "$(python3 -m pytest -q -p no:cacheprovider --collect-only tests 2>/dev/null | grep -c "::")" -ge 8 ]'
ac "hidden API/validation tests pass" python3 -m pytest -q -p no:cacheprovider "$OLDPWD/check/test_hidden.py"
ac "example still loads" python3 -c "from robot_config import load_config; load_config('examples/fr3.toml')"
ac_done
