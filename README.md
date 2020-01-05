# Exploring REST API with OCaml

* [Introduction](#introduction)
* [Creating the backend](#creating-the-backend)
  * [Dune project initialization](#dune-project-initialization)
  * [A backend with the main httpaf example](#a-backend-with-the-main-httpaf-example)
  * [A backend that handles GET POST PUT and DELETE http requests](#a-backend-that-handles-GET-POST-PUT-and-DELETE-http-request)
  * [A backend that handles JSON data requests](#a-backedn-that-handles-json-data-requests)
  * [A backend that uses a database]
* [Creating the React frontend]
* [From React to Reasonml]
* [Deploying with Docker]

## Introduction
the technical stack will be:

backend: https://github.com/inhabitedtype/httpaf
database:
frontend: react/reasonml
deployement: docker https://jaredforsyth.com/posts/deploying-native-reason-ocaml-with-now-sh/

the application will be a classical todo list.

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

```ocaml
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

```ocaml
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

See full sources in the directory: backend-1

### A backend that handles GET POST PUT and DELETE http requests

Now the backend will be splitted in two files:
- backend.ml: with the code that manages the web server
- lib.ml: with the code that handles the requests.

For the `GET` and `DELETE` requests, the server just returns a string with the type of the request and the url requested.

```ocaml
    let response_body = Printf.sprintf "%s request on url %s\n" (Method.to_string meth) target in
    let resp_headers = build_headers response_body in
    Reqd.respond_with_string reqd (Response.create ~headers:resp_headers `OK) response_body
```

For the `POST` and `PUT` requests, the server will return the same data sent in the request.

```ocaml
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

```

First, a response_body stream is created, then `Body.schedule_read` is called to read the request_body and write the data in the response_body. At `eof`, the call to `Body.close_writer` indicates that the response_body should be returned to the client.

*backend.ml*

```ocaml
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
```

*lib.ml*

```ocaml
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

```

Build and run :

```
$ dune build bin/backend.exe
$ dune exec bin/backend.exe
Starting server and listening at http://localhost:8080

```

test:

```
$ curl -i -X GET localhost:8080/toto
HTTP/1.1 200 OK
Content-length: 25
connection: close

GET request on url /toto
```

```
$ curl -i -X DELETE localhost:8080/toto/1
HTTP/1.1 200 OK
Content-length: 30
connection: close

DELETE request on url /toto/1
```

```
$ curl -i -X POST -H 'Content-Type: application/json' -d '{"numberofsaves": "272"}' localhost:8080/toto
HTTP/1.1 200 OK
content-type: application/json
connection: close

{"numberofsaves": "272"}
```

```
$ curl -i -X PUT -H 'Content-Type: application/json' -d '{"numberofsaves": "272"}' localhost:8080/toto
HTTP/1.1 200 OK
content-type: application/json
connection: close

{"numberofsaves": "272"}
```

See full sources in the directory backend-2.

### A backend that handles JSON data requests.

The library `yojson` (https://github.com/ocaml-community/yojson) allows to manipulate json data from a string.

For the `PUT` and `POST` requests, data is passed in json format. In the server the data is just received as a string and should be verified and transformed into json.

```ocaml
    let request_body  = Reqd.request_body reqd in
    let data = Buffer.create 1024 in
    let rec on_read buffer ~off ~len =
      let str = Bigstringaf.substring buffer ~off ~len in
      let () = Buffer.add_string data str in
      Body.schedule_read request_body ~on_eof ~on_read;
    and on_eof () =
      (* Get the JSON data and print it in the backend output *)
      let json = (Buffer.sub data 0 (Buffer.length data)) |> Bytes.to_string  |> Yojson.Basic.from_string in
      Stdio.print_endline (Yojson.Basic.pretty_to_string json);
      (* Return an OK response *)
      let response_body = Printf.sprintf "%s request on url %s\n" (Method.to_string meth) target in
      send_response response_body
    in
    Body.schedule_read request_body ~on_eof ~on_read
```

The `GET` request should return data into the json format.

```ocaml
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
    send_response response_body
```

