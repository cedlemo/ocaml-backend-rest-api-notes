open Httpaf
open Base
open Lwt.Infix
open Httpaf_lwt_unix

module String = Caml.String
module Arg = Caml.Arg

let invalid_request reqd status body =
  (* Responses without an explicit length or transfer-encoding are
     close-delimited. *)
  let headers = Headers.of_list [ "Connection", "close" ] in
  Reqd.respond_with_string reqd (Response.create ~headers status) body
;;

let _request_handler reqd =
  let { Request.meth; target; _ } = Reqd.request reqd in
  match meth with
  | `GET ->
    begin match String.split_on_char '/' target with
    | "" :: "hello" :: rest ->
      let who =
        match rest with
        | [] -> "world"
        | who :: _ -> who
      in
      let response_body = Printf.sprintf "Hello, %s!\n" who in
      (* Specify the length of the response. *)
      let headers =
        Headers.of_list
          [ "Content-length", Int.to_string (String.length response_body) ]
      in
      Reqd.respond_with_string reqd (Response.create ~headers `OK) response_body
    | _ ->
      let response_body = Printf.sprintf "%S not found\n" target in
      invalid_request reqd `Not_found response_body
    end
  | meth ->
    let response_body =
      Printf.sprintf "%s is not an allowed method\n" (Method.to_string meth)
    in
    invalid_request reqd `Method_not_allowed response_body
;;

let request_handler (_: Unix.sockaddr) = _request_handler

let _error_handler ?request:_ error start_response =
  let response_body = start_response Headers.empty in
  begin match error with
    | `Exn exn ->
      Body.write_string response_body (Exn.to_string exn);
      Body.write_string response_body "\n";
    | #Status.standard as error ->
      Body.write_string response_body (Status.default_reason_phrase error)
  end;
  Body.close_writer response_body
;;

let error_handler (_ : Unix.sockaddr) = _error_handler

let main port =
  let listen_address = Unix.(ADDR_INET (inet_addr_loopback, port)) in
  Lwt.async (fun () ->
    Lwt_io.establish_server_with_client_socket
      listen_address
      (Server.create_connection_handler ~request_handler ~error_handler)
    >|= fun _server ->
      Stdio.printf "Starting server and listening at http://localhost:%d\n\n%!" port);
  let forever, _ = Lwt.wait () in
  Lwt_main.run forever
;;

let () =
  let port = ref 8080 in
  Arg.parse
    ["-p", Arg.Set_int port, " Listening port number (8080 by default)"]
    ignore
    "Echoes POST requests. Runs forever.";
  main !port
;;
