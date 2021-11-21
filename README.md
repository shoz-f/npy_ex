# Npy

Npy handles npy/npz file - loading or saving array and so on. You can use Npy to exchange array data with Python.

  1. load %Npy/%Nx.Tensor from npy file.
  2. load a list of %Npy/%Nx.Tensor from npz - zipped npy - file.
  3. save %Npy/%Nx.Tensor to npy file.
  4. save a list of %Npy/%Nx.Tensor to npz file.
  5. convert %Npy to/from %Nx.Tensor.
  etc.

## Installation
Npy is pure Elixir module. You need to add following code as a dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:npy, git: "https://github.com/shoz-f/npy_ex.git"}
  ]
end
```

I cannot publish this module to Hex, because depending module - Nx - isn't Hex item yet. 

## Hello World
```elixir
iex> t = t = Nx.random_uniform({5,5})
iex> Npy.save("random.npy", t)
iex> {:ok, s} = Npy.load("random.npy")
```

## C++ companion
There are C++ codes to handle npy file under "cxx_companion" directory. You can use it in your C++ application to handle npy free.

## License
Npy is licensed under the Apache License Version 2.0.
