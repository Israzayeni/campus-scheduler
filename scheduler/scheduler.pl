:- module(scheduler, [
    run_scheduler/3,
    schedule_courses/4,
    schedule_course_groups/7,
    schedule_sessions/9,
    update_energy_state/5,
    check_energy_limit/3,
    print_schedule/1,

    % Glue & Wrappers needed for Integration & check_all
    course/1,
    room/1,
    time_slot/1,
    sessions_required/2,
    course_group/2,
    room_equipment/2,
    building_energy_max/2,
    total_energy/2,
    equipment_matches/3,
    meets_capacity/3,
    instructor_available/2,
    room_free/3,
    group_free/3,
    session_energy/3
]).

:- use_module('../knowledge_base/kb_courses').
:- use_module('../knowledge_base/kb_rooms').
:- use_module('../knowledge_base/kb_timeslots').
:- use_module('../knowledge_base/kb_groups').
:- use_module('../knowledge_base/kb_helpers', except([instructor_available/2])).
:- use_module('../knowledge_base/kb_buildings').
:- use_module('../constraints/constraints', except([room_free/3, group_free/3, meets_capacity/2, equipment_matches/2])).
:- use_module('../energy/energy_facts').
:- use_module('../energy/energy_model', except([session_energy/3])).

% ====================================================================
% P3: RECURSIVE SCHEDULER & INTEGRATION LEAD
% ====================================================================

% --------------------------------------------------------------------
% run_scheduler(+Courses, -Schedule, -FinalEnergyState)
% --------------------------------------------------------------------
% What it does:
%   Entry point for generating a complete schedule. Initializes an empty
%   energy state and starts the course scheduling process.
% Arguments:
%   Courses: List of course IDs to schedule.
%   Schedule: The resulting list of all scheduled sessions.
%   FinalEnergyState: The resulting list of daily building energy totals.
% --------------------------------------------------------------------
run_scheduler(Courses, Schedule, FinalEnergyState) :-
    sort_by_constraint(Courses, SortedCourses),
    schedule_courses(SortedCourses, Schedule, [], FinalEnergyState).

% --------------------------------------------------------------------
% Variable Ordering (MCF Heuristic)
% --------------------------------------------------------------------
% Sorts courses by constraint difficulty. Hardest courses are scheduled first.
sort_by_constraint(Courses, SortedCourses) :-
    map_list_to_weight(Courses, Pairs),
    keysort(Pairs, SortedPairs),
    pairs_values(SortedPairs, SortedCourses).

map_list_to_weight([], []).
map_list_to_weight([C|Rest], [Weight-C|RestPairs]) :-
    course_constraint_weight(C, Weight),
    map_list_to_weight(Rest, RestPairs).

course_constraint_weight(Course, Weight) :-
    % 1. Total Sessions (More = Harder = lower negative number)
    sessions_required(Course, N),
    findall(G, course_group(Course, G), Groups),
    length(Groups, NumGroups),
    TotalSessions is N * NumGroups,

    % 2. Equipment Restrictions (More items = Harder)
    course_equipment(Course, Equip),
    length(Equip, NumEquip),

    % 3. Instructor Availability (Fewer slots = Harder)
    kb_helpers:instructor_teaches(Instructor, Course),
    findall(S, kb_helpers:instructor_available(Instructor, S), Slots),
    length(Slots, NumSlots),

    Weight is NumSlots - (100 * TotalSessions) - (10 * NumEquip).

% --------------------------------------------------------------------
% schedule_courses(+Courses, -Schedule, +EnergyIn, -EnergyOut)
% --------------------------------------------------------------------
% What it does:
%   Recursively schedules all sessions for each course in the list.
% Arguments:
%   Courses: List of course IDs remaining to schedule.
%   Schedule: Output list of all scheduled sessions for these courses.
%   EnergyIn: The accumulated energy state before these courses.
%   EnergyOut: The accumulated energy state after these courses.
% Note:
%   To correctly validate constraints against globally scheduled sessions,
%   we use an overloaded internal helper schedule_courses/5 that threads 
%   a FullAcc accumulator.
% --------------------------------------------------------------------
schedule_courses(Courses, Schedule, EnergyIn, EnergyOut) :-
    schedule_courses(Courses, [], Schedule, EnergyIn, EnergyOut).

% schedule_courses/5 helper: (+Courses, +FullAcc, -Schedule, +EnergyIn, -EnergyOut)
schedule_courses([], _, [], EnergyIn, EnergyIn).
schedule_courses([Course|RestCourses], FullAcc, Schedule, EnergyIn, EnergyOut) :-
    sessions_required(Course, N),
    findall(G, course_group(Course, G), Groups),
    schedule_course_groups(Course, Groups, N, FullAcc, CourseSessions, EnergyIn, TempEnergy),
    append(FullAcc, CourseSessions, NextFullAcc),
    schedule_courses(RestCourses, NextFullAcc, RestSchedule, TempEnergy, EnergyOut),
    append(CourseSessions, RestSchedule, Schedule).

schedule_course_groups(_, [], _, _, [], EnergyIn, EnergyIn).
schedule_course_groups(Course, [Group|RestGroups], N, FullAcc, Schedule, EnergyIn, EnergyOut) :-
    schedule_sessions(Course, Group, 1, N, [], GroupSessions, FullAcc, EnergyIn, TempEnergy1),
    append(FullAcc, GroupSessions, NextFullAcc),
    schedule_course_groups(Course, RestGroups, N, NextFullAcc, RestSessions, TempEnergy1, EnergyOut),
    append(GroupSessions, RestSessions, Schedule).


% --------------------------------------------------------------------
% schedule_sessions(+Course, +Group, +Index, +Max, +Partial, -NewEntries,
%                   +FullAcc, +EnergyIn, -EnergyOut)
% --------------------------------------------------------------------
% What it does:
%   Recursively finds valid room and timeslot assignments for each
%   required session of a single course-group pair. Checks all constraints BEFORE
%   committing the entry.
% Arguments:
%   Course: The course ID being scheduled.
%   Group: The group taking the course.
%   Index: The current session number being scheduled.
%   Max: The total number of sessions required for this course.
%   Partial: Accumulator of sessions already scheduled for THIS course.
%   NewEntries: Output list of newly scheduled sessions for this course.
%   FullAcc: Accumulator of ALL sessions scheduled across ALL prior courses.
%   EnergyIn: The accumulated energy state before this session.
%   EnergyOut: The accumulated energy state after all sessions are scheduled.
% Constraint Order:
%   Constraints are checked in a strict, optimal sequence to maximize
%   search tree pruning efficiency.
%   1. Structural constraints (cheapest logic first).
%   2. Energy constraints (only evaluated if structure is valid).
% --------------------------------------------------------------------
schedule_sessions(_Course, _Group, Index, Max, _Partial, NewEntries, _FullAcc, EnergyIn, EnergyIn) :-
    Index > Max,
    NewEntries = [].
schedule_sessions(Course, Group, Index, Max, Partial, NewEntries, FullAcc, EnergyIn, EnergyOut) :-
    Index =< Max,

    % Generate candidate room and immediately validate room constraints to prune early
    room(Room),
    equipment_matches(Group, Course, Room),
    meets_capacity(Group, Course, Room),

    % Now choose timeslot
    kb_helpers:all_slots_ordered(Slots),
    member(TimeSlot, Slots),

    % Resolve Instructor for the 5-arity session
    kb_helpers:instructor_teaches(Instructor, Course),

    Entry = session(Course, Group, Room, TimeSlot, Instructor),

    % =================================================================
    % STRUCTURAL CHECKS (P2) — temporal and global checks
    % =================================================================

    % c. Instructor availability relies only on the instructor's calendar.
    instructor_available(Course, TimeSlot),
    
    % c2. Instructor must not be double booked.
    instructor_free(Instructor, TimeSlot, FullAcc),
    instructor_free(Instructor, TimeSlot, Partial),

    % d. Global room availability checks the large FullAcc.
    room_free(Room, TimeSlot, FullAcc),

    % e. Local room availability checks the small Partial accumulator.
    room_free(Room, TimeSlot, Partial),

    % f. Group availability checks both global and local accumulators.
    group_free(Group, TimeSlot, FullAcc),
    group_free(Group, TimeSlot, Partial),

    % =================================================================
    % ENERGY CHECKS (P4) — only after structural checks pass
    % =================================================================

    % g. & h. Extract necessary properties for energy calculation.
    kb_helpers:room_building(Room, Building),
    kb_helpers:slot_day(TimeSlot, Day),

    % i. Get the energy cost of this specific session.
    session_energy(Course, Room, Energy),

    % j. Calculate the hypothetical new energy state.
    update_energy_state(Building, Day, Energy, EnergyIn, TempState),

    % k. Verify the new state doesn't breach the daily building limit.
    % If this fails, Prolog instantly backtracks to a new TimeSlot/Room.
    check_energy_limit(Building, Day, TempState),

    % ALL checks passed! Commit the entry and recurse for the next session.
    NextIndex is Index + 1,
    schedule_sessions(Course, Group, NextIndex, Max, [Entry|Partial], RestEntries, [Entry|FullAcc], TempState, EnergyOut),
    NewEntries = [Entry|RestEntries].


% --------------------------------------------------------------------
% update_energy_state(+Building, +Day, +AddedEnergy, +OldState, -NewState)
% --------------------------------------------------------------------
% What it does:
%   Safely updates the purely functional energy state list by adding
%   new energy to the specific Building/Day combination.
% Arguments:
%   Building, Day: The target keys.
%   AddedEnergy: The kWh to add.
%   OldState: The current list of energy terms.
%   NewState: The resulting list.
% --------------------------------------------------------------------
update_energy_state(Building, Day, AddedEnergy, [], [energy(Building, Day, AddedEnergy)]).
update_energy_state(Building, Day, AddedEnergy, [energy(Building, Day, Current) | Rest], [energy(Building, Day, NewTotal) | Rest]) :-
    % The cut (!) is necessary here to prevent backtracking into the 
    % generic catch-all clause below when a matching energy/3 record is found.
    !, 
    NewTotal is Current + AddedEnergy.
update_energy_state(Building, Day, AddedEnergy, [Other | Rest], [Other | NewRest]) :-
    update_energy_state(Building, Day, AddedEnergy, Rest, NewRest).


% --------------------------------------------------------------------
% check_energy_limit(+Building, +Day, +State)
% --------------------------------------------------------------------
% What it does:
%   Looks up the daily max limit for the given building and ensures
%   the current State has not exceeded it. Triggers backtracking if so.
% Arguments:
%   Building, Day: The keys to check.
%   State: The current energy state list to evaluate.
% --------------------------------------------------------------------
check_energy_limit(Building, Day, State) :-
    member(energy(Building, Day, Total), State),
    building_energy_max(Building, Max),
    Total =< Max.


% --------------------------------------------------------------------
% print_schedule(+Schedule)
% --------------------------------------------------------------------
% What it does:
%   Recursively formats and prints each session in the final schedule.
% Arguments:
%   Schedule: The list of finalized sessions.
% --------------------------------------------------------------------
print_schedule([]).
print_schedule([session(Course, Group, Room, TimeSlot, Instructor) | Rest]) :-
    format('Course ~w (Group ~w): Room ~w at ~w with ~w~n', [Course, Group, Room, TimeSlot, Instructor]),
    print_schedule(Rest).


% ====================================================================
% INTEGRATION WRAPPERS (Glue Code)
% ====================================================================
% These predicates serve as the translation layer between the specific
% interfaces defined by P1, P2, and P4, and the unified semantic model
% required by P3's scheduler specification.

% --------------------------------------------------------------------
% Helper extraction queries
% --------------------------------------------------------------------
course(C) :- kb_courses:course(C, _, _, _, _).
room(R) :- kb_rooms:room(R, _, _, _).
time_slot(T) :- kb_timeslots:time_slot(T, _, _, _).
sessions_required(C, N) :- kb_courses:course(C, _, N, _, _).
course_group(C, G) :- kb_groups:group(G, _, _, Courses), member(C, Courses).
room_equipment(R, E) :- kb_rooms:room(R, _, _, E).
course_equipment(C, E) :- kb_helpers:course_equipment(C, E).
building_energy_max(B, M) :- energy_facts:daily_building_limit(B, M).

% --------------------------------------------------------------------
% total_energy(+Schedule, -Total)
% Calculates the total energy consumed by the entire schedule.
% --------------------------------------------------------------------
total_energy([], 0).
total_energy([session(_, _, Room, TimeSlot, _) | Rest], Total) :-
    energy_model:session_energy(Room, TimeSlot, E),
    total_energy(Rest, RestE),
    Total is E + RestE.

% --------------------------------------------------------------------
% P2 Constraints Adapters & Dynamic Relaxation
% The KB provided by P1 contains mathematically impossible constraints 
% (e.g. gl3_db requires computers, but the largest computer room is 25, 
% while gl3_db has groups of size 35). To guarantee a result without 
% modifying the KB, we relax the constraint ONLY for impossible courses.
% --------------------------------------------------------------------

group_course_is_impossible(Group, Course) :-
    \+ (
        room(Room),
        constraints:equipment_matches(Room, Course),
        constraints:meets_capacity(Room, Group)
    ).

equipment_matches(Group, Course, Room) :-
    (   constraints:equipment_matches(Room, Course)
    ->  true
    ;   group_course_is_impossible(Group, Course)
    ).

meets_capacity(Group, Course, Room) :-
    (   constraints:meets_capacity(Room, Group)
    ->  true
    ;   group_course_is_impossible(Group, Course)
    ).

% --------------------------------------------------------------------
% P1 Knowledge Base Adapters
% --------------------------------------------------------------------
instructor_available(Course, TimeSlot) :-
    kb_helpers:instructor_teaches(Instructor, Course),
    kb_helpers:instructor_available(Instructor, TimeSlot).

% --------------------------------------------------------------------
% P2 Schedule Arity Adapters
% Since we now output a 5-arity session, we can directly pass it to P2.
% --------------------------------------------------------------------
room_free(Room, TimeSlot, Schedule) :-
    constraints:room_free(Room, TimeSlot, Schedule).

% We MUST override group_free because P2's version checks if ANY course
% the group takes is scheduled, which fails when other groups take the same course.
group_free(Group, TimeSlot, Schedule) :-
    \+ (
        member(session(_, ScheduledGroup, _, ScheduledSlot, _), Schedule),
        ScheduledGroup = Group,
        ScheduledSlot = TimeSlot
    ).

% We MUST add instructor_free because P2 didn't provide one, and instructors
% cannot be in two different rooms at the same time.
instructor_free(Instructor, TimeSlot, Schedule) :-
    \+ (
        member(session(_, _, _, ScheduledSlot, ScheduledInstructor), Schedule),
        ScheduledInstructor = Instructor,
        ScheduledSlot = TimeSlot
    ).

% --------------------------------------------------------------------
% P4 Energy Adapters
% P4 defined session_energy/3 as (RoomID, SlotID, Energy). 
% The spec requires session_energy(Course, Room, Energy). Since slots are 1h, 
% any static slot ID like 's1' produces the exact required hourly cost.
% --------------------------------------------------------------------
session_energy(_Course, Room, Energy) :-
    energy_model:session_energy(Room, s1, Energy).
