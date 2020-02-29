open Core
open Async

let request_handler =
  let headers =
    Httpaf.Headers.of_list
      [ "content-length", Int.to_string (Bigstring.length Test_data.text) ]
  in
  let handler reqd =
    let request_body = Httpaf.Reqd.request_body reqd in
    Httpaf.Body.close_reader request_body;
    Httpaf.Reqd.respond_with_bigstring
      reqd
      (Httpaf.Response.create ~headers `OK)
      Test_data.text
  in
  handler
;;

let main port =
  let where_to_listen = Tcp.Where_to_listen.of_port port in
  let request_handler _conn = request_handler in
  Async_connection.(
    Server.create
      ~crt_file:"./certs/localhost.pem"
      ~key_file:"./certs/localhost.key"
      ~on_handler_error:`Ignore
      where_to_listen)
    (Async_http.Server.create_connection_handler ~request_handler)
  >>= fun server ->
  Deferred.forever () (fun () ->
      Clock.after Time.Span.(of_sec 0.5)
      >>| fun () ->
      Logs.info (fun m -> m "connections: %d" (Tcp.Server.num_connections server)));
  Deferred.never ()
;;

let () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_reporter (Logs_fmt.reporter ());
  Logs.set_level ~all:true (Some Logs.Debug);
  Command.async
    ~summary:"Sample server"
    Command.Param.(
      map
        (flag "-p" (optional_with_default 8080 int) ~doc:"int Server port number")
        ~f:(fun port () -> main port))
  |> Command.run
;;
