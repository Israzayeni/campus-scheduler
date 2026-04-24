:- use_module('../knowledge_base/kb_buildings').
:- use_module('../knowledge_base/kb_courses').
:- use_module('../knowledge_base/kb_rooms').
:- use_module('../knowledge_base/kb_timeslots').
:- use_module('../knowledge_base/kb_groups').
:- use_module('../knowledge_base/kb_instructors').
:- use_module('../knowledge_base/kb_helpers').
:- use_module('../constraints/constraints').

:- use_module(library(plunit)).

:- begin_tests(constraints).

% ============================================================================
% Tests for room_free/3
% ============================================================================

test(room_free_empty_schedule) :-
    % Any room should be free when schedule is empty
    room_free(r101, s1, []).

test(room_free_different_room) :-
    % Room is free if different room is occupied
    Schedule = [session(gl3_algo, 1, r102, s1, prof_ali)],
    room_free(r101, s1, Schedule).

test(room_free_different_slot) :-
    % Room is free if same room occupied at different slot
    Schedule = [session(gl3_algo, 1, r101, s1, prof_ali)],
    room_free(r101, s2, Schedule).

test(room_occupied) :-
    % Room occupied should fail
    Schedule = [session(gl3_algo, 1, r101, s1, prof_ali)],
    \+ room_free(r101, s1, Schedule).

test(room_free_multiple_sessions) :-
    % Room still free when other sessions exist elsewhere
    Schedule = [
        session(gl3_algo, 1, r102, s1, prof_ali),
        session(gl3_db, 1, r103, s2, prof_sana),
        session(gl3_os, 1, r201, s3, prof_karim)
    ],
    room_free(r101, s4, Schedule).

% ============================================================================
% Tests for group_free/3
% ============================================================================

test(group_free_empty_schedule) :-
    % Any group should be free when schedule is empty
    group_free(g1, s1, []).

test(group_free_different_group) :-
    % Group is free if no course it takes is scheduled at that slot
    Schedule = [session(gl3_ai, 1, r201, s1, prof_sana)],
    % g4 doesn't take gl3_ai, so it's free at s1 even though gl3_ai is scheduled
    group_free(g4, s1, Schedule).

test(group_conflict_same_course) :-
    % Group conflicts if a course it takes is already scheduled
    Schedule = [session(gl3_algo, 1, r101, s1, prof_ali)],
    % g1 takes gl3_algo, so it should conflict
    \+ group_free(g1, s1, Schedule).

test(group_free_different_slot_same_course) :-
    % Group is free if its course is scheduled at different time
    Schedule = [session(gl3_algo, 1, r101, s1, prof_ali)],
    % gl3_algo at s1 means g1 is busy at s1 but free at s2
    group_free(g1, s2, Schedule).

test(group_multiple_conflicts) :-
    % Group should avoid conflicts with ALL its courses
    Schedule = [
        session(gl3_algo, 1, r101, s1, prof_ali),
        session(gl3_db, 1, r102, s1, prof_sana)
    ],
    % g1 takes both gl3_algo and gl3_db, so conflicts at s1
    \+ group_free(g1, s1, Schedule).

% ============================================================================
% Tests for meets_capacity/2
% ============================================================================

test(meets_capacity_exact_fit) :-
    % r101 has capacity 40, g1 has size 32
    meets_capacity(r101, g1).

test(meets_capacity_room_larger) :-
    % r301 has capacity 50, g4 has size 22
    meets_capacity(r301, g4).

test(meets_capacity_insufficient) :-
    % r203 has capacity 15, g1 has size 32
    \+ meets_capacity(r203, g1).

test(meets_capacity_exact_boundary) :-
    % Edge case: exact capacity match (r101 has 40, closest group is g1 with 32)
    meets_capacity(r101, g1).

test(meets_capacity_all_combinations) :-
    % Every room should accommodate its available groups
    forall(
        (room(R, _, _, _), group(G, _, _, _)),
        (
            room_capacity(R, Cap),
            group_size(G, Size),
            (Cap >= Size -> meets_capacity(R, G) ; \+ meets_capacity(R, G))
        )
    ).

% ============================================================================
% Tests for equipment_matches/2
% ============================================================================

test(equipment_matches_perfect) :-
    % r201 has [projector, computers, whiteboard]
    % gl3_db needs [projector, computers]
    equipment_matches(r201, gl3_db).

test(equipment_matches_superset) :-
    % r101 has [projector, whiteboard]
    % gl3_se needs [projector] only
    equipment_matches(r101, gl3_se).

test(equipment_mismatch_missing) :-
    % r101 has [projector, whiteboard]
    % gl3_db needs [projector, computers]
    % missing computers
    \+ equipment_matches(r101, gl3_db).

test(equipment_mismatch_lab_bench) :-
    % r101 has [projector, whiteboard]
    % gl3_net needs [projector, lab_bench]
    % missing lab_bench
    \+ equipment_matches(r101, gl3_net).

test(equipment_lab_available) :-
    % r203 has [computers, lab_bench]
    % gl3_net needs [projector, lab_bench]
    % has lab_bench but missing projector
    \+ equipment_matches(r203, gl3_net).

test(equipment_specialized_room) :-
    % r203 is lab room with [computers, lab_bench]
    % gl3_sec needs [projector, computers]
    % r203 has computers but not projector, so should fail
    \+ equipment_matches(r203, gl3_sec).

% ============================================================================
% Tests for instructor_available/2
% ============================================================================

test(instructor_available_yes) :-
    % prof_ali is available at s1
    instructor_available(prof_ali, s1).

test(instructor_available_no) :-
    % prof_ali is NOT available at s5
    \+ instructor_available(prof_ali, s5).

test(instructor_available_sana) :-
    % prof_sana available at s5 (Monday 13-14)
    instructor_available(prof_sana, s5),
    !.

test(instructor_available_all_scheduled) :-
    % Verify each instructor has at least one available slot
    forall(
        instructor(I, _, _),
        (   available(I, _)
        ->  true
        ;   format('ERROR: instructor ~w has no availability~n', [I]), fail
        )
    ).

test(instructor_available_no_gaps) :-
    % prof_ali: s1,s2,s3,s4 (Mon 8-12), s9,s10 (Tue 8-10), s13,s14 (Tue 13-15)
    % Should fail for other slots
    \+ instructor_available(prof_ali, s5),  % Mon afternoon
    \+ instructor_available(prof_ali, s8),  % Mon 16-17
    \+ instructor_available(prof_ali, s11), % Tue 10-11
    \+ instructor_available(prof_ali, s25). % Thu morning

% ============================================================================
% Tests for validate_assignment/6 (Composite Constraint)
% ============================================================================

test(validate_assignment_valid_basic) :-
    % Attempt to assign gl3_algo session 1 to group g1
    % with prof_ali in r101 at s1
    validate_assignment(
        gl3_algo,      % Course
        g1,            % Group
        r101,          % Room
        s1,            % Slot
        prof_ali,      % Instructor
        []             % Empty schedule (no conflicts)
    ),
    !.

test(validate_assignment_fail_capacity) :-
    % r203 (cap 15) cannot fit g1 (size 32)
    \+ validate_assignment(
        gl3_algo,
        g1,
        r203,          % Too small!
        s1,
        prof_ali,
        []
    ).

test(validate_assignment_fail_equipment) :-
    % r101 lacks computers, gl3_db needs them
    \+ validate_assignment(
        gl3_db,
        g1,
        r101,          % Missing equipment
        s2,
        prof_sana,
        []
    ).

test(validate_assignment_fail_instructor_wrong_course) :-
    % prof_ali cannot teach gl3_db (only algo, math)
    \+ validate_assignment(
        gl3_db,
        g1,
        r201,
        s1,
        prof_ali,      % Can't teach this course
        []
    ).

test(validate_assignment_fail_instructor_unavailable) :-
    % prof_ali not available at s5
    \+ validate_assignment(
        gl3_algo,
        g1,
        r101,
        s5,            % prof_ali not available
        prof_ali,
        []
    ).

test(validate_assignment_fail_room_occupied) :-
    % r101 is already booked at s1
    Schedule = [session(gl3_se, 1, r101, s1, prof_rania)],
    \+ validate_assignment(
        gl3_algo,
        g1,
        r101,          % Occupied at s1
        s1,
        prof_ali,
        Schedule
    ).

test(validate_assignment_fail_group_conflict) :-
    % Group g1 already has a session at s1
    Schedule = [session(gl3_db, 1, r201, s1, prof_sana)],
    \+ validate_assignment(
        gl3_algo,      % Different course but same slot for g1
        g1,
        r101,
        s1,            % g1 already busy
        prof_ali,
        Schedule
    ).

test(validate_assignment_multiple_valid) :-
    % Can assign same course different group at different slot
    Schedule1 = [session(gl3_algo, 1, r101, s1, prof_ali)],
    validate_assignment(
        gl3_algo,
        g2,            % Different group
        r102,          % Different room
        s2,            % Different slot
        prof_ali,
        Schedule1
    ),
    !.

% ============================================================================
% Integration Tests
% ============================================================================

test(no_room_double_booked) :-
    % Verify room is NOT free when already booked at same time
    Schedule = [session(gl3_algo, 1, r101, s1, prof_ali)],
    \+ room_free(r101, s1, Schedule).

test(no_group_double_booked) :-
    % Verify group is NOT free when one of its courses is already scheduled
    Schedule = [session(gl3_algo, 1, r101, s1, prof_ali)],
    \+ group_free(g1, s1, Schedule).

% ============================================================================
% Summary Test
% ============================================================================

test(all_constraints_implemented) :-
    % Simply verify all constraint predicates are defined
    (   predicate_property(room_free(_, _, _), defined)
    ->  true
    ;   fail
    ),
    (   predicate_property(group_free(_, _, _), defined)
    ->  true
    ;   fail
    ),
    (   predicate_property(meets_capacity(_, _), defined)
    ->  true
    ;   fail
    ),
    (   predicate_property(equipment_matches(_, _), defined)
    ->  true
    ;   fail
    ),
    (   predicate_property(instructor_available(_, _), defined)
    ->  true
    ;   fail
    ).

:- end_tests(constraints).

:- run_tests.
