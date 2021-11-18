defmodule Npy.MixProject do
  use Mix.Project

  def project do
    [
      app: :npy,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
#      description: description(),
#      package: package(),
      deps: deps(),
      name: "npy_ex",
      source_url: "https://github.com/shoz-f/npy_ex.git"
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
      {:nx, "~> 0.1.0-dev", github: "elixir-nx/nx", branch: "main", sparse: "nx"}
    ]
  end
  
#  defp description() do
#    "manipulating .npy in Elixir."
#  end
#
#  defp package() do
#    [
#       name: "npy_ex",
#      licenses: ["Apache-2.0"],
#      links: %{"GitHub" => "https://github.com/shoz-f/npy_ex.git"}
#    ]
#  end
end
