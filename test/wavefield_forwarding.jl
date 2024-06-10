
function wavefield_forwarding_set(DIM::Int)

    eqstrs = String[]

    for i = 1:DIM
        push!(eqstrs, "∂t u$i == v$i")
    end

    for i = 1:DIM
        push!(eqstrs, "∂t v$i == a$i")
    end

    for i = 1:DIM
        left = "a$i"
        right = "(f$i"
        for j = 1:DIM
            right *= " + ∂x$j σ$(min(i,j))$(max(i,j))"
        end
        right *= ")/ρ"
        push!(eqstrs, left*" == "*right)
    end

    for i = 1:DIM
        for j = 1:i
            if i == j
                push!(eqstrs, "ϵ$i$i == ∂x$i u$i")
            else
                push!(eqstrs, "ϵ$j$i == 0.5 * (∂x$j u$i + ∂x$i u$j)")
            end
        end
    end

    push!(eqstrs, "ϵ0 == " * join(map(i->"ϵ$i$i", 1:DIM), " + "))

    for i = 1:DIM
        for j = 1:i
            if i == j
                push!(eqstrs, "σ$j$i == 2 * μ * ϵ$j$i + λ * ϵ0")
            else
                push!(eqstrs, "σ$j$i == 2 * μ * ϵ$j$i")
            end
        end
    end
    return eqstrs
end
