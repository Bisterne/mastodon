# frozen_string_literal: true

class Auth::RegistrationsController < Devise::RegistrationsController
  layout :determine_layout

  before_action :check_enabled_registrations, only: [:new, :create]
  before_action :configure_sign_up_params, only: [:create]

  def update
    if current_user.initial_password_usage
      send_reset_password_instructions
    else
      super
    end
  end
  

  protected

  def send_reset_password_instructions
    _resource = resource_class.send_reset_password_instructions(email: current_user.email)

    if successfully_sent?(_resource)
      sign_out :user
      redirect_to edit_user_registration_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def build_resource(hash = nil)
    super(hash)
    resource.locale = I18n.locale
    resource.build_account if resource.account.nil?
  end

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up) do |u|
      u.permit({ account_attributes: [:username] }, :email, :password, :password_confirmation)
    end
  end

  def after_sign_up_path_for(_resource)
    new_user_session_path
  end

  def after_inactive_sign_up_path_for(_resource)
    new_user_session_path
  end

  def check_enabled_registrations
    redirect_to root_path if single_user_mode? || !Setting.open_registrations
  end

  private

  def determine_layout
    %w(edit update).include?(action_name) ? 'admin' : 'auth'
  end
end
