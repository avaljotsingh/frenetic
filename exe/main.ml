open Filename
open Parsers
open Topology

type modeType =
  | WriteMode
  | DefaultMode

type fileType =
  | DotFile
  | GmlFile
  | MnFile
  | UnknownFile

let mode = ref DefaultMode
let outmode = ref false
let infname = ref ""
let outfname = ref ""
let inft = ref UnknownFile
let outft = ref UnknownFile

let arg_spec =
  [
    ("--dot",
     Arg.Unit (fun () -> if !outmode then outft := DotFile else inft := DotFile ),
     "\tRead or write a file in DOT format")
    ; ("--gml",
     Arg.Unit (fun () -> if !outmode then outft := GmlFile else inft := GmlFile ),
     "\tRead or write a file in GML format")
    ; ("-o",
       Arg.String (fun s -> mode := WriteMode; outmode := true ; outfname := s ),
       "\tWrite topology to a file")
    ; ("--help",
       Arg.Unit (fun () -> mode := DefaultMode),
       "\tDisplay this list of options")
    ; ("-help",
       Arg.Unit (fun () -> mode := DefaultMode),
       "\tDisplay this list of options")
]

let usage = Printf.sprintf "usage: %s [--dot|--gml] filename -o [--dot|--mn] filename" Sys.argv.(0)

let from_extension fname =
  if check_suffix fname ".dot" then from_dotfile fname
  else if check_suffix fname ".gml" then from_gmlfile fname
  else failwith "Cannot parse given file type"


let _ =
  Arg.parse arg_spec (fun fn -> infname := fn) usage ;
  Printf.printf "Attempting to topology from file: %s\n%!" !infname;
  let topo = match !inft with
     | DotFile ->
      Printf.printf "Parsing file as DOT format\n";
      from_dotfile !infname
     | GmlFile ->
      Printf.printf "Parsing file as GML format\n";
      from_gmlfile !infname
     | MnFile ->
       failwith "Cannot read from a topology from a Mininet file\n";
    | UnknownFile ->
      if ( !infname = "" ) then begin
        Arg.usage arg_spec usage;
        exit 1 end
      else  begin
        Printf.printf "Unspecified file format. Inferring format.\n";
        from_extension !infname end
  in
  if !outmode then match !outft with
    | DotFile ->
      Printf.printf "\nDotfile: %s\n\n" (Topology.to_dot topo)
    | GmlFile ->
      Printf.printf "\nWriting to GML format not supported yet\n"
    | _ ->
      Printf.printf "\nMininet script: %s\n\n" (Topology.to_mininet topo)
  else
    Printf.printf "\nMininet script: %s\n\n" (Topology.to_mininet topo)
