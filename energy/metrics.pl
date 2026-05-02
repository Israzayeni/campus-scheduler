:- module(metrics, [
    total_energy/2,
    daily_energy_summary/2,
    imbalance_calculation/2,
    room_fairness_variance/2,
    weighted_score/4,
    optimal_schedule/1
]).

:- use_module(energy/energy_facts).
:- use_module(knowledge_base/kb_helpers).

% METRIC 1: Total Energy - Sum all session energies
total_energy([], 0).
total_energy([session(_, _, Room, TimeSlot, _) | Rest], Total) :-
    energy_facts:room_energy_cost(Room, CostPerHour),
    energy_facts:slot_duration(TimeSlot, Duration),
    E is CostPerHour * Duration,
    total_energy(Rest, RestE),
    Total is E + RestE.

% METRIC 2: Daily Energy Summary
daily_energy_summary(Schedule, DailySummary) :-
    findall(B-D-E,
            (member(session(_, _, Room, Slot, _), Schedule),
             kb_helpers:room_building(Room, B),
             kb_helpers:slot_day(Slot, D),
             energy_facts:room_energy_cost(Room, Cost),
             energy_facts:slot_duration(Slot, Dur),
             E is Cost * Dur),
            All),
    aggregate_by_building_day(All, DailySummary).

aggregate_by_building_day([], []).
aggregate_by_building_day([B-D-E|Rest], [energy(B, D, Total)|Result]) :-
    findall(E2, member(B-D-E2, [B-D-E|Rest]), Energies),
    sumlist(Energies, Total),
    exclude(same_bd(B, D), Rest, Remaining),
    aggregate_by_building_day(Remaining, Result).

same_bd(B, D, B-D-_).

% METRIC 3: Imbalance
imbalance_calculation(Schedule, Imbalance) :-
    daily_energy_summary(Schedule, DailyData),
    findall(Day, member(energy(_, Day, _), DailyData), Days),
    sort(Days, UniqueDays),
    findall(Diff,
            (member(Day, UniqueDays),
             findall(E, member(energy(_, Day, E), DailyData), Es),
             (Es = [] -> Diff = 0 ; (max_list(Es, Max), min_list(Es, Min), Diff is Max - Min))),
            Diffs),
    sumlist(Diffs, Imbalance).

% METRIC 4: Room Variance
room_fairness_variance(Schedule, Variance) :-
    findall(Room-E,
            (member(session(_, _, Room, Slot, _), Schedule),
             energy_facts:room_energy_cost(Room, Cost),
             energy_facts:slot_duration(Slot, Dur),
             E is Cost * Dur),
            RoomEs),
    (RoomEs = [] -> Variance = 0 ;
     (findall(Room-Total, (member(R, RoomEs), aggregate_room(RoomEs, R, Total)), RoomTotals),
      maplist(get_energy, RoomTotals, Usages),
      length(Usages, N),
      sumlist(Usages, Sum),
      Avg is Sum / N,
      findall(Sq, (member(U, Usages), Sq is (U - Avg) ** 2), Squares),
      sumlist(Squares, SumSq),
      Variance is SumSq / N)).

aggregate_room(List, R, Total) :- 
    findall(E, member(R-E, List), Es), 
    sumlist(Es, Total).

get_energy(_-E, E).

% METRIC 5: Weighted Score
weighted_score(TotalEnergy, Imbalance, Variance, Score) :-
    W1 = 0.5, W2 = 0.3, W3 = 0.2,
    Fairness is 1.0 / (1.0 + Variance),
    Score is W1 * TotalEnergy + W2 * Imbalance + W3 * Fairness.

% METRIC 6: Optimal Schedule - NOT NEEDED YET
optimal_schedule(Schedule) :- 
    Schedule = [].