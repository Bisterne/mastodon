# frozen_string_literal: true

# FIXME
require 'type_attributes'

class Form::OauthRegistration
  include ActiveModel::Model
  include TypeAttributes

  PRIVATE_USER_NAME = /\Auser_/

  attr_accessor :user, :avatar, :locale
  attr_accessor :provider, :uid

  type_attribute :email, :string
  type_attribute :username, :string
  type_attribute :twitter_username, :string
  type_attribute :token, :string
  type_attribute :token_secret, :string

  validate :validate_user

  class << self
    def from_omniauth_auth(omniauth_auth)
      case omniauth_auth['provider']
      when 'twitter'
        new(
          provider: 'twitter',
          uid: omniauth_auth['uid'],
          email: omniauth_auth['info']['email'],
          username: normalize_username(omniauth_auth['info']['nickname']),
          avatar: fetch_twitter_avatar(omniauth_auth['info']['image']),
          twitter_username: omniauth_auth['info']['nickname'],
          token: omniauth_auth['credentials']['token'],
          token_secret: omniauth_auth['credentials']['secret']
        )
      else
        new
      end
    end

    private

    # Normalize username for format validator of Account#username
    def normalize_username(string)
      username = string.to_s.tr('-', '_').remove(/[^a-z0-9_]/i, '')
      username unless username.match?(PRIVATE_USER_NAME)
    end

    def fetch_twitter_avatar(url)
      image = OpenURI.open_uri(url, 'Referer' => "https://#{Rails.configuration.x.local_domain}")
      account = Account.new(avatar: image)
      account.valid?
      account.avatar unless account.errors.key?(:avatar)
    rescue
      nil
    end
  end

  def email=(value)
    @email = value
  end

  def save
    return false if invalid?

    ApplicationRecord.transaction do
      self.user = User.new(user_attributes)
      oauth_authentication = user.oauth_authentications.build(
        provider: provider,
        uid: uid,
        username: twitter_username,
        token: token,
        token_secret: token_secret
      )
      user.save! && user.create_initial_password_usage! && oauth_authentication.save!
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  private

  def validate_user
    user = User.new(user_attributes)
    user.valid?

    [user, user.account].each do |record|
      record.errors.each do |key, value|
        errors.add(key, value) if respond_to?(key)
      end
    end
  end

  def user_attributes
    password = SecureRandom.base64

    {
      email: email,
      locale: locale,
      password: password,
      account_attributes: {
        username: username,
        avatar: avatar
      }
    }
  end
end
