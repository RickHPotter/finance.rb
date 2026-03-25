# frozen_string_literal: true

class ContextsController < ApplicationController
  include TabsConcern

  before_action :set_context_tabs

  def index
    contexts = current_user.contexts.order(:created_at)
    render Views::Contexts::Index.new(contexts:, current_context:)
  end

  def show
    context = current_user.contexts.find(params[:id])
    render Views::Contexts::Show.new(context:, current_context:)
  end

  def new
    context = current_user.contexts.new(source_context: source_context)
    render Views::Contexts::New.new(context:, source_context:)
  end

  def create
    context = Logic::ContextCloneService.new(
      source_context:,
      name: context_params[:name],
      description: context_params[:description]
    ).call

    redirect_to context_path(context)
  end

  def dismiss
    render inline: helpers.turbo_frame_tag(:context_overlay), layout: false
  end

  def archive
    context = current_user.contexts.find(params[:id])

    if context.main?
      redirect_to contexts_path, alert: t("contexts.archive.main_forbidden")
      return
    end

    context.update!(archived_at: Time.current)
    session[:current_context_id] = current_user.main_context.id if current_context == context

    redirect_to contexts_path, notice: t("contexts.archive.success")
  end

  def unarchive
    context = current_user.contexts.find(params[:id])

    if context.main?
      redirect_to contexts_path, alert: t("contexts.archive.main_forbidden")
      return
    end

    context.update!(archived_at: nil)

    redirect_to contexts_path, notice: t("contexts.unarchive.success")
  end

  def switch
    context = current_user.contexts.find(params[:id])
    session[:current_context_id] = context.id

    redirect_to switch_redirect_path, **switch_flash_options
  end

  private

  def context_params
    params.require(:context).permit(:name, :description, :source_context_id)
  end

  def source_context
    source_context_id = params.dig(:context, :source_context_id) || params[:source_context_id]
    @source_context ||= current_user.contexts.find(source_context_id)
  end

  def set_context_tabs
    set_tabs(active_menu: :hub, active_sub_menu: :context)
  end

  def switch_redirect_path
    return conversations_path if redirect_to_conversations_index?

    request.referer || root_path
  end

  def switch_flash_options
    return { notice: t("contexts.switch.redirected_to_index") } if redirect_to_conversations_index?

    {}
  end

  def redirect_to_conversations_index?
    recognized_referer_route[:controller] == "conversations" && recognized_referer_route[:action] == "show"
  end

  def recognized_referer_route
    @recognized_referer_route ||= begin
      referer_path = URI.parse(request.referer).path
      Rails.application.routes.recognize_path(referer_path)
    rescue URI::InvalidURIError, ActionController::RoutingError, NoMethodError
      {}
    end
  end
end
