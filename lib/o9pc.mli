(******************************************************************************)
(* OCaml-9P                                                                  *)
(*                                                                            *)
(* Copyright 2007 Oscar Hellstr�m, oscar at oscarh dot net.                   *)
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
(**

9P Library Client interface.
{{:http://v9fs.sourceforge.net/rfc/} http://v9fs.sourceforge.net/rfc/}

Primarily written to be used with {{:http://www.suckless.org/wmii} WMII}.

*)

(** The type of an 9P connection &c. *)
type t
type fid
type io

(** Error in the underlying socket communication *)
exception Socket_error of string

(** Remote Client_error *)
exception Client_error of string

(** {2 File Modes} *)

type filemode = private int

val oREAD : filemode
val oWRITE : filemode
val oRDWR : filemode
val oEXEC : filemode
val oEXCL : filemode
val oTRUNC : filemode
val oREXEC : filemode
val oRCLOSE : filemode
val oAPPEND : filemode

val combine_mode: filemode -> filemode -> filemode


type modebit = private int32

(** Mode bit for directories *)
val dMDIR : modebit

(** Mode bit for append only files *)
val  dMAPPEND : modebit

(** Mode bit for exclusive use files *)
val  dMEXCL : modebit

(** Mode bit for mounted channel *)
val  dMMOUNT : modebit

(** Mode bit for authentication file *)
val  dMAUTH : modebit

(** Mode bit for non-backed-up file *)
val  dMTMP : modebit

(** Mode bit for read permission *)
val  dMREAD : modebit

(** Mode bit for write permission *)
val  dMWRITE : modebit

(** Mode bit for execute permission *)
val  dMEXEC : modebit


(** {2 9P client interface functions} *)

(**
[connect sockaddr] connects to the Unix socket [sockaddr]. Returns a
connection.
*)
val connect : string -> t

(** 
[attach conn user address] attaches the connection [conn] to [address] and
returns the [fid] for that file.
It is common to attach to [/]. Returns a fid for the attached address.
[user] defaults to [Sys.getenv "USER"].
*)
val attach : t -> ?user:string -> string -> fid

(**
[walk conn oldfid reuse file] walks from [oldfid] to the [file]. [file] must be
a file-name relative to the file represented by [oldfid]. If [reuse] is [Some ()],
the old [fid] will represent the new file. Returns the fid, [oldfid] if [reuse]
was [Some ()] and a new fid if [reuse] was [None] (default).
*)
val walk : t -> fid -> ?reuse:unit -> string -> fid

(**
[fopen conn fid mode] [mode] is one of the File Modes. Returns an [iounit].
*)
val fopen : t -> fid -> filemode -> io

(**
[clunk conn fid] forgets about the [fid]. The [fid] may not be used to access
the file it did represent.
*)
val clunk : t -> fid -> unit

(**
[stat conn fid] returns [stat] results for the file/dir represented by [fid].
*)
val stat : t -> fid -> Fcall.stat

(**
[read conn fid iounit offset count] reads [count] bytes from [offset] in the
file represented by [fid].
[offset] defaults to [0L].
*)
val read : t -> fid -> io -> ?offset:int64 -> int32 -> string

(**
[write conn fid iounit offset count data] writes [count] bytes of [data] at
[offset] to the file represented by [fid]. Returns the amount of bytes actually
written.
[offset] defaults to [0L].
[count] defaults to [Int32.of_int (String.length data)].
*)
val write : t -> fid -> io -> ?offset:int64 -> ?count:int32 -> string -> int32

(**
[create conn fid name perm mode] creates a file [name] in the directory
represented by [fid]. The file will have permissions according to [perm] and
will be opened according to [mode]. Returns an [iounit].
*)
val create : t -> fid -> filename:string -> perm:int32 -> mode:filemode -> int32

(**
[remove conn fid] removes the file represented by fid.
*)
val remove : t -> fid -> unit

(** {2 Misc helper functions} *)

(**
[unpack_files data] takes data from a directory read and transforms it to a list
of stat structures.
*)
val unpack_files : string -> Fcall.stat list
