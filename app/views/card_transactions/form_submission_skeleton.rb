# frozen_string_literal: true

class Views::CardTransactions::FormSubmissionSkeleton < Views::Base
  attr_reader :transaction

  def initialize(transaction: nil)
    @transaction = transaction
  end

  def view_template
    div(class: "space-y-5 dark:[&_*]:border-slate-700/50 dark:[&_.animate-pulse]:bg-slate-700", id: "card_transaction_form_submission_skeleton") do
      # form badge
      Skeleton(class: "mb-2 inline-flex h-7 w-28 rounded-sm")

      div(class: "space-y-5") do
        # description
        Skeleton(class: "h-16 w-full rounded-md")
        # comment
        Skeleton(class: "h-24 w-full rounded-lg")
      end

      # third row (user_card, category, entity, date/time, price, button, installments_count)
      div(class: "pt-2") do
        div(class: "lg:flex lg:gap-2 w-full mb-2") do
          # user_bank_account/user_card
          div(class: "w-full lg:w-[16%] lg:flex-none mb-3") do
            Skeleton(class: "h-10 w-full rounded-md")
          end

          # categories and entities
          div(class: "flex w-full lg:flex-1 gap-2 mb-3 lg:mb-0 min-w-0") do
            Skeleton(class: "h-10 w-1/2 rounded-md")
            Skeleton(class: "h-10 w-1/2 rounded-md")
          end

          # date/time
          div(class: "w-full lg:w-[20%] lg:flex-none mb-3 lg:mb-0") do
            render_datetime_skeleton
          end

          # price and installments controls
          div(class: "flex w-full lg:w-[24%] lg:flex-none gap-0 mb-3 lg:mb-0") do
            Skeleton(class: "h-10 w-1/12 rounded-md lg:hidden")
            div(class: "w-7/12 lg:w-7/12") do
              Skeleton(class: "h-10 w-full rounded-md")
            end
            Skeleton(class: "h-10 w-1/12 rounded-l-none rounded-r-md")
            div(class: "w-3/12 pl-1 lg:w-4/12") do
              Skeleton(class: "h-10 w-full rounded-md")
            end
          end

          div(class: "mb-3 flex items-stretch lg:mb-0") do
            Skeleton(class: "h-10 w-full rounded-md lg:w-20")
          end
        end
      end

      render_purchase_tabs_skeleton

      render_installments_skeleton

      div(class: "flex w-full flex-col gap-3 pb-6") do
        # create more checkbox
        div(class: "flex w-full items-center justify-center pt-1") do
          Skeleton(class: "h-5 w-52 rounded-sm")
        end

        # submit buttons
        div(class: "grid grid-cols-1 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center gap-2 mx-auto w-full") do
          action_button_count.times do
            Skeleton(class: "h-9 w-64 rounded-md")
          end
        end
      end
    end
  end

  private

  def render_datetime_skeleton
    div(class: "grid grid-cols-[minmax(0,2fr)_minmax(7rem,1fr)] gap-2 lg:hidden") do
      render_calendar_skeleton
      render_clock_skeleton
    end

    div(class: "hidden lg:block") do
      div(class: "flex gap-1 mb-1") do
        Skeleton(class: "h-10 min-w-0 grow rounded-md")
        Skeleton(class: "h-10 w-28 shrink-0 rounded-md")
      end
      div(class: "flex") do
        Skeleton(class: "mx-auto h-4 w-20 rounded-sm")
        div(class: "h-0 w-28")
      end
    end
  end

  def render_calendar_skeleton
    div(class: "rounded-md border border-slate-200 bg-white dark:border-slate-700/50 dark:bg-slate-900 p-3 shadow-sm") do
      div(class: "mb-3 flex items-center justify-between") do
        Skeleton(class: "h-7 w-7 rounded-md")
        Skeleton(class: "h-5 w-20 rounded-sm")
        Skeleton(class: "h-7 w-7 rounded-md")
      end

      div(class: "grid grid-cols-7 gap-1") do
        35.times do
          Skeleton(class: "aspect-square w-full rounded-md")
        end
      end
    end
  end

  def render_clock_skeleton
    div(class: "flex h-full flex-col gap-1 rounded-md border border-slate-200 bg-white dark:border-slate-700/50 dark:bg-slate-900 p-2 shadow-sm") do
      2.times do
        div(class: "grid min-w-0 flex-1 grid-rows-[auto_minmax(0,1fr)_auto] gap-1") do
          Skeleton(class: "h-7 w-full rounded-md")
          Skeleton(class: "h-12 w-full rounded-md")
          Skeleton(class: "h-7 w-full rounded-md")
        end
      end
    end
  end

  def render_installments_skeleton
    div(class: "border-t py-2 dark:border-slate-700/50") do
      div(class: "hidden lg:block") do
        div(class: "grid grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-3") do
          render_previous_installment_arrow
          render_desktop_installment_cards
          render_next_installment_arrows
        end
      end

      div(class: "lg:hidden") do
        div(class: "grid grid-rows-[auto_minmax(0,1fr)_auto] gap-2") do
          Skeleton(class: "h-6 w-full rounded-md")
          render_mobile_installment_cards
          Skeleton(class: "h-6 w-full rounded-md")
        end
      end
    end
  end

  def render_purchase_tabs_skeleton
    div(class: "mb-3") do
      div(class: "flex h-11 w-full border-b border-slate-200 dark:border-slate-700/50") do
        Skeleton(class: tab_trigger_class(active: !composite?))
        Skeleton(class: tab_trigger_class(active: composite?))
      end

      div(class: "pt-2") do
        composite? ? render_split_purchase_skeleton : render_single_purchase_skeleton
      end
    end
  end

  def composite?
    transaction&.composite? || false
  end

  def tab_trigger_class(active:)
    active_classes = active ? "border-b-2 border-slate-800 dark:border-slate-200" : "border-b-2 border-transparent"
    "h-full w-40 #{active_classes}"
  end

  def render_single_purchase_skeleton
    div(class: "overflow-hidden rounded-lg border border-gray-300 bg-white dark:border-slate-700/60 dark:bg-slate-900/30") do
      div(class: "grid grid-cols-2 border-b border-gray-200 bg-gray-50 px-3 py-1.5 dark:border-slate-700/40 dark:bg-slate-800/30") do
        Skeleton(class: "h-4 w-24 rounded-sm")
        Skeleton(class: "h-4 w-20 rounded-sm border-l border-gray-200 pl-3 dark:border-slate-700/40")
      end

      div(class: "grid grid-cols-1 divide-y divide-gray-200 md:grid-cols-2 md:divide-x md:divide-y-0 dark:divide-slate-700/50") do
        render_collection_section_skeleton
        render_collection_section_skeleton
      end
    end
  end

  def render_split_purchase_skeleton
    div(class: "overflow-hidden rounded-lg border border-gray-300 bg-white dark:border-slate-700/60 dark:bg-slate-900/30") do
      div(class: "flex flex-wrap items-center gap-3 border-b border-gray-200 bg-gray-50 px-3 py-2 dark:border-slate-700/40 dark:bg-slate-800/30") do
        3.times { Skeleton(class: "h-4 w-24 rounded-sm") }
        Skeleton(class: "ml-auto h-7 w-24 rounded-md")
      end

      div(class: "divide-y divide-gray-200 dark:divide-slate-700/40") do
        split_line_item_count.times { render_split_line_item_skeleton }
      end
    end
  end

  def split_line_item_count
    [ transaction&.line_items&.size || 0, 1 ].max.clamp(1, 3)
  end

  def render_split_line_item_skeleton
    div(class: "flex items-center gap-2 px-3 py-2") do
      div(class: "flex min-w-0 flex-1 flex-col items-center gap-2 md:flex-row") do
        Skeleton(class: "h-9 w-full rounded-md md:w-4/12")
        Skeleton(class: "h-9 w-full rounded-md md:w-2/12")
        Skeleton(class: "h-9 w-full rounded-md md:w-3/12")
        Skeleton(class: "h-9 w-full rounded-md md:w-3/12")
      end
      Skeleton(class: "h-8 w-8 shrink-0 rounded-md")
    end
  end

  def render_previous_installment_arrow
    div(class: "grid grid-rows-2 gap-3") do
      Skeleton(class: "row-span-2 h-full min-h-12 w-full rounded-lg")
    end
  end

  def render_next_installment_arrows
    div(class: "grid grid-rows-2 gap-3") do
      Skeleton(class: "h-full min-h-12 w-full rounded-lg")
      Skeleton(class: "h-full min-h-12 w-full rounded-lg")
    end
  end

  def action_button_count
    return 3 if transaction.nil? || transaction.new_record?

    1 + (transaction.can_be_destroyed? ? 2 : 0)
  end

  def render_desktop_installment_cards
    div(class: "overflow-hidden pt-1") do
      div(class: "flex -ml-3") do
        4.times do
          div(class: "min-w-0 shrink-0 grow-0 basis-full pl-3 sm:basis-1/2 md:basis-1/3 lg:basis-1/4 xl:basis-1/5") do
            render_installment_card
          end
        end
      end
    end
  end

  def render_mobile_installment_cards
    div(class: "overflow-hidden") do
      div(class: "flex flex-col") do
        render_installment_card
      end
    end
  end

  def render_installment_card
    div(class: "space-y-1 rounded-xl border bg-white p-1 shadow-sm dark:rounded-lg dark:bg-slate-800") do
      div(class: "flex items-center justify-between rounded-lg border border-gray-200 bg-gray-100 px-2 py-1 dark:border-slate-700/50 dark:bg-slate-700/50") do
        Skeleton(class: "h-5 w-4 rounded-sm")
        Skeleton(class: "h-5 w-20 rounded-sm")
        Skeleton(class: "h-5 w-4 rounded-sm")
      end

      div(class: "grid grid-cols-[minmax(0,1fr)_5.5rem] gap-1") do
        Skeleton(class: "h-9 w-full rounded-md")
        Skeleton(class: "h-9 w-full rounded-md")
      end

      div(class: "flex gap-1") do
        Skeleton(class: "h-9 min-w-0 flex-1 rounded-md")
        Skeleton(class: "h-9 w-9 shrink-0 rounded-md")
      end
    end
  end

  def render_collection_section_skeleton
    div(class: "min-h-[3.5rem] p-2") do
      div(class: "grid grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-2") do
        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-purple-100 dark:bg-slate-700")

        div(class: "overflow-hidden") do
          div(class: "flex gap-2") do
            2.times do |index|
              width = %w[w-36 w-44][index]
              Skeleton(class: "h-12 #{width} shrink-0 rounded-sm bg-purple-100 dark:bg-slate-700")
            end
          end
        end

        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-purple-100 dark:bg-slate-700")
      end
    end
  end
end
