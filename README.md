# Addon Service Demo

This Sinatra based demo can be used as a basic addon service server to handle Addons.io provision, deprovision, plan change, and SSO requests.

Follow the [Addon service provider guidelines](https://addons.io/docs/addon-service-provider-guidelines) to create an addon service.

## Deploy

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/addonsio/addon-service-demo)

## Running locally

Clone the project from GitHub:

```
git clone https://github.com/addonsio/addon-service-demo.git
```

This demo requires setting your Addons.io addon service configuration:

1. Copy .env.example to .env and set the values to those of your addon service 

    ```bash
    cp .env.example .env
    ```

2. Run the server

    ```bash
    ruby server.rb
    ```

3. Create a public tunnel to your local server. You can use any tunneling utility out there. Here's an example for ngrok:
    
    ```bash
    ngrok http 9292
    ```

    You should get a publicly available URL that you can use to set as your addon service base and SSO URLs suffixed with `/addonsio/resources` and `/addonsio/sso` respectively.

