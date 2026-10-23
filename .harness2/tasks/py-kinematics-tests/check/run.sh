#!/usr/bin/env bash
# Hidden acceptance check for py-kinematics-tests. The original kinematics.py is restored from the
# seed before grading, so the agent's tests are judged against the real module and its mutants.
source "$(dirname "$0")/ac.sh"
CHECK="$PWD/check"
cd output/planar_arm || { echo '{"n_passed": 0, "n_criteria": 1, "notes": "output/planar_arm missing"}'; exit 1; }
export PYTHONPATH="$PWD" PYTHONDONTWRITEBYTECODE=1
cp "$HARNESS2_TASK_DIR/files/output/planar_arm/planar_arm/kinematics.py" planar_arm/kinematics.py
PYT=(python3 -m pytest -q -x -p no:cacheprovider tests)
ac "own suite passes on the real module" "${PYT[@]}"
ac "branch coverage >= 90%" python3 -m pytest -q -p no:cacheprovider --cov=planar_arm --cov-branch --cov-fail-under=90 tests
ac "uses parametrize and fixtures" bash -c 'grep -rq "pytest.mark.parametrize" tests && grep -rq "pytest.fixture" tests'
for m in forward-y-cos elbow-flip reach-boundary jacobian-sign inner-radius singular-tol; do
  cp "$HARNESS2_TASK_DIR/files/output/planar_arm/planar_arm/kinematics.py" planar_arm/kinematics.py
  python3 "$CHECK/mutate.py" planar_arm/kinematics.py "$m"
  ac "kills mutant $m" bash -c '! timeout 120 "$@"' _ "${PYT[@]}"
done
cp "$HARNESS2_TASK_DIR/files/output/planar_arm/planar_arm/kinematics.py" planar_arm/kinematics.py
ac_done
