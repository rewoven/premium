defmodule RewovenPremiumWeb.Layouts do
  @moduledoc """
  Layouts and shared HTML components for the premium site.
  """
  use RewovenPremiumWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    """
  end

  @doc "Site-wide chrome (nav + footer) for the premium site."
  attr :user, :any, default: nil
  attr :profile, :any, default: nil
  slot :inner_block, required: true

  def premium_page(assigns) do
    ~H"""
    <nav>
      <div class="container nav-inner">
        <a href="https://rewovenapp.com" class="nav-logo">
          <img src="https://rewovenapp.com/assets/logo.png" alt="Rewoven" />
          <span>Rewoven</span>
        </a>
        <ul class="nav-links">
          <li><a href="https://rewovenapp.com">Home</a></li>
          <li><a href="https://rewovenapp.com/brands/">Brands</a></li>
          <%= if @user do %>
            <li><a href="/account">Account</a></li>
            <li><span class="user-pill">{@user["email"]}</span></li>
          <% end %>
        </ul>
      </div>
    </nav>

    <main>
      {render_slot(@inner_block)}
    </main>

    <footer>
      <div class="container">
        <p>A <a href="https://rewovenapp.com">Rewoven</a> service · <a href="mailto:hello@rewovenapp.com">Contact</a></p>
      </div>
    </footer>

    <script>
      (() => {
        const SUPABASE_URL = document.body.dataset.supabaseUrl;
        const SUPABASE_KEY = document.body.dataset.supabaseAnonKey;
        if (!SUPABASE_URL || !SUPABASE_KEY || !window.supabase) return;
        const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

        const subscribeBtn = document.getElementById('subscribe-btn');
        const signInBtn = document.getElementById('sign-in-btn');
        const manageBtn = document.getElementById('manage-btn');

        const getToken = async () => {
          const { data } = await sb.auth.getSession();
          return data.session?.access_token;
        };
        const post = async (path) => {
          const token = await getToken();
          const res = await fetch(path, {
            method: 'POST',
            headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' }
          });
          if (!res.ok) throw new Error('Request failed');
          return res.json();
        };

        if (subscribeBtn) {
          subscribeBtn.addEventListener('click', async () => {
            subscribeBtn.disabled = true;
            const orig = subscribeBtn.textContent;
            subscribeBtn.textContent = 'Loading...';
            try {
              const { url } = await post('/checkout');
              window.location = url;
            } catch (e) {
              alert('Error starting checkout. Please try again.');
              subscribeBtn.disabled = false;
              subscribeBtn.textContent = orig;
            }
          });
        }
        if (signInBtn) {
          signInBtn.addEventListener('click', () => {
            sb.auth.signInWithOAuth({
              provider: 'google',
              options: { redirectTo: window.location.origin + '/' }
            });
          });
        }
        if (manageBtn) {
          manageBtn.addEventListener('click', async () => {
            manageBtn.disabled = true;
            try {
              const { url } = await post('/portal');
              window.location = url;
            } catch (e) { manageBtn.disabled = false; }
          });
        }
      })();
    </script>
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id}></div>
    """
  end
end
