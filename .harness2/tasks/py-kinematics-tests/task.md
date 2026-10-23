`output/planar_arm/` holds the kinematics for our 2-link planar test arm. It only has a single smoke
test, and we're about to refactor it. Before we do, please write a proper pytest suite in
`output/planar_arm/tests/` so a refactor can't silently break it.

- Cover `forward`, `inverse` (both elbow configurations), `jacobian`, `is_singular`, and every error
  path (bad link lengths, unreachable targets both too far and too close).
- Include the edge cases: the full-stretch boundary, a target exactly on the workspace edge, and the
  forward/inverse round trip.
- Use fixtures and `pytest.mark.parametrize` where they make sense, and compare floats with
  tolerances.
- I want branch coverage of the `planar_arm` package at 90% or higher (`pytest --cov=planar_arm
  --cov-branch`).

Don't change `planar_arm/kinematics.py`. It's correct, and the tests should pin its behaviour down.
