open Base
open Lwt.Infix
open Httpaf_lwt_unix

module String = Caml.String
module Arg = Caml.Arg

let request_handler (_: Unix.sockaddr) = Lib.request_handler
let error_handler (_ : Unix.sockaddr) = Lib.error_handler

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

let () =
  let port = ref 8080 in
  Arg.parse
    ["-p", Arg.Set_int port, " Listening port number (8080 by default)"]
    ignore
    "Echoes POST requests. Runs forever.";
  main !port
