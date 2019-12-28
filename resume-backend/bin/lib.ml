open Httpaf
open Base

module String = Caml.String

let invalid_request reqd status body =
  (* Responses without an explicit length or transfer-encoding are
     close-delimited. *)
  let headers = Headers.of_list [ "Connection", "close" ] in
  Reqd.respond_with_string reqd (Response.create ~headers status) body

let request_handler reqd =
  let { Request.meth; target; headers; _ } = Reqd.request reqd in
  let build_headers response_body =
        Headers.of_list
          [ "Content-length", Int.to_string (String.length response_body) ; "connection", "close"]
  in
  match meth with
  | `GET | `DELETE ->
    let response_body = Printf.sprintf "%s request on url %s\n" (Method.to_string meth) target in
    let resp_headers = build_headers response_body in
    Reqd.respond_with_string reqd (Response.create ~headers:resp_headers `OK) response_body
  | `POST | `PUT ->
    let response =
        let content_type =
          match Headers.get headers "content-type" with
          | None   -> "application/octet-stream"
          | Some x -> x
        in
        Response.create ~headers:(Headers.of_list ["content-type", content_type; "connection", "close"]) `OK
    in
    let request_body  = Reqd.request_body reqd in
    let response_body = Reqd.respond_with_streaming reqd response in
    let rec on_read buffer ~off ~len =
      Body.write_bigstring response_body buffer ~off ~len;
      Body.schedule_read request_body ~on_eof ~on_read;
    and on_eof () =
      Body.close_writer response_body
    in
    Body.schedule_read request_body ~on_eof ~on_read
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
