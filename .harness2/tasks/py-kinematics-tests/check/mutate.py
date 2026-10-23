"""Apply one named mutant to kinematics.py in place: python3 mutate.py <file> <mutant>."""
import sys

MUTANTS = {
    "forward-y-cos": ("y = l1 * math.sin(q1) + l2 * math.sin(q1 + q2)",
                      "y = l1 * math.sin(q1) + l2 * math.cos(q1 + q2)"),
    "elbow-flip": ("    if elbow_up:\n        s2 = -s2", "    if not elbow_up:\n        s2 = -s2"),
    "reach-boundary": ("if r > l1 + l2 or", "if r >= l1 + l2 or"),
    "jacobian-sign": ("(-l1 * s1 - l2 * s12, -l2 * s12)", "(-l1 * s1 - l2 * s12, l2 * s12)"),
    "inner-radius": ("or r < abs(l1 - l2)", "or r < 0"),
    "singular-tol": ("return abs(math.sin(q2)) < tol", "return abs(math.cos(q2)) < tol"),
}

path, name = sys.argv[1], sys.argv[2]
old, new = MUTANTS[name]
src = open(path).read()
assert src.count(old) == 1, f"mutant {name} does not apply"
open(path, "w").write(src.replace(old, new))
