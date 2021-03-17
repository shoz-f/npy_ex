defmodule Npy.MixProject do
  use Mix.Project

  def project do
    [
      app: :npy,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      make_executable: "make",
      make_clean: ["clean"],
      compilers: [:elixir_make] ++ Mix.compilers(),
      deps: deps()
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
         {:elixir_make, "~> 0.6.2", runtime: false},
#         {:exla, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "exla"},
         {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", sparse: "nx", override: true}
    ]
  end
end
