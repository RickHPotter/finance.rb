# frozen_string_literal: true

class ColourPicker < Base
  def initialize
    # @colour = colour
    # @options = options
    super
  end

  def view_template
    h1 { "hello, bitches" }
  end
end

__END__

<div class="relative" id="color-picker-container">
  <div class="relative">
    <input 
      type="text" 
      id="selected-color" 
      value="slate" 
      readonly 
      class="w-full px-3 py-2 bg-white border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 cursor-pointer"
      onclick="toggleColorPicker()"
    />
    <div 
      id="color-indicator"
      class="absolute right-2 top-1/2 -translate-y-1/2 w-6 h-6 rounded-full border border-slate-200 bg-slate-500"
    ></div>
  </div>

  <div id="color-options" class="hidden absolute z-50 w-64 mt-2 p-2 bg-white rounded-lg shadow-lg border border-slate-200 grid grid-cols-4 gap-2">
    <% colors = [
      { name: 'slate', bg: 'bg-slate-500' },
      { name: 'gray', bg: 'bg-gray-500' },
      { name: 'zinc', bg: 'bg-zinc-500' },
      { name: 'neutral', bg: 'bg-neutral-500' },
      { name: 'stone', bg: 'bg-stone-500' },
      { name: 'red', bg: 'bg-red-500' },
      { name: 'orange', bg: 'bg-orange-500' },
      { name: 'amber', bg: 'bg-amber-500' },
      { name: 'yellow', bg: 'bg-yellow-500' },
      { name: 'lime', bg: 'bg-lime-500' },
      { name: 'green', bg: 'bg-green-500' },
      { name: 'emerald', bg: 'bg-emerald-500' },
      { name: 'teal', bg: 'bg-teal-500' },
      { name: 'cyan', bg: 'bg-cyan-500' },
      { name: 'sky', bg: 'bg-sky-500' },
      { name: 'blue', bg: 'bg-blue-500' },
      { name: 'indigo', bg: 'bg-indigo-500' },
      { name: 'violet', bg: 'bg-violet-500' },
      { name: 'purple', bg: 'bg-purple-500' },
      { name: 'fuchsia', bg: 'bg-fuchsia-500' },
      { name: 'pink', bg: 'bg-pink-500' },
      { name: 'rose', bg: 'bg-rose-500' }
    ] %>
    
    <% colors.each do |color| %>
      <button 
        onclick="selectColor('<%= color[:name] %>', '<%= color[:bg] %>')" 
        class="w-full aspect-square rounded-lg border border-slate-200 <%= color[:bg] %> hover:opacity-90 transition-opacity"
        title="<%= color[:name] %>"
      ></button>
    <% end %>
  </div>
</div>

<script>
  function toggleColorPicker() {
    document.getElementById('color-options').classList.toggle('hidden');
  }

  function selectColor(name, bgClass) {
    document.getElementById('selected-color').value = name;
    document.getElementById('color-indicator').className = `absolute right-2 top-1/2 -translate-y-1/2 w-6 h-6 rounded-full border border-slate-200 ${bgClass}`;
    document.getElementById('color-options').classList.add('hidden');
  }

  document.addEventListener('click', function(event) {
    let container = document.getElementById('color-picker-container');
    if (!container.contains(event.target)) {
      document.getElementById('color-options').classList.add('hidden');
    }
  });
</script>
