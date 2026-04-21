## 2.1 Overview

The knowledge base is the foundation of the scheduling system.
It contains seven Prolog modules. All other modules depend on it
through documented helper predicates. No reverse dependency exists.

## 2.2 Fact Schemas

| Predicate      | Arity | Arguments                                        |
|----------------|-------|--------------------------------------------------|
| course/5       | 5     | ID, Name, DurationSlots, EquipmentList, Credits  |
| building/4     | 4     | ID, Name, EnergyRate, MaxActiveRooms             |
| room/4         | 4     | ID, BuildingID, Capacity, EquipmentList          |
| time_slot/4    | 4     | ID, Day, StartHour, EndHour                      |
| group/4        | 4     | ID, Name, Size, CourseList                       |
| instructor/3   | 3     | ID, Name, CourseList                             |
| available/2    | 2     | InstructorID, SlotID                             |

## 2.3 Relationships Between Entities

- room.BuildingID → building.ID          (every room belongs to a building)
- group.CourseList → course.ID           (groups reference valid courses)
- instructor.CourseList → course.ID      (instructors reference valid courses)
- available.InstructorID → instructor.ID (availability links to instructors)
- available.SlotID → time_slot.ID        (availability links to slots)
- room.Equipment ⊇ course.Equipment      (checked by room_satisfies_course/2)
- room.Capacity ≥ group.Size             (checked by room_fits_group/2)

## 2.4 Helper Predicate Layer

Helper predicates in kb_helpers.pl abstract all joins so that
the constraints and scheduler modules never query raw facts directly.

Key helpers and their logic:

room_satisfies_course(Room, Course):
  Uses forall/2 to verify every item in the course equipment list
  exists in the room equipment list. Subset check.

consecutive_slots(Slot1, Slot2):
  Extracts integer N from slot atom (s5 → 5), checks N2 = N1+1,
  AND checks both slots are on the same day. Prevents cross-day booking.

all_slots_ordered(Slots):
  Uses numeric sort on extracted slot numbers to return slots in
  correct order s1..s40, avoiding lexicographic bug from sort/2.

## 2.5 Data Summary

| Entity       | Count |
|--------------|-------|
| Courses      | 8     |
| Buildings    | 3     |
| Rooms        | 8     |
| Time Slots   | 40    |
| Groups       | 4     |
| Instructors  | 4     |
| Avail. facts | 32    |

## 2.6 Validation

validate_kb/0 checks at runtime:
- Every room's BuildingID exists in building/4
- Every course in group/4 lists exists in course/5
- Every course in instructor/3 lists exists in course/5
- No duplicate slot IDs exist
- Every course has at least one qualified instructor

## 2.7 Test Coverage

14 unit tests in tests/test_kb.pl — all passing.
Run with: swipl -g "run_tests" -t halt tests/test_kb.pl