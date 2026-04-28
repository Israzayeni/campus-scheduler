:- module(energy_facts, [
    room_energy_cost/2,
    daily_building_limit/2,
    slot_duration/2
]).

% ============================================================
% room_energy_cost(+RoomID, ?CostPerHour_kWh)
%
% Basé sur kb_rooms.pl : room(ID, Building, Capacity, Equipment)
%   base fixe  = 3 kWh  (éclairage, prises)
%   projector  = +2 kWh
%   computers  = +8 kWh
%   lab_bench  = +3 kWh
%   whiteboard =  0 kWh  (passif)
%   grande salle (cap >= 45) = +1 kWh
% ============================================================

room_energy_cost(r101, 5).   % b_main,  cap=40 : base(3) + projector(2)
room_energy_cost(r102, 5).   % b_main,  cap=35 : base(3) + projector(2)
room_energy_cost(r103, 3).   % b_main,  cap=30 : base(3)
room_energy_cost(r201, 13).  % b_tech,  cap=25 : base(3) + projector(2) + computers(8)
room_energy_cost(r202, 13).  % b_tech,  cap=20 : base(3) + projector(2) + computers(8)
room_energy_cost(r203, 14).  % b_tech,  cap=15 : base(3) + computers(8) + lab_bench(3)
room_energy_cost(r301, 7).   % b_annex, cap=50 : base(3) + projector(2) + grande(1) + grande_extra(1)
room_energy_cost(r302, 7).   % b_annex, cap=45 : base(3) + projector(2) + whiteboard(0) + grande(1) + grande_extra(1)

% ============================================================
% daily_building_limit(+BuildingID, ?MaxKWh)
%
% Basé sur kb_buildings.pl : building(ID, Name, EnergyFactor, Floors)
%   b_main  : factor=1.0, salles r101+r102+r103, 8 slots/jour max → ~104 kWh max théorique * 1.0
%   b_tech  : factor=1.5, salles r201+r202+r203, consommatrices   → limite haute
%   b_annex : factor=0.8, salles r301+r302, grandes salles légères → limite réduite
% ============================================================

daily_building_limit(b_main,  80).
daily_building_limit(b_tech,  120).
daily_building_limit(b_annex, 70).

% ============================================================
% slot_duration(+SlotID, ?Hours)
%
% Basé sur kb_timeslots.pl : time_slot(ID, Day, StartH, EndH)
% Tous les créneaux font EndH - StartH = 1 heure (8->9, 9->10, etc.)
% ============================================================

slot_duration(s1,  1).
slot_duration(s2,  1).
slot_duration(s3,  1).
slot_duration(s4,  1).
slot_duration(s5,  1).
slot_duration(s6,  1).
slot_duration(s7,  1).
slot_duration(s8,  1).
slot_duration(s9,  1).
slot_duration(s10, 1).
slot_duration(s11, 1).
slot_duration(s12, 1).
slot_duration(s13, 1).
slot_duration(s14, 1).
slot_duration(s15, 1).
slot_duration(s16, 1).
slot_duration(s17, 1).
slot_duration(s18, 1).
slot_duration(s19, 1).
slot_duration(s20, 1).
slot_duration(s21, 1).
slot_duration(s22, 1).
slot_duration(s23, 1).
slot_duration(s24, 1).
slot_duration(s25, 1).
slot_duration(s26, 1).
slot_duration(s27, 1).
slot_duration(s28, 1).
slot_duration(s29, 1).
slot_duration(s30, 1).
slot_duration(s31, 1).
slot_duration(s32, 1).
slot_duration(s33, 1).
slot_duration(s34, 1).
slot_duration(s35, 1).
slot_duration(s36, 1).
slot_duration(s37, 1).
slot_duration(s38, 1).
slot_duration(s39, 1).
slot_duration(s40, 1).