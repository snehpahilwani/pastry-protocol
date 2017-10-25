defmodule Server do
    def serve(randList, numfirstset, firstset, countJoined, numNodes, countNotInBoth, countRouted, countHops, numRequests, countRoutenotinboth, processpid) do
    receive do
        {:go} ->
          IO.puts "Starting Join.."
          messageallworkers("firstjoin", randList, numfirstset - 1, [firstset, "server"])

        {:joinfinish} ->
          countJoined = countJoined + 1
          if countJoined == numfirstset do
            IO.puts "First group join finished for " <> "#{countJoined}" <> " nodes."
            if countJoined >= numNodes do
              :global.whereis_name(:server) |> send({:routeBegin})
            else
              :global.whereis_name(:server) |> send({:secondjoin})
            end
          end

          if countJoined > numfirstset do
            if countJoined == numNodes do
              IO.puts "Routing not in both count: " <> "#{countNotInBoth}"
              :global.whereis_name(:server) |> send({:routeBegin})
            else
              :global.whereis_name(:server) |> send({:secondjoin})
            end
          end

        {:secondjoin} ->
          startid = :rand.uniform(countJoined)
          messageworker(startid, "route", ["join", startid, Enum.at(randList, countJoined), -1, -1])

        {:routeBegin} ->
          IO.puts "Join finished."
          IO.puts "Routing starts.."
          messageallworkers("routeBegin", randList, numNodes - 1, [])

        {:notinboth} ->
          countNotInBoth = countNotInBoth + 1

        {:routingFinished, [fromid, toid, hops]} ->
          countRouted = countRouted + 1
          countHops = countHops + hops
          if countRouted == numNodes * numRequests do
            IO.puts "Total number of routes: " <> "#{countRouted}"
            IO.puts "Total number of hops: " <> "#{countHops}"
            IO.puts "Average hops per route: " <> "#{countHops / countRouted}"
            Process.exit(processpid, :kill)
          end

        {:routenotinboth} ->
          countRoutenotinboth = countRoutenotinboth + 1
    end
    serve(randList, numfirstset, firstset, countJoined, numNodes, countNotInBoth, countRouted, countHops, numRequests, countRoutenotinboth, processpid)
  end

  def messageworker(id, func, args) do
    name = "act" <> "#{id}"
    worker = String.to_atom(name)
    funcatom = String.to_atom(func)
    :global.whereis_name(worker) |> send({funcatom, args})
  end

  def messageworkernoargs(id, func) do
    name = "act" <> "#{id}"
    worker = String.to_atom(name)
    funcatom = String.to_atom(func)
    :global.whereis_name(worker) |> send({funcatom})
  end

  def messageallworkers(func, randList, numNodes, args) when numNodes < 0 do
    IO.puts "Message sent to all workers"
  end

  def messageallworkers(func, randList, numNodes, args) do
    if length(args) == 0 do
      messageworkernoargs(Enum.at(randList, numNodes), func)
    else
      messageworker(Enum.at(randList, numNodes), func, args)
    end
    messageallworkers(func, randList, numNodes - 1, args)
  end

end