# Letterboxd VCL

vcl 4.0;

import geoip;
import digest;
import directors;
import cookie;
import urlcode;
import header;

include "inc/backends.vcl";
include "inc/functions.vcl";
include "inc/custom.vcl";

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
  "123.100.90.137";
}

sub vcl_recv {
  /* Bans */
  if (req.method == "DELETE" && req.url ~ "^/surrogate-key/") {
    if (!client.ip ~ purge) {
      return(synth(403, "Not allowed."));
    }

    set req.http.X-Supermodel-Purge-Key = urlcode.decode(regsub(req.url, "^/surrogate-key/", ""));
    if (req.http.X-Supermodel-Purge-Key == "ALL") {
      ban("obj.http.Surrogate-Key != NEVER_PURGE_ME");
    } else {
      ban("obj.http.Surrogate-Key ~ (^|\s)" + req.http.X-Supermodel-Purge-Key + "($|\s)");
    }

    # Throw a synthetic page so the request won't go to the backend.
    return(synth(200, "Ban added"));
  }
   
  /* Backend server */
  set req.backend_hint = bar.backend();
  
# if (req.http.Host == "varnish.letterboxd.com" && req.url ~ "^/robots.txt") {
#   return(synth(902, "No robots"));
# }

  # KVR: force the Host so we can test with Varnish on any URL
  # set req.http.Host = "letterboxd.com";

  if (client.ip ~ debug) {
    set req.http.X-Supermodel-Debug = "YES";
  } else {
    unset req.http.X-Supermodel-Debug;
  }
  
  /* Clean request - avoids abuse from clients */
  unset req.http.X-Supermodel-Generated-CSRF;
  unset req.http.X-Supermodel-Dont-Modify;
  unset req.http.X-Supermodel-ESI;
  unset req.http.X-Supermodel-User;
  unset req.http.X-Letterboxd-Cacheable;
  unset req.http.X-Letterboxd-Cacheable-Reason;

  /* Geolocation - always add headers, and then remove if not allowed later */
  set req.http.X-Supermodel-Country-Code = geoip.country_code("" + client.ip);
  unset req.http.X-Supermodel-City; # We're not using City at the moment
  #set req.http.X-Supermodel-City = geoip.city;

  /* Backup original cookie */
  set req.http.X-Supermodel-Original-Cookie = req.http.Cookie;

  /* Normalize the request */
  call req_normalize_accept_encoding;

  # Request methods that do not get served from cache or doctored by vcl_fetch
  if (req.method != "HEAD" && req.method != "GET" && req.method != "PURGE") {
    set req.http.X-Letterboxd-Cacheable = "NO";
    set req.http.X-Letterboxd-Cacheable-Reason = "HTTP METHOD";

    set req.http.X-Supermodel-Dont-Modify = "YES";
    call req_allow_esi;
    return(pass);
  }

  /* Remove context paths on dev */
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

  /* Cookie domains */
  if (req.http.host ~ "letterboxd\.com$") {
    set req.http.X-Supermodel-Cookie-Domain = "letterboxd.com";
  } else if (req.http.host ~ "letterboxd-dev\.com$") {
    set req.http.X-Supermodel-Cookie-Domain = "letterboxd-dev.com";
  } else if (req.http.host ~ "^www\.") {
    set req.http.X-Supermodel-Cookie-Domain = regsub(req.http.host, "^www\.", "");
  } else {
    set req.http.X-Supermodel-Cookie-Domain = req.http.host;
  }

  # Remove Accept-Language as it affects our fmt:format* tags and we cache things containing them
  unset req.http.Accept-Language;

  # Remove User-Agent so there is no chance of doing anything special based upon it
  unset req.http.User-Agent;

  /* Normalize the request */
  call req_normalize_url;

  /* Static assets */
  if (req.http.X-Supermodel-Path ~ "^/static/" || req.http.X-Supermodel-Path ~ "^/assets/" || req.http.X-Supermodel-Path ~ "^/_maint/") {
    unset req.http.Cookie;
    unset req.http.X-Supermodel-Country-Code;
    unset req.http.X-Supermodel-City;
    return(hash);
  }

  # Allow ESI on everything that gets to this point.
  call req_allow_esi;

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

  #LB

  unset req.http.X-Supermodel-User-Stripped;
  unset req.http.X-Letterboxd-Filter-Stripped;

  set req.http.X-Letterboxd-Cookie-Set = "";
  set req.http.X-Supermodel-Cookies-Allowed = "X-this-string-cant-be-empty-or-no-filtering-occurs";
  if (req.http.X-Supermodel-Path ~ "(\?|&)esiAllowUser=true(&|$)" || req.http.X-Supermodel-Allow-User == "YES") {
    set req.http.X-Letterboxd-Cookie-Set = req.http.X-Letterboxd-Cookie-Set + "USER ";
    set req.http.X-Supermodel-Cookies-Allowed = req.http.X-Supermodel-Cookies-Allowed + ",com.xk72.webparts.csrf,com.xk72.webparts.user,com.xk72.webparts.user.CURRENT";
  } else {
    set req.http.X-Supermodel-User-Stripped = "YES";
  }
  if (req.http.X-Supermodel-Path ~ "(\?|&)esiAllowFilters=true(&|$)") {
    set req.http.X-Letterboxd-Cookie-Set = req.http.X-Letterboxd-Cookie-Set + "FILTERS ";
    set req.http.X-Supermodel-Cookies-Allowed = req.http.X-Supermodel-Cookies-Allowed + ",hideShortsFilter,hideUnreleasedFilter,hideWatchlistedFilter,watchedOrUnwatchedFilter";
  } else {
    set req.http.X-Letterboxd-Filter-Stripped = "YES";
  }
  if (!(req.http.X-Supermodel-Path ~ "(\?|&)esiAllowGeoip=true(&|$)")) {
    unset req.http.X-Supermodel-Country-Code;
    unset req.http.X-Supermodel-City;
  }

  /* Cookies */
  cookie.parse(req.http.Cookie);

  if (cookie.isset("com.xk72.webparts.user.CURRENT")) {
    set req.http.X-Supermodel-User = "YES"; # Need this so we know whether the cache-control needs to be private
  }

  if (!cookie.isset("com.xk72.webparts.csrf")) {
    /* CSRF
       There isn't a CSRF so we generate one in VCL, as we strip cookies set by the backend.
       We pass the CSRF back to the client as a Set-Cookie in vcl_deliver. That will only work if this
       request is not an ESI, as ESI responses can't set headers.
       As we may contain ESIs, which don't see any of the headers the parent request sets, we need to ensure
       that the ESIs will generate the same CSRF. So we use properties of the request that the ESI will
       have the same as the parent request. Note that req.xid is identical for parent requests and ESI requests.
       This surprised the ESI tech support person. If that changes then this approach will break.
     */
    #set req.http.X-Supermodel-Generated-CSRF = randomstr(20, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    set req.http.X-Supermodel-Generated-CSRF = regsub(digest.hash_sha1(client.ip + req.xid), "^(.{20}).*$", "\1");

    /* Add it to the request cookie. Note that we may strip it below, but it's not there to not strip if appropriate.
       So we will _always_ have a CSRF cookie.
     */
    cookie.set("com.xk72.webparts.csrf", req.http.X-Supermodel-Generated-CSRF);
  }

  set req.http.X-Letterboxd-UseMobileSite = cookie.get("useMobileSite");

  cookie.filter_except(req.http.X-Supermodel-Cookies-Allowed);

  if (req.http.X-Letterboxd-UseMobileSite == "yes") {
    cookie.set("useMobileSite", "yes");
  } else if (req.http.X-Letterboxd-UseMobileSite == "no") {
    cookie.set("useMobileSite", "no");
  }
  unset req.http.X-Letterboxd-UseMobileSite;

  set req.http.Cookie = cookie.get_string();
  cookie.clean();

  # KVR: Remove all cookies from the request before sending to the backend, so we do not
  # personalise anything.
  #unset req.http.Cookie;

  return(hash);
}

sub vcl_backend_response {
  # Check if we've indicated that this response is uncacheable
  if (bereq.http.X-Supermodel-Uncacheable == "YES") {
    set beresp.uncacheable = true;
  }

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

  if ((beresp.status == 500 || beresp.status == 503) && bereq.retries < 1 && (bereq.method == "GET" || bereq.method == "HEAD")) {
    return(retry);
  }
  
  if (bereq.retries > 0 ) {
    set beresp.http.X-Retries = bereq.retries;
  }

  set beresp.http.X-Backend = beresp.backend.name;

  if (bereq.http.X-Supermodel-Dont-Modify == "YES") {
    return (deliver);
  }

  #LB
  # KVR: Some server responses come back with a Cache-Control: private because they have user personalisation
  # however we want to cache them for this user.
  if (bereq.http.X-Letterboxd-Cookie-Set ~ "(^|\s)USER(\s|$)") {
    if (beresp.http.Cache-Control ~ "private") {
      header.remove(beresp.http.Cache-Control, "private");
      if (bereq.http.X-Supermodel-Debug == "YES") {
        set beresp.http.X-Letterboxd-Removed-Cache-Control-Private = "YES";
      }
    }
  }

  # KVR: If the response is private then we don't remove cookies, we just pass it through.
  if (beresp.http.Cache-Control ~ "private") {
    set beresp.uncacheable = true;
    set beresp.ttl = 0s;
    return (deliver);
  }

  # KVR: Remove any cookies set by the backend, so we remove any personalisation and we enable Varnish
  # to cache the response.
  unset beresp.http.Set-Cookie;
  set beresp.http.X-Supermodel-Removed-Set-Cookie = "YES";

  if (beresp.http.Set-Cookie) {
    set beresp.uncacheable = true;
    set beresp.ttl = 0s;
    return (deliver);
  }

  # KVR: If there was a user in the request, and we're using ESI, then there may be ESI components that contain
  # parts that have different cookie policies, so we must send a Cache-Control: private header to the browser.
  if (bereq.http.X-Supermodel-ESI == "YES" && bereq.http.X-Supermodel-User == "YES") {
    if (beresp.http.Cache-Control !~ "private") {
      header.append(beresp.http.Cache-Control, "private");

      if (bereq.http.X-Supermodel-Debug == "YES") {
        set beresp.http.X-Supermodel-Debug-Added-Cache-Control-Private = "YES";
      }
    }
  }

  if (beresp.status == 500 || beresp.status == 503) {
    set beresp.ttl = 1s;
    set beresp.grace = 5s;
    return (deliver);
  }

  # KVR: Don't cache 404s etc for very long, as these are possibly new pages being created
  if (beresp.status == 404) {
    set beresp.ttl = 10s;
    set beresp.grace = 30s;
    return (deliver);
  } else if (beresp.status >= 400 && beresp.status <= 499) {
    set beresp.ttl = 5m;
    set beresp.grace = 2m;
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
  set req.http.X-Cache-Type = "HIT";

  if (obj.ttl >= 0s) {
      // A pure unadultered hit, deliver it
      return (deliver);
  }
  if (obj.ttl + obj.grace > 0s) {
      // Object is in grace, deliver it
      // Automatically triggers a background fetch
      return (deliver);
  }
  // fetch & deliver once we get the result
  return (fetch);
}

sub vcl_miss {
  set req.http.X-Cache-Type = "MISS";

  return(fetch);
}

sub vcl_deliver {
  /* 401 support - handle forbidden responses where we have stripped the user details */
  if (resp.status == 401 && req.http.X-Supermodel-User-Stripped == "YES") {
    # Restart the request, not stripping the user details this time.
    set req.http.X-Supermodel-Allow-User = "YES";
    set req.http.Cookie = req.http.X-Supermodel-Original-Cookie;
    return(restart);
  }

  /* Info */
  header.append(resp.http.X-Served-By, server.identity);

  if (req.http.X-Cache-Type) {
    header.append(resp.http.X-Cache, req.http.X-Cache-Type);
  }

  header.append(resp.http.X-Cache-Hits, "" + obj.hits);

  unset resp.http.X-Varnish;

  # Pop the surrogate headers into the request object so we can reference them later
  set req.http.Surrogate-Key = resp.http.Surrogate-Key;
  set req.http.Surrogate-Control = resp.http.Surrogate-Control;

  if (resp.http.X-Supermodel-Removed-Set-Cookie) {
    call deliver_add_csrf;
  }

  if (client.ip ~ debug) {
    set resp.http.X-Supermodel-Debug-VCL-Version = "72";
    set resp.http.X-Supermodel-Debug-Cookie = req.http.Cookie;
    set resp.http.X-Supermodel-Debug-Original-Cookie = req.http.X-Supermodel-Original-Cookie;
    set resp.http.X-Supermodel-Debug-Path = req.http.X-Supermodel-Path;
    set resp.http.X-Supermodel-Debug-Dont-Modify = req.http.X-Supermodel-Dont-Modify;
    set resp.http.X-Supermodel-Debug-URL = req.url;

    #LB
    set resp.http.X-Letterboxd-Debug-Cookie-Set = req.http.X-Letterboxd-Cookie-Set;
    set resp.http.X-Letterboxd-Debug-Cacheable = req.http.X-Letterboxd-Cacheable;
    set resp.http.X-Letterboxd-Debug-Cacheable-Reason = req.http.X-Letterboxd-Cacheable-Reason;
  } else {
    /* Clean the response */
    unset resp.http.Surrogate-Key;
    unset resp.http.Surrogate-Control;

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
  } else if (resp.status == 902) {
    set resp.status = 200;
    set resp.http.Content-type = "text/plain";
    synthetic({"User-agent: *
Disallow: /"});
    return (deliver);
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
}

sub vcl_pass {
  set req.http.X-Cache-Type = "PASS";

  return (fetch);
}

sub vcl_backend_fetch {
  call fetch_tidy_bereq;
  return (fetch);
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
  set req.http.X-Cache-Type = "PIPE";

  # By default Connection: close is set on all piped requests, to stop
  # connection reuse from sending future requests directly to the
  # (potentially) wrong backend. If you do want this to happen, you can undo
  # it here.
  # unset bereq.http.connection;
  return (pipe);
}
