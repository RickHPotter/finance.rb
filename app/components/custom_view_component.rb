# frozen_string_literal: true

# CustomViewComponent for DRY reasons
class CustomViewComponent < ViewComponent::Base
  COLOURS = { pink: 'pink-500', indigo: 'indigo-500' }.freeze

  def prefix(array)
    elements = array.pop
    prefix = array.join(':')
    elements.split(' ').map { |item| "#{prefix}:#{item}" }.join(' ')
  end

  def custom_input_class(colour:)
    peer = 'peer'
    border = 'border-0 rounded-[7px] shadow-md bg-transparent outline-none'
    spacing = 'w-full px-2.5 pb-2.5 pt-3 appearance-none'
    text = 'text-sm text-gray-900'
    transition = 'transition-all'
    focus = prefix(['focus', "ring-1 ring-#{colour} "])

    [peer, border, spacing, text, transition, focus].join(' ')
  end

  def custom_label_class(colour:)
    position = 'absolute top-2 z-10'
    text = 'text-sm text-gray-500'
    transition = 'duration-300 transform -translate-y-4 scale-75 origin-[0] bg-white px-2 start-1'
    peer_focus = prefix(['peer-focus', "text-#{colour} top-2 scale-75 -translate-y-4"])
    peer_placeholder_shown = prefix(['peer-placeholder-shown', 'scale-100 -translate-y-1/2 top-1/2 text-sm'])

    rtl_peer_focus = 'rtl:peer-focus:-translate-x-1/4 rtl:peer-focus:left-auto'

    # tst = "absolute text-sm text-gray-500 duration-300 transform -translate-y-4 scale-75 top-2 z-10 origin-[0] bg-white px-2
    # peer-focus:text-#{colour} peer-placeholder-shown:scale-100 peer-placeholder-shown:-translate-y-1/2
    # peer-placeholder-shown:top-1/2 peer-focus:top-2 peer-focus:scale-75 peer-focus:-translate-y-4 rtl:peer-focus:translate-x-1/4
    # rtl:peer-focus:left-auto start-1"

    [position, text, transition, peer_focus, peer_placeholder_shown, rtl_peer_focus].join(' ')
  end
end
