# frozen_string_literal: true

SimpleNavigation::Configuration.run do |navigation|
  navigation.items do |primary|
    primary.item :web, safe_join([fa_icon('chevron-left fw'), t('settings.back')]), root_url

    primary.item :settings, safe_join([fa_icon('cog fw'), t('settings.settings')]), settings_profile_url do |settings|
      settings.item :profile, safe_join([fa_icon('user fw'), t('settings.edit_profile')]), settings_profile_url
      settings.item :preferences, safe_join([fa_icon('sliders fw'), t('settings.preferences')]), settings_preferences_url
      settings.item :password, safe_join([fa_icon('cog fw'), t('auth.change_password')]), edit_user_registration_url
      settings.item :two_factor_authentication, safe_join([fa_icon('mobile fw'), t('settings.two_factor_authentication')]), settings_two_factor_authentication_url, highlights_on: %r{/settings/two_factor_authentication}
      settings.item :import, safe_join([fa_icon('cloud-upload fw'), t('settings.import')]), settings_import_url
      settings.item :export, safe_join([fa_icon('cloud-download fw'), t('settings.export')]), settings_export_url
      settings.item :authorized_apps, safe_join([fa_icon('list fw'), t('settings.authorized_apps')]), oauth_authorized_applications_url
      settings.item :oauth_authentications, safe_join([fa_icon('list fw'), t('settings.oauth_authentications')]), settings_oauth_authentications_url
      settings.item :follower_domains, safe_join([fa_icon('users fw'), t('settings.followers')]), settings_follower_domains_url
    end

    primary.item :admin, safe_join([fa_icon('cogs fw'), t('admin.title')]), admin_reports_url, if: proc { current_user.admin? } do |admin|
      admin.item :reports, safe_join([fa_icon('flag fw'), t('admin.reports.title')]), admin_reports_url, highlights_on: %r{/admin/reports}
      admin.item :accounts, safe_join([fa_icon('users fw'), t('admin.accounts.title')]), admin_accounts_url, highlights_on: %r{/admin/accounts}
      admin.item :instances, safe_join([fa_icon('cloud fw'), t('admin.instances.title')]), admin_instances_url, highlights_on: %r{/admin/instances}
      admin.item :pubsubhubbubs, safe_join([fa_icon('paper-plane-o fw'), t('admin.pubsubhubbub.title')]), admin_pubsubhubbub_index_url
      admin.item :domain_blocks, safe_join([fa_icon('lock fw'), t('admin.domain_blocks.title')]), admin_domain_blocks_url, highlights_on: %r{/admin/domain_blocks}
      admin.item :sidekiq, safe_join([fa_icon('diamond fw'), 'Sidekiq']), sidekiq_url, link_html: { target: 'sidekiq' }
      admin.item :pghero, safe_join([fa_icon('database fw'), 'PgHero']), pghero_url, link_html: { target: 'pghero' }
      admin.item :settings, safe_join([fa_icon('cogs fw'), t('admin.settings.title')]), admin_settings_url
    end

    primary.item :logout, safe_join([fa_icon('sign-out fw'), t('auth.logout')]), destroy_user_session_url, link_html: { 'data-method' => 'delete' }
  end
end
