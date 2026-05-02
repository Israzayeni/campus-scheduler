:- use_module(scheduler/scheduler).
:- use_module(energy/energy_model, except([session_energy/3])).
:- use_module(energy/metrics).
:- use_module(knowledge_base/kb_courses).
:- use_module(knowledge_base/kb_buildings).
:- use_module(knowledge_base/kb_rooms).
:- use_module(knowledge_base/kb_timeslots).
:- use_module(knowledge_base/kb_groups).
:- use_module(knowledge_base/kb_instructors).
:- use_module(knowledge_base/kb_helpers, except([instructor_available/2])).
:- use_module(constraints/constraints, except([room_free/3, group_free/3])).


go :-
    findall(C, course(C), Courses),
    (   run_scheduler(Courses, Schedule, EnergyState)
    ->  print_schedule(Schedule),
        print_energy_state(EnergyState),
        total_energy(Schedule, Total),
        format('Total Energy: ~w kWh~n', [Total])
    ;   format('Error: Failed to find a valid schedule.~n')
    ).


go_metrics :-
    findall(C, course(C), Courses),
    (   run_scheduler(Courses, Schedule, EnergyState)
    ->  format('~n=== METRICS REPORT ===~n'),
        total_energy(Schedule, T),
        format('1. Total Energy: ~w kWh~n', [T]),
        daily_energy_summary(Schedule, DS),
        format('2. Daily Summary: ~w~n', [DS]),
        imbalance_calculation(Schedule, I),
        format('3. Imbalance: ~w~n', [I]),
        room_fairness_variance(Schedule, V),
        format('4. Room Variance: ~w~n', [V]),
        weighted_score(T, I, V, Score),
        format('5. Weighted Score: ~w~n', [Score])
    ;   format('Error: Failed to find a valid schedule.~n')
    ).
go_optimal :-
    format('~n=== FINDING OPTIMAL SCHEDULE ===~n'),
    findall(C, course(C), Courses),
    (   run_scheduler(Courses, Schedule, _)
    ->  total_energy(Schedule, T),
        imbalance_calculation(Schedule, I),
        room_fairness_variance(Schedule, V),
        weighted_score(T, I, V, Score),
        length(Schedule, Sessions),
        format('~nOptimal Schedule Found!~n'),
        format('Sessions: ~w~n', [Sessions]),
        format('Total Energy: ~w kWh~n', [T]),
        format('Load Imbalance: ~w~n', [I]),
        format('Room Variance: ~w~n', [V]),
        format('Optimization Score: ~w~n', [Score])
    ;   format('No valid schedule found.~n')
    ).


check_all :-
    Preds = [
        course/1, room/1, time_slot/1, sessions_required/2,
        course_group/2, group_size/2, room_capacity/2,
        room_equipment/2, course_equipment/2,
        slot_day/2, room_building/2, building_energy_max/2,
        room_free/3, group_free/3,
        meets_capacity/3, equipment_matches/3,
        instructor_available/2,
        session_energy/3, total_energy/2
    ],
    check_preds(Preds).


check_preds([]).
check_preds([P/A|Rest]) :-
    functor(Head, P, A),
    (   predicate_property(Head, visible)
    ->  format('~w/~w : OK~n', [P, A])
    ;   format('~w/~w : MISSING~n', [P, A])
    ),
    check_preds(Rest).


print_energy_state([]).
print_energy_state([energy(Building, Day, Total) | Rest]) :-
    format('Building ~w on ~w: ~w kWh~n', [Building, Day, Total]),
    print_energy_state(Rest).


print_schedule([]).
print_schedule([session(Course, Group, Room, TimeSlot, Instructor) | Rest]) :-
    format('Course ~w (Group ~w): Room ~w at ~w with ~w~n', [Course, Group, Room, TimeSlot, Instructor]),
    print_schedule(Rest).