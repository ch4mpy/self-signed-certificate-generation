I did not know about [mkcert](https://github.com/FiloSottile/mkcert) when I wrote this, you could consider using it instead of this script (but I'm not sure it is able to add the new certificate to several JDK/JRE cacerts file like the script below does).

# self-signed-certificate-generation
Generate self-signed certificate in various formats for your dev machine and adds it to the `cacerts` files of your JREs / JDKs. You may add as many `alt_names` (including IP adresses) and JDK/JRE as you want (for the new certificate to be added to `cacerts` file).

Ouput formats for generated certificate include :
- `.jks` for Java apps
- `.crt` and request key `.pem` for Angular dev-server
- `.pem` (certificate, no request key this time) to provide to spring-boot buildpacks (add your self-signed certificate to genreated docker images cacerts)

`.crt` can also be imported as root certificate authority in your OS so that web browser does not display errors nor warnings when browsing to https://localhost, https://{hostname} or any of the altnames you provided.

## How to use
Dead simple:

1. set `SERVER_SSL_KEY_PASSWORD` and `SERVER_SSL_KEY_STORE_PASSWORD` environment variables (must be identical due to pk12 limitations, so use one to set the other). For that:
  - on windows: go to `system properties` -> `environment variables` -> `user variables for xxx` set the following pairs:
    * `SERVER_SSL_KEY_PASSWORD` with a random value of your choice
    * `SERVER_SSL_KEY_STORE_PASSWORD` with `%SERVER_SSL_KEY_PASSWORD%` as value
    * `JAVA_HOME` pointing to the home directory of your default JDK (if not set already)
  - on OS X: edit ~/.zshenv or ~/.bash_profile or whatever your favourite shell uses to add:
    * `export SERVER_SSL_KEY_PASSWORD="change-m3-with-A-strong-paSsword!"`
    * `export SERVER_SSL_KEY_STORE_PASSWORD=$SERVER_SSL_KEY_PASSWORD`
    * `export JAVA_HOME=$(/usr/libexec/java_home)` (if not set already)
2. download the script from Github releases and run it:
```bash
curl https://github.com/ch4mpy/self-signed-certificate-generation/archive/refs/tags/1.0.1.zip  -O -J -L
unzip ./self-signed-certificate-generation-1.0.1.zip
touch ~/.ssh
cp ./self-signed-certificate-generation-1.0.1/self_signed.sh ~/.ssh/
rm -R ./self-signed-certificate-generation-1.0.1/ self-signed-certificate-generation-1.0.1.zip
cd ~/.ssh/
bash ./self_signed.sh
```
You'll be prompted to override defaults

On Windows, [Git-scm](https://git-scm.com/downloads) provides with bash. On Mac OS, it is provided by default.

## What to do after
**HOSTNAME** hereafter is to be replaced with any of the `alt_names` you provided when generating the certificate. Could be `localhost`, but I recommand the value of `HOSTNAME` environment variable on Windows or the output of `hostanme` on Linux / MacOS if using mobile test devices or Docker containers.

### OS
Import generated certificate as trusted root authority. This will remove errors and warnings from all your browsers when you navigate over https to any of the `altnames` you provided (localhost, $HOSTNAME, ...).

On Windows, this is done with `certmgr.msc`

On Mac, open `Keychain`, import the `.p12` file in your session certificates and then open it from `Keychain` to approve it in "trust" tab.

### Spring-boot
- export a `SERVER_SSL_KEY_STORE` environment variable pointing to the generated jks. Be aware that this will enable SSL by default for every spring-boot app on your host. If you prefer default to be "non-ssl", also define an environment variable called `SERVER_SSL_ENABLED` with value set to `false`. In both cases, default behaviour can be overriden by adding `spring.ssl.enabled` property on command line (command line args > environment variables > properties files).
- add `.pem` to your spring-boot projects `bindings/ca-certificates/` directory (along with a `type` file containing `ca-certificates`)

### DNS
If you don't already have a DNS for your test client to resolve your dev machine, you might install one like MaraDNS.
This is super useful for mobile phones, tablets, virtual devices, etc.

Here is the conf I use on my Windows laptop as sample:
```
#upstream_servers = {}
#upstream_servers["."]="8.8.8.8, 8.8.4.4" # Servers we connect to 
root_servers = {}
# ICANN DNS root servers 
root_servers["."]="198.41.0.4, 199.9.14.201, 192.33.4.12, 199.7.91.13,"
root_servers["."]+="192.203.230.10, 192.5.5.241, 192.112.36.4, "
root_servers["."]+="198.97.190.53, 192.36.148.17, 192.58.128.30, "
root_servers["."]+="193.0.14.129, 199.7.83.42, 202.12.27.33"
# local DNS server
root_servers["bravo-ch4mp."]="192.168.1.181"
root_servers["local."]="192.168.1.181"

# The IP this program has 
bind_address="127.0.0.1, 192.168.1.181, 192.168.1.132"

# The IPs allowed to connect and use the cache
recursive_acl = "127.0.0.1/16, 192.168.0.1/16"

chroot_dir = "/etc/maradns"

# This is the file Deadwood uses to read the cache to and from disk
cache_file = "dw_cache_bin"

filter_rfc1918 = 0

ip4 = {}
ip4["bravo-ch4mp."] = "192.168.1.181"

ip6 = {}
```

### Local services
Services you run on your dev machine (such as [keycloak](https://www.keycloak.org/server/enabletls)) should be configured to be served over https, using the certificates you generated. 

#### Angular
To run Angular apps with dev-server and https (change `HOSTNAME` below):
- edit npm `serve` target in `package.json` to add `--ssl --external --public-host='HOSTNAME' -c='HOSTNAME'`
- edit angular.json, for each app, under architect -> serve -> configurations, add (after editing HOSTNAME, USERNAME and APP_NAME):
  ```json
  "HOSTNAME": {
    "browserTarget": "APP_NAME:build:development",
    "host": "HOSTNAME",
    "ssl": true,
    "sslCert": "C:/Users/USERNAME/.ssh/HOSTNAME_self_signed.crt",
    "sslKey": "C:/Users/USERNAME/.ssh/HOSTNAME_req_key.pem"
  },
  ```
  
### Android
- create file `res/xml/network_security_config` such as (android resources names can not contain '-'):
    * `cleartextTrafficPermitted="false"` forces the use of https for all trafic
    * `<certificates src="@raw/bravo_ch4mp_self_signed"/>` is required only if certificate used by remote servers are self-signed (`res/raw/bravo_ch4mp_self_signed.crt` is the certificate with which my local API instance is served)
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
        <certificates src="@raw/bravo_ch4mp_self_signed"/>
        <certificates src="system"/>
        </trust-anchors>
    </base-config>
</network-security-config>
```
- Add `networkSecurityConfig` property to `application` tag in `AndroidManifest.xml`: 
```xml
<application
    ...
    android:networkSecurityConfig="@xml/network_security_config">
```
- Add / edit intent filters in AndroidManifest.xml for deep links to use https instead of http: 
``` xml
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="bravo-ch4mp" android:port="8100" />
    </intent-filter>

    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="bao-loc.c4-soft.com" />
    </intent-filter>
```

### Capacitor (and Ionic) 
Add this to `CapacitorConfig` in `projects/$APP_NAME/capacitor.config.ts`: 
```typescript
server: {
    hostname: 'localhost',
    androidScheme: 'https'
}
``` 
