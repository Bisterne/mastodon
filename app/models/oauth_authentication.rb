class OauthAuthentication < ApplicationRecord
  belongs_to :user, required: true

  validates :provider, :uid, presence: true
  validates :user_id, uniqueness: { scope: :provider }
  validates :provider, inclusion: Devise.omniauth_configs.keys.map(&:to_s)
  validates :uid, uniqueness: { scope: :provider }
  validate :prevent_create_if_two_factor_authentication_is_enabled

  before_destroy :prevent_destroy_if_initial_password_usage_is_exists

  private

  def prevent_destroy_if_initial_password_usage_is_exists
    throw(:abort) if user.initial_password_usage
  end
  
  def prevent_create_if_two_factor_authentication_is_enabled
    errors.add(:base, :enabled_two_factor_authentication) if user&.otp_required_for_login
  end
end
