# frozen_string_literal: true

module BabyNames
  class Flow
    attr_reader :user, :state, :partner, :partner_state

    def initialize(user)
      @user = user
      @state = BabyNameProcessState.for(user)
      @partner = find_partner(user)
      @partner_state = partner ? BabyNameProcessState.for(partner) : nil
    end

    def current_phase
      sync_phase_progress!
      state.phase
    end

    def phase_completed?
      sync_phase_progress!
      state.phase_completed?
    end

    def partner_phase_completed?
      sync_phase_progress!
      partner_state&.phase_completed? || false
    end

    def phase_names
      case current_phase
      when "phase1" then phase1_names
      when "phase2" then phase2_names
      when "phase3" then phase3_names
      when "phase4" then phase4_names
      else BabyName.none
      end
    end

    def calculate_n
      common_count = mutual_accepted_ids.size
      return 3 if common_count >= 15

      [ 1, ((16 - common_count) / 2.0).round ].max
    end

    def complete_phase2!(ordered_ids)
      ordered_ids.each_with_index do |id, index|
        decision = user.baby_name_decisions.find_by(baby_name_id: id)
        decision&.update_columns(position: index + 1)
      end
      state.update!(phase_completed: true)
      sync_phase_progress!
    end

    def complete_phase3!(ordered_ids)
      k = user.baby_name_decisions.accepted.count
      n = calculate_n
      selected_ids = ordered_ids.first(n)

      selected_ids.each_with_index do |id, index|
        decision = user.baby_name_decisions.find_or_initialize_by(baby_name_id: id)
        decision.choice ||= "rejected"
        decision.position = k + index + 1
        decision.save!
      end

      state.update!(phase_completed: true)
      sync_phase_progress!
    end

    def complete_phase4!(ordered_ids)
      ordered_ids.each_with_index do |id, index|
        decision = user.baby_name_decisions.find_or_initialize_by(baby_name_id: id)
        decision.choice ||= "accepted"
        decision.position = index + 1
        decision.save!
      end
      state.update!(phase_completed: true)
      sync_phase_progress!
    end

    def final_rankings
      finalist_ids = finalist_names_pool.pluck(:id)
      return [] if finalist_ids.empty?

      total_candidates = finalist_ids.size
      results = BabyName.where(id: finalist_ids).map do |baby_name|
        build_finalist_result(baby_name, total_candidates)
      end

      results.sort_by { |item| [ -item[:score], item[:user_position] || 999, item[:baby_name].id ] }
    end

    private

    def build_finalist_result(baby_name, total_candidates)
      pos1 = user.baby_name_decisions.find_by(baby_name_id: baby_name.id)&.position
      pos2 = partner ? partner.baby_name_decisions.find_by(baby_name_id: baby_name.id)&.position : nil

      pts1 = pos1 ? [ total_candidates - pos1 + 1, 0 ].max : 0
      pts2 = pos2 ? [ total_candidates - pos2 + 1, 0 ].max : 0

      {
        baby_name:,
        user_name: user.first_name.presence || "You",
        partner_name: partner&.first_name.presence || "Partner",
        user_position: pos1,
        partner_position: pos2,
        score: pts1 + pts2
      }
    end

    def find_partner(current_user)
      partner_id = (BabyNamesAccess::ALLOWED_USER_IDS - [ current_user.id ]).first
      partner_id ? User.find_by(id: partner_id) : nil
    end

    def sync_phase_progress!
      state.reload if state.persisted?
      partner_state&.reload if partner_state&.persisted?

      case state.phase
      when "phase1" then sync_phase1
      when "phase2" then sync_phase2
      when "phase3" then sync_phase3
      when "phase4" then sync_phase4
      end
    end

    def sync_phase1
      state.update!(phase_completed: true) if !state.phase_completed? && phase1_done_for?(user)
      partner_state.update!(phase_completed: true) if partner && !partner_state.phase_completed? && phase1_done_for?(partner)

      return unless state.phase_completed? && partner_state&.phase_completed?

      state.update!(phase: "phase2", phase_completed: false)
      partner_state.update!(phase: "phase2", phase_completed: false)
    end

    def sync_phase2
      return unless state.phase_completed? && partner_state&.phase_completed?

      next_phase = identical_accepted_lists? ? "phase4" : "phase3"
      state.update!(phase: next_phase, phase_completed: false)
      partner_state.update!(phase: next_phase, phase_completed: false)
    end

    def sync_phase3
      return unless state.phase_completed? && partner_state&.phase_completed?

      state.update!(phase: "phase4", phase_completed: false)
      partner_state.update!(phase: "phase4", phase_completed: false)
    end

    def sync_phase4
      return unless state.phase_completed? && partner_state&.phase_completed?

      state.update!(phase: "completed", phase_completed: true)
      partner_state.update!(phase: "completed", phase_completed: true)
    end

    def phase1_done_for?(target_user)
      BabyName.active.unreviewed_by(target_user).none? && target_user.baby_name_decisions.later.none?
    end

    def identical_accepted_lists?
      user_acc = user.baby_name_decisions.accepted.pluck(:baby_name_id).sort
      partner_acc = partner ? partner.baby_name_decisions.accepted.pluck(:baby_name_id).sort : []
      user_acc == partner_acc
    end

    def mutual_accepted_ids
      user_acc = user.baby_name_decisions.accepted.pluck(:baby_name_id)
      partner_acc = partner ? partner.baby_name_decisions.accepted.pluck(:baby_name_id) : []
      user_acc & partner_acc
    end

    def phase1_names
      BabyName.active.in_display_order
    end

    def phase2_names
      user.baby_name_decisions
          .accepted
          .joins(:baby_name)
          .merge(BabyName.active)
          .order("baby_name_decisions.position ASC NULLS LAST, baby_names.id ASC")
          .map(&:baby_name)
    end

    def phase3_names
      return [] unless partner

      partner_accepted = partner.baby_name_decisions.accepted.pluck(:baby_name_id)
      user_accepted = user.baby_name_decisions.accepted.pluck(:baby_name_id)
      exclusive_ids = partner_accepted - user_accepted
      BabyName.where(id: exclusive_ids).in_display_order
    end

    def phase4_names
      names = finalist_names_pool
      decisions = user.baby_name_decisions.where(baby_name_id: names.map(&:id)).index_by(&:baby_name_id)

      names.sort_by do |bn|
        pos = decisions[bn.id]&.position
        pos.nil? ? 999 : pos
      end
    end

    def finalist_names_pool
      mutual = mutual_accepted_ids
      n = calculate_n

      k1 = user.baby_name_decisions.accepted.count
      user_repescagem = user.baby_name_decisions.where("position > ?", k1).order(:position).limit(n).pluck(:baby_name_id)

      partner_repescagem = []
      if partner
        k2 = partner.baby_name_decisions.accepted.count
        partner_repescagem = partner.baby_name_decisions.where("position > ?", k2).order(:position).limit(n).pluck(:baby_name_id)
      end

      combined_ids = (mutual + user_repescagem + partner_repescagem).uniq
      BabyName.where(id: combined_ids)
    end
  end
end
