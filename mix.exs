defmodule ConcurrentLimiter.MixProject do
  use Mix.Project
  @repo "https://git.pleroma.social/pleroma/elixir-libraries/concurrent_limiter"

  def project do
    [
      app: :concurrent_limiter,
      description: "A concurrency limiter",
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      # Docs
      name: "Concurrent Limiter",
      source_url: @repo,
      homepage_url: @repo,
      docs: [
        main: "ConcurrentLimiter",
        extras: [],
        source_url_pattern: @repo <> "/blob/master/%{path}#L%{line}"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:benchee, "~> 1.0", only: [:dev, :test]}
    ]
  end

  defp package do
    [
      licenses: ["LGPLv3"],
      links: %{"GitLab" => @repo}
    ]
  end
end
