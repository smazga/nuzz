let getns () =
  let user = (Unix.getpwuid (Unix.getuid ())).pw_name in (* getlogin() returns 'root' *)
  let disp = Unix.getenv "DISPLAY" in
  let suffix = String.concat "_" (String.split_on_char '/' disp) in
  String.concat "." ["/tmp/ns"; user; suffix]

let dial () =
  let fd = Comms.connect (getns() ^ "/factotum") in
  "dial: " ^ Comms.receive fd
