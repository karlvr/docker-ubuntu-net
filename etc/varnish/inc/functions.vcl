sub req_normalize_accept_encoding {  
  # KVR: Normalize Accept-Encoding header, as it will be in the Vary headers
  # See http://www.slideshare.net/Fastly/fastly-inaugural-nyc-varnish-meetup
  if (req.http.Accept-Encoding) {
    if (req.http.User-Agent ~ "MSIE 6") {
      unset req.http.Accept-Encoding;
    } else if (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } else if (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      unset req.http.Accept-Encoding;
    }
  }
}

sub req_normalize_url {
    # Strip out Google Analytics campaign variables. They are only needed by the javascript running on the page
    # utm_source, utm_medium, utm_campaign, gclid, ...
    if(req.url ~ "(\?|&)(gclid|cx|ie|cof|siteurl|zanpid|origin|utm_[a-z]+|mr:[A-z]+)=") {
        set req.url = regsuball(req.url, "(\?|&)(gclid|cx|ie|cof|siteurl|zanpid|origin|utm_[a-z]+|mr:[A-z]+)=[^&]+", "\1");
    }

    # Tidy up the query string
    set req.url = regsuball(req.url, "&&+", "");
    set req.url = regsub(req.url, "\?&", "?");
    set req.url = regsub(req.url, "\?$", "");
}
