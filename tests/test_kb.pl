:- use_module('../knowledge_base/kb_buildings').
:- use_module('../knowledge_base/kb_courses').
:- use_module('../knowledge_base/kb_rooms').
:- use_module('../knowledge_base/kb_timeslots').
:- use_module('../knowledge_base/kb_groups').
:- use_module('../knowledge_base/kb_instructors').
:- use_module('../knowledge_base/kb_helpers').

:- use_module(library(plunit)).

:- begin_tests(kb_facts).

test(course_exists) :-
    course(_, _, _, _, _),!.

test(course_equipment_is_list) :-
    course(_, _, _, Equip, _),!,
    is_list(Equip),!.

test(room_in_known_building) :-
    forall(
        room(R, B, _, _),
        (   building(B, _, _, _)
        ->  true
        ;   format('FAIL room ~w bad building ~w~n',[R,B]), fail
        )
    ).

test(room_capacity_positive) :-
    forall(
        room(R, _, Cap, _),
        (   integer(Cap), Cap > 0
        ->  true
        ;   format('FAIL room ~w bad cap ~w~n',[R,Cap]), fail
        )
    ).

test(slot_day_works) :-
    slot_day(s1, monday).

test(slot_day_tuesday) :-
    slot_day(s9, tuesday).

test(consecutive_slots_basic) :-
    consecutive_slots(s1, s2).

test(consecutive_slots_no_cross_day) :-
    \+ consecutive_slots(s8, s9).

test(room_satisfies_course_true) :-
    room_satisfies_course(r201, gl3_db).

test(room_satisfies_course_false) :-
    \+ room_satisfies_course(r101, gl3_db).

test(room_fits_group_ok) :-
    room_fits_group(r101, g1).

test(group_courses_nonempty) :-
    group_courses(g1, Courses),
    Courses \= [].

test(instructor_teaches_match) :-
    instructor_teaches(prof_ali, gl3_algo),!.

test(instructor_available_slot) :-
    instructor_available(prof_ali, s1),!.

:- end_tests(kb_facts).

:- run_tests.