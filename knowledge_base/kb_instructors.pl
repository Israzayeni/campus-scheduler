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

% Prof Karim available Mon-Tue afternoon + Wed morning
available(prof_karim, s5).  available(prof_karim, s6).
available(prof_karim, s7).  available(prof_karim, s8).
available(prof_karim, s13). available(prof_karim, s14).
available(prof_karim, s17). available(prof_karim, s18).
available(prof_karim, s19). available(prof_karim, s20).

% Prof Rania available Wed afternoon + Thu-Fri
available(prof_rania, s21). available(prof_rania, s22).
available(prof_rania, s23). available(prof_rania, s24).
available(prof_rania, s25). available(prof_rania, s26).
available(prof_rania, s27). available(prof_rania, s28).
available(prof_rania, s29). available(prof_rania, s30).
available(prof_rania, s31). available(prof_rania, s32).
available(prof_rania, s33). available(prof_rania, s34).
available(prof_rania, s35). available(prof_rania, s36).
available(prof_rania, s37). available(prof_rania, s38).
available(prof_rania, s39). available(prof_rania, s40).

