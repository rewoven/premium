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

  @doc "Site-wide chrome (nav + footer + styles) for the premium site."
  attr :user, :any, default: nil
  attr :profile, :any, default: nil
  slot :inner_block, required: true

  def premium_page(assigns) do
    ~H"""
    <style>
      *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }
      html { scroll-behavior: smooth; }
      :root {
        --green-50:#ECFDF5; --green-100:#D1FAE5; --green-200:#A7F3D0;
        --green-400:#34D399; --green-500:#10B981; --green-600:#059669;
        --green-700:#047857; --green-800:#065F46; --green-900:#064E3B;
        --gold:#F59E0B; --dark:#111827; --gray-600:#4B5563;
        --gray-400:#9CA3AF; --gray-200:#E5E7EB; --white:#FFFFFF;
        --bg-cream:#F0FDF4; --radius:16px;
      }
      body {
        font-family:'Inter',-apple-system,BlinkMacSystemFont,sans-serif;
        color:var(--dark); background:var(--white);
        -webkit-font-smoothing:antialiased; overflow-x:hidden;
      }
      .container { max-width:1200px; margin:0 auto; padding:0 24px; }
      a { color:inherit; text-decoration:none; }
      h1,h2,h3 { font-family:'Playfair Display',serif; }

      .btn {
        display:inline-flex; align-items:center; gap:10px;
        padding:14px 28px; border-radius:50px; font-weight:600;
        font-size:16px; text-decoration:none; transition:all .25s ease;
        border:none; cursor:pointer; font-family:inherit;
      }
      .btn-primary {
        background:var(--green-500); color:var(--white);
        box-shadow:0 4px 14px rgba(16,185,129,.4);
      }
      .btn-primary:hover {
        background:var(--green-600); transform:translateY(-2px);
        box-shadow:0 6px 20px rgba(16,185,129,.5);
      }
      .btn-secondary {
        background:var(--white); color:var(--green-700);
        border:2px solid var(--green-200);
      }
      .btn-secondary:hover {
        border-color:var(--green-500); background:var(--green-50);
      }
      .btn-xl { padding:18px 38px; font-size:18px; }

      nav {
        position:fixed; top:0; left:0; right:0; z-index:100;
        background:rgba(255,255,255,.85); backdrop-filter:blur(20px);
        border-bottom:1px solid rgba(229,231,235,.5);
      }
      nav .container { display:flex; align-items:center; justify-content:space-between; height:72px; }
      .nav-logo { display:flex; align-items:center; gap:12px; }
      .nav-logo img { width:40px; height:40px; border-radius:10px; }
      .nav-logo span { font-family:'Playfair Display',serif; font-size:22px; font-weight:800; color:var(--green-800); }
      .nav-links { display:flex; gap:24px; align-items:center; list-style:none; }
      .nav-links a { color:var(--gray-600); font-size:15px; font-weight:500; }
      .nav-links a:hover { color:var(--green-600); }
      .user-pill {
        display:inline-flex; align-items:center; gap:8px;
        padding:6px 14px; border-radius:50px;
        background:var(--green-50); color:var(--green-700);
        font-size:13px; font-weight:600;
      }

      .hero {
        min-height:90vh; display:flex; align-items:center;
        background:linear-gradient(180deg,var(--bg-cream) 0%,var(--green-50) 40%,var(--white) 100%);
        padding-top:72px; position:relative; overflow:hidden;
      }
      .hero::before {
        content:''; position:absolute; top:-200px; right:-200px;
        width:600px; height:600px; border-radius:50%;
        background:radial-gradient(circle,rgba(16,185,129,.08) 0%,transparent 70%);
      }
      .hero-content { max-width:780px; padding:80px 0; }
      .badge {
        display:inline-block; padding:6px 16px; border-radius:50px;
        background:var(--green-100); color:var(--green-700);
        font-size:13px; font-weight:700; letter-spacing:.5px;
        margin-bottom:24px;
      }
      .hero-content h1 {
        font-size:clamp(40px,6vw,64px); font-weight:900;
        line-height:1.1; color:var(--dark); margin-bottom:24px;
      }
      .highlight {
        background:linear-gradient(135deg,var(--green-500),var(--green-700));
        -webkit-background-clip:text; -webkit-text-fill-color:transparent;
        background-clip:text;
      }
      .lede { font-size:20px; line-height:1.7; color:var(--gray-600); margin-bottom:36px; max-width:620px; }
      .cta-note { margin-top:14px; font-size:13px; color:var(--gray-400); }

      .card {
        background:var(--white); border:1px solid var(--gray-200);
        border-radius:var(--radius); padding:24px;
      }
      .status-card {
        display:flex; align-items:center; gap:18px; max-width:560px;
        background:var(--green-50); border-color:var(--green-200);
      }
      .status-icon { font-size:36px; }
      .status-card h3 { font-family:'Inter',sans-serif; font-size:18px; font-weight:800; }
      .status-card p { font-size:14px; color:var(--gray-600); }

      .features { padding:100px 0; background:var(--white); }
      .section-title {
        font-size:clamp(32px,5vw,48px); font-weight:800;
        text-align:center; margin-bottom:64px; line-height:1.2;
      }
      .section-subtitle {
        font-size:18px; line-height:1.7; color:var(--gray-600);
        max-width:720px; margin:0 auto; text-align:center;
      }
      .feature-grid {
        display:grid; grid-template-columns:repeat(3,1fr); gap:32px;
      }
      .feature-card {
        background:var(--bg-cream); border:1px solid var(--green-100);
        border-radius:var(--radius); padding:36px 28px;
        transition:transform .25s, box-shadow .25s;
      }
      .feature-card:hover {
        transform:translateY(-4px);
        box-shadow:0 12px 32px rgba(16,185,129,.12);
      }
      .feature-icon { font-size:42px; margin-bottom:18px; }
      .feature-card h3 { font-family:'Inter',sans-serif; font-size:20px; font-weight:800; margin-bottom:10px; }
      .feature-card p { color:var(--gray-600); line-height:1.65; font-size:15px; }

      .why { padding:100px 0; background:var(--green-50); }

      footer {
        padding:48px 0; text-align:center; color:var(--gray-400);
        font-size:14px; border-top:1px solid var(--gray-200);
      }
      footer a { color:var(--green-600); font-weight:600; }

      @media (max-width: 760px) {
        .feature-grid { grid-template-columns:1fr; }
        .nav-links li:not(:last-child) { display:none; }
      }
    </style>

    <nav>
      <div class="container">
        <a href="https://rewovenapp.com" class="nav-logo">
          <img src="https://rewovenapp.com/assets/logo.png" alt="Rewoven" />
          <span>Rewoven</span>
        </a>
        <ul class="nav-links">
          <li><a href="https://rewovenapp.com">Home</a></li>
          <li><a href="https://quiz.rewovenapp.com">Quiz</a></li>
          <li><a href="https://rewovenapp.com/brands/">Brands</a></li>
          <%= if @user do %>
            <li><span class="user-pill">{@user["email"]}</span></li>
          <% end %>
        </ul>
      </div>
    </nav>

    {render_slot(@inner_block)}

    <footer>
      <div class="container">
        <p>A <a href="https://rewovenapp.com">Rewoven</a> service · <a href="mailto:hello@rewovenapp.com">Contact</a></p>
      </div>
    </footer>

    <script>
      (() => {
        const SUPABASE_URL = document.body.dataset.supabaseUrl;
        const SUPABASE_KEY = document.body.dataset.supabaseAnonKey;
        if (!SUPABASE_URL || !SUPABASE_KEY) return;
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
            subscribeBtn.textContent = 'Loading...';
            try {
              const { url } = await post('/checkout');
              window.location = url;
            } catch (e) {
              alert('Error starting checkout. Please try again.');
              subscribeBtn.disabled = false;
              subscribeBtn.textContent = 'Subscribe — $4.99/mo';
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
