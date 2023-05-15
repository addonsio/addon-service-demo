# server.rb
#
# Use this sample code to handle Addons.io addon service provision, de-provision, plan change, and SSO requests.
#
# 1) Install dependencies
#   bundle install
#
# 2) Run the server on http://localhost:9292
#   ruby server.rb
#
# 3) Configure your addon service to use http://localhost:9292/addonsio/resources as the base URL
#
# 4) Configure your addon service to use http://localhost:9292/addonsio/sso as the SSO URL
#  Note: The SSO URL is only required if you want to enable SSO for your addon service
#

require 'json'
require 'sinatra'
require 'addons-api'
require 'dotenv/load'

# Set settings
set :slug, ENV['ADDON_SERVICE_SLUG']
set :password, ENV['ADDON_SERVICE_PASSWORD']
set :oauth_client_secret, ENV['ADDON_SERVICE_CLIENT_SECRET']
set :sso_salt, ENV['ADDON_SERVICE_SSO_SALT']

set :default_content_type, :json

# If provisioning takes more than 30 seconds, use the asynchronous provisioning pattern
asynchronous_provisioning = (ENV.fetch('ADDON_SERVICE_ASYNC_PROVISIONING') { false }) == 'true'

# Set the port to listen on. $PORT will override it.
set :port, ENV.fetch('PORT') { 9292 }

# Enable sessions for the sake of this demo
enable :sessions

helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [settings.slug, settings.password]
  end
end

#
# Provision
#
post '/addonsio/resources' do
  # Provision endpoint is protected by Addons.io API authentication
  protected!

  begin
    payload = JSON.parse(request.body.read)

    # Persist metadata and issue a response
    # ...
    
    # Exchange OAuth grant for an access token
    if settings.oauth_client_secret && payload['oauth_grant']
      client = AddonsApi::Client.connect

      token = client.oauth.token.create({
        secret: settings.oauth_client_secret
      }, payload['oauth_grant']['code'])
      # Do something with the token, like updating configuration variables
      # or following asynchronous provisioning
    end

    # Provision the necessary resources on your end
    # If it takes more than 30 seconds, consider using the asynchronous provisioning pattern
    # ...
    # Lear more on https://addons.io/docs/addon-service-provider-guidelines#provision

    if asynchronous_provisioning
      # Return a 202 Accepted response with your internal resource id
      body JSON.dump({
        # In this example, use the uuid provided by Addons.io. You can use your own id if you prefer.
        id: payload['uuid'], 
        message: "Your add-on is being provisioned. It will be available shortly.",
      })

      # Return a 202 Accepted response
      # In this case you will have to callback to Addons.io when provisioning is complete,
      # usually by using a background job.
      status 202
      return
    else
      # Return a 201 Created response with your internal resource id
      body JSON.dump({
        # In this example, use the uuid provided by Addons.io. You can use your own id if you prefer.
        id: payload['uuid'], 
        message: "Wooohoo! Your add-on is all set up and ready to be used!",
        # Provide the config vars and log drain url
        config: {
          "API_KEY": SecureRandom.uuid,
          "URL": "https://#{SecureRandom.hex}:#{SecureRandom.hex}@#{settings.slug}.com",
        },
        log_drain_url: "syslog://stream.#{settings.slug}.com"
      })

      # Return a 201 Created response
      status 201
      return
    end

  rescue UnprocessableEntityError, JSON::ParserError
    # Invalid payload. Return unprocessable entity.
    body JSON.dump({
      message: "Invalid payload."
    })

    # Return a 422 Unprocessable Entity response
    status 422
    return
  end
end

#
# Plan change
#
put '/addonsio/resources/:uuid' do
  # Plan change endpoint is protected by Addons.io API authentication
  protected!

  begin
    payload = JSON.parse(request.body.read)

    # Change the plan internally using payload['plan'] and params[:uuid]
    # ...

    # Return a 200 OK response
    body JSON.dump({
      message: "Wooohoo! Your add-on plan has been changed!",
    })

    status 200
    return

  rescue NotFoundError => e
    # Return a 404 Not Found response
    status 404
    return
    
  rescue UnprocessableEntityError, JSON::ParserError
    # Return a 422 
    body JSON.dump({
      message: "Unprocessable entity."
    })
    
    # Return a 422 Unprocessable Entity response
    status 422
    return
  end
end

#
# Deprovision
#
delete '/addonsio/resources/:uuid' do
  # Deprovision endpoint is protected by Addons.io API authentication
  protected!

  begin
    # Delete the resource from your system using params[:uuid]
    # ...

    # Return a 204 No Content response
    status 204
    return

  rescue NotFoundError => e
    # Return a 404 Not Found response
    status 404
    return

  rescue UnprocessableEntityError, JSON::ParserError
    # Return a 422 
    body JSON.dump({
      message: "Unprocessable entity."
    })
    status 422
    return

  rescue
    # Return a 410 Gone response
    status 410
    return

  end
end

#
# SSO
#
post '/addonsio/sso' do
  content_type :html

  # SSO endpoint is not protected by Addons.io API authentication
  begin
    # Verify the SSO request
    if !verify_sso(
      params['resource_id'], 
      timestamp = params['timestamp'], 
      params['resource_token'], 
      settings.sso_salt
    )
      # Return a forbidden error page
      body "Forbidden."
      status 200
      return
    end
    
    # Verify the requested resource exists using params['resource_id']
    # ...

    # Create a session for the user using params['user_id'] and params['user_email']
    # You can use any session management library you prefer.
    # For the sake of this demo, we'll just store the 
    # user email in the session to be used in the dashboard.
    # ...
    session[:user_email] = params['user_email']

    # Redirect to the dashboard
    redirect to('/dashboard'), 302
    return

  rescue NotFoundError => e
    # Return a 404 Not Found response
    body "Not found."
    status 200
    return
      
  rescue UnprocessableEntityError, JSON::ParserError
    # Return a 422
    body "Unprocessable entity."
    status 200
    return

  rescue Exception => e
    # Return a 403 Forbidden response
    body "Forbidden."
    status 200
    return
  end
end

# Dashboard
get '/dashboard' do
  content_type :html

  # You should validate the user's session here.
  # Return a 200 OK response with some dashboard content.
  if session[:user_email]
    body "<h1>Hello #{session[:user_email]}!</h1><div>This is your dashboard!</div>"

    status 200
    return
  else
    # Return a 403 Forbidden response
    status 403
    return    
  end
end

class UnprocessableEntityError < StandardError; end
class NotFoundError < StandardError; end

def verify_sso(resource_id, timestamp, resource_token, sso_salt)
  # Create pre token to compare to
  pre_token = resource_id + ":" + sso_salt + ":" + timestamp
  token = Digest::SHA1.hexdigest(pre_token).to_s

  # Forbidden unless token is valid
  if token != resource_token
    return false
  end

  # Forbidden unless timestamp is within a 2 minute grace period
  if timestamp.to_i < (Time.now - 2*60).to_i
    return false
  end

  # SSO verified
  return true
end