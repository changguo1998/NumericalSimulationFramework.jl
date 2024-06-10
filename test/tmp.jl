if !(@isdefined GE)
    include(joinpath(@__DIR__, "../src/NumericalSimulationFramework.jl"))
    GE = NumericalSimulationFramework.GoverningEquation
    include("wavefield_forwarding.jl")
end

eqset = wavefield_forwarding_set(2)
eqexprs = GE.Equation.(eqset)
leftvars = vcat(map(e->GE.getexpressionvars(e.left), eqexprs)...) |> sort |> unique
rightvars = vcat(map(e->GE.getexpressionvars(e.right), eqexprs)...) |> sort |> unique
allvars = [leftvars; rightvars] |> unique |> sort
indepvars = GE.Expression[]
relation = falses(length(allvars), length(allvars))

for eq = eqexprs
    println("============")
    GE.printexpression(eq.left)
    println("-"^8)
    GE.printexpression(eq.right)
    println("-"^8)
    if isempty(eq.left.operands)
        varout = eq.left
    else
        push!(indepvars, eq.left.operands[1])
        varout = eq.left.operands[2]
        ivar = findfirst(==(varout), allvars)
        jvar = findfirst(==(eq.left.operands[1]), allvars)
        relation[jvar, ivar] = true
    end
    println(varout)
    ivar = findfirst(==(varout), allvars)
    reqvars = GE.getexpressionvars(eq.right) |> sort |> unique
    for rv = reqvars
        jvar = findfirst(==(rv), allvars)
        relation[jvar, ivar] = true
    end
    buffexpr = GE.Expression[]
    push!(buffexpr, eq.right)
    while !isempty(buffexpr)
        global indepvars
        texpr = popfirst!(buffexpr)
        append!(buffexpr, texpr.operands)
        if texpr.operator == "∂"
            push!(indepvars, texpr.operands[1])
            println(texpr.operands[1])
        end
    end
end

unique!(sort!(indepvars))

for i = axes(relation, 2)
    if allvars[i] ∈ indepvars
        print(allvars[i].operator, "* <-")
    else
        print(allvars[i].operator, "  <-")
    end
    for j = axes(relation, 1)
        if relation[j, i]
            print(" ", allvars[j].operator)
        end
    end
    println("")
end
