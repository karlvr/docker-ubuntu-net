
sub fetch_tidy_bereq {
  /* Remove headers we've added for internal use that we don't need to send to the backend */
  unset bereq.http.X-Supermodel-Generated-CSRF;
  unset bereq.http.X-Supermodel-Path;
  unset bereq.http.X-Supermodel-Original-Cookie;
  unset bereq.http.X-Supermodel-Cookie-Domain;
  unset bereq.http.X-Supermodel-Allow-User;
  unset bereq.http.X-Real-IP;
}

sub deliver_add_csrf {
  # KVR: Add CSRF cookie if the user didn't supply it. This is because we don't allow the server to set it (as it would be cached). The
  # server will accept the Fastly generated cookie from the client and use it client-side to set the CSRF fields in forms, and then to validate
  # posted forms.
  if (req.http.X-Supermodel-Generated-CSRF) {
    header.append(resp.http.Set-Cookie, "com.xk72.webparts.csrf=" + req.http.X-Supermodel-Generated-CSRF + "; Path=/; HttpOnly; Domain=" + req.http.X-Supermodel-Cookie-Domain);
    if (client.ip ~ debug) {
      set resp.http.X-Supermodel-Generated-CSRF = "YES";
    }
  }
}

sub req_allow_esi {
  set req.http.X-Supermodel-ESI = "YES";
}
