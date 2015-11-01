vcl 4.0;

import directors;
import saintmode;

backend b0 {
    .first_byte_timeout = 60s;
    .connect_timeout = 5s;
    .max_connections = 200;
    .between_bytes_timeout = 60s;
    .port = "8082";
    .host = "10.1.10.10";
    .probe = {
        .url = "/letterboxd/s/health";
        .timeout = 3s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
    }
}

backend b1 {
    .first_byte_timeout = 60s;
    .connect_timeout = 5s;
    .max_connections = 200;
    .between_bytes_timeout = 60s;
    .port = "8083";
    .host = "10.1.10.10";
    .probe = {
        .url = "/letterboxd/s/health";
        .timeout = 3s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
    }
}

sub vcl_init {
	new sm0 = saintmode.saintmode(b0, 10);
	new sm1 = saintmode.saintmode(b1, 10);

  	new vdir = directors.round_robin();
  	vdir.add_backend(sm0.backend());
  	vdir.add_backend(sm1.backend());
}

include "inc/core.vcl";
