module JuMPExtension
# Simple example of JuMP extension used in the tests to check that JuMP works well with extensions
# The main difference between `JuMP.Model` and `JuMPExtension.MyModel` is the fact that in `addvariable` (resp. `addconstraint`),
# `JuMP.Model` applies the modification to its `moibackend` field while
# `JuMPExtension.MyModel` stores the `AbstractVariable` (resp. `AbstractConstraint`) in a list.

using MathOptInterface
const MOI = MathOptInterface
using JuMP

mutable struct MyModel <: JuMP.AbstractModel
    nextvaridx::Int                                 # Next variable index is nextvaridx+1
    variables::Dict{Int, JuMP.AbstractVariable}     # Map varidx -> variable
    varnames::Dict{Int, String}                     # Map varidx -> name
    nextconidx::Int                                 # Next constraint index is nextconidx+1
    constraints::Dict{Int, JuMP.AbstractConstraint} # Map conidx -> variable
    connames::Dict{Int, String}                     # Map varidx -> name
    objectivesense::Symbol
    objectivefunction::JuMP.AbstractJuMPScalar
    objdict::Dict{Symbol, Any}                      # Same that JuMP.Model's field `objdict`
    function MyModel()
        new(0, Dict{Int, JuMP.AbstractVariable}(),   Dict{Int, String}(), # Variables
            0, Dict{Int, JuMP.AbstractConstraint}(), Dict{Int, String}(), # Constraints
            :Min, zero(JuMP.GenericAffExpr{Float64, MyVariableRef}),
            Dict{Symbol, Any}())
    end
end

JuMP.object_dictionary(m::MyModel) = m.objdict

# Variables
struct MyVariableRef <: JuMP.AbstractVariableRef
    model::MyModel # `model` owning the variable
    idx::Int       # Index in `model.variables`
end
Base.copy(v::MyVariableRef) = v
Base.:(==)(v::MyVariableRef, w::MyVariableRef) = v.model === w.model && v.idx == w.idx
JuMP.isequal_canonical(v::MyVariableRef, w::MyVariableRef) = v == w
JuMP.variabletype(::MyModel) = MyVariableRef
function JuMP.addvariable(m::MyModel, v::JuMP.AbstractVariable, name::String="")
    m.nextvaridx += 1
    vref = MyVariableRef(m, m.nextvaridx)
    m.variables[vref.idx] = v
    JuMP.setname(vref, name)
    vref
end
function MOI.delete!(m::MyModel, vref::MyVariableRef)
    delete!(m.variables, vref.idx)
    delete!(m.varnames, vref.idx)
end
MOI.isvalid(m::MyModel, vref::MyVariableRef) = vref.idx in keys(m.variables)

# Constraints
struct MyConstraintRef
    model::MyModel # `model` owning the constraint
    idx::Int       # Index in `model.constraints`
end
JuMP.constrainttype(::MyModel) = MyConstraintRef
function JuMP.addconstraint(m::MyModel, c::JuMP.AbstractConstraint, name::String="")
    m.nextconidx += 1
    cref = MyConstraintRef(m, m.nextconidx)
    m.constraints[cref.idx] = c
    JuMP.setname(cref, name)
    cref
end
function MOI.delete!(m::MyModel, cref::MyConstraintRef)
    delete!(m.constraints, cref.idx)
    delete!(m.connames, cref.idx)
end
MOI.isvalid(m::MyModel, cref::MyConstraintRef) = cref.idx in keys(m.constraints)
function JuMP.constraintobject(cref::MyConstraintRef, F::Type, S::Type)
    c = cref.model.constraints[cref.idx]
    # `TypeError` should be thrown is `F` and `S` are not correct
    # This is needed for the tests in `constraints.jl`
    c.func::F
    c.set::S
    c
end

# Objective
function JuMP.setobjective(m::MyModel, sense::Symbol, f::JuMP.AbstractJuMPScalar)
    m.objectivesense = sense
    m.objectivefunction = f
end

# Names
JuMP.name(vref::MyVariableRef) = vref.model.varnames[vref.idx]
function JuMP.setname(vref::MyVariableRef, name::String)
    vref.model.varnames[vref.idx] = name
end
JuMP.name(cref::MyConstraintRef) = cref.model.connames[cref.idx]
function JuMP.setname(cref::MyConstraintRef, name::String)
    cref.model.connames[cref.idx] = name
end

end
