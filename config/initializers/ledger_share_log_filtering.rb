# frozen_string_literal: true

module LedgerShareRequestLogFiltering
  SHARED_LEDGER_TOKEN = %r{(?<=/shared/)[^/?]+}

  def filtered_path
    super.sub(SHARED_LEDGER_TOKEN, "[FILTERED]")
  end
end

ActionDispatch::Request.prepend(LedgerShareRequestLogFiltering)
Rails.application.config.filter_redirect += [ %r{/shared/} ]
