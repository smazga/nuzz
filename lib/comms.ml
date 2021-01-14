open Fcall

exception Socket_error of string
exception Client_error of string

let msize = ref 8192

let deserialize obj package =
  try obj#deserialize package
  with Fcall.Illegal_package_type 107 ->
    let error = new rError obj#tag "" in
    error#deserialize package ; raise (Client_error error#message)

let send sockfd data =
  try
    let data_len = String.length data in
    let sent_len = Unix.send sockfd (Bytes.of_string data) 0 data_len [] in
    if data_len != sent_len then raise (Socket_error "Sent 0 bytes")
  with Unix.Unix_error (num, "send", _) -> raise (Socket_error (Unix.error_message num))

let receive sockfd =
  try
    let buff = Bytes.create !msize in
    let recv = Unix.recv sockfd buff in
    let rlen = recv 0 4 [] in
    if rlen = 0 then raise (Socket_error "Socket closed cleanly") ;
    let plen = Int32.to_int (Fcall.d_int32 (Bytes.to_string buff) 0) in
    let rlen = recv 4 plen [] in
    if rlen = 0 then raise (Socket_error "Socket closed cleanly") else String.sub (Bytes.to_string buff) 0 plen
  with Unix.Unix_error (num, "recv", _) -> raise (Socket_error (Unix.error_message num))

(* Low level function *)
let read fd fid _ ?(offset = 0L) count =
  let tread = new tRead fid offset count in
  send fd tread#serialize ;
  let rread = new rRead tread#tag "" in
  deserialize rread (receive fd) ;
  rread#data

(* Low level function *)
let write fd fid iounit ?(offset = 0L) ?count data =
  let count =
    match count with
    | None -> Int32.of_int (String.length data)
    | Some c -> c in
  let rec write offset count data =
    let i32write_len = if iounit > count then count else iounit in
    let write_len = Int32.to_int i32write_len in
    let i64write_len = Int64.of_int write_len in
    let d = String.sub data 0 write_len in
    let twrite = new tWrite fid offset i32write_len d in
    send fd twrite#serialize ;
    let rwrite = new rWrite twrite#tag Int32.zero in
    deserialize rwrite (receive fd) ;
    ( if not (rwrite#count = i32write_len) then
      let swrite_len = string_of_int write_len in
      let msg = "Failed to write " ^ swrite_len ^ " bytes, " ^ "wrote " ^ Int32.to_string rwrite#count in
      raise (Client_error msg) ) ;
    let i_64_count = Int64.of_int32 count in
    if Int64.add offset i64write_len < i_64_count then
      let new_offset = Int64.add offset i64write_len in
      let new_count = Int32.sub count i32write_len in
      let rest = String.sub data write_len (Int32.to_int new_count) in
      write new_offset new_count rest in
  write offset count data ; count

(* FIXME Should we keep track of how much we have written? *)

let serveraddr address =
  let parts = String.split_on_char '!' address in
  let port = if List.length parts = 1 then 564 else int_of_string (List.nth parts 1) in
  ((Unix.gethostbyname (List.nth parts 0)).Unix.h_addr_list.(0), port)

let connect address =
  print_endline ("connect:" ^ address);
  let sockaddr =
    try
      let addr, port = serveraddr address in
      Unix.ADDR_INET (addr, port)
    with Not_found -> Unix.ADDR_UNIX address
  in
  let fd = Unix.socket (Unix.domain_of_sockaddr sockaddr) Unix.SOCK_STREAM 0 in
  Unix.connect fd sockaddr; fd
