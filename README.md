# Exploring REST API with OCaml

* [Introduction](#introduction)
* [Creating the backend](#creating-the-backend)
  * [Dune project initialization](#dune-project-initialization)
  * [A backend with the main httpaf example](#a-backend-with-the-main-httpaf-example)
  * [A backend that handles GET, POST, PUT and DELETE http request]
  * [A backend that handles JSON data requests]
  * [A backend that use a database]
* [Creating the React frontend]
* [From React to Reasonml]
* [Deploying with Docker]

## Introduction
the technical stack will be:

backend: https://github.com/inhabitedtype/httpaf
database:
frontend: react/reasonml
deployement: docker https://jaredforsyth.com/posts/deploying-native-reason-ocaml-with-now-sh/

the application will be an application where one can create a resume (CV)

Data Model: (to improve)

Resume:

  Person
    name
    firstname

  Period:
    start_date
    end_date
    description
    section

  Section:
    name

## Creating the backend:

### Dune project initialization:

```
mkdir -p resume-backend/bin
cd resume-backend
touch bin/dune
touch bin/backend.ml
```

In the dune file:

```
(executable
 (name backend)
)
```

in the backend.ml file:

```
let () =
  print_endline "Hello, world!"
```

build and run:

```
$ dune build bin/backend.exe
  Info: Creating file dune-project with this contents:
  | (lang dune 1.11)
$ ll
  total 12K
  drwxr-xr-x 2 cedlemo cedlemo 4,0K 27 déc.  17:35 bin
  drwxr-xr-x 3 cedlemo cedlemo 4,0K 27 déc.  17:35 _build
  -rw-r--r-- 1 cedlemo cedlemo   17 27 déc.  17:35 dune-project
$ dune exec bin/backend.exe
  Hello, world!
```

Import `httpaf` dependency and trying to build the main example:

int the *bin/dune* file

```
(executable
 (name backend)
 (library httpaf)
)
```

in the *bin/backend.ml* file
```
open Httpaf
module String = Caml.String

let invalid_request reqd status body =
  (* Responses without an explicit length or transfer-encoding are
     close-delimited. *)
  let headers = Headers.of_list [ "Connection", "close" ] in
  Reqd.respond_with_string reqd (Response.create ~headers status) body
;;

let request_handler reqd =
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
          [ "Content-length", string_of_int (String.length response_body) ]
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
```

```
dune build bin/backend.exe
```

### A backend with the main example:

In the first part, there is the main example of `httpaf`:

```
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
```

then, we create an http server that listens to a port and dispatch the request to the `request_handler`:
```
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
```

In order to build and launch the server:

```
dune clean
dune build bin/backend.exe
dune exec bin/backend.exe
Listening at http://localhost:8080
```

Just try to go to *http://localhost:8080/hello/toto* and observe :
```
Hello, toto!
```
