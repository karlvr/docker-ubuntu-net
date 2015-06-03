# Backends

# backend LB_charles {
#     .first_byte_timeout = 60s;
#     .connect_timeout = 5s;
#     .max_connections = 200;
#     .between_bytes_timeout = 60s;
#     .port = "8082";
#     .host = "127.0.0.1";
# }

backend LB_app1 {
    .first_byte_timeout = 60s;
    .connect_timeout = 5s;
    .max_connections = 200;
    .between_bytes_timeout = 60s;
    .port = "80";
    .host = "199.195.199.60";
    .host_header = "letterboxd.com";
    #.port = "8082";
    #.host = "127.0.0.1";
    .probe = {
        .url = "/";
        .timeout = 1s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
    }
}

backend LB_app2 {
    .first_byte_timeout = 60s;
    .connect_timeout = 5s;
    .max_connections = 200;
    .between_bytes_timeout = 60s;
    .port = "80";
    .host = "199.195.199.116";
    .host_header = "letterboxd.com";
    .probe = {
        .url = "/";
        .timeout = 1s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
    }
}

sub vcl_init {
  new bar = directors.round_robin();
  bar.add_backend(LB_app1);
  bar.add_backend(LB_app2);
  # bar.add_backend(LB_charles);
}
