sub synthetic_gremlins {
  synthetic({"
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
}
