defmodule RewovenPremiumWeb.PageHTML do
  @moduledoc """
  Templates for PageController. Imports Layouts so templates can call
  `<.premium_page>`.
  """
  use RewovenPremiumWeb, :html
  import RewovenPremiumWeb.Layouts, only: [premium_page: 1]

  embed_templates "page_html/*"
end
