# frozen_string_literal: true

class Auth::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include WithRedisSessionStore
  include Localized

  def twitter
    data = request.env['omniauth.auth']

    if signed_in?(:user)
      oauth_authentication = current_user.oauth_authentications.find_or_initialize_by(
        provider: data[:provider],
        uid: data[:uid],
        username: data[:info][:nickname],
        token: data[:credentials][:token],
        token_secret: data[:credentials][:secret]
      )

      if oauth_authentication.save
        flash[:notice] = t('oauth_authentications.successfully_linked')
      else
        flash[:alert] = oauth_authentication.errors.full_messages.first
      end
      
      redirect_to settings_oauth_authentications_path
    else
      oauth_authentication = OauthAuthentication.find_by(provider: data.provider, uid: data.uid)

      if oauth_authentication
        sign_in(oauth_authentication.user)
        redirect_to root_path
      else
        store_omniauth_auth
        redirect_to new_user_oauth_registration_path
      end
    end
  end
  
  private

  def store_omniauth_auth
    redis_session_store('devise.omniauth') do |redis|
      redis.setex('auth', 15.minutes, request.env['omniauth.auth'].to_json)
    end
  end
end
