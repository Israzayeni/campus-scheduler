:- module(kb_helpers, [
    slot_day/2,
    slot_hour/3,
    slot_number/2,
    room_building/2,
    room_capacity/2,
    room_has_equipment/2,
    room_fits_group/2,
    room_satisfies_course/2,
    group_size/2,
    group_courses/2,
    instructor_teaches/2,
    instructor_available/2,
    consecutive_slots/2,
    slots_same_day/2,
    course_equipment/2,
    all_slots_ordered/1,
    all_rooms/1,
    all_groups/1,
    validate_kb/0
]).

% These use_module lines come AFTER the module declaration
:- use_module(kb_courses).
:- use_module(kb_rooms).
:- use_module(kb_buildings).
:- use_module(kb_timeslots).
:- use_module(kb_groups).
:- use_module(kb_instructors).



slot_day(Slot, Day) :-
    time_slot(Slot, Day, _, _).

slot_hour(Slot, Start, End) :-
    time_slot(Slot, _, Start, End).

slot_number(Slot, N) :-
    atom_concat(s, NAtom, Slot),
    atom_number(NAtom, N).

consecutive_slots(Slot1, Slot2) :-
    slot_number(Slot1, N1),
    slot_number(Slot2, N2),
    N2 =:= N1 + 1,
    slot_day(Slot1, Day),
    slot_day(Slot2, Day).

slots_same_day(Slot1, Slot2) :-
    slot_day(Slot1, Day),
    slot_day(Slot2, Day).

all_slots_ordered(Slots) :-
    findall(N-S,
        (time_slot(S, _, _, _), slot_number(S, N)),
        Pairs),
    sort(Pairs, Sorted),
    pairs_values(Sorted, Slots).


room_building(Room, Building) :-
    room(Room, Building, _, _).

room_capacity(Room, Cap) :-
    room(Room, _, Cap, _).

room_has_equipment(Room, Item) :-
    room(Room, _, _, EquipList),
    member(Item, EquipList).

room_fits_group(Room, Group) :-
    room_capacity(Room, Cap),
    group_size(Group, Size),
    Cap >= Size.

room_satisfies_course(Room, Course) :-
    course_equipment(Course, Required),
    room(Room, _, _, RoomEquip),
    forall(
        member(Item, Required),
        member(Item, RoomEquip)
    ).

all_rooms(Rooms) :-
    findall(R, room(R, _, _, _), Rooms).



group_size(Group, Size) :-
    group(Group, _, Size, _).

group_courses(Group, Courses) :-
    group(Group, _, _, Courses).

all_groups(Groups) :-
    findall(G, group(G, _, _, _), Groups).



course_equipment(Course, Equip) :-
    course(Course, _, _, Equip, _).



instructor_teaches(Instructor, Course) :-
    instructor(Instructor, _, Courses),
    member(Course, Courses).

instructor_available(Instructor, Slot) :-
    available(Instructor, Slot).



validate_kb :-
    write('--- KB Validation Start ---'), nl,
    check_rooms_have_valid_buildings,
    check_groups_have_valid_courses,
    check_instructors_have_valid_courses,
    check_no_duplicate_slots,
    check_every_course_has_instructor,
    write('--- All checks passed ---'), nl.

check_rooms_have_valid_buildings :-
    forall(
        room(R, B, _, _),
        (   building(B, _, _, _)
        ->  true
        ;   format('ERROR: room ~w unknown building ~w~n', [R, B]),
            fail
        )
    ),
    write('OK: rooms have valid buildings'), nl.

check_groups_have_valid_courses :-
    forall(
        (group(G, _, _, Courses), member(C, Courses)),
        (   course(C, _, _, _, _)
        ->  true
        ;   format('ERROR: group ~w unknown course ~w~n', [G, C]),
            fail
        )
    ),
    write('OK: group courses exist'), nl.

check_instructors_have_valid_courses :-
    forall(
        (instructor(I, _, Courses), member(C, Courses)),
        (   course(C, _, _, _, _)
        ->  true
        ;   format('ERROR: instructor ~w unknown course ~w~n', [I, C]),
            fail
        )
    ),
    write('OK: instructor courses exist'), nl.

check_no_duplicate_slots :-
    findall(S, time_slot(S, _, _, _), Slots),
    sort(Slots, Unique),
    length(Slots, N), length(Unique, N),
    write('OK: no duplicate slot IDs'), nl.

check_every_course_has_instructor :-
    forall(
        course(C, _, _, _, _),
        (   instructor(_, _, Courses), member(C, Courses)
        ->  true
        ;   format('ERROR: course ~w has no instructor~n', [C]),
            fail
        )
    ),
    write('OK: every course has an instructor'), nl.