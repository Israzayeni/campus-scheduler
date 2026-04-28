:- module(energy_model, [
    session_energy/3,
    daily_building_energy/4,
    init_energy_state/1,
    update_energy_state/4,
    check_daily_limit/1,
    enforce_daily_limits/1,
    build_energy_state/3
]).

:- use_module(knowledge_base/kb_helpers).    % room_building/2, slot_day/2
:- use_module(knowledge_base/kb_rooms).      % room/4
:- use_module(knowledge_base/kb_timeslots).  % time_slot/4
:- use_module(energy/energy_facts).          % room_energy_cost/2, slot_duration/2, daily_building_limit/2


% ============================================================
% session_energy(+RoomID, +SlotID, -EnergyCost)
%
% Calcule le coût énergétique (kWh) d'une session.
% Formule : coût_horaire(salle) × durée(créneau)
%
% Exemple :
%   ?- session_energy(r201, s3, E).
%   E = 13.
%
%   ?- session_energy(r103, s1, E).
%   E = 3.
% ============================================================

session_energy(RoomID, SlotID, Energy) :-
    room_energy_cost(RoomID, CostPerHour),
    slot_duration(SlotID, Duration),
    Energy is CostPerHour * Duration.


% ============================================================
% daily_building_energy(+BuildingID, +Day, +Schedule, -TotalEnergy)
%
% Calcule l'énergie totale (kWh) consommée par un bâtiment
% pour un jour donné, d'après un Schedule complet.
%
% Schedule = liste de session(CourseID, RoomID, SlotID, GroupID)
%
% Utilise room_building/2 de kb_helpers (qui appelle kb_rooms)
% et slot_day/2 de kb_helpers (qui appelle kb_timeslots).
%
% Exemple :
%   ?- Schedule = [session(c1, r101, s1, g1), session(c2, r201, s1, g2)],
%      daily_building_energy(b_main, monday, Schedule, E).
%   E = 5.   % seulement r101 est dans b_main
% ============================================================

daily_building_energy(BuildingID, Day, Schedule, TotalEnergy) :-
    findall(E,
        (   member(session(_, RoomID, SlotID, _), Schedule),
            room_building(RoomID, BuildingID),
            slot_day(SlotID, Day),
            session_energy(RoomID, SlotID, E)
        ),
        Energies),
    sumlist(Energies, TotalEnergy).


% ============================================================
% ENERGY STATE
%
% Représentation : liste de termes energy(BuildingID, Day, AccKWh)
% Exemple : [energy(b_main, monday, 18), energy(b_tech, monday, 26)]
%
% Conçu pour fonctionner avec le backtracking de P3 :
% chaque update_energy_state produit un nouvel état sans détruire l'ancien.
% ============================================================

% init_energy_state(-State)
% Crée un état vide.
init_energy_state([]).


% update_energy_state(+OldState, +RoomID, +SlotID, -NewState)
%
% Ajoute l'énergie d'une session à l'état courant.
% Crée une nouvelle entrée si (BuildingID, Day) n'existe pas encore,
% sinon incrémente l'existante.
%
% Exemple :
%   ?- update_energy_state([], r201, s1, S).
%   S = [energy(b_tech, monday, 13)].
%
%   ?- update_energy_state([energy(b_tech, monday, 13)], r202, s2, S).
%   S = [energy(b_tech, monday, 26)].

update_energy_state(OldState, RoomID, SlotID, NewState) :-
    room_building(RoomID, BuildingID),
    slot_day(SlotID, Day),
    session_energy(RoomID, SlotID, Energy),
    update_entry(OldState, BuildingID, Day, Energy, NewState).

% Cas : entrée (BuildingID, Day) introuvable → on la crée
update_entry([], BuildingID, Day, Energy,
             [energy(BuildingID, Day, Energy)]).

% Cas : entrée (BuildingID, Day) trouvée → on accumule
update_entry([energy(BuildingID, Day, Acc) | Rest],
             BuildingID, Day, Energy,
             [energy(BuildingID, Day, NewAcc) | Rest]) :-
    !,
    NewAcc is Acc + Energy.

% Cas : entrée différente → on continue
update_entry([H | T], BuildingID, Day, Energy, [H | NewT]) :-
    update_entry(T, BuildingID, Day, Energy, NewT).


% ============================================================
% check_daily_limit(+EnergyState)
%
% Vérifie que chaque entrée de l'état respecte la limite journalière.
% Échoue (fail) dès qu'une limite est dépassée et affiche un message.
%
% Exemple :
%   ?- check_daily_limit([energy(b_tech, monday, 130)]).
%   WARNING: b_tech on monday: 130 kWh > limit 120 kWh
%   false.
% ============================================================

check_daily_limit([]).
check_daily_limit([energy(BuildingID, Day, Acc) | Rest]) :-
    daily_building_limit(BuildingID, Limit),
    (   Acc =< Limit
    ->  true
    ;   format("WARNING: ~w on ~w: ~w kWh > limit ~w kWh~n",
               [BuildingID, Day, Acc, Limit]),
        fail
    ),
    check_daily_limit(Rest).


% ============================================================
% build_energy_state(+Schedule, +InitState, -FinalState)
%
% Construit l'état énergétique complet à partir d'un Schedule.
% Utilisé en interne par enforce_daily_limits/1.
% ============================================================

build_energy_state([], State, State).
build_energy_state([session(_, RoomID, SlotID, _) | Rest], State, Final) :-
    update_energy_state(State, RoomID, SlotID, NewState),
    build_energy_state(Rest, NewState, Final).


% ============================================================
% enforce_daily_limits(+Schedule)
%
% Prédicat principal appelé par P3 après génération d'un Schedule.
% Réussit si toutes les limites journalières sont respectées.
% Échoue dès qu'un bâtiment dépasse sa limite un jour donné.
%
% Interface pour P3 :
%   Appeler enforce_daily_limits(Schedule) comme contrainte globale.
%   Si fail → backtrack et essayer un autre Schedule.
%
% Exemple :
%   ?- enforce_daily_limits([session(c1,r201,s1,g1),
%                            session(c2,r202,s2,g2)]).
%   true.   % 13 + 13 = 26 kWh < 120 kWh limite b_tech
% ============================================================

enforce_daily_limits(Schedule) :-
    init_energy_state(InitState),
    build_energy_state(Schedule, InitState, FinalState),
    check_daily_limit(FinalState).