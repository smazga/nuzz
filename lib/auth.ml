open Fcall
open Comms

type ticketreq =
  { ttype: char
  ; authid: string
  ; (* 28 chars *)
    authdom: string
  ; (* 48 chars *)
    challenge: string
  ; (* 8 chars *)
    hostid: string
  ; (* 28 chars *)
    uid: string (* 28 chars *) }

let getns () =
  let user = Unix.getlogin () in
  let disp = Unix.getenv "DISPLAY" in
  String.concat "." (["/tmp/ns"; user] @ List.tl (String.split_on_char '/' disp))

let factotum () =
  let ic = open_in (getns() ^ "/factotum/ctl") in
  input_line ic

let query_auth fd uname aname =
  let tauth = new tAuth uname aname in
  print_endline "Tauth ->" ;
  send fd tauth#serialize ;
  let rauth = new rAuth tauth#tag tauth#afid in
  deserialize rauth (receive fd) ;
  print_endline "-> Rauth" ;
  print_endline (" qid:" ^ rauth#aqid#to_string) ;
  rauth

let parse protocols =
  let names = String.split_on_char ' ' protocols in
  let authtuples =
    List.map
      (fun x ->
        let p = String.split_on_char '@' x in
        (List.nth p 0, List.nth p 1) )
      names in
  List.iter (fun (proto, domain) -> print_endline ("(" ^ proto ^ ", " ^ domain ^ ")")) authtuples ;
  authtuples

let convm2tr msg =
  if String.length msg < 141 then raise (Failure ("short p9sk1 ticketreq: " ^ string_of_int (String.length msg))) ;
  let offset = ref 0 in
  let ttype = msg.[!offset] in
  let authid = String.sub msg !offset 28 in
  offset += 28 ;
  let authdom = String.sub msg !offset 48 in
  offset += 28 ;
  let challenge = String.sub msg !offset 8 in
  offset += 8 ;
  let hostid = String.sub msg !offset 28 in
  offset += 28 ;
  let uid = String.sub msg !offset 28 in
  print_endline ("authid: " ^ authid) ;
  print_endline ("authdom: " ^ authdom) ;
  print_endline ("challenge: " ^ challenge) ;
  print_endline ("hostid: " ^ hostid) ;
  print_endline ("uid: " ^ uid) ;
  {ttype; authid; authdom; challenge; hostid; uid}

let getkey (req : ticketreq) proto =
  let key = "key proto=" ^ proto ^ " dom=" ^ req.authdom ^ " user=" ^ req.authid ^ " !password=" in
  print_endline ("key: " ^ key)

let p9sk1 fd rauth auth =
  let proto, dom = auth in
  let msg = proto ^ " " ^ dom in
  ignore
    (write fd rauth#afid
       (Int32.of_int (String.length msg))
       ~offset:(Int64.of_int 0)
       ~count:(Int32.of_int (String.length msg))
       msg ) ;
  let challenge = s_int64 (Random.int64 (Int64.of_int 0xffffffff)) in
  ignore
    (write fd rauth#afid (Int32.of_int 2048) ~offset:(Int64.of_int 0)
       ~count:(Int32.of_int (String.length challenge))
       challenge ) ;
  let treq = convm2tr (read fd rauth#afid None ~offset:(Int64.of_int 0) (Int32.of_int 2048)) in
  getkey treq "p9sk1"

let handle_auth fd uname aname =
  Random.self_init () ;
  let rauth = query_auth fd uname aname in
  if rauth#aqid#qtype = Qtauth then (
    print_endline "NEED TO AUTHENTICATE" ;
    let authtuples = parse (read fd rauth#afid None ~offset:(Int64.of_int 0) (Int32.of_int 2048)) in
    p9sk1 fd rauth (List.hd authtuples) ;
    print_endline ("factotum: " ^ factotum ()) )
