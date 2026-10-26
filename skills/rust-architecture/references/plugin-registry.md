# Plugin Contracts and a Static Registry

Rust trait objects have no stable ABI across separately compiled dylibs,
so pluginlib-style runtime loading of Rust `.so` files is unsound. Arche
uses **static registration**: implementations are ordinary crates, and the
composition root (`arche-ros2`, `arche-cli`, ...) registers the ones it was
built with. Runtime-loaded third-party plugins need a separate C-ABI or
process-isolated RPC design (implementation.md Step 15).

The example below is a design sketch for Step 04, not existing code. Names
are illustrative.

## Contract trait

```rust
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

/// Cooperative cancellation shared between caller and plugin.
#[derive(Debug, Clone, Default)]
pub struct CancelToken(Arc<AtomicBool>);

impl CancelToken {
    pub fn cancel(&self) {
        self.0.store(true, Ordering::Release);
    }
    pub fn is_cancelled(&self) -> bool {
        self.0.load(Ordering::Acquire)
    }
}

/// What a planner can do, as data instead of `supports_x()` methods.
#[derive(Debug, Clone, PartialEq)]
#[non_exhaustive]
pub struct PlannerCapabilities {
    pub algorithms: Vec<String>,
    pub base_types: Vec<BaseType>,
    pub supports_cancellation: bool,
    pub deterministic_with_seed: bool,
}

#[derive(Debug)]
#[non_exhaustive]
pub enum PlanError {
    InvalidRequest(String),
    Infeasible,
    Timeout { budget: Duration },
    Cancelled,
    Backend(String),
}

/// Object-safe, shareable across threads.
pub trait MotionPlanner: Send + Sync {
    /// Stable id, kept equal to the pluginlib class name for config
    /// compatibility, e.g. "arche_planner_ompl/OmplPlanner".
    fn id(&self) -> &str;
    fn capabilities(&self) -> PlannerCapabilities;
    /// `request` carries seed, time budget and algorithm choice.
    fn plan(&self, request: &PlanningRequest, cancel: &CancelToken)
        -> Result<PlanResult, PlanError>;
}
```

Notes:
- `&self`, not `&mut self`: one instance can serve concurrent requests, or
  documents that it serialises internally. If an implementation cannot be
  shared, the factory creates one instance per request instead.
- Lifecycle (`configure/activate/deactivate/cleanup`) of the C++ contract
  maps to: construction with a typed config (configure), dropping the
  object (cleanup). Activation state belongs to the ROS adapter, not to the
  algorithm.

## Registry

```rust
use std::collections::BTreeMap;

pub type PlannerFactory =
    fn(&PlannerConfig) -> Result<Box<dyn MotionPlanner>, PlanError>;

#[derive(Debug, Default)]
pub struct PlannerRegistry {
    factories: BTreeMap<String, PlannerFactory>, // sorted → deterministic listing
}

#[derive(Debug)]
pub struct DuplicateId(pub String);

impl PlannerRegistry {
    pub fn register(&mut self, id: &str, factory: PlannerFactory) -> Result<(), DuplicateId> {
        if self.factories.contains_key(id) {
            return Err(DuplicateId(id.to_owned()));
        }
        self.factories.insert(id.to_owned(), factory);
        Ok(())
    }

    pub fn create(&self, id: &str, config: &PlannerConfig)
        -> Option<Result<Box<dyn MotionPlanner>, PlanError>> {
        self.factories.get(id).map(|f| f(config))
    }

    pub fn ids(&self) -> impl Iterator<Item = &str> {
        self.factories.keys().map(String::as_str)
    }
}
```

Composition root:

```rust
let mut planners = PlannerRegistry::default();
planners.register("arche_planner_trajopt/TrajOptPlanner", arche_planning::trajopt::factory)?;
#[cfg(feature = "ompl")]
planners.register("arche_planner_ompl/OmplPlanner", arche_ffi_ompl::factory)?;
```

Why not `inventory`/`linkme` auto-registration: it works through
linker sections, hides which plugins a binary contains, and complicates
reproducibility metadata. Explicit registration lists every plugin in one
reviewable place.

## Conformance tests

Every contract ships a generic test suite in the contract crate (behind a
`conformance` feature or as a `pub fn` in a test-support module). Each
implementation crate runs it against itself:

```rust
#[test]
fn trajopt_conforms() {
    arche_plugin_api::conformance::planner::run_all(|| {
        Box::new(TrajOpt::new(&PlannerConfig::default()).unwrap())
    });
}
```

The suite checks contract semantics, not quality: invalid request →
`InvalidRequest`, pre-cancelled token → `Cancelled` without work, zero
budget handling, `id()` stable, capabilities consistent with behaviour.
