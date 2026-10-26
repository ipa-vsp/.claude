# cxx Bridge Patterns

Worked example: a forward-kinematics bridge to Pinocchio. This is an
illustrative design for Step 05/06, not existing code. Paths are relative
to `rust/crates/arche-ffi-pinocchio/`.

## 1. Shim header (`cpp/shim.hpp`) — no vendor types

```cpp
#pragma once
#include <memory>
#include "rust/cxx.h"

namespace arche_ffi {

class KinModel;  // opaque: wraps pinocchio::Model + a pinocchio::Data

// Throws std::runtime_error on parse failure (mapped to Result in Rust).
std::unique_ptr<KinModel> load_urdf(rust::Str urdf_xml, std::uint8_t base_type);

std::size_t nq(const KinModel& m);
std::size_t nv(const KinModel& m);

// Writes a 4x4 column-major homogeneous transform into `out` (16 values).
// Throws on unknown frame or q.size() != nq.
void frame_placement(KinModel& m, rust::Slice<const double> q, rust::Str frame,
                     rust::Slice<double> out);

}  // namespace arche_ffi
```

## 2. Shim implementation (`cpp/shim.cpp`) — the only vendor include

```cpp
#include "arche-ffi-pinocchio/cpp/shim.hpp"

#include <pinocchio/algorithm/frames.hpp>
#include <pinocchio/algorithm/kinematics.hpp>
#include <pinocchio/parsers/urdf.hpp>
#include <stdexcept>
#include <string>

namespace arche_ffi {

class KinModel {
 public:
  pinocchio::Model model;
  pinocchio::Data data;  // scratch; KinModel is therefore NOT Sync
  explicit KinModel(pinocchio::Model m) : model(std::move(m)), data(model) {}
};

std::unique_ptr<KinModel> load_urdf(rust::Str urdf_xml, std::uint8_t base_type) {
  pinocchio::Model model;
  const std::string xml(urdf_xml);
  switch (base_type) {
    case 0: pinocchio::urdf::buildModelFromXML(xml, model); break;
    case 2: pinocchio::urdf::buildModelFromXML(xml, pinocchio::JointModelFreeFlyer(), model); break;
    default: throw std::invalid_argument("unsupported base_type " + std::to_string(base_type));
  }
  return std::make_unique<KinModel>(std::move(model));
}

std::size_t nq(const KinModel& m) { return static_cast<std::size_t>(m.model.nq); }
std::size_t nv(const KinModel& m) { return static_cast<std::size_t>(m.model.nv); }

void frame_placement(KinModel& m, rust::Slice<const double> q, rust::Str frame,
                     rust::Slice<double> out) {
  if (q.size() != static_cast<std::size_t>(m.model.nq)) throw std::invalid_argument("q size");
  if (out.size() != 16) throw std::invalid_argument("out size");
  const std::string name(frame);
  if (!m.model.existFrame(name)) throw std::out_of_range("unknown frame " + name);
  const Eigen::Map<const Eigen::VectorXd> qv(q.data(), static_cast<Eigen::Index>(q.size()));
  pinocchio::framesForwardKinematics(m.model, m.data, qv);
  const Eigen::Matrix4d t = m.data.oMf[m.model.getFrameId(name)].toHomogeneousMatrix();
  Eigen::Map<Eigen::Matrix4d>(out.data()) = t;  // column-major copy into Rust memory
}

}  // namespace arche_ffi
```

The C++ side rejects an unknown frame with an exception. The legacy plugin
returned identity instead, and that silent fallback is deliberately not
carried over (`COMPATIBILITY_MATRIX.md` §2).

## 3. Bridge + safe wrapper (`src/lib.rs`)

```rust
#![allow(unsafe_code, reason = "cxx bridge to Pinocchio; see SAFETY comments")]

#[cxx::bridge(namespace = "arche_ffi")]
mod ffi {
    unsafe extern "C++" {
        include!("arche-ffi-pinocchio/cpp/shim.hpp");

        type KinModel;

        fn load_urdf(urdf_xml: &str, base_type: u8) -> Result<UniquePtr<KinModel>>;
        fn nq(m: &KinModel) -> usize;
        fn nv(m: &KinModel) -> usize;
        fn frame_placement(
            m: Pin<&mut KinModel>,
            q: &[f64],
            frame: &str,
            out: &mut [f64],
        ) -> Result<()>;
    }
}

// SAFETY: KinModel owns its pinocchio::Model and Data exclusively and has no
// thread-affine state, so moving it to another thread is sound. It is NOT
// Sync: `frame_placement` mutates the internal Data.
unsafe impl Send for ffi::KinModel {}

/// Errors from the Pinocchio backend.
#[derive(Debug)]
#[non_exhaustive]
pub enum PinocchioError {
    /// `q` has the wrong length (checked before calling C++).
    Dimension { expected: usize, actual: usize },
    /// C++ threw; message from `what()`.
    Backend(String),
}

impl From<cxx::Exception> for PinocchioError {
    fn from(e: cxx::Exception) -> Self {
        Self::Backend(e.what().to_owned())
    }
}

/// Pinocchio-backed model. Not `Sync`; create one per thread.
pub struct PinocchioModel {
    inner: cxx::UniquePtr<ffi::KinModel>,
    nq: usize,
}

impl PinocchioModel {
    pub fn from_urdf(xml: &str, base: BaseType) -> Result<Self, PinocchioError> {
        let inner = ffi::load_urdf(xml, base.to_wire())?;
        let nq = ffi::nq(&inner);
        Ok(Self { inner, nq })
    }

    /// World pose of `frame` at configuration `q` (length `nq`).
    pub fn frame_pose(&mut self, q: &[f64], frame: &str) -> Result<Pose, PinocchioError> {
        if q.len() != self.nq {
            return Err(PinocchioError::Dimension { expected: self.nq, actual: q.len() });
        }
        let mut m = [0.0_f64; 16];
        ffi::frame_placement(self.inner.pin_mut(), q, frame, &mut m)?;
        Ok(Pose::from_column_major_4x4(&m))
    }
}
```

Notes:
- `UniquePtr::pin_mut()` panics on null. `load_urdf` never returns null
  (it throws instead), and the constructor is the only producer. State
  that invariant in a comment where you rely on it.
- `Pin<&mut KinModel>` is how cxx passes a mutable opaque C++ object.
- The `Pose` conversion is the only place that knows the storage order.

## 4. Callbacks into Rust (OMPL state validity)

Long-lived C++ objects that call back into Rust (OMPL's
`StateValidityChecker`) are the riskiest pattern:

```rust
#[cxx::bridge(namespace = "arche_ffi")]
mod ffi {
    extern "Rust" {
        type ValidityCtx;
        fn is_valid(ctx: &ValidityCtx, q: &[f64]) -> bool;   // must not panic
    }
    unsafe extern "C++" {
        include!("arche-ffi-ompl/cpp/shim.hpp");
        type Planner;
        fn solve(p: Pin<&mut Planner>, ctx: &ValidityCtx, budget_s: f64) -> Result<Vec<f64>>;
    }
}
```

- Pass the context **per call** (`solve(.., ctx, ..)`), not stored in C++
  across calls, so the borrow checker sees the lifetime.
- `is_valid` wraps its body in `std::panic::catch_unwind` and treats a panic
  as "invalid" plus a recorded error. An unwinding panic across cxx aborts
  the process.
- If the C++ side calls back from several threads, `ValidityCtx` must be
  `Sync`; check this with a test that runs the planner's multithreaded mode.

## 5. Matrix transfer helpers (`arche-ffi-common`)

```rust
/// Column-major view of a dense matrix for passing to C++.
#[derive(Debug, Clone, Copy)]
pub struct ColMajor<'a> {
    pub data: &'a [f64],
    pub rows: usize,
    pub cols: usize,
}

impl<'a> ColMajor<'a> {
    pub fn new(data: &'a [f64], rows: usize, cols: usize) -> Option<Self> {
        (rows.checked_mul(cols)? == data.len()).then_some(Self { data, rows, cols })
    }
}
```

The shim receives `(rust::Slice<const double>, rows, cols)` and checks
`rows * cols == size` again before mapping.
