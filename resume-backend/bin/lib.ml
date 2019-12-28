open Httpaf
open Base

module String = Caml.String

let invalid_request reqd status body =
  let headers = Headers.of_list [ "Connection", "close" ] in
  Reqd.respond_with_string reqd (Response.create ~headers status) body

let request_handler reqd =
  let { Request.meth; target; headers; _ } = Reqd.request reqd in
  let build_headers response_body =
        Headers.of_list
          [ "Content-length", Int.to_string (String.length response_body);
            "Content-Type", "application/json";
            "connection", "close"]
  in
  match meth with
  | `GET -> let json_values =
              `List [
                `Assoc
                [
                    ("id", `String "1");
                    ("name", `String "todo 1");
                    ( "description", `String "do this, do that");
                ];
                `Assoc
                [
                    ("id", `String "2");
                    ("name", `String "todo 2");
                    ( "description", `String "do this again, do that again");
                ]
              ]
    in
    let response_body = Yojson.Basic.to_string json_values in
    let resp_headers = build_headers response_body in
    Reqd.respond_with_string reqd (Response.create ~headers:resp_headers `OK) response_body
  | `POST | `PUT ->
    let request_body  = Reqd.request_body reqd in
    let data = Buffer.create 1024 in
    let rec on_read buffer ~off ~len =
      let str = Bigstringaf.substring buffer ~off ~len in
      let () = Buffer.add_string data str in
      Body.schedule_read request_body ~on_eof ~on_read;
    and on_eof () =
      let json = (Buffer.sub data 0 (Buffer.length data)) |> Bytes.to_string  |> Yojson.Basic.from_string in
      let () = Stdio.print_endline (Yojson.Basic.pretty_to_string json) in
      let response_body = Printf.sprintf "%s request on url %s\n" (Method.to_string meth) target in
      let resp_headers = build_headers response_body in
      Reqd.respond_with_string reqd (Response.create ~headers:resp_headers `OK) response_body
    in
    Body.schedule_read request_body ~on_eof ~on_read
  | `DELETE ->
    let response_body = Printf.sprintf "%s request on url %s\n" (Method.to_string meth) target in
    let resp_headers = build_headers response_body in
    Reqd.respond_with_string reqd (Response.create ~headers:resp_headers `OK) response_body
  | meth ->
    let response_body =
      Printf.sprintf "%s is not an allowed method\n" (Method.to_string meth)
    in
    invalid_request reqd `Method_not_allowed response_body

let error_handler ?request:_ error start_response =
  let response_body = start_response Headers.empty in
  begin match error with
    | `Exn exn ->
      Body.write_string response_body (Exn.to_string exn);
      Body.write_string response_body "\n";
    | #Status.standard as error ->
      Body.write_string response_body (Status.default_reason_phrase error)
  end;
  Body.close_writer response_body
