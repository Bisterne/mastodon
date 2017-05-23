module WithRedisSessionStore
  private

  def redis_session_store(suffix)
    raise 'session_id is not found' unless session.id

    redis = Redis::Namespace.new(['redis_session_store', session.id, suffix].join(':'))
    yield(redis) if block_given?
    redis
  end
end
