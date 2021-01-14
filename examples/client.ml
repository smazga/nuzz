let server = ref "localhost"
let user = ref "nobody"
let aname = ref "/"

let () =
  Arg.parse [("-s", Arg.Set_string server, "server");
             ("-u", Arg.Set_string user, "user");
             ("-a", Arg.Set_string aname, "aname")] print_endline "./client -s <host><!port> -u fred [-a <aname>]";
  (* try *)
  print_endline "v5";
  let conn = Nuzz.connect !server in
  let _ = Nuzz.attach conn ~user:!user !aname in
  print_endline "connected!"
  (* with _ ->
   *   failwith ("failed to connect to " ^ !server) *)
