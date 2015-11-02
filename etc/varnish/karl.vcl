############################################################################################################################
# Use Charles as the backend, so you can observe the requests from Varnish to the backend.
#
# Configure Charles to have a Reverse Proxy on port 8082 that connects to app#.srv.letterboxd.com on port 80
# with "Preserve Host Header" off.
# This way, Varnish will make a request to Charles with the host name that you request Varnish with (localhost or whatever)
# and Charles will then make a request to the backend app server, passing in its own name, so it will serve the request.

vcl 4.0;

import directors;
import saintmode;

backend LB_karl_charles {
    .first_byte_timeout = 60s;
    .connect_timeout = 5s;
    .max_connections = 200;
    .between_bytes_timeout = 60s;
    .port = "8082";
    .host = "10.1.10.10";
    .probe = {
        .url = "/s/health";
        .timeout = 3s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
    }
}

sub vcl_init {
    new sm0 = saintmode.saintmode(LB_karl_charles, 10);

    new vdir = directors.round_robin();
    vdir.add_backend(sm0.backend());
}

include "inc/core.vcl";
