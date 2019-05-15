open Core
module Netkat = Frenetic.Netkat
module Fdd = Netkat.Fdd.FDD
module Automaton = Netkat.Global_compiler.Automaton

(*===========================================================================*)
(* UTILITY FUNCTIONS                                                         *)
(*===========================================================================*)

let parse_pol ?(json=false) (policy : [`File of string | `String of string]) =
  match json, policy with
  | false, `String s -> Netkat.Parser.pol_of_string s
  | false, `File file -> Netkat.Parser.pol_of_file file
  | true, `String s -> Netkat.Json.pol_of_json_string s
  | true, `File file ->
    In_channel.create file
    |> Netkat.Json.pol_of_json_channel

let parse_pred file = Netkat.Parser.pred_of_file file

let fmt = Format.formatter_of_out_channel stdout
let _ = Format.pp_set_margin fmt 120

let print_fdd fdd =
  printf "%s\n" (Netkat.Local_compiler.to_string fdd)

let dump data ~file =
  Out_channel.write_all file ~data

let dump_local fdd ~file =
  Netkat.Local_compiler.to_local_pol fdd
  |> Netkat.Pretty.string_of_policy
  |> dump ~file

let dump_pol pol ~file =
  Netkat.Pretty.string_of_policy pol
  |> dump ~file

let dump_fdd fdd ~file =
  dump ~file (Netkat.Local_compiler.to_dot fdd)

let dump_auto auto ~file =
  dump ~file (Netkat.Global_compiler.Automaton.to_dot auto)

open Frenetic.Async
module Controller = NetKAT_Controller.Make(OpenFlow0x01_Plugin)

let update_controller ?(port=6633) fdd : unit =
  Controller.start port;
  Async_unix.Thread_safe.block_on_async_exn (fun () -> Controller.update_fdd fdd)

let print_table fdd sw =
  Netkat.Local_compiler.to_table sw fdd
  |> Frenetic.OpenFlow.string_of_flowTable ~label:(sprintf "Switch %Ld" sw)
  |> printf "%s\n"

let print_all_tables ?(no_tables=false) fdd switches =
  if not no_tables then List.iter switches ~f:(print_table fdd)

let time f =
  let t1 = Unix.gettimeofday () in
  let r = f () in
  let t2 = Unix.gettimeofday () in
  (t2 -. t1, r)

let print_time ?(prefix="") time =
  printf "%scompilation time: %.4f\n" prefix time

let print_order () =
  Netkat.Local_compiler.Field.(get_order ()
    |> List.map ~f:to_string
    |> String.concat ~sep:" > "
    |> printf "FDD field ordering: %s\n")


(*===========================================================================*)
(* FLAGS                                                                     *)
(*===========================================================================*)

module Flag = struct
  open Command.Spec

  let switches =
    flag "--switches" (optional int)
      ~doc:"n number of switches to dump flow tables for (assuming \
            switch-numbering 1,2,...,n)"

  let print_fdd =
    flag "--print-fdd" no_arg
      ~doc:" print an ASCI encoding of the intermediate representation (FDD) \
            generated by the local compiler"

  let dump_fdd =
    flag "--dump-fdd" no_arg
      ~doc:" dump a dot file encoding of the intermediate representation \
            (FDD) generated by the local compiler"

  let render_fdd =
    flag "--render-fdd" no_arg
      ~doc:" renders the intermediate representation \
            (FDD) generated by the local compiler.\
            Requires that graphviz is installed and on the PATH."

  let print_auto =
    flag "--print-auto" no_arg
      ~doc:" print an ASCI encoding of the intermediate representation \
            generated by the global compiler (symbolic NetKAT automaton)"

  let dump_auto =
    flag "--dump-auto" no_arg
      ~doc:" dump a dot file encoding of the intermediate representation \
            generated by the global compiler (symbolic NetKAT automaton)"

  let render_auto =
    flag "--render-auto" no_arg
      ~doc:" renders the intermediate representation \
            generated by the global compiler (symbolic NetKAT automaton).\
            Requires that graphviz is installed and on the PATH."

  let print_global_pol =
    flag "--print-global-pol" no_arg
      ~doc: " print global NetKAT policy generated by the virtual compiler"

  let no_tables =
    flag "--no-tables" no_arg
      ~doc: " Do not print tables."

  let json =
    flag "--json" no_arg
      ~doc: " Parse input file as JSON."

  let print_order =
    flag "--print-order" no_arg
      ~doc: " Print FDD field order used by the compiler."

  let vpol =
    flag "--vpol" (optional_with_default "vpol.dot" file)
      ~doc: "file Virtual policy. Must not contain links. \
             If not specified, defaults to vpol.dot"

  let vrel =
    flag "--vrel" (optional_with_default "vrel.kat" file)
      ~doc: "file Virtual-physical relation. If not specified, defaults to vrel.kat"

  let vtopo =
    flag "--vtopo" (optional_with_default "vtopo.kat" file)
      ~doc: "file Virtual topology. If not specified, defaults to vtopo.kat"

  let ving_pol =
    flag "--ving-pol" (optional_with_default "ving_pol.kat" file)
      ~doc: "file Virtual ingress policy. If not specified, defaults to ving_pol.kat"

  let ving =
    flag "--ving" (optional_with_default "ving.kat" file)
      ~doc: "file Virtual ingress predicate. If not specified, defaults to ving.kat"

  let veg =
    flag "--veg" (optional_with_default "veg.kat" file)
      ~doc: "file Virtual egress predicate. If not specified, defaults to veg.kat"

  let ptopo =
    flag "--ptopo" (optional_with_default "ptopo.kat" file)
      ~doc: "file Physical topology. If not specified, defaults to ptopo.kat"

  let ping =
    flag "--ping" (optional_with_default "ping.kat" file)
      ~doc: "file Physical ingress predicate. If not specified, defaults to ping.kat"

  let peg =
    flag "--peg" (optional_with_default "peg.kat" file)
      ~doc: "file Physical egress predicate. If not specified, defaults to peg.kat"

  let dump_local =
    flag "--dump-local" (optional file)
      ~doc: "file Translate compiler output to local program and dump it to file"

  let dump_global =
    flag "--dump-global" (optional file)
      ~doc: "file Translate compiler output to global program and dump it to file"

  let determinize =
    flag "--determinize" no_arg
      ~doc:"Determinize automaton."

  let minimize =
    flag "--minimize" no_arg
      ~doc:"Minimize automaton (heuristically)."

  let update_controller =
    flag "--update-controller" no_arg
      ~doc:"Push flow tables to OpenFlow controller"

  let remove_topo =
    flag "--remove-topo" no_arg
      ~doc:"Remove topology states from automaton. (Not equivalence preserving!)"

  let stdin =
    flag "--stdin" no_arg
      ~doc:"Read policy from stdin instead of from file."

  let containment =
    flag "--containment" no_arg
      ~doc:"Check that the second policy is contained in the first using bisimulation."
end


(*===========================================================================*)
(* COMMANDS: Local, Global, Virtual, Auto, Bisimulation                      *)
(*===========================================================================*)

module Local = struct
  let spec = Command.Spec.(
    empty
    +> anon ("file" %: file)
    +> Flag.switches
    +> Flag.print_fdd
    +> Flag.dump_fdd
    +> Flag.render_fdd
    +> Flag.no_tables
    +> Flag.json
    +> Flag.print_order
    +> Flag.update_controller
    +> Flag.stdin
  )

  let run file_or_pol nr_switches printfdd dumpfdd renderfdd no_tables json
    printorder updatecontroller stdin () =
    let pol =
      parse_pol ~json (if stdin then `String file_or_pol else `File file_or_pol) in
    let (t, fdd) = time (fun () -> Netkat.Local_compiler.compile pol) in
    let switches = match nr_switches with
      | None -> Netkat.Semantics.switches_of_policy pol
      | Some n -> List.range 0 n |> List.map ~f:Int64.of_int
    in
    if Option.is_none nr_switches && List.is_empty switches then
      printf "Number of switches not automatically recognized!\n\
              Use the --switch flag to specify it manually.\n"
    else
      if printorder then print_order ();
      if printfdd then print_fdd fdd;
      let file = if stdin then Sys.getcwd () ^ "stdin" else file_or_pol in
      if dumpfdd then dump_fdd fdd ~file:(file ^ ".dot");
      if renderfdd then Fdd.render fdd;
      if updatecontroller then update_controller fdd;
      print_all_tables ~no_tables fdd switches;
      print_time t;
end


module Global = struct
  let spec = Command.Spec.(
    empty
    +> anon ("file" %: file)
    +> Flag.print_fdd
    +> Flag.dump_fdd
    +> Flag.render_fdd
    (* +> Flag.print_auto *)
    (* +> Flag.dump_auto *)
    (* +> Flag.render_auto *)
    +> Flag.no_tables
    +> Flag.json
    +> Flag.print_order
    +> Flag.dump_local
    +> Flag.update_controller
    +> Flag.stdin
  )

  let run file_or_pol printfdd dumpfdd renderfdd
    no_tables json printorder dumplocal updatecontroller stdin () =
    let pol =
      parse_pol ~json (if stdin then `String file_or_pol else `File file_or_pol) in
    let (t, fdd) = time (fun () -> Netkat.Global_compiler.compile pol) in
    let switches = Netkat.Semantics.switches_of_policy pol in
    if printorder then print_order ();
    if printfdd then print_fdd fdd;
    let file = if stdin then Sys.getcwd () ^ "stdin" else file_or_pol in
    if dumpfdd then dump_fdd fdd ~file:(file ^ ".dot");
    if renderfdd then Fdd.render fdd;
    begin match dumplocal with
      | Some file -> dump_local fdd ~file
      | None -> ()
    end;
    if updatecontroller then update_controller fdd;
    print_all_tables ~no_tables fdd switches;
    print_time t;

end



module Virtual = struct
  let spec = Command.Spec.(
    empty
    +> anon ("file" %: file)
    +> Flag.vrel
    +> Flag.vtopo
    +> Flag.ving_pol
    +> Flag.ving
    +> Flag.veg
    +> Flag.ptopo
    +> Flag.ping
    +> Flag.peg
    +> Flag.print_fdd
    +> Flag.dump_fdd
    +> Flag.render_fdd
    +> Flag.print_global_pol
    +> Flag.no_tables
    +> Flag.print_order
    +> Flag.dump_local
    +> Flag.update_controller
    +> Flag.dump_global
    +> Flag.stdin
  )

  let run vpol_file_or_str vrel vtopo ving_pol ving veg ptopo ping peg
    printfdd dumpfdd renderfdd printglobal
    no_tables printorder dumplocal updatecontroller dumpglobal stdin () =
    (* parse files *)
    let vpol = parse_pol (if stdin then `String vpol_file_or_str else `File vpol_file_or_str) in
    let vrel = parse_pred vrel in
    let vtopo = parse_pol (`File vtopo) in
    let ving_pol = parse_pol (`File ving_pol) in
    let ving = parse_pred ving in
    let veg = parse_pred veg in
    let ptopo = parse_pol (`File ptopo) in
    let ping = parse_pred ping in
    let peg = parse_pred peg in

    (* compile *)
    let module FG = Netkat.FabricGen.FabricGen in
    let module Virtual = Netkat.Virtual_Compiler.Make(FG) in
    let (t1, global_pol) = time (fun () ->
      Virtual.compile vpol ~log:true ~vrel ~vtopo ~ving_pol ~ving ~veg ~ptopo ~ping ~peg) in
    let (t2, fdd) = time (fun () -> Netkat.Global_compiler.compile global_pol) in

    (* print & dump *)
    let switches = Netkat.Semantics.switches_of_policy global_pol in
    if printglobal then begin
      Format.fprintf fmt "Global Policy:@\n@[%a@]@\n@\n"
        Netkat.Pretty.format_policy global_pol
    end;
    begin match dumpglobal with
      | Some file -> dump_pol global_pol ~file
      | None -> ()
    end;
    if printorder then print_order ();
    if printfdd then print_fdd fdd;
    let file = if stdin then Sys.getcwd () ^ "stdin" else vpol_file_or_str in
    if dumpfdd then dump_fdd fdd ~file:(file ^ ".dot");
    if renderfdd then Fdd.render fdd;
    begin match dumplocal with
      | Some file -> dump_local fdd ~file
      | None -> ()
    end;
    if updatecontroller then update_controller fdd;
    print_all_tables ~no_tables fdd switches;
    print_time ~prefix:"virtual " t1;
    print_time ~prefix:"global " t2;
end


module Auto = struct
  let spec = Command.Spec.(
    empty
    +> anon ("file" %: file)
    +> Flag.json
    +> Flag.print_order
    +> Flag.determinize
    +> Flag.minimize
    +> Flag.remove_topo
    +> Flag.render_auto
  )

  let run file json printorder dedup cheap_minimize remove_topo render_auto () =
    let open Netkat.Global_compiler in
    let pol = parse_pol ~json (`File file) in
    let (t, auto) = time (fun () ->
      Automaton.of_policy pol ~dedup ~cheap_minimize) in
    if remove_topo then ignore (Automaton.skip_topo_states auto);
    if printorder then print_order ();
    if render_auto then Automaton.render auto;
    dump_auto auto ~file:(file ^ ".auto.dot");
    print_time t;

end


module Bisim = struct
  let spec = Command.Spec.(
      empty
      +> anon ("file1" %: file)
      +> anon ("file2" %: file)
      +> Flag.json
      +> Flag.stdin
      +> Flag.containment
    )

  let run file_or_pol1 file_or_pol2 json stdin containment () =
    let pol1 =
      (if stdin then `String file_or_pol1 else `File file_or_pol1)
      |> parse_pol ~json
    in
    let pol2 =
      (if stdin then `String file_or_pol2 else `File file_or_pol2)
      |> parse_pol ~json
      |> fun p -> if containment then Netkat.Syntax.Union (pol1, p) else p
    in

    let a1 = Automaton.of_policy ~dedup:true pol1 in
    let a2 = Automaton.of_policy ~dedup:true pol2 in

    if Netkat.Bisim.check a1 a2 then
      printf "true\n"
    else
      printf "false\n";

end



(*===========================================================================*)
(* BASIC SPECIFICATION OF COMMANDS                                           *)
(*===========================================================================*)

let bisim : Command.t =
  Command.basic_spec
    ~summary:"Runs a bisimulation"
    Bisim.spec
    Bisim.run

let local : Command.t =
  Command.basic_spec
    ~summary:"Runs local compiler and dumps resulting tables."
    (* ~readme: *)
    Local.spec
    Local.run

let global : Command.t =
  Command.basic_spec
    ~summary:"Runs global compiler and dumps resulting tables."
    (* ~readme: *)
    Global.spec
    Global.run

let virt : Command.t =
  Command.basic_spec
    ~summary:"Runs virtual compiler and dumps resulting tables."
    (* ~readme: *)
    Virtual.spec
    Virtual.run

let auto : Command.t =
  Command.basic_spec
    ~summary:"Converts program to automaton and dumps it."
    (* ~readme: *)
    Auto.spec
    Auto.run

let main : Command.t =
  Command.group
    ~summary:"Runs (local/global/virtual) compiler and dumps resulting tables."
    (* ~readme: *)
    [("local", local); ("global", global); ("virtual", virt); ("auto", auto); ("bisim", bisim)]
