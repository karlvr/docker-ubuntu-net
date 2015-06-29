############################################################################################################################
# Use Charles as the backend, so you can observe the requests from Varnish to the backend.
#
# Configure Charles to have a Reverse Proxy on port 8082 that connects to app#.srv.letterboxd.com on port 80
# with "Preserve Host Header" off.
# This way, Varnish will make a request to Charles with the host name that you request Varnish with (localhost or whatever)
# and Charles will then make a request to the backend app server, passing in its own name, so it will serve the request.

import directors;

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