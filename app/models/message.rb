# frozen_string_literal: true

class Message < ApplicationRecord # rubocop:disable Metrics/ClassLength
  # @extends ..................................................................
  # @includes .................................................................
  include TranslateHelper

  KINDS = %w[human transaction_notification transaction_destroy_notification paid_state_sync].index_by(&:itself).freeze
  ACTION_STATES = %w[pending accepted rejected expired failed unavailable reverted].index_by(&:itself).freeze

  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :conversation
  belongs_to :user
  belongs_to :superseded_by, class_name: "Message", optional: true
  has_one :supersedes, class_name: "Message", foreign_key: "superseded_by_id"
  belongs_to :reference_transactable, polymorphic: true, optional: true
  belongs_to :audit_operation, optional: true
  has_many :message_actions, dependent: :restrict_with_error

  # @validations ..............................................................
  validates :body, presence: true
  validates :kind, inclusion: { in: KINDS.keys }
  validates :action_state, inclusion: { in: ACTION_STATES.keys }, allow_nil: true
  validate :valid_kind_and_action_state_combination
  validate :valid_action_state_timestamps

  # @callbacks ................................................................
  before_validation :assign_kind_and_action_state
  before_validation :assign_audit_operation, on: :create
  after_create :reactivate_conversation_participants
  after_update :propagate_read_at_to_superseded_messages, if: :read_at_became_present?
  after_create_commit do
    broadcast_append_to conversation,
                        target: "messages_#{conversation.id}",
                        html: ApplicationController.render(Views::Messages::Message.new(message: self), layout: false)
  end
  after_create_commit :send_email, if: -> { Rails.env.production? }
  after_create_commit :enqueue_auto_apply, if: :auto_apply_candidate?

  # @scopes ...................................................................
  scope :latest, -> { where(superseded_by_id: nil) }
  scope :unread, -> { where(read_at: nil) }

  # @additional_config ........................................................
  enum :kind, KINDS, prefix: true
  enum :action_state, ACTION_STATES, prefix: true

  # @class_methods ............................................................
  # @public_instance_methods ..................................................
  def transaction_notification_message?
    effective_kind == "transaction_notification"
  end

  def transaction_destroy_notification_message?
    effective_kind == "transaction_destroy_notification"
  end

  def human_message?
    effective_kind == "human"
  end

  def backfill_kind
    return "paid_state_sync" if action_payload.version == "message_paid_state_v1"

    if action_payload.version == "message_notification_v2"
      return "transaction_destroy_notification" if notification_action == "destroy"
      return "transaction_notification" if notification_action.in?(%w[create update])

      return "human"
    end

    return "transaction_notification" if headers.present?
    return "transaction_destroy_notification" if reference_transactable.present?

    "human"
  end

  def classification_compatible_with_legacy?
    kind == backfill_kind
  end

  def action_state_compatible_with_legacy?
    action_state == inferred_action_state_for(backfill_kind)
  end

  def workflow_state
    effective_action_state
  end

  def action_payload
    return @action_payload if defined?(@action_payload_headers) && @action_payload_headers == headers

    @action_payload_headers = headers
    @action_payload = Logic::Messages::ActionPayload.new(headers)
  end

  def replay_payload
    return if headers.blank?

    return parsed_headers["replay"] if notification_payload_v2?

    parsed_headers
  end

  def rendered_body
    return body unless action_payload.valid?
    return render_paid_state_sync_body if paid_state_sync_message?
    return body unless notification_payload_v2?

    render_notification_body
  end

  def preview_body
    return body.to_s.tr("\n", " ").presence || "" unless action_payload.valid?
    return render_paid_state_sync_preview if paid_state_sync_message?
    return body.to_s.tr("\n", " ").presence || "" unless notification_payload_v2?

    [
      I18n.t("activerecord.attributes.message.notification_actions.#{notification_action}"),
      notification_event.dig("details", "description")
    ].compact.join(": ")
  end

  def notification_payload_v2?
    action_payload.version == "message_notification_v2"
  end

  def paid_state_sync_message?
    effective_kind == "paid_state_sync"
  end

  def applied?
    effective_action_state == "accepted"
  end

  def reverted?
    effective_action_state == "reverted"
  end

  def action_button_key(local_reference_exists:)
    return unless effective_action_state.in?(%w[pending failed])
    return :ok if paid_state_sync_message?
    return :destroy if transaction_destroy_notification_message?
    return :correct if notification_action == "update" && local_reference_exists
    return :create unless local_reference_exists

    :edit
  end

  def completed_message_key
    return :already_acknowledged if paid_state_sync_message?

    {
      "create" => :already_created,
      "update" => :already_updated,
      "destroy" => :already_destroyed
    }.fetch(notification_action, :already_updated)
  end

  def assistant_side_for(user)
    user_id == user.id ? "mine" : "theirs"
  end

  def actionable_for?(context: user.ensure_main_context!)
    return true if auto_applied? && read_at.blank? && !reverted?
    return false unless effective_action_state.in?(%w[pending failed])

    action_button_key(local_reference_exists: local_reference_for(context:).present?).in?(%i[create correct destroy ok])
  end

  def local_reference_for(context:)
    cash_transactions = context.cash_transactions

    return destroy_local_reference_for(cash_transactions) if transaction_destroy_notification_message?

    payload = replay_payload || {}
    type = payload["type"]
    id = payload["id"]
    return if type.blank? || id.blank?

    direct_cash_transaction_reference = cash_transactions.find_by(id:) if type == "CashTransaction"
    return direct_cash_transaction_reference if direct_cash_transaction_reference.present?

    exact_reference_local = cash_transactions.find_by(reference_transactable_type: type, reference_transactable_id: id)
    return exact_reference_local if exact_reference_local.present?

    chain_local_reference_for(cash_transactions:, type:, id:)
  end

  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................

  private

  def effective_kind
    kind.presence || backfill_kind
  end

  def effective_action_state
    action_state.presence || inferred_action_state
  end

  def assign_kind_and_action_state
    self.kind ||= backfill_kind

    return unless kind != "human" && (action_state.blank? || (legacy_action_facts_changed? && !will_save_change_to_action_state?))

    self.action_state = inferred_action_state
  end

  def inferred_action_state
    inferred_action_state_for(effective_kind)
  end

  def inferred_action_state_for(message_kind)
    return if message_kind == "human"
    return "unavailable" if contradictory_action_facts?
    return "reverted" if reverted_at.present?
    return "accepted" if applied_at.present?
    return "expired" if superseded_by_id.present?
    return "unavailable" unless action_payload.valid?

    "pending"
  end

  def contradictory_action_facts?
    (reverted_at.present? && applied_at.blank?) ||
      (auto_applied? && applied_at.blank?) ||
      (reverted_at.present? && applied_at.present? && reverted_at < applied_at)
  end

  def legacy_action_facts_changed?
    will_save_change_to_applied_at? || will_save_change_to_reverted_at? || will_save_change_to_superseded_by_id?
  end

  def valid_kind_and_action_state_combination
    if kind == "human" && action_state.present?
      errors.add(:action_state, "must be blank for human messages")
    elsif kind.present? && kind != "human" && action_state.blank?
      errors.add(:action_state, "can't be blank for actionable messages")
    end
  end

  def valid_action_state_timestamps
    errors.add(:applied_at, "can't be blank for accepted messages") if action_state == "accepted" && applied_at.blank?
    return unless action_state == "reverted"

    errors.add(:applied_at, "can't be blank for reverted messages") if applied_at.blank?
    errors.add(:reverted_at, "can't be blank for reverted messages") if reverted_at.blank?
  end

  def enqueue_auto_apply
    ActionableMessageAutoApplyJob.perform_now(self)
  end

  def auto_apply_candidate?
    (transaction_notification_message? || transaction_destroy_notification_message?) && !paid_state_sync_message?
  end

  def assign_audit_operation
    operation_id = Audit::Current.operation_id
    self.audit_operation_id = operation_id if operation_id.present? && AuditOperation.exists?(id: operation_id)
  end

  def reactivate_conversation_participants
    conversation.conversation_participants.where.not(archived_at: nil).update_all(archived_at: nil, updated_at: Time.current)
  end

  def read_at_became_present?
    saved_change_to_read_at? && read_at.present?
  end

  def propagate_read_at_to_superseded_messages
    Message.where(id: superseded_message_ids, read_at: nil).update_all(read_at:)
  end

  def superseded_message_ids
    seen_ids = [ id ]
    frontier_ids = seen_ids

    loop do
      predecessor_ids = Message.where(superseded_by_id: frontier_ids).where.not(id: seen_ids).pluck(:id)
      break if predecessor_ids.empty?

      seen_ids.concat(predecessor_ids)
      frontier_ids = predecessor_ids
    end

    seen_ids.without(id)
  end

  def local_reference_exists_for?(context:)
    local_reference_for(context:).present?
  end

  def chain_local_reference_for(cash_transactions:, type:, id:)
    reference = payload_reference_transaction(type:, id:)
    return if reference.blank?

    return cash_transactions.find_by(id: reference.id) if reference.instance_of?(CashTransaction) && cash_transactions.where(id: reference.id).exists?

    if reference.instance_of?(CardTransaction)
      projected_reference = projected_shared_return_from_card(reference)
      return cash_transactions.find_by(id: projected_reference.id) if projected_reference.present? && cash_transactions.where(id: projected_reference.id).exists?

      return CashTransaction.first_reference_descendant_for(projected_reference, scope: cash_transactions) if projected_reference.present?
    end

    CashTransaction.first_reference_descendant_for(reference, scope: cash_transactions)
  end

  def destroy_local_reference_for(cash_transactions)
    reference = reference_transactable
    return if reference.blank?

    if reference.instance_of?(CashTransaction)
      direct_reference = cash_transactions.find_by(id: reference.id)
      return direct_reference if direct_reference.present?
    end

    chain_reference_from(reference, cash_transactions:)
  end

  def chain_reference_from(reference, cash_transactions:)
    if reference.instance_of?(CardTransaction)
      projected_reference = projected_shared_return_from_card(reference)
      return cash_transactions.find_by(id: projected_reference.id) if projected_reference.present? && cash_transactions.where(id: projected_reference.id).exists?

      return CashTransaction.first_reference_descendant_for(projected_reference, scope: cash_transactions) if projected_reference.present?
    end

    CashTransaction.first_reference_descendant_for(reference, scope: cash_transactions) if reference.instance_of?(CashTransaction)
  end

  def payload_reference_transaction(type:, id:)
    return reference_transactable if payload_reference_transaction_match?(reference_transactable, type:, id:)

    case type
    when "CashTransaction"
      CashTransaction.find_by(id:)
    when "CardTransaction"
      CardTransaction.find_by(id:)
    end
  end

  def payload_reference_transaction_match?(transaction, type:, id:)
    transaction.present? &&
      payload_reference_transaction_class_match?(transaction, type:) &&
      transaction.id == id.to_i
  end

  def payload_reference_transaction_class_match?(transaction, type:)
    case type
    when "CashTransaction"
      transaction.instance_of?(CashTransaction)
    when "CardTransaction"
      transaction.instance_of?(CardTransaction)
    else
      false
    end
  end

  def projected_shared_return_from_card(card_transaction)
    card_transaction.entity_transactions
                    .includes(exchanges: :cash_transaction)
                    .flat_map(&:exchanges)
                    .select(&:monetary?)
                    .map(&:cash_transaction)
                    .compact
                    .find(&:exchange_return?)
  end

  def parsed_headers
    action_payload.data
  end

  def notification_action
    action_payload.action
  end

  def notification_event
    action_payload.event
  end

  def render_notification_body # rubocop:disable Metrics/AbcSize
    details = notification_event.fetch("details", {})
    installments = Array(details["installments"])
    new_line = "\n"
    transaction_class = notification_event["transaction_type"].constantize

    body = [ "<b>#{model_attribute(self, :hello)}, #{notification_event['receiver_first_name']}!</b>#{new_line * 2}" ]

    body << "#{model_attribute(self, notification_action_message_key)}#{new_line * 2}"
    body << "<b>#{details['transaction_label'].to_s.upcase}</b>#{new_line}"
    body << "#{model_attribute(transaction_class, :description)}: #{details['description']}#{new_line}" if details["description"].present?
    body << "#{model_attribute(transaction_class, :date)}: #{formatted_notification_date(details['date'])}#{new_line}" if details["date"].present?
    body << "#{model_attribute(transaction_class, :reference_month_year)}: #{details['reference_month_year']}#{new_line}" if details["reference_month_year"].present?
    body << "#{model_attribute(transaction_class, :price)}: #{from_cent_based_to_float(details['price'], 'R$')}#{new_line}" if details["price"].present?
    body << "#{model_attribute(transaction_class, :installments_count)}: #{details['installments_count']}#{new_line * 2}" if details["installments_count"].present?
    body << "<b>#{model_attribute(installment_class(notification_event['transaction_type']), :self).upcase}</b>#{new_line}" if installments.present?

    installments.each do |installment|
      installment_date = installment["date"].present? ? I18n.l(Date.parse(installment["date"]), format: :long) : installment["date"]
      body << " - #{installment['number']} [#{installment_date}] #{from_cent_based_to_float(installment['price'], 'R$')}#{new_line}"
    end

    body.join
  rescue NameError, Date::Error
    body
  end

  def render_paid_state_sync_body # rubocop:disable Metrics/AbcSize
    details = notification_event.fetch("details", {})
    new_line = "\n"
    state_key = notification_action == "paid" ? :ivepaidayoursharedtransaction : :iveunpaidayoursharedtransaction
    state_label_key = notification_action == "paid" ? :paid : :not_paid

    body = [ "<b>#{model_attribute(self, :hello)}, #{notification_event['receiver_first_name']}!</b>#{new_line * 2}" ]
    body << "#{model_attribute(self, state_key)}#{new_line * 2}"
    body << "<b>#{details['transaction_label'].to_s.upcase}</b>#{new_line}"
    body << "#{model_attribute(CashTransaction, :description)}: #{details['description']}#{new_line}" if details["description"].present?
    body << "#{model_attribute(CashInstallment, :cash_installment)} ##{details['installment_number']}#{new_line}" if details["installment_number"].present?
    body << "#{model_attribute(CashInstallment, state_label_key)}#{new_line}"
    body << "#{model_attribute(CashInstallment, :date)}: #{formatted_notification_date(details['date'])}#{new_line}" if details["date"].present?
    body.join
  rescue Date::Error
    body
  end

  def render_paid_state_sync_preview
    [
      I18n.t("activerecord.attributes.message.notification_actions.#{notification_action}"),
      notification_event.dig("details", "description")
    ].compact.join(": ")
  end

  def installment_class(transaction_type)
    transaction_type.to_s.sub("Transaction", "Installment").constantize
  end

  def formatted_notification_date(date)
    I18n.l(Date.parse(date), format: :long)
  end

  def notification_action_message_key
    {
      "create" => :ivemadeatransactiononyou,
      "update" => :iveupdatedatransactiononyou,
      "destroy" => :ivedeletedatransactiononyou
    }.fetch(notification_action, :ivemadeatransactiononyou)
  end

  def send_email
    title = user.full_name
    body =  model_attribute(self, :you_have_a_new_message)
    url = Rails.application.routes.url_helpers.root_url(host: Rails.env.production? ? "30fev.com" : "localhost")

    friends_to_notify = conversation.conversation_participants.where.not(user_id: user.id).where(muted_at: nil)

    friends_to_notify.each { |participant| send_push_notification_to(participant, title:, body:, url:) }

    I18n.locale = user.locale
  end

  def send_push_notification_to(participant, title:, body:, url:)
    friend_user = participant.user
    I18n.locale = friend_user.locale

    friend_user.push_subscriptions.each do |subscription|
      WebPush.payload_send(
        message: { title:, body:, url: }.to_json,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        vapid:
      )
    end
  end

  def vapid
    {
      subject: "mailto:30fevfun@gmail.com",
      public_key: Rails.application.credentials.dig(:vapid, :public_key),
      private_key: Rails.application.credentials.dig(:vapid, :private_key)
    }
  end
end

# == Schema Information
#
# Table name: messages
# Database name: primary
#
#  id                          :bigint           not null, primary key
#  action_state                :string           indexed => [kind]
#  applied_at                  :datetime         indexed
#  auto_applied                :boolean          default(FALSE), not null
#  body                        :text
#  headers                     :text
#  kind                        :string           indexed => [action_state]
#  read_at                     :datetime
#  reference_transactable_type :string           indexed => [reference_transactable_id]
#  reverted_at                 :datetime         indexed
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  audit_operation_id          :uuid             indexed
#  conversation_id             :bigint           not null, indexed
#  reference_transactable_id   :bigint           indexed => [reference_transactable_type]
#  superseded_by_id            :bigint           indexed
#  user_id                     :bigint           not null, indexed
#
# Indexes
#
#  index_messages_on_applied_at              (applied_at)
#  index_messages_on_audit_operation_id      (audit_operation_id)
#  index_messages_on_conversation_id         (conversation_id)
#  index_messages_on_kind_and_action_state    (kind,action_state)
#  index_messages_on_reference_transactable  (reference_transactable_type,reference_transactable_id)
#  index_messages_on_reverted_at             (reverted_at)
#  index_messages_on_superseded_by_id        (superseded_by_id)
#  index_messages_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (audit_operation_id => audit_operations.id) ON DELETE => restrict
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (superseded_by_id => messages.id)
#  fk_rails_...  (user_id => users.id)
#
