
let index_html =
  {html|<html>
  <head>
    <title>httpcats</title>
  </head>
  <body>
    <h1>Hello World!</h1>
  </body>
</html>|html}

let error_msgf fmt = Format.kasprintf (fun msg -> Error msg) fmt

let inet_addr_of_string str =
  try Ok (Unix.inet_addr_of_string str)
  with _ -> error_msgf "Invalid address: %S" str

let port_of_string str =
  try Ok (int_of_string str) with _ -> error_msgf "Invalid port: %S" str

let listen sockaddr =
  let file_descr =
    match sockaddr with
    | Unix.ADDR_INET (inet_addr, _) ->
        if Unix.is_inet6_addr inet_addr then Miou_unix.tcpv6 ()
        else Miou_unix.tcpv4 ()
    | _ -> failwith "Invalid address"
  in
  Miou_unix.bind_and_listen file_descr sockaddr;
  file_descr

let rec cleanup orphans =
  match Miou.care orphans with
  | None | Some None -> ()
  | Some (Some prm) -> Miou.await_exn prm; cleanup orphans

let handler = function
  | `V2 _ -> assert false
  | `V1 reqd -> (
      let open Httpaf in
      let request = Reqd.request reqd in
      match request.Request.target with
      | "" | "/" | "/index.html" ->
          let headers =
            Headers.of_list
              [
                ("content-type", "text/html; charset=utf-8")
              ; ("content-length", string_of_int (String.length index_html))
              ]
          in
          let resp = Response.create ~headers `OK in
          let body = Reqd.request_body reqd in
          Body.close_reader body;
          Reqd.respond_with_string reqd resp index_html
      | _ ->
          let headers = Headers.of_list [ ("content-length", "0") ] in
          let resp = Response.create ~headers `Not_found in
          Reqd.respond_with_string reqd resp "")

let server sockaddr = Httpcats.Server.clear ~handler sockaddr

let run port =
  let addr = Unix.ADDR_INET (Unix.inet_addr_loopback, port) in
  let () = Printexc.record_backtrace true in
  Miou_unix.run ~domains:3 @@ fun () ->
  let prm = Miou.call_cc @@ fun () -> server addr in
  Miou.parallel server (List.init 3 (Fun.const addr))
  |> List.iter (function Ok () -> () | Error exn -> raise exn);
  Miou.await_exn prm
