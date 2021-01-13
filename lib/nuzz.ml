(******************************************************************************)
(* OCaml-9P                                                                  *)
(*                                                                            *)
(* Copyright 2007 Oscar Hellström, oscar at oscarh dot net.                   *)
(* Copyright 2014 Raphaël Proust.                                             *)
(* All rights reserved                                                        *)
(* Redistribution and use in source and binary forms, with or without         *)
(* modification, are permitted provided that the following conditions are     *)
(* met:                                                                       *)
(*                                                                            *)
(*     * Redistributions of source code must retain the above copyright       *)
(*       notice, this list of conditions and the following disclaimer.        *)
(*     * Redistributions in binary form must reproduce the above copyright    *)
(*       notice, this list of conditions and the following disclaimer in the  *)
(*       documentation and/or other materials provided with the distribution. *)
(*     * The names of its contributors may not be used to endorse or promote  *)
(*       products derived from this software without specific prior written   *)
(*       permission.                                                          *)
(*                                                                            *)
(*                                                                            *)
(* THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND    *)
(* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE      *)
(* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE *)
(* ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE    *)
(* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL *)
(* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR *)
(* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER *)
(* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT         *)
(* LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY  *)
(* OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF     *)
(* SUCH DAMAGE.                                                               *)
(******************************************************************************)

(*
 * 9P Library Client interface.
 * http://v9fs.sourceforge.net/rfc/
 *
 * Primarily written to be used with WMII.
 * http://www.suckless.org/wmii
 *)

open Fcall
open Comms

type t = Unix.file_descr
type fid = int32
type io = int32

(* File modes *)
type filemode = int

let oREAD = 0x00
let oWRITE = 0x01
let oRDWR = 0x02
let oEXEC = 0x03
let oEXCL = 0x04
let oTRUNC = 0x10
let oREXEC = 0x20
let oRCLOSE = 0x40
let oAPPEND = 0x80
let combine_mode = ( lor )

type modebit = int32

(* Mode bits for files / dirs *)
let dMDIR = Int32.shift_left Int32.one 31
let dMAPPEND = Int32.shift_left Int32.one 30
let dMEXCL = Int32.shift_left Int32.one 29
let dMMOUNT = Int32.shift_left Int32.one 28
let dMAUTH = Int32.shift_left Int32.one 27
let dMTMP = Int32.shift_left Int32.one 26
let dMREAD = Int32.shift_left (Int32.of_int 0x4) 6
let dMWRITE = Int32.shift_left (Int32.of_int 0x2) 6
let dMEXEC = Int32.shift_left (Int32.of_int 0x1) 6
let delimiter_exp = Str.regexp "/"

let fopen fd fid mode =
  let topen = new tOpen fid mode in
  send fd topen#serialize ;
  let ropen = new rOpen topen#tag Int32.zero in
  deserialize ropen (receive fd) ;
  ropen#iounit

let version fd =
  let tversion = new tVersion (Int32.of_int !msize) in
  send fd tversion#serialize ;
  let rversion = new rVersion Int32.zero in
  deserialize rversion (receive fd) ;
  msize := Int32.to_int rversion#msize

let walk fd oldfid ?reuse filename =
  let reuse =
    match reuse with
    | None -> false
    | Some () -> true in
  let wname = Str.split delimiter_exp filename in
  let twalk = new tWalk oldfid reuse wname in
  send fd twalk#serialize ;
  let rwalk = new rWalk twalk#tag 0 in
  deserialize rwalk (receive fd) ;
  twalk#newfid

let clunk fd fid =
  let tclunk = new tClunk fid in
  send fd tclunk#serialize ;
  let rclunk = new rClunk tclunk#tag in
  deserialize rclunk (receive fd)

let remove fd fid =
  let tremove = new tRemove fid in
  send fd tremove#serialize ;
  let rremove = new rRemove tremove#tag in
  deserialize rremove (receive fd)

let create fd fid ~filename ~perm ~mode =
  let tcreate = new tCreate fid filename perm mode in
  send fd tcreate#serialize ;
  let rcreate = new rCreate tcreate#tag Int32.zero in
  deserialize rcreate (receive fd) ;
  rcreate#iounit

let stat fd fid =
  let tstat = new tStat fid in
  send fd tstat#serialize ;
  let rstat = new rStat tstat#tag None in
  deserialize rstat (receive fd) ;
  rstat#stat

let attach fd ?user aname =
  let user =
    match user with
    | Some u -> u
    | None -> Sys.getenv "USER" in
  Auth.handle_auth fd user aname ;
  let tattach = new tAttach None user aname in
  send fd tattach#serialize ;
  let rattach = new rAttach tattach#tag in
  deserialize rattach (receive fd) ;
  tattach#fid

let serveraddr address =
  let parts = String.split_on_char '!' address in
  let port = if List.length parts = 1 then 564 else int_of_string (List.nth parts 1) in
  ((Unix.gethostbyname (List.nth parts 0)).Unix.h_addr_list.(0), port)

let connect address =
  let sockaddr =
    if Sys.file_exists address then Unix.ADDR_UNIX address
    else
      let addr, port = serveraddr address in
      Unix.ADDR_INET (addr, port) in
  let fd = Unix.socket (Unix.domain_of_sockaddr sockaddr) Unix.SOCK_STREAM 0 in
  Unix.connect fd sockaddr ; version fd ; fd

let unpack_files data =
  try
    let rec unpack_files data acc =
      let record = Fcall.d_stat data 0 in
      let stat_len = Fcall.d_int16 data 0 + 2 in
      if stat_len < String.length data then
        let rest_len = String.length data - stat_len in
        let rest = String.sub data stat_len rest_len in
        unpack_files rest (record :: acc)
      else List.rev (record :: acc) in
    if String.length data > 0 then unpack_files data [] else []
  with _ -> raise (Client_error "invalid package, expected directory read")
