backend LB_charles {
    .first_byte_timeout = 60s;
    .connect_timeout = 5s;
    .max_connections = 200;
    .between_bytes_timeout = 60s;
    .port = "8082";
    .host = "127.0.0.1";
}

sub vcl_init {
  new vdir = directors.round_robin();
  vdir.add_backend(LB_charles);
}
