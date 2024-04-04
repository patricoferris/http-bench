http-bench
----------

Mostly similar to `cohttp-bench`. Linux-only.

```sh
git clone --recursive https://github.com/patricoferris/http-bench
opam pin vendor/httpcats -yn
opam install httpcats eio_main.1.0 cohttp-eio -y 
dune build --profile release
# Install wrk2
./latency.sh
```
