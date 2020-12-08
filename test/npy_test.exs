defmodule NpyTest do
  use ExUnit.Case
  doctest Npy

  test "load dog_output0.npy" do
    assert {:ok, npy} = Npy.load("test/dog_output0.npy")
    assert %Npy{descr: "<f4", fortran_order: false, shape: [1,10647,4]} = npy
  end

  test "load pred0.npy" do
    assert {:ok, npy} = Npy.load("test/pred0.npy")
    assert %Npy{descr: "<f4", fortran_order: false, shape: [1,10647,4]} = npy
  end

  test "load illegal file" do
    assert {:error, "illegal npy file"} = Npy.load("test/test_helper.exs")
  end

  test "load absent file" do
    assert {:error, :enoent} = Npy.load("test/nofile.npy")
  end

  test "to_list" do
    assert {:ok, npy} = Npy.load("test/dog_output0.npy")
    assert [[[4.177847385406494, 2.4681198596954346,7.7223896980285645, 4.816765785217285]|_]] = Npy.to_list(npy)
  end
  
  test "from_list: vector" do
    assert %Npy{descr: "<i4", shape: [5], data: data} = Npy.from_list([1,2,3,4,5], "<i4")
    assert data == <<1,0,0,0, 2,0,0,0, 3,0,0,0, 4,0,0,0, 5,0,0,0>>
  end
  
  test "from_list: matrix" do
    assert %Npy{descr: "<f4", shape: [2,2], data: data} = Npy.from_list([[1.0, 0.0],[0.0, 1.0]], "<f4")
    assert <<1.0::little-32, 0.0::little-32, 0.0::little-32, 1.0::little-32>> == data
  end

  test "from_list: tensor" do
    assert {:ok, npy} = Npy.load("test/dog_output0.npy")
    assert npy == Npy.from_list(Npy.to_list(npy), "<f4")
  end

  test "from_list: []" do
    assert nil == Npy.from_list([], "<f4")
  end
  
  test "from_list: <p16" do
    assert nil == Npy.from_list([1,2,3,4,5], "<i16")
  end
end
