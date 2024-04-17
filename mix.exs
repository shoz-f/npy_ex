defmodule Npy.MixProject do
  use Mix.Project

  def project do
    [
      app: :npy,
      version: "0.1.3",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      description: description(),
      package: package(),
#      name: "npy_ex",
      source_url: "https://github.com/shoz-f/npy_ex.git",

      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.14", only: :dev, runtime: false},
#      {:nx, "~> 0.2.1"}
    ]
  end

  defp description() do
    "manipulating .npy in Elixir."
  end

  defp package() do
    [
       name: "npy",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/shoz-f/npy_ex.git"},
      files: ~w(lib mix.exs README* CHANGELOG* LICENSE*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
#        "LICENSE",
        "CHANGELOG.md"
      ],
#      source_ref: "v#{@version}",
#      source_url: @source_url,
#      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
