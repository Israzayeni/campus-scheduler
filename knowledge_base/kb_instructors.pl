 :- module(kb_instructors, [instructor/3, available/2]).

instructor(prof_ali,   'Dr. Ali Ben Salem',   [gl3_algo, gl3_math]).
instructor(prof_sana,  'Dr. Sana Mansour',    [gl3_db, gl3_ai]).
instructor(prof_karim, 'Dr. Karim Trabelsi',  [gl3_os, gl3_net]).
instructor(prof_rania, 'Dr. Rania Chaabane',  [gl3_se, gl3_sec]).

% Availability: list every slot the instructor CAN teach
% Prof Ali is available Mon-Wed morning + Tue afternoon
available(prof_ali, s1).  available(prof_ali, s2).
available(prof_ali, s3).  available(prof_ali, s4).
available(prof_ali, s9).  available(prof_ali, s10).
available(prof_ali, s13). available(prof_ali, s14).

available(prof_sana, s5).  available(prof_sana, s6).
available(prof_sana, s11). available(prof_sana, s12).
available(prof_sana, s15). available(prof_sana, s16).

