# Numerical Oracles (code)

Dependency-free helpers on plain arrays. Once `arche-core` has its own
`Pose`/`Rotation` types (Step 02), implement the same checks on those types
in `arche-testkit`.

## Angle wrapping

```rust
use std::f64::consts::PI;

/// Wrap to (-π, π].
fn wrap_angle(a: f64) -> f64 {
    let w = (a + PI).rem_euclid(2.0 * PI) - PI;
    if w <= -PI { w + 2.0 * PI } else { w }
}

fn assert_angle_close(actual: f64, expected: f64, tol_rad: f64) {
    let d = wrap_angle(actual - expected).abs();
    assert!(d <= tol_rad, "angle diff {d:e} rad > {tol_rad:e}");
}
```

## Rotation comparison

```rust
/// Angle (rad) of the relative rotation between two unit quaternions
/// [x, y, z, w]. Sign-invariant: q and -q give 0.
fn quat_angle_between(a: [f64; 4], b: [f64; 4]) -> f64 {
    let dot = a.iter().zip(&b).map(|(x, y)| x * y).sum::<f64>().abs().min(1.0);
    2.0 * dot.acos()
}

/// Angle (rad) of R_a^T R_b for row-major 3x3 rotation matrices.
fn rot_angle_between(ra: &[[f64; 3]; 3], rb: &[[f64; 3]; 3]) -> f64 {
    // trace(R_a^T R_b) = sum_ij ra[i][j] * rb[i][j]
    let tr: f64 = (0..3).flat_map(|i| (0..3).map(move |j| (i, j)))
        .map(|(i, j)| ra[i][j] * rb[i][j]).sum();
    ((tr - 1.0) / 2.0).clamp(-1.0, 1.0).acos()
}
```

`acos` loses precision near 0. For tolerances below about 1e-7 rad, use
`atan2(‖axis‖, cos)` from the log map instead. State which form you used.

## Pose comparison

```rust
struct PoseTol { trans_m: f64, rot_rad: f64 }

fn assert_pose_close(t_a: [f64; 3], q_a: [f64; 4], t_b: [f64; 3], q_b: [f64; 4], tol: PoseTol) {
    let dt = t_a.iter().zip(&t_b).map(|(x, y)| (x - y).powi(2)).sum::<f64>().sqrt();
    let dr = quat_angle_between(q_a, q_b);
    assert!(dt <= tol.trans_m, "translation diff {dt:e} m > {:e}", tol.trans_m);
    assert!(dr <= tol.rot_rad, "rotation diff {dr:e} rad > {:e}", tol.rot_rad);
}
```

## Finite-difference Jacobian check

Central differences; perturb in the **tangent space** via `integrate` so
floating/planar bases (nq ≠ nv) are handled correctly.

```rust
/// `f`: configuration -> task vector (len m). `integrate(q, dv)` -> q'.
/// `jac`: analytic m x nv Jacobian, row-major.
fn check_jacobian(
    q: &[f64],
    nv: usize,
    f: impl Fn(&[f64]) -> Vec<f64>,
    integrate: impl Fn(&[f64], &[f64]) -> Vec<f64>,
    jac: &[Vec<f64>],
    h: f64,       // 1e-6
    tol: f64,     // 1e-5, as in the C++ test_jacobian
) {
    for j in 0..nv {
        let mut dv = vec![0.0; nv];
        dv[j] = h;
        let fp = f(&integrate(q, &dv));
        dv[j] = -h;
        let fm = f(&integrate(q, &dv));
        for (i, row) in jac.iter().enumerate() {
            let fd = (fp[i] - fm[i]) / (2.0 * h);
            assert!((row[j] - fd).abs() <= tol,
                "J[{i}][{j}] = {:e}, finite difference {fd:e}", row[j]);
        }
    }
}
```

For orientation rows, `f` must return a minimal error (log map of
`R(q₀)ᵀR(q)`), not raw matrix entries. Also check the Jacobian's
reference frame: the legacy contract uses `LOCAL_WORLD_ALIGNED`.

Test configurations: zero, a random in-limit q (seeded), and a near-singular
one (elbow straight). At singularities, check the Jacobian against FD only.
Never invert it in the test.

## Lie-group round trips (planar / floating base)

```rust
// q layout planar: [x, y, cosθ, sinθ, joints...]; floating: [x, y, z, qx, qy, qz, qw, joints...]
let r = integrate(&q, &v);
assert_all_close(&difference(&q, &r), &v, Tolerance::abs(1e-12));
let back = integrate(&q, &difference(&q, &other));
// compare `back` and `other` with a pose comparison for the base part,
// abs tolerance for joints; check unit norm of the cos/sin or quaternion block:
assert_close(back[2].hypot(back[3]), 1.0, Tolerance::abs(1e-12));
```

## Collision / signed distance

- Classification (`in_collision`) is discrete: exact equality on fixtures.
- Signed distance: compare with the reference library value (coal), with a
  tolerance from the C++ test. Sign convention: negative = penetration.
- Keep fixture geometry at least about 1e-3 m away from contact boundaries,
  unless the test is about the boundary.
