# Domain probe questions

Starting points, not a script. Adapt every question to the user's actual robot,
stack, and problem — a probe that names their hardware lands, a generic one
doesn't. **Pick one, not five.**

Each section ends with the misconceptions common in that area, so this doubles
as a checklist for what to listen for in their answers.

## Contents

- Code: design, debugging, review
- Kinematics and frames
- Dynamics and identification
- Control: impedance, admittance, compliance
- Optimisation-based control: IK, MPC, whole-body
- ROS 2 architecture and timing
- Real-time and embedded
- Behaviour trees, state machines and recovery
- Perception and grasping
- Sim-to-real and learned policies

---

## Code: design, debugging, review

**Before they write it**

- What's the contract — what goes in, what comes out, what must be true when it
  returns?
- What are the three ways a caller could use this wrong, and which of them should
  be a crash rather than a wrong answer?
- What's the smallest slice you can run in the next ten minutes and actually
  observe?
- What state does this own, and who else can mutate it while it's running?
- If this is wrong at 3 a.m. on hardware, what artifact tells you that — a log
  line, a test, a topic?

**When it's broken**

- What did you expect that line to do, and what does it do?
- Where's the first point in the chain where the value is already wrong?
- What changed between the last time it worked and now?
- Is this deterministic? If not, what varies — timing, ordering, or data?
- What's the cheapest measurement that would rule out half the hypotheses?
- You've assumed one thing here without checking it. Which assumption is it?

**Reviewing what they wrote**

- What happens on the first call, before anything is initialised?
- What happens if that lookup or allocation throws — where does the robot end up?
- This runs in a callback: what's the worst-case execution time, and what's
  blocked meanwhile?
- Which of these branches has no test, and is that the one that runs on hardware?
- If someone deletes this line, what test goes red? If none, what does that tell
  you?

**Reading someone else's code**

- Before reading the body: what must this return for its caller to be correct?
- What does this do at a singularity / on an empty buffer / on the first tick?
- Summarise this class's responsibility in one sentence — what does it refuse to
  do?
- Why is this abstraction here? What would break if it were inlined?

---

## Kinematics and frames

- Which frame is that pose expressed in, and which frame does the consumer
  assume?
- Who publishes that transform, at what rate, and what happens between
  publications?
- Is that a static transform that's actually static, or one that drifts once the
  base moves?
- What does the Jacobian's smallest singular value do along the trajectory you
  just ran?
- Which Jacobian reference frame are you in — local, world, or
  local-world-aligned — and does the controller downstream expect the same one?
- Nullspace: what secondary objective is currently occupying the redundancy,
  whether you asked for one or not?

**Common misconceptions:** treating a body-frame twist as if it were world-frame;
assuming `lookupTransform` at time zero means "now"; assuming a redundant arm's
nullspace motion is harmless.

## Dynamics and identification

- Which inertial parameters actually influence the torques on the trajectory you
  excited? Which are structurally unidentifiable there?
- Is the identified inertia matrix physically consistent, and what breaks
  downstream if it isn't?
- What's the mass of the payload versus the link it's attached to — does your
  estimator have the signal-to-noise to see it?
- Is the friction model absorbing error that belongs to the inertial terms?
- What does your excitation trajectory optimise for, and does that objective
  match what you actually need to estimate?

**Common misconceptions:** believing a good torque fit implies correct
parameters; assuming gravity-compensation error is a gain problem when it's a
payload estimate problem.

## Control: impedance, admittance, compliance

- Is the robot rendering a stiffness or reacting to a measured force? Those fail
  in opposite ways — which one is yours?
- At your commanded stiffness and approach velocity, what's the peak contact
  force, and does the control loop run fast enough to see it?
- What's the effective damping ratio at that stiffness, given the arm's apparent
  inertia in this configuration?
- Where does the environment's stiffness sit relative to yours, and which one
  dominates the coupled dynamics?
- What happens to your impedance behaviour when the joint torque controller
  saturates?

**Common misconceptions:** using "compliant" to mean "safe" without checking
transient forces; assuming impedance and admittance are interchangeable
regardless of environment stiffness.

## Optimisation-based control: IK, MPC, whole-body

- What's in the cost, what's in the constraints, and why is each thing where it
  is?
- When the QP is infeasible, what does your controller emit — and is that the
  behaviour you want on hardware?
- Which tasks conflict in that configuration, and what resolves the conflict:
  weights, hierarchy, or slack?
- What's your horizon length in seconds, and what dynamics does it fail to see
  beyond that?
- Does the solver converge within the control period on the worst-case
  configuration, or only the average one?
- Warm-starting: what does the solver inherit from the previous tick, and is that
  still valid after a discrete mode switch?

**Common misconceptions:** tuning weights to fix what is actually a constraint
problem; assuming a solved QP means a feasible physical motion.

## ROS 2 architecture and timing

- What's the actual end-to-end latency from sensor exposure to command, and which
  link in that chain is unbounded?
- Which executor and how many threads — and can two callbacks on that node run at
  once?
- Is that a callback-group problem, a QoS mismatch, or genuine compute overrun?
  What measurement distinguishes them?
- Which QoS settings do publisher and subscriber disagree on, and does that
  silently drop the connection?
- Is the message timestamped at capture or at publish, and how far apart are
  those?
- What's the failure behaviour when the action server is preempted mid-execution
  — where does the robot stop?
- Does that node hold state that survives a lifecycle transition it shouldn't
  survive?

**Common misconceptions:** blaming the network for what is single-threaded
executor blocking; assuming `use_sim_time` is set consistently across the graph.

## Real-time and embedded

- What's the worst-case execution time of that loop body, not the average — and
  what did you measure it with?
- What in that path allocates, locks, logs, or touches the filesystem? Which of
  those can block unboundedly?
- What happens on a missed deadline: does it skip, catch up, or accumulate?
- Where does the priority inversion live — which low-priority thread holds
  something the control loop needs?
- Is the jitter you're seeing in the scheduler, the driver, or the bus? What
  measurement separates them?
- On the first tick after startup, what does that filter or integrator hold?

**Common misconceptions:** treating average latency as a real-time guarantee;
assuming a fast CPU removes the need for bounded worst cases.

## Behaviour trees, state machines and recovery

- When that node fails, who sees the failure — and what state is the hardware
  left in at that instant?
- Is that condition checked once at entry, or on every tick? Which did you want?
- What's the difference between "this action failed" and "this action should not
  have been attempted"? Does your tree distinguish them?
- After recovery succeeds, where does execution resume, and what assumptions
  about the world does the resumed branch still hold?
- Can two recoveries trigger for the same fault? What arbitrates?
- What's the behaviour on preemption mid-action versus on failure — are they the
  same code path, and should they be?

**Common misconceptions:** conflating a node returning FAILURE with the robot
being in a safe state; assuming retry is a recovery strategy rather than a
symptom of an unmodelled precondition.

## Perception and grasping

- What's the actual latency between the RGB-D frame and the pose you act on, and
  how far has the scene moved in that window?
- Which coordinate frame does the pose estimator output, and is its convention
  the same as your grasp planner's?
- How does your detector fail — does it return a wrong box, or no box? Those need
  different recovery behaviour.
- What's the depth quality on that specific material, and does your pose estimate
  depend on the region where depth is bad?
- What confidence signal does the model give you, and is it calibrated well
  enough to gate execution on?
- When segmentation returns two instances of the same label, what picks between
  them, and is that decision explicit anywhere in your code?

**Common misconceptions:** treating detector confidence as pose accuracy;
assuming a correct mask implies a correct 6D pose.

## Sim-to-real and learned policies

- Which specific gap are you closing — dynamics, visual appearance, latency, or
  actuation? They need different fixes.
- What does the policy observe in sim that it will not have on hardware, in
  exactly the same form?
- Is the sim control rate, action space, and latency identical to the real stack?
  Where do they diverge?
- What does the policy do when it encounters a state outside its training
  distribution, and can you detect that state before the arm moves?
- Is randomisation widening the training distribution in the direction that
  actually matters, or just making training harder?
- What's the safety layer between the policy output and the joints, and what does
  it clamp?

**Common misconceptions:** assuming domain randomisation covers a gap it wasn't
parameterised over; evaluating in sim and inferring real-world success rate.
