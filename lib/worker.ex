defmodule Worker do
    def listen(numnodes, numrequests, id, log4, table, numofback, leftLeafSet, rightLeafSet, idspace) do
      receive do
        {:firstjoin, [firstSet, sender]} ->
          firstSet = firstSet -- [id]
          rlist = addbuffer(firstSet, length(firstSet) - 1, id, rightLeafSet, leftLeafSet, log4, table)
          table = Enum.at(rlist, 0)
          leftLeafSet = Enum.at(rlist, 1)
          rightLeafSet = Enum.at(rlist, 2)
          :global.whereis_name(:server) |> send({:joinfinish})

        {:route, [msg, fromID, toID, hops, sender]} ->
          cond do
              msg == "join" ->
                    samePre = shl(toBase4String(id, log4), toBase4String(toID, log4))

                    if(hops == -1 && samePre >0) do
                        j = Enum.to_list(0..(samePre - 1))
                        Enum.each(j, fn(s) ->  talkToWorker(toID, "addrow", [s, Enum.at(table, s)])  end)
                    end
                    talkToWorker(toID, "addrow", [samePre,Enum.at(table, samePre)])

                    cond do
                        (length(leftLeafSet) > 0 && toID >= Enum.min(leftLeafSet) && toID <= id)  || (length(rightLeafSet)> 0 && toID <= Enum.max(rightLeafSet) && toID >= id) ->
                              diff = length(idspace) + 10
                              nearest = -1
                              if(toID < id) do
                                rlist = getNearestNode(leftLeafSet, length(leftLeafSet) - 1, diff, nearest, [], toID)
                                diff = Enum.at(rlist, 0)
                                nearest = Enum.at(rlist, 1)

                              else
                                rlist = getNearestNode(rightLeafSet, length(rightLeafSet) - 1, diff, nearest, [], toID)
                                diff = Enum.at(rlist, 0)
                                nearest = Enum.at(rlist, 1)
                              end

                             if(abs(toID - id) > diff) do
                                talkToWorker(nearest, "route", [msg, fromID, toID, hops + 1, id])
                             else
                                allleaf = [id] ++ leftLeafSet ++ rightLeafSet
                                talkToWorker(toID, "addleaf", [allleaf])
                             end

                       (length(leftLeafSet) <= 4 && length(leftLeafSet) > 0 && toID < Enum.min(leftLeafSet)) ->
                             talkToWorker(Enum.min(leftLeafSet), "route", [msg, fromID, toID, hops+1, id])

                       (length(rightLeafSet) <= 4 && length(rightLeafSet) > 0 && toID > Enum.max(rightLeafSet)) ->
                             talkToWorker(Enum.max(rightLeafSet), "route", [msg,fromID, toID, hops+1, id])

                       ((length(leftLeafSet) == 0 && toID < id) || (length(rightLeafSet) == 0 && toID > id)) ->
                             allleaf = [id] ++ leftLeafSet ++ rightLeafSet
                             talkToWorker(toID, "addleaf", [allleaf])

                       getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toID, log4), samePre)) != -1) ->
                             value = getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toID, log4), samePre)))
                             talkToWorker(value, "route", [msg, fromID, toID, hops + 1, id])

                       (toID > id) ->
                             talkToWorker(Enum.max(rightLeafSet), "route", [msg,fromID, toID, hops + 1, id])
                             :global.whereis_name(:server) |> send({String.to_atom("notinboth")})

                       (toID < id) ->
                             talkToWorker(Enum.min(leftLeafSet), "route", [msg,fromID, toID, hops + 1, id])
                             :global.whereis_name(:server) |> send({String.to_atom("notinboth")})

                       true ->  IO.puts "Call it magic, call it true. And it just got broken, broken into two."

                    end

              (msg == "route") ->
                    if(id == toID) do
                      :global.whereis_name(:server) |> send({:routingFinished, [fromID, toID, hops]})
                    else
                      samePre = shl(toBase4String(id, log4), toBase4String(toID, log4))
                      cond do
                         ((length(leftLeafSet) > 0 && toID >= Enum.min(leftLeafSet) && toID < id) ||
                            (length(rightLeafSet) > 0 && toID <= Enum.max(rightLeafSet) && toID > id)) ->
                            diff = length(idspace) + 10
                            nearest = -1

                            if (toID < id) do
                              rlist = getNearestNode(leftLeafSet, length(leftLeafSet) - 1, diff, nearest, [], toID)
                              diff = Enum.at(rlist, 0)
                              nearest = Enum.at(rlist, 1)

                              else
                                rlist = getNearestNode(rightLeafSet, length(rightLeafSet) - 1, diff, nearest, [], toID)
                                diff = Enum.at(rlist, 0)
                                nearest = Enum.at(rlist, 1)
                            end
                            if (abs(toID - id) > diff) do
                              talkToWorker(nearest, "route", [msg, fromID, toID, hops + 1, id])
                            else
                              if hops == -1 do
                                hops = 0
                              end
                              :global.whereis_name(:server) |> send({String.to_atom("routingFinished"), [fromID, toID, hops]})
                            end

                            getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toID, log4), samePre))) != -1 ->
                               talkToWorker(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(toID, log4), samePre))), "route", [msg, fromID, toID, hops + 1, id])

                          (length(leftLeafSet) <= 4 && length(leftLeafSet) > 0 && toID < Enum.min(leftLeafSet)) ->
                             talkToWorker(Enum.min(leftLeafSet), "route", [msg, fromID, toID, hops + 1, id])

                          (length(rightLeafSet) <= 4 && length(rightLeafSet) > 0 && toID > Enum.max(rightLeafSet)) ->
                             talkToWorker(Enum.max(rightLeafSet), "route", [msg, fromID, toID, hops + 1, id])

                          ((length(leftLeafSet) == 0 && toID < id) || (length(rightLeafSet) == 0 && toID > id)) ->
                            if hops == -1 do
                              hops = 0
                            end
                             :global.whereis_name(:server) |> send({String.to_atom("routingFinished"), [fromID, toID, hops]})

                          (toID > id) ->
                             talkToWorker(Enum.max(rightLeafSet), "route", [msg, fromID, toID, hops + 1, id])
                             :global.whereis_name(:server) |> send({String.to_atom("routenotinboth")})

                          (toID < id) ->
                            talkToWorker(Enum.min(leftLeafSet), "route", [msg, fromID, toID, hops + 1, id])
                            :global.whereis_name(:server) |> send({String.to_atom("routenotinboth")})

                          true -> IO.puts "Call it magic, call it true. And it just got broken, broken into two."
                      end
                    end
            end
        {:routeBegin} ->
            ilist = Enum.to_list(0..(numrequests - 1))
            Enum.each ilist, fn(i) ->
               self() |> send({:clocktick})
               :timer.sleep(1000)
            end

        {:updateme, [newnode]} ->
            rlist = addone(newnode, id, rightLeafSet, leftLeafSet, log4, table)
            table = Enum.at(rlist, 0)
            leftLeafSet = Enum.at(rlist, 1)
            rightLeafSet = Enum.at(rlist, 2)
            talkToWorkernoargs(newnode, "ack")

        {:addrow, [rownum, newrow]} ->
          table = addrow(table, rownum, newrow, 3)
          {:ack} ->
            numofback = numofback - 1
            if numofback == 0 do
              :global.whereis_name(:server) |> send({"joinfinish"})
            end

        {:addleaf, [allleaf]} ->
          rlist = addbuffer(allleaf, length(allleaf) - 1, id, rightLeafSet, leftLeafSet, log4, table)
          table = Enum.at(rlist, 0)
          leftLeafSet = Enum.at(rlist, 1)
          rightLeafSet = Enum.at(rlist, 2)
          printinfo(leftLeafSet, rightLeafSet, log4 - 1, table)
          numofback = getNumReturn(leftLeafSet, length(leftLeafSet) - 1, numofback, id)
          numofback = getNumReturn(rightLeafSet, length(rightLeafSet) - 1 , numofback, id)
          numofback = updateMultiple(numofback, id, log4 - 1, table)
          table = updateMultipleRouteTable(log4 - 1, id, log4, table)

          

          {:clocktick} ->
            toID = Enum.random(idspace)
            self() |> send({:route, ["route", id, toID, -1, id]})
      end
      listen(numnodes, numrequests, id, log4, table, numofback, leftLeafSet, rightLeafSet, idspace)
    end

    def updateMultiple(numofback, id, i, table) do
      if i < 0 do
        numofback
      else
        numofback = updateMultiple_j(numofback, id, i, 3, table)
      end
      updateMultiple(numofback, id, i-1, table)
    end

    def updateMultiple_j(numofback, id, i, j, table) do
      if j < 0 do
        numofback
      else
        idxval = Enum.at(Enum.at(table, i), j)
        if idxval != -1 do
          numofback = numofback + 1
          talkToWorker(getfromtable(table, i, j), "updateme", [id])
        end
      end
      updateMultiple_j(numofback, id, i, j - 1, table)
    end

    def addrow(table, rownum, newrow, i) do
      if(i < 0)do
        table
      else
        idxval = Enum.at(Enum.at(table, rownum), i)
        if idxval == -1 do
          table = updateRouteTable(table, rownum, i, Enum.at(newrow, i))
        end
        addrow(table, rownum, newrow, i-1)
      end
    end

    def addbuffer(all, lenall, id, rightLeafSet, leftLeafSet, log4, table) do
      if lenall < 0 do
        rlist = [table, leftLeafSet, rightLeafSet]
        rlist
      else
        s = Enum.at(all, lenall)
        if s > id && !Enum.member?(rightLeafSet,s) do
           if(length(rightLeafSet) < 4) do
              rightLeafSet = rightLeafSet ++ [s]
           else
              if(s < Enum.max(rightLeafSet)) do
               rightLeafSet = rightLeafSet -- [Enum.max(rightLeafSet)]
               rightLeafSet = rightLeafSet ++ [s]
              end
           end
        else
          if s < id && !Enum.member?(leftLeafSet,s) do
             if(length(leftLeafSet) < 4) do
               leftLeafSet = leftLeafSet ++ [s]
             else
               if(s > Enum.min(leftLeafSet)) do
                 leftLeafSet = leftLeafSet -- [Enum.min(leftLeafSet)]
                 leftLeafSet = leftLeafSet ++ [s]
               end
             end
          end
        end
        samePre = shl(toBase4String(id, log4), toBase4String(s, log4))
        if(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(s, log4), samePre))) == -1) do
          tabletemp = table
          table = updateRouteTable(table, samePre, String.to_integer(String.at(toBase4String(s, log4), samePre)), s)
        end
        addbuffer(all, lenall - 1, id, rightLeafSet, leftLeafSet, log4, table)
      end
     end

   def addone(one, id, rightLeafSet, leftLeafSet, log4, table) do
     if (one > id && !Enum.member?(rightLeafSet,one)) do
           if (length(rightLeafSet) < 4) do
             rightLeafSet = rightLeafSet ++ [one]
           else
              if (one < Enum.max(rightLeafSet)) do
                 rightLeafSet = rightLeafSet -- [Enum.max(rightLeafSet)]
                 rightLeafSet = rightLeafSet ++ one
              end
           end
      else
           if (one < id && !Enum.member?(leftLeafSet,one)) do
              if (length(leftLeafSet) < 4) do
                 leftLeafSet = leftLeafSet ++ [one]
              else
                 if (one > Enum.min(leftLeafSet)) do
                   leftLeafSet = leftLeafSet -- [Enum.min(leftLeafSet)]
                   leftLeafSet = leftLeafSet ++ [one]
                 end
              end
            end
      end
     samePre = shl(toBase4String(id, log4), toBase4String(one, log4))

     if(getfromtable(table, samePre, String.to_integer(String.at(toBase4String(one, log4), samePre))) == -1) do
       table = updateRouteTable(table, samePre, String.to_integer(String.at(toBase4String(one, log4), samePre)), one)
     end
     rlist = [table, leftLeafSet, rightLeafSet]
   end

    def toBase4String(raw, len) do
      str = Integer.to_string(raw,4)
      diff = len - String.length(str)
      if diff > 0 do
        str = createstr(str, 1, diff)
      end
      str
    end

    def createstr(str, j, diff) do
      if j > diff do
        str
      else
        str = "0" <> str
        createstr(str, j+1, diff)
      end
    end

    def shl(str1, str2) do
      j = getjshl(str1, str2, 0)
    end

    def getjshl(str1, str2, j) do
      if j < String.length(str1) && String.at(str1, j) == String.at(str2, j) do
        getjshl(str1, str2, j+1)
      else
        j
      end
    end

    def printinfo(leftLeafSet, rightLeafSet, log4, table) do
      if log4 < 0 do
      else
        row = Enum.at(table, log4 - 1)
        Enum.each row, fn row ->
        end
      printinfo(leftLeafSet, rightLeafSet, log4 - 1, table)
      end
    end

    def talkToWorker(id, func, args) do
      name = "act" <> "#{id}"
      worker = String.to_atom(name)
      funcatom = String.to_atom(func)
      :global.whereis_name(worker) |> send({funcatom, args})
    end

    def talkToWorkernoargs(id, func) do
      name = "act" <> "#{id}"
      worker = String.to_atom(name)
      funcatom = String.to_atom(func)
      :global.whereis_name(worker) |> send({funcatom})
    end

    def updateRouteTable(table, i, j, value) do
      val = Enum.at(table, i)
      toreplace = value
      val = List.replace_at(val, j, toreplace)
      table = List.replace_at(table, i, val)
    end

    def getfromtable(table, i, j) do
      val = Enum.at(Enum.at(table, i), j)
    end

    def getNumReturn(list, lenlist, numofback, id) do
      if lenlist < 0 do
        numofback
      else
        numofback = numofback + 1
        talkToWorker(Enum.at(list, lenlist), "updateme", [id])
        getNumReturn(list, lenlist - 1, numofback, id)
      end
    end

    def updateMultipleRouteTable(lenlist, id, log4, table) do
      if lenlist < 0 do
        table
      else
        jidx = String.to_integer(String.at(toBase4String(id, log4), lenlist))
        table = updateRouteTable(table, lenlist, jidx, id)
        updateMultipleRouteTable(lenlist - 1, id, log4, table)
      end
    end

    def initiateTable(table, id, log4, s) do
      if s < 0 do
        table
      else
        jidx = String.to_integer(String.at(toBase4String(id, log4), s))
        table = updateRouteTable(table, s, jidx, id)
        initiateTable(table, id, log4, s-1)
      end
    end

    def getNearestNode(list, lenlist, diff, nearest, rlist, toID) do
      if lenlist < 0 do
      rlist = [diff, nearest]
      rlist
      else
        if (abs(toID - Enum.at(list, lenlist)) < diff) do
          nearest = Enum.at(list, lenlist)
          diff = abs(toID - Enum.at(list, lenlist))
        end
        getNearestNode(list, lenlist - 1, diff, nearest, rlist, toID)
      end
    end

    
  end
