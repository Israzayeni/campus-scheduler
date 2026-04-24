:- module(constraints, [
    room_free/3,
    group_free/3,
    meets_capacity/2,
    equipment_matches/2,
    validate_assignment/6
]).

% Import all knowledge bases
:- use_module('../knowledge_base/kb_courses').
:- use_module('../knowledge_base/kb_rooms').
:- use_module('../knowledge_base/kb_buildings').
:- use_module('../knowledge_base/kb_timeslots').
:- use_module('../knowledge_base/kb_groups').
:- use_module('../knowledge_base/kb_instructors').
:- use_module('../knowledge_base/kb_helpers').

room_free(Room, Slot, CurrentSchedule) :-
    % Check that NO other session occupies this room at this slot
    \+ (
        member(session(_, _, AssignedRoom, AssignedSlot, _), CurrentSchedule),
        AssignedRoom = Room,
        AssignedSlot = Slot
    ).


group_free(Group, Slot, CurrentSchedule) :-
    % Get all courses this group must take
    group_courses(Group, Courses),
    
    % For each course, verify NO session is scheduled at Slot
    forall(
        member(Course, Courses),
        (
            % Check all sessions of this course in CurrentSchedule
            \+ (
                member(session(ScheduledCourse, _, _, ScheduledSlot, _), CurrentSchedule),
                ScheduledCourse = Course,
                ScheduledSlot = Slot
            )
        )
    ).


meets_capacity(Room, Group) :-
    room_capacity(Room, RoomCap),
    group_size(Group, GroupSize),
    RoomCap >= GroupSize.


equipment_matches(Room, Course) :-
    % Get required equipment for this course
    course_equipment(Course, RequiredEquipment),
    
    % Get room's equipment list
    room(Room, _, _, RoomEquipment),
    
    % Check that EVERY required item is in room's equipment list
    forall(
        member(RequiredItem, RequiredEquipment),
        member(RequiredItem, RoomEquipment)
    ).


validate_assignment(Course, Group, Room, Slot, Instructor, CurrentSchedule) :-
    % 1. STRUCTURAL: Room capacity
    meets_capacity(Room, Group),
    
    % 2. STRUCTURAL: Equipment compatibility
    equipment_matches(Room, Course),
    
    % 3. INSTRUCTOR: Can this instructor teach this course?
    instructor_teaches(Instructor, Course),
    
    % 4. TEMPORAL: Is instructor available at this slot?
    instructor_available(Instructor, Slot),
    
    % 5. TEMPORAL: Is room free at this slot?
    room_free(Room, Slot, CurrentSchedule),
    
    % 6. TEMPORAL: Is group free at this slot?
    group_free(Group, Slot, CurrentSchedule).

