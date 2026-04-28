:- module(test_energy, [run_energy_tests/0]).

:- use_module(knowledge_base/kb_helpers).
:- use_module(knowledge_base/kb_rooms).
:- use_module(knowledge_base/kb_timeslots).
:- use_module(energy/energy_facts).
:- use_module(energy/energy_model).


% ============================================================
% run_energy_tests/0
% Lance tous les tests. Appeler avec : ?- run_energy_tests.
% ============================================================

run_energy_tests :-
    write('========================================'), nl,
    write('   ENERGY MODEL TESTS'), nl,
    write('========================================'), nl,
    test_session_energy,
    test_daily_building_energy,
    test_update_energy_state,
    test_enforce_limits_pass,
    test_enforce_limits_fail,
    write('========================================'), nl,
    write('   ALL TESTS PASSED'), nl,
    write('========================================'), nl.


% ============================================================
% TEST 1 : session_energy/3
% ============================================================

test_session_energy :-
    write('[TEST 1] session_energy/3'), nl,

    % r103 (whiteboard seul) + s1 (1h) = 3 kWh
    session_energy(r103, s1, E1),
    assertion(E1 =:= 3, 'r103 s1 should be 3 kWh'),

    % r101 (projector+whiteboard) + s2 (1h) = 5 kWh
    session_energy(r101, s2, E2),
    assertion(E2 =:= 5, 'r101 s2 should be 5 kWh'),

    % r201 (projector+computers+whiteboard) + s1 (1h) = 13 kWh
    session_energy(r201, s1, E3),
    assertion(E3 =:= 13, 'r201 s1 should be 13 kWh'),

    % r203 (computers+lab_bench) + s5 (1h) = 14 kWh
    session_energy(r203, s5, E4),
    assertion(E4 =:= 14, 'r203 s5 should be 14 kWh'),

    write('  PASS: session_energy'), nl.


% ============================================================
% TEST 2 : daily_building_energy/4
% ============================================================

test_daily_building_energy :-
    write('[TEST 2] daily_building_energy/4'), nl,

    % Schedule avec 2 sessions dans b_main le lundi
    % r101(s1) + r102(s2) = 5 + 5 = 10 kWh
    Schedule1 = [
        session(c1, r101, s1, g1),   % b_main, monday
        session(c2, r102, s2, g2),   % b_main, monday
        session(c3, r201, s1, g3)    % b_tech,  monday — ne doit PAS compter
    ],
    daily_building_energy(b_main, monday, Schedule1, E1),
    assertion(E1 =:= 10, 'b_main monday should be 10 kWh'),

    % b_tech dans ce même schedule = 13 kWh (r201 s1)
    daily_building_energy(b_tech, monday, Schedule1, E2),
    assertion(E2 =:= 13, 'b_tech monday should be 13 kWh'),

    % Aucune salle b_annex → 0 kWh
    daily_building_energy(b_annex, monday, Schedule1, E3),
    assertion(E3 =:= 0, 'b_annex monday should be 0 kWh'),

    write('  PASS: daily_building_energy'), nl.


% ============================================================
% TEST 3 : update_energy_state/4
% ============================================================

test_update_energy_state :-
    write('[TEST 3] update_energy_state/4'), nl,

    % Départ : état vide
    init_energy_state(S0),

    % Ajout d'une session r201 s1 (b_tech, monday, 13 kWh)
    update_energy_state(S0, r201, s1, S1),
    memberchk(energy(b_tech, monday, 13), S1),

    % Ajout d'une autre session r202 s2 (b_tech, monday, 13 kWh)
    update_energy_state(S1, r202, s2, S2),
    memberchk(energy(b_tech, monday, 26), S2),

    % Ajout d'une session r101 s1 (b_main, monday, 5 kWh)
    update_energy_state(S2, r101, s1, S3),
    memberchk(energy(b_main, monday, 5), S3),
    memberchk(energy(b_tech, monday, 26), S3),  % b_tech inchangé

    write('  PASS: update_energy_state'), nl.


% ============================================================
% TEST 4 : enforce_daily_limits/1 — Schedule valide
% ============================================================

test_enforce_limits_pass :-
    write('[TEST 4] enforce_daily_limits — schedule valide'), nl,

    % 2 sessions b_tech lundi : 13 + 13 = 26 kWh < 120 limite
    Schedule = [
        session(c1, r201, s1, g1),
        session(c2, r202, s2, g2)
    ],
    (   enforce_daily_limits(Schedule)
    ->  write('  PASS: limites respectées'), nl
    ;   write('  FAIL: devrait passer mais a échoué'), nl, fail
    ).


% ============================================================
% TEST 5 : enforce_daily_limits/1 — Schedule qui dépasse la limite
% ============================================================

test_enforce_limits_fail :-
    write('[TEST 5] enforce_daily_limits — dépassement de limite'), nl,

    % b_tech limite = 120 kWh
    % r201(13) * 8 slots lundi = 104, + r202(13) = 117, + r203(14) = 131 > 120
    Schedule = [
        session(c1,  r201, s1,  g1),
        session(c2,  r201, s2,  g1),
        session(c3,  r201, s3,  g1),
        session(c4,  r201, s4,  g1),
        session(c5,  r202, s5,  g2),
        session(c6,  r202, s6,  g2),
        session(c7,  r202, s7,  g2),
        session(c8,  r202, s8,  g2),
        session(c9,  r203, s1,  g3),
        session(c10, r203, s2,  g3)
    ],
    (   enforce_daily_limits(Schedule)
    ->  write('  FAIL: aurait dû échouer (limite dépassée)'), nl, fail
    ;   write('  PASS: limite dépassée détectée correctement'), nl
    ).


% ============================================================
% assertion/2 — utilitaire interne
% ============================================================

assertion(Goal, _Msg) :-
    Goal, !.
assertion(_Goal, Msg) :-
    format("  FAIL: ~w~n", [Msg]),
    fail.