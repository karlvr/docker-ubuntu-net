# Letterboxd production

vcl 4.0;

import directors;
import saintmode;

backend LB_app1 {
    .first_byte_timeout = 60s;
    .connect_timeout = 5s;
    .max_connections = 200;
    .between_bytes_timeout = 60s;
    .port = "80";
    .host = "199.195.199.60";
    .host_header = "letterboxd.com";
    .probe = {
        .url = "/s/health";
        .timeout = 3s;
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
        .url = "/s/health";
        .timeout = 3s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
    }
}

sub vcl_init {
    new sm0 = saintmode.saintmode(LB_app1, 10);
    new sm1 = saintmode.saintmode(LB_app2, 10);

    new vdir = directors.round_robin();
    vdir.add_backend(sm0.backend());
    vdir.add_backend(sm1.backend());
}

include "inc/core.vcl";
