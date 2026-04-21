:- module(kb_groups, [group/4]).

group(g1, 'GL3-Group1', 32, [gl3_algo, gl3_db, gl3_os, gl3_net, gl3_se, gl3_math]).
group(g2, 'GL3-Group2', 28, [gl3_algo, gl3_db, gl3_os, gl3_net, gl3_ai, gl3_sec]).
group(g3, 'GL3-Group3', 35, [gl3_algo, gl3_db, gl3_math, gl3_ai, gl3_se]).
group(g4, 'GL3-Group4', 22, [gl3_algo, gl3_os, gl3_sec, gl3_net, gl3_math]).

