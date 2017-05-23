# frozen_string_literal: true

class Settings::OauthAuthenticationsController < ApplicationController
  layout 'admin'

  before_action :authenticate_user!
  before_action :reject_initial_password_usage, only: [:destroy]
  before_action :set_oauth_authentication, only: [:destroy]

  def index; end

  def destroy
    if @oauth_authentication.destroy
      flash[:notice] = t('oauth_authentications.successfully_unlinked')
    else
      flash[:alert] = t('oauth_authentications.failed_linking')
    end
    
    redirect_to action: :index
  end
  
  private

  def reject_initial_password_usage
    redirect_to action: :index if current_user.initial_password_usage
  end
  
  def set_oauth_authentication
    @oauth_authentication = current_user.oauth_authentications.find(params[:id])
  end
end
