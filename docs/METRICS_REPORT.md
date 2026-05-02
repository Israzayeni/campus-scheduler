# Energy Metrics & Optimization Report

## Project: Intelligent Energy-Aware Campus Scheduler
**Group**: 6 Students | **Deadline**: May 31, 2026
**Team Role**: Metrics, Optimization & Documentation Lead

---

## Executive Summary

This report documents the energy metrics and optimization framework for the Campus Scheduler project. The system evaluates schedule quality across five key dimensions: total energy consumption, daily load distribution, room utilization fairness, and overall optimization score.

---

## 1. Total Energy Consumption

**Predicate**: `total_energy/2`

**Formula**: 
```
Total Energy = Sum of all (room_energy_cost × slot_duration)
```

**Calculation Method**:
- Iterates through all scheduled sessions
- For each session: retrieves room's hourly energy cost
- Multiplies by time slot duration (1 hour per slot)
- Sums all session energies

**Usage in Prolog**:
```prolog
?- run_scheduler(Courses, Schedule, _), total_energy(Schedule, T).
```

**Current Result**: **205 kWh**

---

## 2. Daily Energy Summary

**Predicate**: `daily_energy_summary/2`

**Output Format**:
```
[energy(building, day, kwh), energy(building, day, kwh), ...]
```

**Calculation Method**:
- Groups sessions by building and day
- Calculates energy for each (building, day) pair
- Aggregates parallel sessions in same room

**Example Output**:
```
[energy(b_main, monday, 76),
 energy(b_main, tuesday, 58),
 energy(b_main, wednesday, 35),
 energy(b_tech, wednesday, 26),
 energy(b_main, thursday, 10)]
```

**Current Results**:
- **Monday**: 76 kWh (b_main) - Peak day
- **Tuesday**: 58 kWh (b_main) - High usage
- **Wednesday**: 35 kWh (b_main) + 26 kWh (b_tech) = 61 kWh total
- **Thursday**: 10 kWh (b_main) - Low usage

---

## 3. Daily Load Imbalance

**Predicate**: `imbalance_calculation/2`

**Formula**:
```
Imbalance = Sum of (E_max_day - E_min_day) for each day
```

**Calculation Method**:
1. Extract unique days from schedule
2. For each day: find max and min energy consumption
3. Calculate difference for that day
4. Sum all daily differences

**Interpretation**:
- **Lower value** = More balanced energy usage across buildings
- **Higher value** = Peaks and valleys in daily load
- Goal: Minimize imbalance for grid stability

**Current Result**: **9 kWh**
- Status:  Excellent - Very well balanced

---

## 4. Room Fairness Variance

**Predicate**: `room_fairness_variance/2`

**Formula**:
```
Var(R) = (1/m) × Sum((Usage(r) - average)²)
where:
  m = number of rooms
  Usage(r) = total energy consumed by room r
  average = mean energy per room
```

**Calculation Method**:
1. Collect energy usage for each room
2. Calculate average usage: `average = total_energy / num_rooms`
3. For each room: `(usage - average)²`
4. Divide sum by number of rooms

**Interpretation**:
- **Lower variance** = Rooms used fairly equally  GOOD
- **Higher variance** = Some rooms overused, others underutilized ❌ AVOID
- Goal: Minimize variance for fair resource allocation

**Current Result**: **0**
- Status:  Perfect - All rooms utilized equally

---

## 5. Weighted Optimization Score

**Predicate**: `weighted_score/4`

**Formula**:
```
Score = (W1 × TotalEnergy) + (W2 × Imbalance) + (W3 × FairnessScore)

Where:
  W1 = 0.5 (Total Energy weight - 50%)
  W2 = 0.3 (Imbalance weight - 30%)
  W3 = 0.2 (Fairness weight - 20%)
  FairnessScore = 1 / (1 + Variance)
```

**Calculation Example**:
```
Given:
  Total Energy = 205 kWh
  Imbalance = 9 kWh
  Variance = 0

Fairness Score = 1 / (1 + 0) = 1.0

Score = (0.5 × 205) + (0.3 × 9) + (0.2 × 1.0)
      = 102.5 + 2.7 + 0.2
      = 105.4
```

**Weight Justification**:
- **50% Total Energy**: Primary optimization goal - minimize campus power
- **30% Imbalance**: Secondary goal - stable grid load
- **20% Fairness**: Tertiary goal - equitable resource access

**Current Result**: **105.4**
- Status:  Good optimization

---

## 6. Optimal Schedule

**Predicate**: `optimal_schedule/1`

**Algorithm**:
```
1. Generate all valid schedules using backtracking
2. For each schedule:
   - Calculate: Total Energy (T)
   - Calculate: Imbalance (I)
   - Calculate: Room Variance (V)
   - Compute: Weighted Score = 0.5T + 0.3I + 0.2F
3. Sort all schedules by score (ascending - lower is better)
4. Return schedule with minimum score (best optimization)
```

**Time Complexity**: O(n log n) where n = number of valid schedules

**Usage in Prolog**:
```prolog
?- optimal_schedule(BestSchedule), 
   length(BestSchedule, Sessions),
   format('Best schedule: ~w sessions~n', [Sessions]).
```

### Optimal Schedule Results

**Sessions Found**: 39
**Total Energy**: 205 kWh
**Load Imbalance**: 9 kWh
**Room Variance**: 0
**Optimization Score**: 105.4

**Status**:  Optimal solution found and validated

---

## Test Results Summary

| Metric | Value | Status |
|--------|-------|--------|
| Total Energy | 205 kWh |  Good |
| Daily Imbalance | 9 kWh |  Excellent |
| Room Variance | 0 |  Perfect |
| Optimization Score | 105.4 |  Good |
| Optimal Sessions | 39 |  Complete |

### Analysis

 **Excellent Schedule Quality**:
1. Energy is well-distributed across the week
2. Room utilization is perfectly fair (variance = 0)
3. Load is well-balanced (imbalance = 9)
4. The scheduler found an optimal solution with 39 sessions

---

## Key Findings

### Strengths
 Excellent load balancing across weekdays
 Perfect room utilization fairness
 Optimal use of campus facilities
 Stable energy grid requirements
 All courses successfully scheduled

### Recommendations

1. **Peak Load Management**
   - Monday (76 kWh) is peak day
   - Consider shifting some courses to underutilized days (Thursday)
   - Helps stabilize grid requirements

2. **Building Utilization**
   - b_tech building underutilized (26 kWh Wednesday only)
   - Could relocate some courses to balance building loads

3. **Future Optimization**
   - Add instructor preferences as constraint
   - Implement time-of-use energy pricing
   - Schedule energy-intensive courses during off-peak hours

---

## Prolog Testing Commands

```prolog
% Run metrics report
?- go_metrics.

% Run full scheduler
?- go.

% Find optimal schedule
?- go_optimal.

% Find all valid schedules
?- go_all.

% Verify modules
?- check_all.
```

---

## Conclusion

The metrics system successfully quantifies schedule quality across multiple dimensions. The current schedule demonstrates excellent performance with:
- Perfect room fairness (variance = 0)
- Very good load balancing (imbalance = 9)
- Efficient energy utilization (205 kWh)
- Weighted optimization score of 105.4

The optimal schedule found contains 39 sessions with all courses successfully allocated while maintaining balance across energy consumption, building utilization, and room fairness.

---

