"""
GoverningEquation

Parse equation and numerically discretize them.
"""
module GoverningEquation

export Expression

"""
```
struct Expression
    operator::String
    operands::Vector{Expression}
end
```
"""
struct Expression
    operator::String
    operands::Vector{Expression}
end

Expression(optr::AbstractString, operands::Vector{Expression}=Expression[]) =
    Expression(String(optr), operands)

function _operatorlevel(c::AbstractChar)
    if c ∈ ['+', '-']
        return 4
    elseif c ∈ ['*', '/']
        return 3
    elseif c ∈ ['∂']
        return 2
    elseif c ∈ ['(', ')']
        return 1
    else
        return 0
    end
end

function _split_string_to_expression_vector(str::AbstractString)
    buffer = collect(str)
    # println("buffer: ", buffer)
    # single symbol operator
    flag_seprator = map(buffer) do c
        c ∈ ['+', '-', '*', '/', '(', ')', '∂', ' ']
    end

    varbegin = 0
    varend = 0

    symbuffer = Any[]
    symlevel = Int[]
    for i = eachindex(buffer)
        if flag_seprator[i]
            if varbegin < varend
                push!(symbuffer, strip(join(buffer[varbegin+1:varend])))
                push!(symlevel, 0)
            end
            varbegin = i
            varend = i
            if buffer[i] != ' '
                push!(symbuffer, buffer[i])
                push!(symlevel, _operatorlevel(buffer[i]))
            end
        else
            varend = i
        end
    end
    if varbegin < varend
        push!(symbuffer, strip(join(buffer[varbegin+1:varend])))
        push!(symlevel, 0)
    end

    # println(symbuffer, symlevel)

    tbuffer = deepcopy(symbuffer)
    symbuffer = Any[]
    for i = eachindex(symlevel)
        if iszero(symlevel[i])
            push!(symbuffer, Expression(tbuffer[i]))
        else
            push!(symbuffer, tbuffer[i])
        end
    end
    return (symbuffer, symlevel)
end

function _bracepair(symvec::Vector{Any}, minloc::Int)
    bl = zeros(Int, length(symvec))
    lcur = 0
    for i = eachindex(symvec)
        if symvec[i] == '('
            lcur += 1
        end
        bl[i] = lcur
        if symvec[i] == ')'
            lcur -= 1
        end
    end
    minloc2 = minloc
    for i = eachindex(bl)
        if i <= minloc2
            continue
        end
        if bl[i] == bl[minloc]
            if i == length(bl)
                minloc2 = i
            end
            continue
        else
            minloc2 = i-1
            break
        end
    end
    return minloc2
end

function _interprete_expression(tsymbuffer::Vector{Any}, tsymlevel::Vector{Int})
    symbuffer = deepcopy(tsymbuffer)
    symlevel = deepcopy(tsymlevel)
    # println(symbuffer)
    while any(>(0), symlevel)
        # println("\n=======")
        minloc = 0
        minval = maximum(symlevel)+1
        for i = eachindex(symlevel)
            if !iszero(symlevel[i])
                if minval > symlevel[i]
                    minval = symlevel[i]
                    minloc = i
                end
            end
        end
        # println("minloc: ", minloc, ", minval: ", minval)
        if minval == 1
            minloc2 = _bracepair(symbuffer, minloc)
            # println("brace range: $minloc - $minloc2")
            tbuffer = deepcopy(symbuffer)
            tlevel = deepcopy(symlevel)
            symbuffer = deepcopy(tbuffer[1:minloc-1])
            symlevel = deepcopy(tlevel[1:minloc-1])
            push!(symbuffer, _interprete_expression(tbuffer[minloc+1:minloc2-1], tlevel[minloc+1:minloc2-1]))
            push!(symlevel, 0)
            append!(symbuffer, tbuffer[minloc2+1:end])
            append!(symlevel, tlevel[minloc2+1:end])
        elseif minval == 2
            if (symlevel[minloc+1]>0) || (symlevel[minloc+2]>0)
                error("must ∂ var1 var2")
            end
            tbuffer = deepcopy(symbuffer)
            tlevel = deepcopy(symlevel)
            symbuffer = deepcopy(tbuffer[1:minloc-1])
            symlevel = deepcopy(tlevel[1:minloc-1])
            push!(symbuffer, Expression(String([tbuffer[minloc]]), tbuffer[minloc+1:minloc+2]))
            push!(symlevel, 0)
            append!(symbuffer, tbuffer[minloc+3:end])
            append!(symlevel, tlevel[minloc+3:end])
        elseif minval ∈ [3, 4]
            if (symlevel[minloc-1]>0) || (symlevel[minloc+1]>0)
                error("must var1 [+-*/] var2")
            end
            tbuffer = deepcopy(symbuffer)
            tlevel = deepcopy(symlevel)
            # println(tbuffer)
            # println(tbuffer[1:minloc-2])
            symbuffer = deepcopy(tbuffer[1:minloc-2])
            symlevel = deepcopy(tlevel[1:minloc-2])
            push!(symbuffer, Expression(String([tbuffer[minloc]]), [tbuffer[minloc-1], tbuffer[minloc+1]]))
            push!(symlevel, 0)
            append!(symbuffer, tbuffer[minloc+2:end])
            append!(symlevel, tlevel[minloc+2:end])
        end
    end
    return symbuffer[1]
end

export parse_string2expression, printexpression

"""
parse_string2expression(str::AbstractString)

===
Example

```julia
str = "a+b"
expr = parse_expression_str(str)

expr: Expression("+", [
    Expression("a", []),
    Expression("b", [])
])
```
"""
function parse_string2expression(str::AbstractString)
    (symbuffer, symlevel) = _split_string_to_expression_vector(str)
    return _interprete_expression(symbuffer, symlevel)
end

function printexpression(expr::Expression, indent::String="")
    println(indent, expr.operator)
    for e in expr.operands
        printexpression(e, "  "*indent)
    end
    return nothing
end

export Equation

struct Equation
    left::Expression
    right::Expression
end

function Equation(str::AbstractString)
    ir = findfirst("==", str)
    # println(ir)
    # println("left: ", str[1:prevind(str, ir[1])])
    leftpart  = parse_string2expression(str[1:prevind(str, ir[1])])
    # println("right: ", str[nextind(str, ir[end]):end])
    rightpart = parse_string2expression(str[nextind(str, ir[end]):end])
    return Equation(leftpart, rightpart)
end


end # module GoverningEquation
