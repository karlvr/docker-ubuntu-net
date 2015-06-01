# Letterboxd VCL

vcl 4.0;

import geoip;
import digest;
import directors;

# Backends

backend F_app1 {
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

backend F_app2 {
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

acl debug {
  "123.100.90.137";
  "121.99.27.111";
  "127.0.0.1";
}

acl purge {
  "127.0.0.1";
  "199.195.199.60";
  "199.195.199.116";
  "10.0.0.0"/8;
}

sub vcl_init {
  new bar = directors.round_robin();
  bar.add_backend(F_app1);
  bar.add_backend(F_app2);
}

sub vcl_recv {
  if (req.method == "BAN") {
    # Same ACL check as above:
    if (!client.ip ~ purge) {
      return(synth(403, "Not allowed."));
    }
    ban("obj.http.Surrogate-Key ~ (^|\s)" + req.url + "($|\s)");
    #ban("obj.http.Surrogate-Key ~ " + req.url);

    # Throw a synthetic page so the
    # request won't go to the backend.
    return(synth(200, "Ban added"));
  }

#--FASTLY RECV CODE START
  # if (req.restarts == 0) {
  #   if (!req.http.X-Timer) {
  #     set req.http.X-Timer = "S" + time.start.sec + "." + time.start.usec_frac;
  #   }
  #   set req.http.X-Timer = req.http.X-Timer + ",VS0";
  # }

            

    
  # default conditions
  set req.backend_hint = bar.backend();
  

  
  # end default conditions

  
      
  
#--FASTLY RECV CODE END

  # KVR: Setup X-Forwarded-For header
  if (req.restarts == 0) {
    if (!req.http.Fastly-FF) {
      set req.http.Fastly-Temp-XFF = client.ip;
    } else {
      set req.http.Fastly-Temp-XFF = req.http.X-Forwarded-For;
    }
  } else {
    # Restore original cookie if the request has been restarted
    if (req.http.X-Supermodel-Original-Cookie) {
      set req.http.Cookie = req.http.X-Supermodel-Original-Cookie;
    }
  }
  
  unset req.http.X-Supermodel-Generated-CSRF;
  unset req.http.X-Supermodel-Dont-Modify;
  unset req.http.X-Supermodel-ESI;
  unset req.http.X-Supermodel-User;
  unset req.http.X-Supermodel-Debug;
  unset req.http.X-Letterboxd-Cacheable;
  unset req.http.X-Letterboxd-Cacheable-Reason;

  if (client.ip ~ debug) {
    set req.http.X-Supermodel-Debug = "YES";
  }

  # KVR: Geolocation (always add headers, and then remove if not allowed later)
  set req.http.X-Supermodel-Country-Code = geoip.country_code("" + client.ip);
  unset req.http.X-Supermodel-City; # We're not using City at the moment
  #set req.http.X-Supermodel-City = geoip.city;

  # Request methods that do not get served from cache or doctored by vcl_fetch
  if (req.method != "HEAD" && req.method != "GET" && req.method != "PURGE") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "HTTP METHOD";
    set req.http.X-Supermodel-Dont-Modify = "YES";
    call allow_esi;
    return(pass);
  }

  # Remove context paths on dev
  if (req.http.host ~ "dev\.cactuslab\.com$" || req.http.host ~ "letterboxd-dev\.com$") {
    set req.http.X-Supermodel-Path = regsub(req.url, "^/letterboxd/", "/");
    set req.http.X-Supermodel-Development = "YES";
  } else {
    set req.http.X-Supermodel-Path = req.url;
  }
  set req.http.X-Supermodel-File = regsub(req.http.X-Supermodel-Path, "[?;].*", "");

  if (req.http.X-Supermodel-Path ~ "^/_vcl_error$") {
    return(synth(901, "Forced error"));
  }

  # Cookie domains
  if (req.http.host ~ "letterboxd\.com$") {
    set req.http.X-Supermodel-Cookie-Domain = "letterboxd.com";
  } else if (req.http.host ~ "letterboxd-dev\.com$") {
    set req.http.X-Supermodel-Cookie-Domain = "letterboxd-dev.com";
  } else if (req.http.host ~ "^www\.") {
    set req.http.X-Supermodel-Cookie-Domain = regsub(req.http.host, "^www\.", "");
  } else {
    set req.http.X-Supermodel-Cookie-Domain = req.http.host;
  }

  # KVR: Remove Accept-Language as it affects our fmt:format* tags and we cache things containing them
  unset req.http.Accept-Language;

  # KVR: Remove User-Agent so there is no chance of doing anything special based upon it
  unset req.http.User-Agent;

  # KVR: Allow stale pages to be served if necessary
  # set req.grace = 5m;

  call normalize_req_url;

  # KVR: Remove all cookies for our static paths, and proceed to lookup
  if (req.http.X-Supermodel-Path ~ "^/static/" || req.http.X-Supermodel-Path ~ "^/assets/" || req.http.X-Supermodel-Path ~ "^/_maint/") {
    unset req.http.Cookie;
    unset req.http.X-Supermodel-Country-Code;
    unset req.http.X-Supermodel-City;
    return(hash);
  }

  # Allow ESI on everything that gets to this point.
  call allow_esi;

  # Blacklist / Whitelist
  # the X-Letterboxd-Cacheable-Reason is only for debugging purposes, although both headers are passed through so we can check server-side for a faulty regex or missing case.
  if (req.http.X-Supermodel-File ~ "^/(add/)?$") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Homepage";
  } else if (req.http.X-Supermodel-File ~ "^/errors/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Error page";
  } else if (req.http.X-Supermodel-File ~ "^/favicon.(ico|png)") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Favicon";
  } else if (req.http.X-Supermodel-File ~ "^/admin/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "Admin page";
  } else if (req.http.X-Supermodel-File ~ "^/(activity|invitations|user|import|data|settings)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "User-centric page";
  } else if (req.http.X-Supermodel-File ~ "^/ajax/(user-homepage|poster)/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Cacheable Ajax page";
  } else if (req.http.X-Supermodel-File ~ "^/(s|ajax|email|register)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "System or Ajax page";
  } else if (req.http.X-Supermodel-File ~ "^/(pro)/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Purchase page";
  } else if (req.http.X-Supermodel-File ~ "^/(films|lists|people)/$") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Cacheable Main page";
  } else if (req.http.X-Supermodel-File ~ "^/(reviews|reviewers|patrons|tags|charts|create-account|imdb|tmdb)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "Main page";
  } else if (req.http.X-Supermodel-File ~ "^/(year-in-review|2012|2013|2014)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "Year in review page";
  } else if (req.http.X-Supermodel-File ~ "^/list/new/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "New list";
  } else if (req.http.X-Supermodel-File ~ "^/film/[^/]+/$") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "A film page";
  } else if (req.http.X-Supermodel-File ~ "^/film/[^/]+/(review|genres|crew|studios)/$") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "A film page aspect";
  } else if (req.http.X-Supermodel-File ~ "^/film/[^/]+/(image-125|image-150)/$") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "A film poster container";
  } else if (req.http.X-Supermodel-File ~ "^(/[a-zA-Z0-9_]{2,15}(/friends)?)?/film/[^/]+/(lists|fans|likes|watches|views|reviews|ratings|activity)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "Film subpage";
  } else if (req.http.X-Supermodel-File ~ "^/esi/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "ESI";
  } else if (req.http.X-Supermodel-File ~ "^/(search|welcome|pro|contact)/$") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "search page, welcome page, pro page, contact page";
  } else if (req.http.X-Supermodel-File ~ "^/(about|legal|api-coming-soon|purpose)/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "editorial page/section";
  } else if (req.http.X-Supermodel-File ~ "^/(actor|director|studio|producer|writer|editor|cinematography|art-direction|visual-effects|composer|sound|costumes|make-up)/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Basic film list";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/$") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "A person's profile page";
  } else if (req.http.X-Supermodel-File ~ "^(/[a-zA-Z0-9_]{2,15}(/friends)?)?/tag/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "A tag page";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/(tags|likes|rss|following|followers|year)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "A person's subpage";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/(avatar)/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "A person's cacheable subpage";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/list/[^/]+/(edit|clones|likes)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "Film list subpage";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/list/[^/]+/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Film list page";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/films/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Personal films page";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/(settings|watchlist|lists|activity)/") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Personal settings, watchlist, lists page, or activity";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/film/[^/]+/(\d+/)?/(likes)/") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "Viewing subpage";
  } else if (req.http.X-Supermodel-File ~ "^/[a-zA-Z0-9_]{2,15}/film/[^/]+/(\d+/)?") {
    set req.http.X-Letterboxd-Cacheable = "YES";
    set req.http.X-Letterboxd-Cacheable-Reason = "Viewing page";
  }

  unset req.http.X-Supermodel-File;
  
  if (!req.http.X-Letterboxd-Cacheable) {
    set req.http.X-Letterboxd-Cacheable = "UNKNOWN";
  }

  if (req.http.X-Letterboxd-Cacheable != "YES") {
    set req.http.X-Supermodel-Dont-Modify = "YES";
    return(pass);
  }

  # KVR: Check if the user is signed in
  if (req.http.Cookie ~ "(^|;\s*)com\.xk72\.webparts\.user(\.CURRENT)?=.*") {
    set req.http.X-Supermodel-User = "YES"; # Need this so we know whether the cache-control needs to be private
  }

  #LB
  set req.http.X-Letterboxd-Cookie-Set = "";
  if (req.http.X-Supermodel-Path ~ "(\?|&)esiAllowUser=true(&|$)" || req.http.X-Supermodel-Allow-User == "true") {
    set req.http.X-Letterboxd-Cookie-Set = req.http.X-Letterboxd-Cookie-Set + "USER ";
  }
  if (req.http.X-Supermodel-Path ~ "(\?|&)esiAllowFilters=true(&|$)") {
    set req.http.X-Letterboxd-Cookie-Set = req.http.X-Letterboxd-Cookie-Set + "FILTERS ";
  }
  if (!(req.http.X-Supermodel-Path ~ "(\?|&)esiAllowGeoip=true(&|$)")) {
    unset req.http.X-Supermodel-Country-Code;
    unset req.http.X-Supermodel-City;
  }

  #
  # Store original cookie
  #

  set req.http.X-Supermodel-Original-Cookie = req.http.Cookie;

  #
  # CSRF handling
  #

  if (!(req.http.Cookie ~ "(^|;\s*)com\.xk72\.webparts\.csrf=")) {
    # There isn't a CSRF so we generate one in VCL, as we strip cookies set by the backend.
    # We pass the CSRF back to the client as a Set-Cookie in vcl_deliver. That will only work if this
    # request is not an ESI, as ESI responses can't set headers.
    # As we may contain ESIs, which don't see any of the headers the parent request sets, we need to ensure
    # that the ESIs will generate the same CSRF. So we use properties of the request that the ESI will
    # have the same as the parent request. Note that req.xid is identical for parent requests and ESI requests.
    # This surprised the ESI tech support person. If that changes then this approach will break.
    #set req.http.X-Supermodel-Generated-CSRF = randomstr(20, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    set req.http.X-Supermodel-Generated-CSRF = regsub(digest.hash_sha1(client.ip + req.xid), "^(.{20}).*$", "\1");

    # Add it to the request cookie. Note that we may strip it below, but it's not there to not strip if appropriate.
    # So we will _always_ have a CSRF cookie.
    if (req.http.Cookie) {
      set req.http.Cookie = req.http.Cookie + "; com.xk72.webparts.csrf=" + req.http.X-Supermodel-Generated-CSRF;
    } else {
      set req.http.Cookie = "com.xk72.webparts.csrf=" + req.http.X-Supermodel-Generated-CSRF;
    }
  }

  #
  # Cookie handling
  #

  unset req.http.X-Supermodel-User-Stripped;
  unset req.http.X-Letterboxd-Filter-Stripped;

  # KVR: Only preserve some cookies
  if (req.http.Cookie) {
    # https://www.varnish-cache.org/trac/wiki/VCLExampleRemovingSomeCookies
    set req.http.Cookie = ";" + req.http.Cookie;
    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");

    #LB
    if (req.http.X-Letterboxd-Cookie-Set ~ "(^|\s)USER(\s|$)") {
      # For the user cookieSet we allow the user related cookies, and the CSRF to come through.
      set req.http.Cookie = regsuball(req.http.Cookie, ";(com\.xk72\.webparts\.user(\.CURRENT)?|com\.xk72\.webparts\.csrf)=", "; \1=");
    } else {
      set req.http.X-Supermodel-User-Stripped = "YES"; # Added by GRB
    }
    if (req.http.X-Letterboxd-Cookie-Set ~ "(^|\s)FILTERS(\s|$)") {
      set req.http.Cookie = regsuball(req.http.Cookie, ";(hideShortsFilter|hideUnreleasedFilter|hideWatchlistedFilter|watchedOrUnwatchedFilter)=", "; \1=");
    } else {
      set req.http.X-Letterboxd-Filter-Stripped = "YES"; # Added by GRB
    }

    set req.http.Cookie = regsuball(req.http.Cookie, ";(useMobileSite)=yes", "; \1=yes"); # Allow useMobileSite=yes
    set req.http.Cookie = regsuball(req.http.Cookie, ";(useMobileSite)=no", "; \1=no"); # Allow useMobileSite=no (don't allow the deprecated useMobileSite=undecided)
    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

    if (req.http.Cookie == "") {
        unset req.http.Cookie;
    }
  }

  # KVR: Remove all cookies from the request before sending to the backend, so we do not
  # personalise anything.
  #unset req.http.Cookie;

  return(hash);
}

sub normalize_req_url {
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

sub allow_esi {
  set req.http.X-Supermodel-ESI = "YES";
}

sub vcl_backend_response {
  if (bereq.http.X-Supermodel-ESI == "YES") {
    # KVR: We pass the X-Supermodel-ESI to the backend to let it know that we support ESI.
    set beresp.do_esi = true;

    if (bereq.http.X-Supermodel-Debug == "YES") {
      set beresp.http.X-Supermodel-ESI = "YES";
    }
    
    if (bereq.url ~ "^/esi/" && beresp.status != 200) {
      set beresp.status = 900;
      # synthetic("ESI content failed");
      return(deliver);
    }
  }

#--FASTLY FETCH START


# record which cache ran vcl_fetch for this object and when
  # set beresp.http.Fastly-Debug-Path = "(F " + server.identity + " " + now + ") " + if(beresp.http.Fastly-Debug-Path, beresp.http.Fastly-Debug-Path, "");

# generic mechanism to vary on something
  if (bereq.http.Fastly-Vary-String) {
    if (beresp.http.Vary) {
      set beresp.http.Vary = "Fastly-Vary-String, " + beresp.http.Vary;
    } else {
      set beresp.http.Vary = "Fastly-Vary-String, ";
    }
  }
  
    
    
#--FASTLY FETCH END

  if ((beresp.status == 401 && bereq.http.X-Supermodel-User-Stripped == "YES") && bereq.retries < 2 && (bereq.method == "GET" || bereq.method == "HEAD")) {
    set bereq.http.X-Supermodel-Allow-User = "true";
    return(retry);
  }

  if ((beresp.status == 500 || beresp.status == 503) && bereq.retries < 1 && (bereq.method == "GET" || bereq.method == "HEAD")) {
    return(retry);
  }
  
  if (bereq.retries > 0 ) {
    set beresp.http.Fastly-Restarts = bereq.retries;
  }

  # if (beresp.http.Content-Type ~ "^(text/html|text/plain|text/xml|text/css|application/xml|application/xhtml+xml|application/x-javascript|text/javascript|application/javascript|text/json|application/json)") {
  #   if (client.ip ~ debug) {
  #     set beresp.http.X-Supermodel-GZIP-Eligible = "YES";
  #   }

  #   if (req.http.X-Supermodel-Accept-Encoding ~ "gzip" && req.url ~ "budapest") {
  #     set beresp.gzip = true;

  #     if (client.ip ~ debug) {
  #       set beresp.http.X-Supermodel-GZIP = "YES";
  #     }
  #   }

  #   if (beresp.http.Vary) {
  #     set beresp.http.Vary = beresp.http.Vary ",Accept-Encoding";
  #   } else {
  #     set beresp.http.Vary = "Accept-Encoding";
  #   }
  # }

  set beresp.http.X-Backend = beresp.backend.name;

  if (bereq.http.X-Supermodel-Dont-Modify) {
    return (deliver);
  }

  #LB
  # KVR: Some server responses come back with a Cache-Control: private because they have user personalisation
  # however we want to cache them for this user.
  if (bereq.http.X-Letterboxd-Cookie-Set ~ "(^|\s)USER(\s|$)") {
    if (beresp.http.Cache-Control ~ "private") {
      set beresp.http.Cache-Control = regsuball(beresp.http.Cache-Control, "(^|,)\s*private\s*(,|$)", "");
      if (beresp.http.Cache-Control == "") {
        unset beresp.http.Cache-Control;
      }
      if (bereq.http.X-Supermodel-Debug == "YES") {
        set beresp.http.X-Letterboxd-Removed-Cache-Control-Private = "YES";
      }
    }
  }

  # KVR: If the response is private then we don't remove cookies, we just pass it through.
  if (beresp.http.Cache-Control ~ "private") {
    set bereq.http.Fastly-Cachetype = "PRIVATE";
    set beresp.uncacheable = true;
    set beresp.ttl = 0s;
    return (deliver);
  }

  # KVR: Remove any cookies set by the backend, so we remove any personalisation and we enable Varnish
  # to cache the response.
  unset beresp.http.Set-Cookie;
  set beresp.http.X-Supermodel-Removed-Set-Cookie = "YES";

  if (beresp.http.Set-Cookie) {
    set bereq.http.Fastly-Cachetype = "SETCOOKIE";
    set beresp.uncacheable = true;
    set beresp.ttl = 0s;
    return (deliver);
  }

  # KVR: If there was a user in the request, and we're using ESI, then there may be ESI components that contain
  # parts that have different cookie policies, so we must send a Cache-Control: private header to the browser.
  if (bereq.http.X-Supermodel-ESI == "YES" && bereq.http.X-Supermodel-User == "YES") {
    if (beresp.http.Cache-Control !~ "private") {
      if (beresp.http.Cache-Control) {
        set beresp.http.Cache-Control = beresp.http.Cache-Control + ", private";
      } else {
        set beresp.http.Cache-Control = "private";
      }
    }
  }

  if (beresp.status == 500 || beresp.status == 503) {
    set bereq.http.Fastly-Cachetype = "ERROR";
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return (deliver);
  }

  # KVR: Don't cache 404s etc for very long, as these are possibly new pages being created
  if (beresp.status >= 400 && beresp.status <= 499) {
    set bereq.http.Fastly-Cachetype = "NOTFOUND";
    set beresp.ttl = 10s;
    set beresp.grace = 30s;
    return (deliver);
  }

  if (beresp.http.Expires || beresp.http.Surrogate-Control ~ "max-age" || beresp.http.Cache-Control ~"(s-maxage|max-age)") {
    # keep the ttl here
    if (bereq.http.X-Supermodel-Debug == "YES") {
      set beresp.http.X-Supermodel-TTL-From-Backend = "YES";
    }
  } else if (bereq.http.X-Supermodel-Development == "YES") {
    # In development use a reduced TTL
    set beresp.ttl = 4h; #4h
    set beresp.grace = 15m; #15m
  } else {
    # apply the default ttl
    set beresp.ttl = 30d; #4h
    set beresp.grace = 15m;
  }

  return(deliver);
}

sub vcl_hit {
#--FASTLY HIT START

# we cannot reach obj.ttl and obj.grace in vcl_deliver, save them when we can in vcl_hit
  set req.http.Fastly-Tmp-Obj-TTL = obj.ttl;
  set req.http.Fastly-Tmp-Obj-Grace = obj.grace;

  {
    set req.http.Fastly-Cachetype = "HIT";

    
  }
#--FASTLY HIT END

  if (obj.ttl <= 0s) {
    return(pass);
  }

  return(deliver);
}

sub vcl_miss {
#--FASTLY MISS START

# this is not a hit after all, clean up these set in vcl_hit
  unset req.http.Fastly-Tmp-Obj-TTL;
  unset req.http.Fastly-Tmp-Obj-Grace;

  {
    if (req.http.Fastly-Check-SHA1) {
       return(synth(550, "Doesnt exist"));
    }
    
#--FASTLY BEREQ START
    # {
    #   if (req.http.Fastly-Original-Cookie) {
    #     set bereq.http.Cookie = req.http.Fastly-Original-Cookie;
    #   }
      
    #   if (req.http.Fastly-Original-URL) {
    #     set bereq.url = req.http.Fastly-Original-URL;
    #   }
    #   {
    #     if (req.http.Fastly-FF) {
    #       set bereq.http.Fastly-Client = "1";
    #     }
    #   }
    #   {
    #     # do not send this to the backend
    #     unset bereq.http.Fastly-Original-Cookie;
    #     unset bereq.http.Fastly-Original-URL;
    #     unset bereq.http.Fastly-Vary-String;
    #     unset bereq.http.X-Varnish-Client;
    #   }
    #   if (req.http.Fastly-Temp-XFF) {
    #      if (req.http.Fastly-Temp-XFF == "") {
    #        unset bereq.http.X-Forwarded-For;
    #      } else {
    #        set bereq.http.X-Forwarded-For = req.http.Fastly-Temp-XFF;
    #      }
    #      # unset bereq.http.Fastly-Temp-XFF;
    #   }
    # }
#--FASTLY BEREQ STOP


 #;

    set req.http.Fastly-Cachetype = "MISS";

    
  }
#--FASTLY MISS STOP

  return(fetch);
}

sub vcl_deliver {
#--FASTLY DELIVER START

# record the journey of the object, expose it only if req.http.Fastly-Debug.
  if (req.http.Fastly-Debug || req.http.Fastly-FF) {
    # set resp.http.Fastly-Debug-Path = "(D " + server.identity + " " + now + ") "
    #    if(resp.http.Fastly-Debug-Path, resp.http.Fastly-Debug-Path, "");

    # set resp.http.Fastly-Debug-TTL = if(obj.hits > 0, "(H ", "(M ")
    #    server.identity
    #    if(req.http.Fastly-Tmp-Obj-TTL && req.http.Fastly-Tmp-Obj-Grace, " " req.http.Fastly-Tmp-Obj-TTL " " req.http.Fastly-Tmp-Obj-Grace " ", " - - ")
    #    if(resp.http.Age, resp.http.Age, "-")
    #    ") "
    #    if(resp.http.Fastly-Debug-TTL, resp.http.Fastly-Debug-TTL, "");
  } else {
    unset resp.http.Fastly-Debug-Path;
    unset resp.http.Fastly-Debug-TTL;
  }

  # add or append X-Served-By/X-Cache(-Hits)
  {

    if(!resp.http.X-Served-By) {
      set resp.http.X-Served-By  = server.identity;
    } else {
      set resp.http.X-Served-By = resp.http.X-Served-By + ", " + server.identity;
    }

    # set resp.http.X-Cache = if(resp.http.X-Cache, resp.http.X-Cache ", ","") if(fastly_info.state ~ "HIT($|-)", "HIT", "MISS");

    if(!resp.http.X-Cache-Hits) {
      set resp.http.X-Cache-Hits = obj.hits;
    } else {
      set resp.http.X-Cache-Hits = resp.http.X-Cache-Hits + ", " + obj.hits;
    }

  }

  # if (req.http.X-Timer) {
  #   set resp.http.X-Timer = req.http.X-Timer ",VE" time.elapsed.msec;
  # }

  # VARY FIXUP
  {
    # remove before sending to client
    set resp.http.Vary = regsub(resp.http.Vary, "Fastly-Vary-String, ", "");
    if (resp.http.Vary ~ "^\s*$") {
      unset resp.http.Vary;
    }
  }
  unset resp.http.X-Varnish;


  # Pop the surrogate headers into the request object so we can reference them later
  set req.http.Surrogate-Key = resp.http.Surrogate-Key;
  set req.http.Surrogate-Control = resp.http.Surrogate-Control;

  # If we are not forwarding or debugging unset the surrogate headers so they are not present in the response
  if (!req.http.Fastly-FF && !req.http.Fastly-Debug) {
    unset resp.http.Surrogate-Key;
    unset resp.http.Surrogate-Control;
  }

  if(resp.status == 550) {
    return(deliver);
  }
  

  #default response conditions
    
      
                  

  
#--FASTLY DELIVER END

  if (resp.http.X-Supermodel-Removed-Set-Cookie) {
    call my_csrf;
  }

  if (client.ip ~ debug) {
    set resp.http.X-Supermodel-VCL-Version = "72";
    set resp.http.X-Supermodel-Cookie = req.http.Cookie;
    set resp.http.X-Supermodel-Original-Cookie = req.http.X-Supermodel-Original-Cookie;
    set resp.http.X-Supermodel-Path = req.http.X-Supermodel-Path;
    set resp.http.X-Supermodel-Dont-Modify = req.http.X-Supermodel-Dont-Modify;
    set resp.http.X-Supermodel-URL = req.url;
    set resp.http.X-Letterboxd-Cacheable = req.http.X-Letterboxd-Cacheable;
    set resp.http.X-Letterboxd-Cacheable-Reason = req.http.X-Letterboxd-Cacheable-Reason;

    #LB
    set resp.http.X-Letterboxd-Cookie-Set = req.http.X-Letterboxd-Cookie-Set;
  } else {
    unset resp.http.X-Supermodel-Removed-Set-Cookie;
  }
  return(deliver);
}

sub vcl_synth {
  if (resp.status == 900) {
    set resp.status = 200;
    set resp.http.Content-type = "text/plain";
    if (req.url ~ "-js/") {
      synthetic({"/* ESI error */ window.componentFailed = true; /* /ESI error */"});
    } else {
      synthetic({"<!-- ESI error "} + req.url + {" --><script>window.componentFailed = true;</script><!-- /ESI error -->"});
    }
    return(deliver);
  }

  return (deliver);
}

sub vcl_backend_error {
  if (bereq.http.Accept ~ "html") {
    set beresp.http.Content-Type = "text/html; charset=utf-8";
    
    synthetic({"
}
<!DOCTYPE html>
<html>
<head>
  <base href="/_maint/" />
  <title>Letterboxd</title>
  <meta charset="UTF-8" />
  
  <meta name="viewport" content="width=1024" />
  
  <style>
  
    /* Reset */
    html, body, div, span, applet, object, iframe,
    h1, h2, h3, h4, h5, h6, p, blockquote, pre,
    a, abbr, acronym, address, big, cite, code,
    del, dfn, em, font, img, ins, kbd, q, s, samp,
    small, strike, strong, sub, sup, tt, var,
    dl, dt, dd, ol, ul, li,
    fieldset, form, label, legend,
    table, caption, tbody, tfoot, thead, tr, th, td,
    article, aside, canvas, details, figcaption, figure, 
    footer, header, hgroup, menu, nav, section, summary,
    time, mark, audio, video {
      margin: 0; padding: 0; border: 0; outline: 0;
      font-weight: inherit; font-style: inherit; font-size: 100%; font-family: inherit;
      vertical-align: baseline;
    }
    :focus { outline: 0; }
    body { line-height: 1; color: black; background: white; }
    ol, ul { list-style: none; }
    article,aside,canvas,details,figcaption,figure,
    footer,header,hgroup,menu,nav,section,summary { display:block; }
    table { border-collapse: separate; border-spacing: 0; }
    caption, th, td { text-align: left; font-weight: normal; }
    blockquote:before, blockquote:after, q:before, q:after { content: ""; }
    blockquote, q { quotes: "" ""; }
  
    body.error {
      overflow: hidden;
      font-family: "Lucida Grande", "Lucida Sans Unicode", sans-serif;
    }

    body.error section.message {
      position: absolute; 
    }
    
    body.error h1 {
      width: 480px;
      height: 80px;
      margin: 0;
      background: url("logo-overlay.png");
    }
    
    body.error h1 a {
      display: block;
      height: 80px;
      text-indent: 110%;
      white-space: nowrap;
      overflow: hidden;
    }
    
    body.error p {
      margin: 0 0 10px 30px;
      font-size: 15px;
      line-height: 1.3;
    }
    
    body.error, body.error a {
      color: #FFF;
      color: rgba(255,255,255,0.75);
    }
    
    body.error p strong {
      font-size: 17px;
      font-weight: normal;
    }
    
    body.error p a {
      text-decoration: underline;
    }
    
    body.error p small a {
      font-size: 11px;
      text-decoration: none;
      color: #678;
    }
    
    body.error #bg {
      position:absolute;
      z-index: -1;
    }

    @media only screen and (-webkit-min-device-pixel-ratio: 2), only screen and (-o-min-device-pixel-ratio: 13/10), only screen and (min-resolution: 120dpi), only screen and (min-resolution: 2dppx) {
      body.error h1 {
        background-image: url('logo-overlay-2x.png') !important;
        -webkit-background-size: 480px 80px;
           -moz-background-size: 480px 80px;
                background-size: 480px 80px;
      }
    }
  </style>

  <script src="jquery-1.6.1.js"></script>
  <script src="jquery.fullscreenr.js"></script>
</head>

<body class="error message-light">

<section class="message">
  <h1><a href="http://letterboxd.com">Letterboxd</a></h1>

  <p><strong>Uh oh, we have gremlins in the control room&hellip;</strong><br/>
  Letterboxd is down due to an unscheduled technical outage. We&rsquo;ll be back soon!</p>

  <p><small><a href="http://letterboxd.com/film/gremlins/">Still from Joe Dante&rsquo;s Gremlins (1984)</a></small></p>
</section>

<script>
  $.fn.fullscreenr({width:1020, height:700, bgID:'#bg'});
</script>

<img src="gremlins.jpg" alt="Gremlins" id="bg"/>

</body>

</html>
    "});
    return (deliver);
  } else {
    synthetic({""});
    return (deliver);
  }

#--FASTLY ERROR START

  # if (beresp.status == 801) {
  #    set beresp.status = 301;
  #    set beresp.reason = "Moved Permanently";
  #    set beresp.http.Location = "https://" + req.http.host + req.url;
  #    synthetic({""});
  #    return (deliver);
  # }

      
                  
  # if (req.http.Fastly-Restart-On-Error) {
  #   if (beresp.status == 503 && req.restarts == 0) {
  #     return(retry);
  #   }
  # }

  # {
  #   if (obj.status == 550) {
  #     return(deliver);
  #   }
  # }
#--FASTLY ERROR END
}

sub vcl_pass {
#--FASTLY PASS START
  {
    
#--FASTLY BEREQ START
    {
      # if (req.http.Fastly-Original-Cookie) {
      #   set bereq.http.Cookie = req.http.Fastly-Original-Cookie;
      # }
      
      # if (req.http.Fastly-Original-URL) {
      #   set bereq.url = req.http.Fastly-Original-URL;
      # }
      # {
      #   if (req.http.Fastly-FF) {
      #     set bereq.http.Fastly-Client = "1";
      #   }
      # }
      # {
      #   # do not send this to the backend
      #   unset bereq.http.Fastly-Original-Cookie;
      #   unset bereq.http.Fastly-Original-URL;
      #   unset bereq.http.Fastly-Vary-String;
      #   unset bereq.http.X-Varnish-Client;
      # }
      # if (req.http.Fastly-Temp-XFF) {
      #    if (req.http.Fastly-Temp-XFF == "") {
      #      unset bereq.http.X-Forwarded-For;
      #    } else {
      #      set bereq.http.X-Forwarded-For = req.http.Fastly-Temp-XFF;
      #    }
      #    # unset bereq.http.Fastly-Temp-XFF;
      # }
    }
#--FASTLY BEREQ STOP


 #;
    set req.http.Fastly-Cachetype = "PASS";
  }
#--FASTLY PASS STOP
}

sub vcl_backend_fetch {
  call my_tidy_up_bereq;
  return (fetch);
}

sub my_tidy_up_bereq {
  # KVR: Remove headers that Fastly should have tidied up
  # KVR: Commented this out as I suspect it breaks shielding and causes loops inside Fastly.
  #unset bereq.http.Fastly-Temp-XFF;

  # KVR: Remove headers we've added for internal use that we don't need to send to the backend
  # unset bereq.http.X-Supermodel-Generated-CSRF;
  # unset bereq.http.X-Supermodel-Dont-Modify;
  unset bereq.http.X-Supermodel-Path;
  unset bereq.http.X-Supermodel-Development;
  # unset bereq.http.X-Supermodel-User; # We do not pass the X-Supermodel-User header to the backend, since it's an unreliable indicator of whether the user is still actually logged in
  unset bereq.http.X-Supermodel-Original-Cookie;
  unset bereq.http.X-Supermodel-Cookie-Domain;

  # We do not remove X-Supermodel-ESI, so the backend will know that we support ESI.

  # unset bereq.http.X-Letterboxd-Cookie-Set;
}

sub my_csrf {
  # KVR: Add CSRF cookie if the user didn't supply it. This is because we don't allow the server to set it (as it would be cached). The
  # server will accept the Fastly generated cookie from the client and use it client-side to set the CSRF fields in forms, and then to validate
  # posted forms.
  if (req.http.X-Supermodel-Generated-CSRF) {
    set resp.http.Set-Cookie = "com.xk72.webparts.csrf=" + req.http.X-Supermodel-Generated-CSRF + "; Path=/; HttpOnly; Domain=" + req.http.X-Supermodel-Cookie-Domain;
    if (client.ip ~ debug) {
      set resp.http.X-Supermodel-Generated-CSRF = "YES";
    }
  }
}

sub vcl_hash {
  {
    hash_data(req.url);
    hash_data(req.http.host);

#   No need to cache logged-in / logged-out separately, since the back end doesn't get this information anymore,
#   so it won't produce different templates.
#   Note that the cache-control will be private if there is a user cookie
#
#   # KVR: Cache differently for logged in vs not
#   if (req.http.X-Supermodel-User == "YES") {
#     set req.hash += "USER";
#   } else {
#     set req.hash += "ANON";
#   }

    # KVR: Cache differently according to cookies allowed through
    hash_data(req.http.Cookie);

    # KVR: Geolocation
    hash_data(req.http.X-Supermodel-Country-Code);
    hash_data(req.http.X-Supermodel-City);

    # KVR: Add to the hash any other things that affect the page output

    # For purge all
    if (req.url ~ "^/esi/.*/poster/" || req.url ~ "^/ajax/poster/") {
      /* Posters don't participate in a purge all - when posters need purging, update the version below */
      hash_data("poster.v1");
    } else {
      hash_data("#####GENERATION#####");
    }
    return (lookup);
  }
}

sub vcl_pipe {
#--FASTLY PIPE START
  {
    #  error 403 "Forbidden";      
    
#--FASTLY BEREQ START
    {
      if (req.http.Fastly-Original-Cookie) {
        set bereq.http.Cookie = req.http.Fastly-Original-Cookie;
      }
      
      if (req.http.Fastly-Original-URL) {
        set bereq.url = req.http.Fastly-Original-URL;
      }
      {
        if (req.http.Fastly-FF) {
          set bereq.http.Fastly-Client = "1";
        }
      }
      {
        # do not send this to the backend
        unset bereq.http.Fastly-Original-Cookie;
        unset bereq.http.Fastly-Original-URL;
        unset bereq.http.Fastly-Vary-String;
        unset bereq.http.X-Varnish-Client;
      }
      if (req.http.Fastly-Temp-XFF) {
         if (req.http.Fastly-Temp-XFF == "") {
           unset bereq.http.X-Forwarded-For;
         } else {
           set bereq.http.X-Forwarded-For = req.http.Fastly-Temp-XFF;
         }
         # unset bereq.http.Fastly-Temp-XFF;
      }
    }
#--FASTLY BEREQ STOP


    #;
    set req.http.Fastly-Cachetype = "PIPE";
    set bereq.http.connection = "close";
  }
#--FASTLY PIPE STOP

}
