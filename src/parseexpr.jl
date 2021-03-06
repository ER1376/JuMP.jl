#  Copyright 2017, Iain Dunning, Joey Huchette, Miles Lubin, and contributors
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

function tryParseIdxSet(arg::Expr)
    if arg.head === :(=)
        @assert length(arg.args) == 2
        return true, arg.args[1], arg.args[2]
    elseif isexpr(arg, :call) && arg.args[1] === :in
        return true, arg.args[2], arg.args[3]
    else
        return false, nothing, nothing
    end
end

function parseIdxSet(arg::Expr)
    parse_done, idxvar, idxset = tryParseIdxSet(arg)
    if parse_done
        return idxvar, idxset
    end
    error("Invalid syntax: $arg")
end

# addtoexpr(ex::Number, c::Number) = ex + c

addtoexpr(ex::Number, c::Number, x::Number) = ex + c*x

addtoexpr(ex::Number, c::Number, x::VariableRef) = AffExpr([x],[c],ex)

function addtoexpr(ex::Number, c::Number, x::T) where T<:GenericAffExpr
    # It's only safe to mutate the first argument.
    if c == 0
        T(ex)
    else
        x = copy(x)
        scale!(x.coeffs, c)
        x.constant *= c
        x.constant += ex
        x
    end
end

function addtoexpr(ex::Number, c::Number, x::T) where T<:GenericQuadExpr
    # It's only safe to mutate the first argument.
    if c == 0
        T(ex)
    else
        x = copy(x)
        scale!(x.qcoeffs, c)
        scale!(x.aff.coeffs, c)
        x.aff.constant *= c
        x.aff.constant += ex
        x
    end
end

addtoexpr(ex::Number, c::VariableRef, x::VariableRef) = QuadExpr([c],[x],[1.0],zero(AffExpr))

function addtoexpr(ex::Number, c::T, x::T) where T<:GenericAffExpr
    q = c*x
    q.aff.constant += ex
    q
end

function addtoexpr(ex::Number, c::GenericAffExpr{C,V}, x::V) where {C,V}
    q = c*x
    q.aff.constant += ex
    q
end

function addtoexpr(ex::Number, c::T, x::Number) where T<:GenericQuadExpr
    if x == 0
        T(ex)
    else
        q = c*x
        q.aff.constant += ex
        q
    end
end

function addtoexpr(aff::GenericAffExpr, c::Number, x::Number)
    aff.constant += c*x
    aff
end

function addtoexpr(aff::GenericAffExpr{C,V}, c::Number, x::V) where {C,V}
    if c != 0
        push!(aff.vars,   x)
        push!(aff.coeffs, c)
    end
    aff
end

function addtoexpr(aff::GenericAffExpr{C,V},c::Number,x::GenericAffExpr{C,V}) where {C,V}
    if c != 0
        append!(aff.vars, x.vars)
        sizehint!(aff.coeffs, length(aff.coeffs)+length(x.coeffs))
        for i in 1:length(x.coeffs)
            push!(aff.coeffs, c*x.coeffs[i])
        end
        aff.constant += c*x.constant
    end
    aff
end

# help w/ ambiguity
addtoexpr(aff::GenericAffExpr{C,V}, c::Number, x::Number) where {C,V<:Number} = aff + c*x

function addtoexpr(aff::GenericAffExpr{C,V}, c::V, x::Number) where {C,V}
    if x != 0
        push!(aff.vars,   c)
        push!(aff.coeffs, x)
    end
    aff
end

addtoexpr(aff::GenericAffExpr{C,V},c::V,x::V) where {C,V} =
    GenericQuadExpr{C,V}([c],[x],[one(C)],aff)

# TODO: add generic versions of following two methods
addtoexpr(aff::AffExpr,c::AffExpr,x::VariableRef) =
    QuadExpr(c.vars,
             fill(x,length(c.vars)),
             c.coeffs,
             addtoexpr(aff,c.constant,x))

addtoexpr(aff::AffExpr,c::VariableRef,x::AffExpr) =
    QuadExpr(fill(c,length(x.vars)),
             x.vars,
             x.coeffs,
             addtoexpr(aff,c,x.constant))

function addtoexpr(aff::GenericAffExpr{C,V},c::GenericAffExpr{C,V},x::Number) where {C,V}
    if x != 0
        append!(aff.vars, c.vars)
        append!(aff.coeffs, c.coeffs * x)
        aff.constant += c.constant * x
    end
    aff
end

function addtoexpr(aff::GenericAffExpr{C,V}, c::GenericQuadExpr{C,V}, x::Number) where {C,V}
    if x == 0
        GenericQuadExpr{C,V}(aff)
    else
        GenericQuadExpr{C,V}(copy(c.qvars1),
                            copy(c.qvars2),
                            c.qcoeffs*x,
                            addtoexpr(aff,c.aff,x))
    end
end

function addtoexpr(aff::GenericAffExpr{C,V}, c::Number, x::GenericQuadExpr{C,V}) where {C,V}
    if c == 0
        GenericQuadExpr{C,V}(aff)
    else
        GenericQuadExpr{C,V}(copy(x.qvars1),
                            copy(x.qvars2),
                            c*x.qcoeffs,
                            addtoexpr(aff,c,x.aff))
    end
end

function addtoexpr(ex::GenericAffExpr{C,V}, c::GenericAffExpr{C,V}, x::GenericAffExpr{C,V}) where {C,V}
    q = convert(GenericQuadExpr{C,V}, ex)
    addtoexpr(q, one(C), c*x)
    q
end

function addtoexpr(quad::GenericQuadExpr{C,V},c::Number,x::V) where {C,V}
    if c != 0
        push!(quad.aff, convert(C,c), x)
    end
    quad
end

function addtoexpr(quad::GenericQuadExpr,c::Number,x::Number)
    quad.aff.constant += c*x
    quad
end

function addtoexpr(quad::GenericQuadExpr{C,V},x::V,y::V) where {C,V}
    push!(quad.qvars1, x)
    push!(quad.qvars2, y)
    push!(quad.qcoeffs, one(C))
    quad
end

function addtoexpr(quad::GenericQuadExpr{C,V},c::Number,x::GenericAffExpr{C,V}) where {C,V}
    if c != 0
        append!(quad.aff.vars, x.vars)
        sizehint!(quad.aff.coeffs, length(quad.aff.coeffs)+length(x.coeffs))
        for i in 1:length(x.coeffs)
            push!(quad.aff.coeffs, c*x.coeffs[i])
        end
        quad.aff.constant += c*x.constant
    end
    quad
end

function addtoexpr(quad::GenericQuadExpr{C,V},c::GenericAffExpr{C,V},x::Number) where {C,V}
    if x != 0
        addtoexpr(quad.aff,c,x)
    end
    quad
end

function addtoexpr(quad::GenericQuadExpr{C,V},c::GenericAffExpr{C,V},x::V) where {C,V}
    append!(quad.qvars1, c.vars)
    append!(quad.qvars2, fill(x,length(c.vars)))
    append!(quad.qcoeffs, c.coeffs)
    addtoexpr(quad.aff,c.constant,x)
    quad
end

function addtoexpr(quad::GenericQuadExpr{C,V},c::V,x::GenericAffExpr{C,V}) where {C,V}
    append!(quad.qvars1, fill(c,length(x.vars)))
    append!(quad.qvars2, x.vars)
    append!(quad.qcoeffs, x.coeffs)
    addtoexpr(quad.aff,c,x.constant)
    quad
end

function addtoexpr(quad::GenericQuadExpr{C,V},c::GenericQuadExpr{C,V},x::Number) where {C,V}
    if x != 0
        append!(quad.qvars1,c.qvars1)
        append!(quad.qvars2,c.qvars2)
        sizehint!(quad.qcoeffs, length(quad.qcoeffs)+length(c.qcoeffs))
        for i in 1:length(c.qcoeffs)
            push!(quad.qcoeffs, c.qcoeffs[i]*x)
        end
        addtoexpr(quad,c.aff,x)
    end
    quad
end

function addtoexpr(quad::GenericQuadExpr{C,V},c::Number,x::GenericQuadExpr{C,V}) where {C,V}
    if c != 0
        append!(quad.qvars1,x.qvars1)
        append!(quad.qvars2,x.qvars2)
        sizehint!(quad.qcoeffs, length(quad.qcoeffs)+length(x.qcoeffs))
        for i in 1:length(x.qcoeffs)
            push!(quad.qcoeffs, c*x.qcoeffs[i])
        end
        addtoexpr(quad,c,x.aff)
    end
    quad
end

function addtoexpr(ex::GenericQuadExpr{C,V}, c::GenericAffExpr{C,V}, x::GenericAffExpr{C,V}) where {C,V}
    q = c*x
    addtoexpr(ex, 1.0, q)
    ex
end

# Catch nonlinear expressions and parameters being used in addconstraint, etc.

const _NLExpr = Union{NonlinearExpression,NonlinearParameter}
_nlexprerr() = error("""Cannot use nonlinear expression or parameter in @constraint or @objective.
                        Use @NLconstraint or @NLobjective instead.""")
# Following three definitions avoid ambiguity warnings
addtoexpr(expr::GenericQuadExpr{C,V}, c::GenericAffExpr{C,V}, x::V) where {C,V<:_NLExpr} = _nlexprerr()
addtoexpr(expr::GenericQuadExpr{C,V}, c::Number, x::V) where {C,V<:_NLExpr} = _nlexprerr()
addtoexpr(expr::GenericQuadExpr{C,V}, c::V, x::GenericAffExpr{C,V}) where {C,V<:_NLExpr} = _nlexprerr()
for T1 in (GenericAffExpr,GenericQuadExpr), T2 in (Number,VariableRef,GenericAffExpr,GenericQuadExpr)
    @eval addtoexpr(::$T1, ::$T2, ::_NLExpr) = _nlexprerr()
    @eval addtoexpr(::$T1, ::_NLExpr, ::$T2) = _nlexprerr()
end

addtoexpr(ex::AbstractArray{T}, c::AbstractArray, x::AbstractArray) where {T<:GenericAffExpr} = append!.(ex, c*x)
addtoexpr(ex::AbstractArray{T}, c::AbstractArray, x::Number) where {T<:GenericAffExpr} = append!.(ex, c*x)
addtoexpr(ex::AbstractArray{T}, c::Number, x::AbstractArray) where {T<:GenericAffExpr} = append!.(ex, c*x)

addtoexpr(ex, c, x) = ex + c*x

addtoexpr_reorder(ex, arg) = addtoexpr(ex, 1.0, arg)
# Special case because "Val{false}()" is used as the default empty expression.
addtoexpr_reorder(ex::Val{false}, arg) = copy(arg)
addtoexpr_reorder(ex::Val{false}, args...) = (*)(args...)


@generated function addtoexpr_reorder(ex, x, y)
    if x <: Union{VariableRef,AffExpr} && y <: Number
        :(addtoexpr(ex, y, x))
    else
        :(addtoexpr(ex, x, y))
    end
end

@generated function addtoexpr_reorder(ex, args...)
    n = length(args)
    @assert n ≥ 3
    varidx = find(t -> (t == VariableRef || t == AffExpr), collect(args))
    allscalar = all(t -> (t <: Number), args[setdiff(1:n, varidx)])
    idx = (allscalar && length(varidx) == 1) ? varidx[1] : n
    coef = Expr(:call, :*, [:(args[$i]) for i in setdiff(1:n,idx)]...)
    :(addtoexpr(ex, $coef, args[$idx]))
end

# takes a generator statement and returns a properly nested for loop
# with nested filters as specified
function parsegen(ex,atleaf)
    if isexpr(ex,:flatten)
        return parsegen(ex.args[1],atleaf)
    end
    if !isexpr(ex,:generator)
        return atleaf(ex)
    end
    function itrsets(sets)
        if isa(sets,Expr)
            return sets
        elseif length(sets) == 1
            return sets[1]
        else
            return Expr(:block, sets...)
        end
    end

    idxvars = []
    if isexpr(ex.args[2], :filter) # if condition
        loop = Expr(:for,esc(itrsets(ex.args[2].args[2:end])),
                    Expr(:if,esc(ex.args[2].args[1]),
                          parsegen(ex.args[1],atleaf)))
        for idxset in ex.args[2].args[2:end]
            idxvar, s = parseIdxSet(idxset)
            push!(idxvars,idxvar)
        end
    else
        loop = Expr(:for,esc(itrsets(ex.args[2:end])),
                         parsegen(ex.args[1],atleaf))
        for idxset in ex.args[2:end]
            idxvar, s = parseIdxSet(idxset)
            push!(idxvars,idxvar)
        end
    end
    b = Expr(:block)
    for idxvar in idxvars
        push!(b.args, localvar(esc(idxvar)))
    end
    return :(let; $b; $loop; end)
end

function parseGenerator(x::Expr, aff::Symbol, lcoeffs, rcoeffs, newaff=gensym())
    @assert isexpr(x,:call)
    @assert length(x.args) > 1
    @assert isexpr(x.args[2],:generator) || isexpr(x.args[2],:flatten)
    header = x.args[1]
    if issum(header)
        parseGeneratorSum(x.args[2], aff, lcoeffs, rcoeffs, newaff)
    else
        error("Expected sum outside generator expression; got $header")
    end
end

function parseGeneratorSum(x::Expr, aff::Symbol, lcoeffs, rcoeffs, newaff)
    # We used to preallocate the expression at the lowest level of the loop.
    # When rewriting this some benchmarks revealed that it actually doesn't
    # seem to help anymore, so might as well keep the code simple.
    code = parsegen(x, t -> parseExpr(t, aff, lcoeffs, rcoeffs, aff)[2])
    return :($code; $newaff=$aff)
end

is_complex_expr(ex) = isa(ex,Expr) && !isexpr(ex,:ref)

parseExprToplevel(x, aff::Symbol) = parseExpr(x, aff, [], [])

# output is assigned to newaff
function parseExpr(x, aff::Symbol, lcoeffs::Vector, rcoeffs::Vector, newaff::Symbol=gensym())
    if !isa(x,Expr)
        # at the lowest level
        callexpr = Expr(:call,:addtoexpr_reorder,aff,lcoeffs...,esc(x),rcoeffs...)
        return newaff, :($newaff = $callexpr)
    else
        if x.head == :call && x.args[1] == :+
            b = Expr(:block)
            aff_ = aff
            for arg in x.args[2:(end-1)]
                aff_, code = parseExpr(arg, aff_, lcoeffs, rcoeffs)
                push!(b.args, code)
            end
            newaff, code = parseExpr(x.args[end], aff_, lcoeffs, rcoeffs, newaff)
            push!(b.args, code)
            return newaff, b
        elseif x.head == :call && x.args[1] == :-
            if length(x.args) == 2 # unary subtraction
                return parseExpr(x.args[2], aff, vcat(-1.0, lcoeffs), rcoeffs, newaff)
            else # a - b - c ...
                b = Expr(:block)
                aff_, code = parseExpr(x.args[2], aff, lcoeffs, rcoeffs)
                push!(b.args, code)
                for arg in x.args[3:(end-1)]
                    aff_,code = parseExpr(arg, aff_, vcat(-1.0, lcoeffs), rcoeffs)
                    push!(b.args, code)
                end
                newaff,code = parseExpr(x.args[end], aff_, vcat(-1.0, lcoeffs), rcoeffs, newaff)
                push!(b.args, code)
                return newaff, b
            end
        elseif x.head == :call && x.args[1] == :*
            # we might need to recurse on multiple arguments, e.g.,
            # (x+y)*(x+y)
            n_expr = mapreduce(is_complex_expr, +, x.args)
            if n_expr == 1 # special case, only recurse on one argument and don't create temporary objects
                which_idx = 0
                for i in 2:length(x.args)
                    if is_complex_expr(x.args[i])
                        which_idx = i
                    end
                end
                return parseExpr(x.args[which_idx], aff, vcat(lcoeffs, [esc(x.args[i]) for i in 2:(which_idx-1)]),
                                                         vcat(rcoeffs, [esc(x.args[i]) for i in (which_idx+1):length(x.args)]),
                                                         newaff)
            else
                blk = Expr(:block)
                for i in 2:length(x.args)
                    if is_complex_expr(x.args[i])
                        s = gensym()
                        newaff_, parsed = parseExprToplevel(x.args[i], s)
                        push!(blk.args, :($s = 0.0; $parsed))
                        x.args[i] = newaff_
                    else
                        x.args[i] = esc(x.args[i])
                    end
                end
                callexpr = Expr(:call,:addtoexpr_reorder,aff,lcoeffs...,x.args[2:end]...,rcoeffs...)
                push!(blk.args, :($newaff = $callexpr))
                return newaff, blk
            end
        elseif x.head == :call && x.args[1] == :^ && is_complex_expr(x.args[2])
            if x.args[3] == 2
                blk = Expr(:block)
                s = gensym()
                newaff_, parsed = parseExprToplevel(x.args[2], s)
                push!(blk.args, :($s = Val(false); $parsed))
                push!(blk.args, :($newaff = addtoexpr_reorder($aff, $(Expr(:call,:*,lcoeffs...,newaff_,newaff_,rcoeffs...)))))
                return newaff, blk
            elseif x.args[3] == 1
                return parseExpr(:(QuadExpr($(x.args[2]))), aff, lcoeffs, rcoeffs)
            elseif x.args[3] == 0
                return parseExpr(:(QuadExpr(1)), aff, lcoeffs, rcoeffs)
            else
                blk = Expr(:block)
                s = gensym()
                newaff_, parsed = parseExprToplevel(x.args[2], s)
                push!(blk.args, :($s = Val(false); $parsed))
                push!(blk.args, :($newaff = addtoexpr_reorder($aff, $(Expr(:call,:*,lcoeffs...,Expr(:call,:^,newaff_,esc(x.args[3])),rcoeffs...)))))
                return newaff, blk
            end
        elseif x.head == :call && x.args[1] == :/
            @assert length(x.args) == 3
            numerator = x.args[2]
            denom = x.args[3]
            return parseExpr(numerator, aff, lcoeffs,vcat(esc(:(1/$denom)),rcoeffs),newaff)
        elseif isexpr(x,:call) && length(x.args) >= 2 && (isexpr(x.args[2],:generator) || isexpr(x.args[2],:flatten))
            return newaff, parseGenerator(x,aff,lcoeffs,rcoeffs,newaff)
        elseif x.head == :curly
            error_curly(x)
        else # at lowest level?
            !isexpr(x,:comparison) || error("Unexpected comparison in expression $x")
            callexpr = Expr(:call,:addtoexpr_reorder,aff,lcoeffs...,esc(x),rcoeffs...)
            return newaff, :($newaff = $callexpr)
        end
    end
end
