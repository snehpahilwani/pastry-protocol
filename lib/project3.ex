defmodule Project3 do

  def main(args) do

    if Enum.count(args) == 2 do
      processpid = self()
        {numNodes,_} = Integer.parse(Enum.at(args,0))
        {numRequests,_} = Integer.parse(Enum.at(args,1))
        pastryprotocol(numNodes, numRequests, processpid)
    else
        IO.puts "Invalid number of arguments. Please provide ./project3 numNodes numRequests"
        System.halt(0)
    end
    Process.sleep(:infinity)
    
  end

  def pastryprotocol(numNodes, numRequests, processpid) do
    log4 = round(Float.ceil(:math.log(numNodes) / :math.log(4)))
    idSpace = round(:math.pow(4, log4))
    randList = []
    firstset = []
    numfirstset = numNodes
    IO.puts "Total Nodes to create in the network: " <> "#{numNodes}"
    IO.puts "ID space for the network: 0 - " <> "#{idSpace - 1}"
    IO.puts "Number Of Request Per Node: " <> "#{numRequests}"
    randList = selectRandomNodes(idSpace - 1, randList)
    randList = Enum.shuffle randList
    #IO.inspect(randList)

    firstset = populatefirstset(numfirstset - 1, randList, firstset)
    firstset = Enum.reverse firstset

    #creating server process
    startServer(randList, numfirstset, firstset, numNodes, numRequests, processpid)

    #Creating worker processes
    startWorkers(numNodes, numRequests, randList, numNodes-1, log4)

    # initiating server
    :global.whereis_name(:server) |> send({:go})
  end

  def selectRandomNodes(idSpace, randList) do
    if idSpace < 0 do
      randList
    else 
      randList = randList ++ [idSpace]
      selectRandomNodes(idSpace - 1, randList)
    end
  end

  def populatefirstset(numfirstset, randList, firstset) do
    if numfirstset < 0 do
      firstset
    else
      firstset = firstset ++ [Enum.at(randList, numfirstset)]
      populatefirstset(numfirstset - 1, randList, firstset)
    end
  end


  def startWorkers(numNodes, numRequests, randList, id, log4) do
    if id < 0 do
      IO.puts "Workers created"
    else
      lessleaf = []
      largerleaf = []
      numofback = 0
      total = round(:math.pow(4, log4))
      idspace = Enum.to_list(0..(total - 1))
      idspace = idspace -- [Enum.at(randList, id)]
      table = []
      sublist = [-1, -1, -1, -1]
      table = for i <- 0..(log4 - 1), do: table = table ++ sublist
      pid = spawn(Worker, :listen, [numNodes, numRequests, Enum.at(randList, id), log4, table, numofback, lessleaf, largerleaf, idspace])
      name = "act" <> "#{Enum.at(randList, id)}"
      worker = String.to_atom(name)
      :global.register_name(worker, pid)
      startWorkers(numNodes, numRequests, randList, id - 1, log4)
    end
    
  end

  def startServer(randList, numfirstset, firstset, numNodes, numRequests, processpid) do
    countJoined = 0
    countNotInBoth = 0
    countRouted = 0
    countHops = 0
    countRoutenotinboth = 0
    pid = spawn(Server, :serve, [randList, numfirstset, firstset, countJoined, numNodes, countNotInBoth, countRouted, countHops, numRequests, countRoutenotinboth, processpid])
    :global.register_name(:server, pid)
    pid
  end
end
