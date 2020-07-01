open Cmi_format
open Coqffi
open Coqffi.Config
open Coqffi.Interface

let coqbase_types_table =
  Translation.empty
  |> Translation.add "list" "list"
  |> Translation.add "bool" "bool"
  |> Translation.add "option" "option"
  |> Translation.add "unit" "unit"
  |> Translation.add "int" "i63"
  |> Translation.add "Coqbase.Bytestring.t" "bytestring"

let stdlib_types_table =
  Translation.empty
  |> Translation.add "list" "list"
  |> Translation.add "bool" "bool"
  |> Translation.add "option" "option"
  |> Translation.add "unit" "unit"

let types_table profile =
  match profile with
  | Coqbase -> coqbase_types_table
  | Stdlib -> stdlib_types_table

let process conf input ochannel =
  read_cmi input
  |> interface_of_cmi_infos ~with_type_value:conf.gen_with_type_value
  |> translate (types_table conf.gen_profile)
  |> pp_interface conf ochannel

exception TooManyArguments
exception MissingInputArgument

let parse _ =
  let impure_mode_opt : impure_mode option ref =
    ref None in

  let extraction_opt : extraction_profile ref =
    ref Stdlib in

  let input_opt : string option ref =
    ref None in

  let output_opt : string option ref =
    ref None in

  let with_type_value_opt : bool ref =
    ref false in

  let get_input_path _ =
    match !input_opt with
    | Some path -> path
    | _ -> raise MissingInputArgument in

  let get_output_formatter _ =
    match !output_opt with
    | Some path -> open_out path |> Format.formatter_of_out_channel
    | _ -> Format.std_formatter in

  let specs = [
    ("-p",
     Arg.Symbol (["stdlib"; "coq-base"], fun profile ->
         match profile with
         | "stdlib" -> extraction_opt := Stdlib
         | "coq-base" -> extraction_opt := Coqbase
         | _ -> assert false),
     "  Select an extraction profile for base types");

    ("-m",
     Arg.Symbol (["FreeSpec"], fun mode ->
         match mode with
         | "FreeSpec" -> impure_mode_opt := Some FreeSpec
         | _ -> assert false),
     "  Select a framework to model impure computations");

    ("-o",
     Arg.String (fun path -> output_opt := Some path),
     " Select a framework to model impure computations");

    ("--with-type-value",
     Arg.Unit (fun _ -> with_type_value_opt := true),
     " Bind OCaml type values to Coq inductive types");
  ] in

  let n = ref 0 in

  Arg.parse specs (fun arg ->
      if !n = 0
      then begin
        input_opt := Some arg;
        n := 1
      end
      else raise TooManyArguments)
    "coqffi";

  let conf = {
    gen_profile = !extraction_opt;
    gen_impure_mode = !impure_mode_opt;
    gen_with_type_value = !with_type_value_opt;
  } in

  validate conf;

  (get_input_path (), get_output_formatter (), conf)

let usage =
  {|coqffi INPUT [-p {stdlib|coq-base}] [-m {FreeSpec}] [-o OUTPUT]|}

let _ =
  try begin
    let (input, output, conf) = parse () in
    process conf input output
  end
  with
  | TooManyArguments ->
    Format.printf "Too many arguments.\n%s\n" usage
  | MissingInputArgument ->
    Format.printf "Too many arguments.\n%s\n" usage
  | Entry.UnsupportedOCamlSignature s ->
    Format.printf "Use of unsupported OCaml construction: %a"
      Printtyp.signature [s]
  | Repr.UnsupportedOCamlType t ->
    Format.printf "Unsupported OCaml type construction %a"
      Printtyp.type_expr t
  | Repr.UnknownOCamlType t ->
    Format.printf "Type %s is not supported by the selected profile"
      t