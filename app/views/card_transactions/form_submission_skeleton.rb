# frozen_string_literal: true

class Views::CardTransactions::FormSubmissionSkeleton < Views::Base
  def view_template
    div(class: "space-y-5", id: "card_transaction_form_submission_skeleton") do
      # hint badge
      div(class: "flex justify-center") do
        Skeleton(class: "h-7 w-28 rounded-sm")
      end

      div(class: "space-y-5") do
        # description
        Skeleton(class: "h-16 w-full rounded-md")
        # comment
        Skeleton(class: "h-24 w-full rounded-lg")
      end

      # third row (user_card, category, entity, date/time, price, button, installments_count)
      div(class: "pt-2") do
        div(class: "lg:flex lg:gap-2 w-full") do
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
          div(class: "flex w-full lg:w-[24%] lg:flex-none gap-1 mb-3 lg:mb-0") do
            Skeleton(class: "h-10 w-1/12 rounded-md lg:hidden")
            div(class: "w-7/12 lg:w-7/12") do
              Skeleton(class: "h-10 w-full rounded-md")
            end
            Skeleton(class: "h-10 w-1/12 rounded-md")
            div(class: "w-3/12 lg:w-4/12") do
              Skeleton(class: "h-10 w-full rounded-md")
            end
          end
        end
      end

      render_installments_skeleton

      div(class: "mb-2 grid grid-cols-1 gap-2 items-stretch md:grid-cols-2 md:gap-0") do
        render_collection_section_skeleton(border_class: "border-y border-purple-100 py-2 md:border-r md:pr-2")
        render_collection_section_skeleton(border_class: "border-y border-purple-100 py-2 md:border-l md:pl-2")
      end

      div(class: "space-y-3") do
        # create more checkbox
        Skeleton(class: "mx-auto h-5 w-36 rounded-sm")

        # submit buttons
        div(class: "grid grid-cols-1 gap-2 sm:grid-flow-col sm:auto-cols-fr items-center justify-items-center mx-auto w-full") do
          3.times do
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
    div(class: "rounded-md border border-slate-200 bg-white p-3 shadow-sm") do
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
    div(class: "flex h-full flex-col gap-1 rounded-md border border-slate-200 bg-white p-2 shadow-sm") do
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
    div(class: "space-y-2 border-t border-purple-100 py-1") do
      div(class: "grid grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-3") do
        # prev carousel and reduce
        div(class: "grid grid-rows-2 gap-3") do
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
        end

        div(class: "overflow-hidden") do
          div(class: "flex -ml-2") do
            4.times do
              div(class: "min-w-0 shrink-0 grow-0 basis-full pl-3 md:basis-1/2 lg:basis-1/3 xl:basis-1/4") do
                div(class: "space-y-3 rounded-lg border border-purple-100 p-3") do
                  div(class: "flex justify-between gap-3") do
                    # prev
                    Skeleton(class: "h-5 w-4 rounded-sm")
                    # ref_month_year
                    Skeleton(class: "h-5 w-16 rounded-sm")
                    # next
                    Skeleton(class: "h-5 w-4 rounded-sm")
                  end
                  # date
                  Skeleton(class: "h-8 w-full rounded-md")
                  div(class: "flex gap-1") do
                    # price
                    Skeleton(class: "h-8 w-7/8 rounded-md")
                    # lock button
                    Skeleton(class: "h-8 w-1/8 rounded-md")
                  end
                end
              end
            end
          end
        end

        # next carousel and expand
        div(class: "grid grid-rows-2 gap-3") do
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
          Skeleton(class: "h-full min-h-12 w-full rounded-lg")
        end
      end
    end
  end

  def render_collection_section_skeleton(border_class:)
    div(class: border_class) do
      div(class: "grid grid-cols-[1.5rem_minmax(0,1fr)_1.5rem] items-stretch gap-2") do
        # prev carousel
        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-purple-100")

        div(class: "overflow-hidden") do
          div(class: "flex gap-2") do
            2.times do |index|
              width = %w[w-36 w-44 w-40][index]
              Skeleton(class: "h-12 #{width} shrink-0 rounded-sm bg-purple-100")
            end
          end
        end

        # next carousel
        Skeleton(class: "h-full min-h-12 w-full rounded-lg bg-purple-100")
      end
    end
  end
end
