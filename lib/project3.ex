defmodule Project3 do
  def main(args) do
        if Enum.count(args) == 2 do
            {numNodes,_} = Integer.parse(Enum.at(args,0))
            {numRequests,_} = Integer.parse(Enum.at(args,1))
        else
            IO.puts "Invalid number of arguments. Please provide ./project3 numNodes numRequests"
            System.halt(0)
        end
  end
end
