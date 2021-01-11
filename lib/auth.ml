open Fcall
open Comms

let query_auth fd uname aname =
  let tauth = new tAuth uname aname in
  print_endline ("sending Tauth");
  send fd tauth#serialize ;
  let rauth = new rAuth tauth#tag tauth#afid in
  deserialize rauth (receive fd) ;
  print_endline ("received Rauth");
  print_endline (" qid:" ^ rauth#aqid#to_string);
  print_endline (" afid:" ^ Int32.to_string rauth#afid);
  rauth

let handle_auth fd uname aname =
  let rauth = query_auth fd uname aname in
  if rauth#aqid#qtype = Qtauth
  then (print_endline "NEED TO AUTHENTICATE";
        (* let read fd fid _ ?(offset = 0L) count = *)
        let foo = read fd rauth#afid None ~offset:(Int64.of_int 0) (Int32.of_int 2048) in
        print_endline ("XXXXX:" ^ foo));
