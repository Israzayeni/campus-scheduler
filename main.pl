:- use_module(scheduler/scheduler).
:- use_module(energy/energy_model, except([session_energy/3])).
:- use_module(knowledge_base/kb_courses).

% Other modules imported so check_all can verify their visibility
:- use_module(knowledge_base/kb_buildings).
:- use_module(knowledge_base/kb_rooms).
:- use_module(knowledge_base/kb_timeslots).
:- use_module(knowledge_base/kb_groups).
:- use_module(knowledge_base/kb_instructors).
:- use_module(knowledge_base/kb_helpers, except([instructor_available/2])).
:- use_module(constraints/constraints, except([room_free/3, group_free/3])).

% --------------------------------------------------------------------
% go/0
% --------------------------------------------------------------------
% What it does:
%   Collects all courses and invokes the scheduler to find a single
%   valid schedule. Prints the schedule, energy state, and total energy.
% --------------------------------------------------------------------
go :-
    findall(C, course(C), Courses),
    (   run_scheduler(Courses, Schedule, EnergyState)
    ->  print_schedule(Schedule),
        print_energy_state(EnergyState),
        total_energy(Schedule, Total),
        format('Total Energy: ~w kWh~n', [Total])
    ;   format('Error: Failed to find a valid schedule.~n')
    ).

% --------------------------------------------------------------------
% go_all/0
% --------------------------------------------------------------------
% What it does:
%   Explores the entire search space to find ALL valid schedules using
%   findall/3. Prints the total count and displays the first schedule.
% --------------------------------------------------------------------
go_all :-
    findall(C, course(C), Courses),
    findall(S-ES, run_scheduler(Courses, S, ES), All),
    length(All, Count),
    format('Found ~w valid schedules.~n', [Count]),
    (   Count > 0, All = [FirstS-FirstES | _]
    ->  format('First schedule:~n'),
        print_schedule(FirstS),
        print_energy_state(FirstES)
    ;   true
    ).

% --------------------------------------------------------------------
% check_all/0
% --------------------------------------------------------------------
% What it does:
%   Uses predicate_property/2 to verify that all required predicates
%   from P1, P2, P4 (and P3's integration adapters) are fully loaded
%   and visible in the environment.
% --------------------------------------------------------------------
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

% --------------------------------------------------------------------
% print_energy_state/1
% --------------------------------------------------------------------
% What it does:
%   Formats and prints the final daily energy consumption per building.
% --------------------------------------------------------------------
print_energy_state([]).
print_energy_state([energy(Building, Day, Total) | Rest]) :-
    format('Building ~w on ~w: ~w kWh~n', [Building, Day, Total]),
    print_energy_state(Rest).