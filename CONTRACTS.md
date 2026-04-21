

## For (Constraints)

| Predicate               | How to call                    | Returns     |
|-------------------------|--------------------------------|-------------|
| room_fits_group/2       | room_fits_group(+Room, +Group) | true/false  |
| room_satisfies_course/2 | room_satisfies_course(+R, +C)  | true/false  |
| room_building/2         | room_building(+Room, -Building)| atom        |
| slot_day/2              | slot_day(+Slot, -Day)          | atom        |
| instructor_available/2  | instructor_available(+I, +S)   | true/false  |
| instructor_teaches/2    | instructor_teaches(+I, +C)     | true/false  |
| group_size/2            | group_size(+Group, -Size)      | integer     |

## For  (Scheduler)

| Predicate               | How to call                    | Returns     |
|-------------------------|--------------------------------|-------------|
| all_slots_ordered/1     | all_slots_ordered(-Slots)      | ordered list|
| all_rooms/1             | all_rooms(-Rooms)              | list        |
| all_groups/1            | all_groups(-Groups)            | list        |
| group_courses/2         | group_courses(+Group, -Courses)| list        |
| consecutive_slots/2     | consecutive_slots(+S1, +S2)   | true/false  |

## Critical notes 
- Always use all_slots_ordered/1, never findall(S, time_slot(...))
  Reason: findall gives lexicographic order (s1,s10,s11..s2)
          all_slots_ordered gives numeric order (s1,s2,s3..s40)
- consecutive_slots(s8, s9) is FALSE — they are on different days