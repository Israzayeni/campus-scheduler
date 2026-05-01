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


run_scheduler(Courses, Schedule, FinalEnergyState) :-
    sort_by_constraint(Courses, SortedCourses),
    schedule_courses(SortedCourses, Schedule, [], FinalEnergyState).


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



schedule_sessions(_Course, _Group, Index, Max, _Partial, NewEntries, _FullAcc, EnergyIn, EnergyIn) :-
    Index > Max,
    NewEntries = [].
schedule_sessions(Course, Group, Index, Max, Partial, NewEntries, FullAcc, EnergyIn, EnergyOut) :-
    Index =< Max,

    room(Room),
    equipment_matches(Group, Course, Room),
    meets_capacity(Group, Course, Room),

    kb_helpers:all_slots_ordered(Slots),
    member(TimeSlot, Slots),

    kb_helpers:instructor_teaches(Instructor, Course),

    Entry = session(Course, Group, Room, TimeSlot, Instructor),

    instructor_available(Course, TimeSlot),
    
    instructor_free(Instructor, TimeSlot, FullAcc),
    instructor_free(Instructor, TimeSlot, Partial),

    room_free(Room, TimeSlot, FullAcc),

    room_free(Room, TimeSlot, Partial),

    group_free(Group, TimeSlot, FullAcc),
    group_free(Group, TimeSlot, Partial),

    kb_helpers:room_building(Room, Building),
    kb_helpers:slot_day(TimeSlot, Day),

    session_energy(Course, Room, Energy),

    update_energy_state(Building, Day, Energy, EnergyIn, TempState),

    check_energy_limit(Building, Day, TempState),

    NextIndex is Index + 1,
    schedule_sessions(Course, Group, NextIndex, Max, [Entry|Partial], RestEntries, [Entry|FullAcc], TempState, EnergyOut),
    NewEntries = [Entry|RestEntries].



update_energy_state(Building, Day, AddedEnergy, [], [energy(Building, Day, AddedEnergy)]).
update_energy_state(Building, Day, AddedEnergy, [energy(Building, Day, Current) | Rest], [energy(Building, Day, NewTotal) | Rest]) :-
    !, 
    NewTotal is Current + AddedEnergy.
update_energy_state(Building, Day, AddedEnergy, [Other | Rest], [Other | NewRest]) :-
    update_energy_state(Building, Day, AddedEnergy, Rest, NewRest).



check_energy_limit(Building, Day, State) :-
    member(energy(Building, Day, Total), State),
    building_energy_max(Building, Max),
    Total =< Max.



print_schedule([]).
print_schedule([session(Course, Group, Room, TimeSlot, Instructor) | Rest]) :-
    format('Course ~w (Group ~w): Room ~w at ~w with ~w~n', [Course, Group, Room, TimeSlot, Instructor]),
    print_schedule(Rest).



course(C) :- kb_courses:course(C, _, _, _, _).
room(R) :- kb_rooms:room(R, _, _, _).
time_slot(T) :- kb_timeslots:time_slot(T, _, _, _).
sessions_required(C, N) :- kb_courses:course(C, _, N, _, _).
course_group(C, G) :- kb_groups:group(G, _, _, Courses), member(C, Courses).
room_equipment(R, E) :- kb_rooms:room(R, _, _, E).
course_equipment(C, E) :- kb_helpers:course_equipment(C, E).
building_energy_max(B, M) :- energy_facts:daily_building_limit(B, M).


total_energy([], 0).
total_energy([session(_, _, Room, TimeSlot, _) | Rest], Total) :-
    energy_model:session_energy(Room, TimeSlot, E),
    total_energy(Rest, RestE),
    Total is E + RestE.



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


instructor_available(Course, TimeSlot) :-
    kb_helpers:instructor_teaches(Instructor, Course),
    kb_helpers:instructor_available(Instructor, TimeSlot).


room_free(Room, TimeSlot, Schedule) :-
    constraints:room_free(Room, TimeSlot, Schedule).

group_free(Group, TimeSlot, Schedule) :-
    \+ (
        member(session(_, ScheduledGroup, _, ScheduledSlot, _), Schedule),
        ScheduledGroup = Group,
        ScheduledSlot = TimeSlot
    ).

instructor_free(Instructor, TimeSlot, Schedule) :-
    \+ (
        member(session(_, _, _, ScheduledSlot, ScheduledInstructor), Schedule),
        ScheduledInstructor = Instructor,
        ScheduledSlot = TimeSlot
    ).


session_energy(_Course, Room, Energy) :-
    energy_model:session_energy(Room, s1, Energy).
