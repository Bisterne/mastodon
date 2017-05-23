# frozen_string_literal: true

class User < ApplicationRecord
  include Settings::Extend

  devise :registerable, :recoverable,
         :rememberable, :trackable, :validatable, :confirmable,
         :two_factor_authenticatable, :two_factor_backupable,
         :omniauthable,
         otp_secret_encryption_key: ENV['OTP_SECRET'],
         otp_number_of_backup_codes: 10

  belongs_to :account, inverse_of: :user, required: true
  has_many :oauth_authentications, dependent: :destroy
  has_one :initial_password_usage, dependent: :destroy
  accepts_nested_attributes_for :account

  validates :locale, inclusion: I18n.available_locales.map(&:to_s), unless: 'locale.nil?'
  validates :email, email: true

  scope :recent,    -> { order('id desc') }
  scope :admins,    -> { where(admin: true) }
  scope :confirmed, -> { where.not(confirmed_at: nil) }

  after_update :delete_initial_password_usage, if: :encrypted_password_changed?

  def confirmed?
    confirmed_at.present?
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def setting_default_privacy
    settings.default_privacy || (account.locked? ? 'private' : 'public')
  end

  def setting_boost_modal
    settings.boost_modal
  end

  def setting_auto_play_gif
    settings.auto_play_gif
  end

  private

  def delete_initial_password_usage
    initial_password_usage&.destroy!
  end
end
