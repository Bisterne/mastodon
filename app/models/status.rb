# frozen_string_literal: true

class Status < ApplicationRecord
  include Paginable
  include Streamable
  include Cacheable

  enum visibility: [:public, :unlisted, :private, :direct], _suffix: :visibility

  belongs_to :application, class_name: 'Doorkeeper::Application'

  belongs_to :account, inverse_of: :statuses, counter_cache: true, required: true
  belongs_to :in_reply_to_account, foreign_key: 'in_reply_to_account_id', class_name: 'Account'

  belongs_to :thread, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :replies
  belongs_to :reblog, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblogs, counter_cache: :reblogs_count

  has_many :favourites, inverse_of: :status, dependent: :destroy
  has_many :reblogs, foreign_key: 'reblog_of_id', class_name: 'Status', inverse_of: :reblog, dependent: :destroy
  has_many :replies, foreign_key: 'in_reply_to_id', class_name: 'Status', inverse_of: :thread
  has_many :mentions, dependent: :destroy
  has_many :media_attachments, dependent: :destroy
  has_and_belongs_to_many :tags

  has_one :notification, as: :activity, dependent: :destroy
  has_one :preview_card, dependent: :destroy

  validates :uri, uniqueness: true, unless: 'local?'
  validates :text, presence: true, unless: 'reblog?'
  validates_with StatusLengthValidator
  validates :reblog, uniqueness: { scope: :account }, if: 'reblog?'

  default_scope { order('id desc') }

  scope :remote, -> { where.not(uri: nil) }
  scope :local, -> { where(uri: nil) }

  scope :without_replies, -> { where('statuses.reply = FALSE OR statuses.in_reply_to_account_id = statuses.account_id') }
  scope :without_reblogs, -> { where('statuses.reblog_of_id IS NULL') }
  scope :with_public_visibility, -> { where(visibility: :public) }
  scope :tagged_with, ->(tag) { joins(:statuses_tags).where(statuses_tags: { tag_id: tag }) }
  scope :local_only, -> { left_outer_joins(:account).where(accounts: { domain: nil }) }
  scope :excluding_silenced_accounts, -> { left_outer_joins(:account).where(accounts: { silenced: false }) }
  scope :including_silenced_accounts, -> { left_outer_joins(:account).where(accounts: { silenced: true }) }
  scope :not_excluded_by_account, ->(account) { where.not(account_id: account.excluded_from_timeline_account_ids) }

  cache_associated :application, :media_attachments, :tags, :stream_entry, mentions: { account: :oauth_authentications }, reblog: [{ account: :oauth_authentications }, :application, :stream_entry, :tags, :media_attachments, mentions: { account: :oauth_authentications }], thread: { account: :oauth_authentications }, account: :oauth_authentications

  def reply?
    !in_reply_to_id.nil? || super
  end

  def local?
    uri.nil?
  end

  def reblog?
    !reblog_of_id.nil?
  end

  def verb
    reblog? ? :share : :post
  end

  def object_type
    reply? ? :comment : :note
  end

  def proper
    reblog? ? reblog : self
  end

  def content
    proper.text
  end

  def target
    reblog
  end

  def title
    reblog? ? "#{account.acct} shared a status by #{reblog.account.acct}" : "New status by #{account.acct}"
  end

  def hidden?
    private_visibility? || direct_visibility?
  end

  def permitted?(other_account = nil)
    if direct_visibility?
      account.id == other_account&.id || mentions.where(account: other_account).exists?
    elsif private_visibility?
      account.id == other_account&.id || other_account&.following?(account) || mentions.where(account: other_account).exists?
    else
      other_account.nil? || !account.blocking?(other_account)
    end
  end

  def ancestors(account = nil)
    ids      = Rails.cache.fetch("ancestors:#{id}") { (Status.find_by_sql(['WITH RECURSIVE search_tree(id, in_reply_to_id, path) AS (SELECT id, in_reply_to_id, ARRAY[id] FROM statuses WHERE id = ? UNION ALL SELECT statuses.id, statuses.in_reply_to_id, path || statuses.id FROM search_tree JOIN statuses ON statuses.id = search_tree.in_reply_to_id WHERE NOT statuses.id = ANY(path)) SELECT id FROM search_tree ORDER BY path DESC', id]) - [self]).pluck(:id) }
    statuses = Status.where(id: ids).group_by(&:id)
    results  = ids.map { |id| statuses[id].first }
    results  = results.reject { |status| filter_from_context?(status, account) }

    results
  end

  def descendants(account = nil)
    ids      = (Status.find_by_sql(['WITH RECURSIVE search_tree(id, path) AS (SELECT id, ARRAY[id] FROM statuses WHERE id = ? UNION ALL SELECT statuses.id, path || statuses.id FROM search_tree JOIN statuses ON statuses.in_reply_to_id = search_tree.id WHERE NOT statuses.id = ANY(path)) SELECT id FROM search_tree ORDER BY path', id]) - [self]).pluck(:id)
    statuses = Status.where(id: ids).group_by(&:id)
    results  = ids.map { |id| statuses[id].first }
    results  = results.reject { |status| filter_from_context?(status, account) }

    results
  end

  def non_sensitive_with_media?
    !sensitive? && media_attachments.any?
  end

  class << self
    def as_home_timeline(account)
      where(account: [account] + account.following)
    end

    def as_public_timeline(account = nil, local_only = false)
      query = timeline_scope(local_only).without_replies

      apply_timeline_filters(query, account)
    end

    def as_tag_timeline(tag, account = nil, local_only = false)
      query = timeline_scope(local_only).tagged_with(tag)

      apply_timeline_filters(query, account)
    end

    def as_outbox_timeline(account)
      where(account: account, visibility: :public)
    end

    def favourites_map(status_ids, account_id)
      Favourite.select('status_id').where(status_id: status_ids).where(account_id: account_id).map { |f| [f.status_id, true] }.to_h
    end

    def reblogs_map(status_ids, account_id)
      select('reblog_of_id').where(reblog_of_id: status_ids).where(account_id: account_id).map { |s| [s.reblog_of_id, true] }.to_h
    end

    def reload_stale_associations!(cached_items)
      account_ids = []

      cached_items.each do |item|
        account_ids << item.account_id
        account_ids << item.reblog.account_id if item.reblog?
      end

      accounts = Account.where(id: account_ids.uniq).map { |a| [a.id, a] }.to_h

      cached_items.each do |item|
        item.account = accounts[item.account_id]
        item.reblog.account = accounts[item.reblog.account_id] if item.reblog?
      end
    end

    def permitted_for(target_account, account)
      return where.not(visibility: [:private, :direct]) if account.nil?

      if target_account.blocking?(account) # get rid of blocked peeps
        none
      elsif account.id == target_account.id # author can see own stuff
        all
      elsif account.following?(target_account) # followers can see followers-only stuff, but also things they are mentioned in
        joins('LEFT OUTER JOIN mentions ON statuses.id = mentions.status_id AND mentions.account_id = ' + account.id.to_s)
          .where('statuses.visibility != ? OR mentions.id IS NOT NULL', Status.visibilities[:direct])
      else # non-followers can see everything that isn't private/direct, but can see stuff they are mentioned in
        joins('LEFT OUTER JOIN mentions ON statuses.id = mentions.status_id AND mentions.account_id = ' + account.id.to_s)
          .where('statuses.visibility NOT IN (?) OR mentions.id IS NOT NULL', [Status.visibilities[:direct], Status.visibilities[:private]])
      end
    end

    private

    def timeline_scope(local_only = false)
      starting_scope = local_only ? Status.local_only : Status
      starting_scope
        .with_public_visibility
        .without_reblogs
    end

    def apply_timeline_filters(query, account)
      if account.nil?
        filter_timeline_default(query)
      else
        filter_timeline_for_account(query, account)
      end
    end

    def filter_timeline_for_account(query, account)
      query = query.not_excluded_by_account(account)
      query.merge(account_silencing_filter(account))
    end

    def filter_timeline_default(query)
      query.excluding_silenced_accounts
    end

    def account_silencing_filter(account)
      if account.silenced?
        including_silenced_accounts
      else
        excluding_silenced_accounts
      end
    end
  end

  before_validation do
    text&.strip!
    spoiler_text&.strip!

    self.reply                  = !(in_reply_to_id.nil? && thread.nil?) unless reply
    self.reblog                 = reblog.reblog if reblog? && reblog.reblog?
    self.in_reply_to_account_id = (thread.account_id == account_id && thread.reply? ? thread.in_reply_to_account_id : thread.account_id) if reply? && !thread.nil?
    self.visibility             = (account.locked? ? :private : :public) if visibility.nil?
  end

  private

  def filter_from_context?(status, account)
    account&.blocking?(status.account_id) || account&.muting?(status.account_id) || (status.account.silenced? && !account&.following?(status.account_id)) || !status.permitted?(account)
  end
end
