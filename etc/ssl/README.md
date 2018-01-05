# Letterboxd SSL

## Renew wildcard SSL

We use namecheap.com to purchase and renew our wildcard SSL certificates for *.letterboxd.com and *.ltrbxd.com.

Create a new year directory inside the appropriate domain directory:

```
openssl req -new -nodes -sha256 -newkey rsa:2048 -keyout server.key -out server.csr
```

### *.letterboxd.com

Answers to prompts:

```
Country Name (2 letter code) [AU]:NZ
State or Province Name (full name) [Some-State]:Auckland
Locality Name (eg, city) []:Auckland
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Letterboxd Ltd
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:*.letterboxd.com
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

### *.ltrbxd.com

Answers to prompts:

* As for *.letterboxd.com, except answer *.ltrbxd.com for Common Name.

### Namecheap process

* Use Email verification to admin@letterboxd.com or ops@letterboxd.com for both domains, which comes to karl@cactuslab.com.
* Company Contacts
  * Company Name: Letterboxd Ltd
  * DUNS: 59-172-6521
  * City of Incorporation: Auckland
  * State of Incorporation: Auckland
  * Country of Incorporation: New Zealand
  * Address: 27 Gillies Ave
  * Address 2: Newmarket
  * PO Box: PO Box 99280
  * City: Auckland
  * State: Auckland
  * ZIP: 1023
  * Country: New Zealand
* Administrative Contacts:
  * Use your own email

### Files

Receive the certificates and CA bundles from Namecheap via email to the administrative contact entered above. Save
as `ca-bundle-crt` and `server.crt` in the appropriate folder.

Create a new file in each named `server.pem` as the concatenation of `server.crt` and `ca-bundle.crt`.

### Deploy

Deploy the letterboxd-scripts to all servers:

```
init/sync-init.sh
```

On the Nginx server:

```
nginx -t && service nginx reload
```

Then test that https://letterboxd.com/ is using the new certiticate, with the new expiry date.

On each app server:

```
apache2ctl configtest && apache2ctl graceful
```

Then test that https://app1.letterboxd.com/ (and for each app server) is using the new certificate, with the new expiry date.

On keycdn.com:

* Login to https://keycdn.com/ 
* Go to the Zones tab, and for each zone:
  * Edit the Zone, tick Show Advanced Features
  * Paste the contents of `server.pem` into Custom SSL Certificate, and `server.key` into Custom SSL Private Key.
  * Save

Wait for the zones to deploy and then test by loading letterboxd.com and checking the certificates on ltrbxd.com using Charles.

Also can find URLs in the source and check them, e.g. https://a.ltrbxd.com/resized/sm/upload/w0/2k/p7/zb/3NLah2aBe1c9iTbDcO07raCb9At-0-230-0-345-crop.jpg
