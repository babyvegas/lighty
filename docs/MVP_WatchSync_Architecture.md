# Lighty MVP Architecture: iPhone + Apple Watch Live Training Sync

## 1. MVP Goal
Build a first production-ready version where:
- User starts a workout and gets a live synchronized session between iPhone and Apple Watch.
- Watch shows current/next exercise, lets user edit weight/reps, complete sets, and track rest timer.
- iPhone and Watch remain consistent in near real-time.
- Calories burned are captured from Apple Watch and saved with the training session.

## 2. Non-Goals (for MVP)
- Multi-user accounts / cloud sync.
- Shared workouts with other users.
- Advanced analytics and PR engine.
- Full bidirectional routine editing during workout creation flows.

## 3. App Topology
- iOS app (existing Lighty app): source of truth for routines and completed training history.
- watchOS app (new companion target): live workout surface + HealthKit runtime.
- Communication channel: `WatchConnectivity`.
- Sensor/fitness data: `HealthKit` (`HKWorkoutSession`, `HKLiveWorkoutBuilder`) on watchOS.

## 4. Source of Truth and Session Model
For MVP, use a **single active session state** mirrored on both devices.

### Session identity
- `sessionId: UUID`
- `startedAt: Date`
- `revision: Int` (monotonic version)

### Session state (shared payload)
- Routine metadata: routine id (optional), routine name.
- Exercise list (ordered), each with:
  - `exerciseId`
  - `name`
  - `restSeconds`
  - sets (ordered): `setId`, `weight`, `reps`, `isCompleted`
- Runtime fields:
  - `elapsedSeconds`
  - `currentExerciseIndex`
  - `activeRestRemainingSeconds`
  - `completedSetsCount`
  - `volumeLbs`
- Health fields (watch-produced):
  - `activeEnergyKcal`
  - `heartRateBpm` (optional MVP+)

## 5. Sync Strategy (Real-Time + Resilient)
Use mixed transport in `WatchConnectivity`:

- `sendMessage`:
  - For immediate UI actions (complete set, change reps, rest controls).
  - Fast path while both apps are reachable.

- `transferUserInfo`:
  - Reliable background delivery fallback.
  - Used for guaranteed event delivery if not reachable.

- `updateApplicationContext`:
  - Periodic full-state snapshot (`SessionState`) to heal drift.

### Rule
- Every mutation increments `revision`.
- Receiver applies only payloads with newer `revision`.
- Conflict policy MVP: **last-write-wins by higher revision**.

## 6. Event Protocol (MVP)
Define compact, typed events:
- `session_started`
- `set_updated`
- `set_toggled_completed`
- `rest_updated`
- `exercise_index_changed`
- `session_paused` / `session_resumed` (optional)
- `session_finished`
- `session_discarded`
- `health_update`

Event envelope:
- `sessionId`
- `eventId` (UUID)
- `revision`
- `timestamp`
- `eventType`
- `payload`

## 7. Watch Workout Runtime (HealthKit)
When session starts:
1. Request HealthKit permissions once (write/read workout and active energy).
2. Start `HKWorkoutSession` with a suitable activity type (`.traditionalStrengthTraining`).
3. Attach `HKLiveWorkoutBuilder` and start collection.
4. Stream active energy and elapsed time into shared session state.

When session ends:
1. End builder collection.
2. Finish workout and get final `HKWorkout` summary.
3. Send final metrics to iPhone in `session_finished` payload.

## 8. Persistence and Finalization
On iPhone, when user taps Finish:
- If routine changed during session:
  - Prompt: `Save training + update routine` or `Save training only`.
- Persist completed training with:
  - duration
  - sets completed
  - volume
  - calories from watch
- Clear active session state.

## 9. Connectivity/Failure Scenarios
- Watch disconnected:
  - Continue local session on watch.
  - Queue outgoing events via `transferUserInfo`.
- iPhone app killed:
  - Session remains on watch; snapshot replay on reconnect.
- Out-of-order events:
  - Ignore stale revisions.
- Duplicate events:
  - Deduplicate by `eventId` cache per `sessionId`.

## 10. Security & Privacy
- Keep all workout and health data local (MVP).
- Only Apple Health authorized types are read.
- Show clear permission messaging explaining calorie tracking value.

## 11. Proposed Module Layout
### iOS target
- `WorkoutSessionManager` (already exists, extend for watch sync)
- `Connectivity/WatchSessionCoordinator.swift`
- `Connectivity/SessionSyncEngine.swift`
- `Domain/LiveWorkoutSession.swift`

### watchOS target (new)
- `WatchWorkoutSessionManager.swift`
- `WatchSessionCoordinator.swift`
- `WatchWorkoutView.swift`
- `HealthKit/WorkoutHealthService.swift`

## 12. Rollout Plan
1. **Phase A: Foundation**
   - Add watchOS companion target.
   - Add WatchConnectivity scaffolding + ping connectivity.

2. **Phase B: Live Session Sync**
   - Implement shared session model + revisioning.
   - Send/receive set edits and completion events.
   - Rest timer sync.

3. **Phase C: HealthKit Calories**
   - Start workout from watch.
   - Stream `activeEnergyBurned` to iPhone.
   - Persist calories in completed training.

4. **Phase D: Robustness**
   - Offline queue/replay.
   - Drift healing with periodic snapshots.
   - Telemetry logs for sync debugging (debug builds only).

## 13. MVP Definition of Done
- Start workout from iPhone and/or watch launches one shared session.
- Watch reflects current exercise and can update set data.
- iPhone reflects watch changes in near real-time.
- Rest timer actions from either device stay synchronized.
- Final saved training includes calories from watch.
- No data loss after temporary disconnects in common scenarios.
