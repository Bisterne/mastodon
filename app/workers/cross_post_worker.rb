# frozen_string_literal: true

class CrossPostWorker
  include Sidekiq::Worker

  def perform(status_id)
    status = Status.find(status_id)

    token = oauth_authentication(status.account.user)
    return true unless token

    client = twitter_client(token.token, token.token_secret)

    text = status.text
    return true if text =~ /\A@/

    text = text.gsub(/https:\/\/3\.nu\/media\/[\w\-]+/, '')
    text = text.strip
    if text.length > 140
      text = text.slice(0, 139) + '…'
    end

    media_ids = []
    status.media_attachments.each do |media_attachment|
      open(media_attachment.file.path) do |media|
        media_ids << client.upload(media)
      end
    end

    if media_ids.empty?
      client.update(text)
    else
      client.update(text, {media_ids: media_ids.join(',')})
    end

  rescue ActiveRecord::RecordNotFound, Twitter::Error::Unauthorized
    true
  end

  private

  def twitter_client(token, token_secret)    
    Twitter::REST::Client.new do |config|
      config.consumer_key        = Rails.application.secrets.oauth['twitter']['key']
      config.consumer_secret     = Rails.application.secrets.oauth['twitter']['secret']
      config.access_token        = token
      config.access_token_secret = token_secret
    end
  end

  def oauth_authentication(user)
    user.oauth_authentications.find {|oauth_authentication| oauth_authentication.provider == 'twitter' }
  end
end
