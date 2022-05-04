# self-signed-certificate-generation
Generate self-signed certificate in various formats for the desktop your developping on.
This script lets you add as many altnames and JDK/JRE cacerts files to update, as you want.

Ouput formats for generated certificate include :
- `.jks` for Java apps
- `.crt` and request key `.pem` for Angular dev-server
- `.pem` (certificate, no request key this time) to provide to spring-boot buildpacks (add your self-signed certificate to genreated docker images cacerts)

`.crt` can also be imported as root certificate authority in your OS so that web browser does not display errors nor warnings when browsing to https://localhost, https://{hostname} or any of the altnames you provided.

## How to use
Dead simple:
- copy `self_signed.sh` to where you want certificates to be generated
- cd to where you copied `self_signed.sh`
- run `bash ./self_signed.sh`
- override defaults on command prompts

## What to do after
`HOSTNAME` hereafter is to be replaced with "HOSTNAME" environment variable on Windows or the output of `hostanme` on Linux / MacOS
- export a `SERVER_SSL_KEY_STORE` environment variable pointing to the generated jks. Be aware that this will enable SSL by default for every spring-boot app on your host. If you prefer default to be "non-ssl", also define an environment variable called `SERVER_SSL_ENABLED` with value set to `false`. In both cases, default behaviour can be overriden by adding `spring.ssl.enabled` property on command line (command line args > environment variables > properties files).
- install generated certificated as "trusted root authority" (use `certmgr.msc` on Windows)
- add `.pem` to your spring-boot projects `bindings/ca-certificates/` directory (along with a `type` file containing `ca-certificates`)
- configure your local services (such as [keycloak](https://www.keycloak.org/docs/latest/server_installation/index.html#_setting_up_ssl)) to use this certificates
- configure Angular apps to be served over `https`:
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
- Configure Android or iOS app deep links.
  To do it on Android:
  - Add intent filters in AndroidManifest.xml such as: 
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
- Configure Android or iOS app to use https.
  To do it on Android:
  - Add this to `CapacitorConfig` in `projects/$APP_NAME/capacitor.config.ts`: 
    ```typescript
    server: {
        hostname: 'localhost',
        androidScheme: 'https'
    }
    ```
  - create file `res/xml/network_security_config` such as (android resources names can not contain '-'):
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
    Here:
    - `cleartextTrafficPermitted="false"` forces the use of https for all trafic
    - `<certificates src="@raw/bravo_ch4mp_self_signed"/>` is required only if certificate used by remote servers are self-signed (`res/raw/bravo_ch4mp_self_signed.crt` is the certificate with which my local API instance is served)
  - Add `networkSecurityConfig` property to `application` tag in `AndroidManifest.xml`: 
    ```xml
    <application
        ...
        android:networkSecurityConfig="@xml/network_security_config">
    ```
