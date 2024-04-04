open Cohttp_eio

let length = 2053
let text = String.make length 'a'
let headers = Cohttp.Header.of_list [ ("content-length", Int.to_string length) ]

let server_callback _conn _req _body =
  Server.respond_string ~headers ~status:`OK ~body:text ()

let run_linux_big_queue fn =
  Eio_linux.run ~n_blocks:4096 ~block_size:4096 ~queue_depth:2048 fn

let run_linux fn =
  Eio_linux.run fn

let run_posix fn =
  Eio_posix.run fn

let run_backend v = match String.lowercase_ascii v with
  | "posix" -> run_posix
  | "linux" -> run_linux
  | "linux-big-queue" -> run_linux_big_queue
  | s -> failwith ("Unknown backend: " ^ s)

let run_eio backend port =
  run_backend backend @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let socket =
    Eio.Net.listen env#net ~sw ~backlog:64 ~reuse_addr:true
      (`Tcp (Eio.Net.Ipaddr.V4.loopback, port))
  and server = Cohttp_eio.Server.make ~callback:server_callback () in
  Cohttp_eio.Server.run socket server ~on_error:raise

let run_miou port =
  Httpcats_server.run port 

let () =
  let port = ref 9091 in
  let backend = ref "posix" in
  Arg.parse
    [ ("-p", Arg.Set_int port, " Listening port number (9091 by default)");
      ("-b", Arg.Set_string backend, " Eio backend to use (POSIX by default)") ]
    ignore "An HTTP/1.1 server";
  match !backend with
  | "miou" -> run_miou !port
  | _ -> run_eio !backend !port
