# TODO: in this file are used many methods TEMPORARILY defined in files matrix_manipulation.jl and stuff_field_gen.jl
# once methods in those files will be deleted / replaced / modified, this file need to be modified too




# descr is always defined
# matrix is always defined except when descr="quadratic"; in such a case, at least one of matrix and pol is defined
# NOTE: the field ring_iso is always defined if the field X is
"""
    SesquilinearForm{T<:RingElem}

Type of groups `G` of `n x n` matrices over the ring `R`, where `n = degree(G)` and `R = base_ring(G)`.
At the moment, only rings of type `fqPolyRepField` are supported.
"""
mutable struct SesquilinearForm{T<:RingElem}
   matrix::MatElem{T}
   descr::Symbol       # quadratic, symmetric, alternating or hermitian
   pol::MPolyRingElem{T}     # only for quadratic forms
   X::GapObj
   ring_iso::MapFromFunc

   function SesquilinearForm{T}(B::MatElem{T},sym) where T
      if sym==:hermitian
         @assert is_hermitian(B) "The matrix is not hermitian"
      elseif sym==:symmetric
         @assert is_symmetric(B) "The matrix is not symmetric"
      elseif sym==:alternating
         @assert is_alternating(B) "The matrix does not correspond to an alternating form"
      elseif sym != :quadratic
         error("Unsupported description")
      end

      if sym==:quadratic
         return new{T}(_upper_triangular_version(B),sym)
      else
         return new{T}(B,sym)
      end
   end

   function SesquilinearForm{T}(f::MPolyRingElem{T},sym) where T
      @assert sym==:quadratic "Only quadratic forms are described by polynomials"
      @assert Set([total_degree(x) for x in AbstractAlgebra.monomials(f)])==Set(2) "The polynomials is not homogeneous of degree 2"
      r = new{T}()
      r.pol = f
      r.descr = :quadratic
      return r
   end
end

SesquilinearForm(B::MatElem{T}, sym) where T = SesquilinearForm{T}(B,sym)
SesquilinearForm(f::MPolyRingElem{T},sym) where T = SesquilinearForm{T}(f,sym)



########################################################################
#
# Properties
#
########################################################################


"""
    is_alternating(f::SesquilinearForm)

Return whether the form `f` is an alternating form.
"""
is_alternating(f::SesquilinearForm) = f.descr==:alternating

"""
    is_hermitian(f::SesquilinearForm)

Return whether the form `f` is a hermitian form.
"""
is_hermitian(f::SesquilinearForm) = f.descr==:hermitian

"""
    is_quadratic(f::SesquilinearForm)

Return whether the form `f` is a quadratic form.
"""
is_quadratic(f::SesquilinearForm) = f.descr==:quadratic

"""
    is_symmetric(f::SesquilinearForm)

Return whether the form `f` is a symmetric form.
"""
is_symmetric(f::SesquilinearForm) = f.descr==:symmetric


########################################################################
#
# Constructors
#
########################################################################


"""
    alternating_form(B::MatElem{T})

Return the alternating form with Gram matrix `B`.
"""
alternating_form(B::MatElem{T}) where T <: FieldElem = SesquilinearForm(B, :alternating)

"""
    symmetric_form(B::MatElem{T})

Return the symmetric form with Gram matrix `B`.
"""
symmetric_form(B::MatElem{T}) where T <: FieldElem = SesquilinearForm(B, :symmetric)

"""
    hermitian_form(B::MatElem{T})

Return the hermitian form with Gram matrix `B`.
"""
hermitian_form(B::MatElem{T}) where T <: FieldElem = SesquilinearForm(B, :hermitian)

# turns the matrix of a quadratic form into an upper triangular matrix of the same form
# (two matrices A,B represent the same quadratic form iff A-B is skew-symmetric)
function _upper_triangular_version(C::MatElem)
   B = deepcopy(C)
   for i in 1:nrows(B), j in i+1:nrows(B)
      B[i,j]+=B[j,i]
      B[j,i]=0
   end
   return B
end

"""
    quadratic_form(B::MatElem{T})

Return the quadratic form with Gram matrix `B`.
"""
quadratic_form(B::MatElem{T}) where T <: FieldElem = SesquilinearForm(B, :quadratic)

"""
    quadratic_form(f::MPolyRingElem{T}; check=true)

Return the quadratic form described by the polynomial `f`.
Here, `f` must be a homogeneous polynomial of degree 2.
If `check` is set as `false`, it does not check whether the polynomial is homogeneous of degree 2.
To define quadratic forms of dimension 1, `f` can also have type `PolyRingElem{T}`.
"""
quadratic_form(f::MPolyRingElem{T}) where T <: FieldElem = SesquilinearForm(f, :quadratic)
# TODO : neither is_homogeneous or is_homogeneous works for variables of type MPolyRingElem{T}

# just to allow quadratic forms over vector fields of dimension 1, so defined over polynomials in 1 variable
function quadratic_form(f::PolyRingElem{T}) where T <: FieldElem
   @assert degree(f)==2 && coefficients(f)[0]==0 && coefficients(f)[1]==0 "The polynomials is not homogeneous of degree 2"
   R1 = polynomial_ring(base_ring(f), [string(parent(f).S)]; cached=false)[1]

   return SesquilinearForm(R1[1]^2*coefficients(f)[2], :quadratic)
end

########################################################################
#
# Show
#
########################################################################


function Base.show(io::IO, f::SesquilinearForm)
   println(io, "$(f.descr) form with Gram matrix ")
   show(io, "text/plain", gram_matrix(f))
end




########################################################################
#
# Basic
#
########################################################################

#TODO: checking whether two quadratic forms coincide by checking their polynomials is not possible yet.
==(B::SesquilinearForm, C::SesquilinearForm) = B.descr == C.descr && gram_matrix(B) == gram_matrix(C)

function Base.hash(f::SesquilinearForm, h::UInt)
   b = 0xf64440baac005f8c % UInt
   h = hash(f.descr, h)
   h = hash(gram_matrix(f), h)
   return xor(h, b)
end

function base_ring(B::SesquilinearForm)
   if isdefined(B,:matrix) return base_ring(gram_matrix(B))
   else return base_ring(B.pol)
   end
end

"""
    corresponding_bilinear_form(Q::SesquilinearForm)

Given a quadratic form `Q`, return the bilinear form `B` defined by `B(u,v) = Q(u+v)-Q(u)-Q(v)`.
"""
function corresponding_bilinear_form(B::SesquilinearForm)
   @req B.descr==:quadratic "The form must be a quadratic form"
   M = gram_matrix(B)+transpose(gram_matrix(B))
   if characteristic(base_ring(B))==2 return alternating_form(M)
   else return symmetric_form(M)
   end
end

"""
    corresponding_quadratic_form(Q::SesquilinearForm)

Given a symmetric form `f`, returns the quadratic form `Q` defined by `Q(v) = f(v,v)/2`.
It is defined only in odd characteristic.
"""
function corresponding_quadratic_form(B::SesquilinearForm)
   @req B.descr==:symmetric "The form must be a symmetric form"
   @req characteristic(base_ring(B))!=2 "Corresponding quadratic form not uniquely determined"
   M = deepcopy(gram_matrix(B))
   l = inv(base_ring(B)(2))
   for i in 1:nrows(M)
      for j in i+1:nrows(M)
         M[j,i]=0
      end
      M[i,i]*=l
   end
   return quadratic_form(M)
end



########################################################################
#
# Fields of the variable
#
########################################################################

"""
    gram_matrix(B::SesquilinearForm)

Return the Gram matrix of a sesquilinear or quadratic form `B`.
"""
function gram_matrix(f::SesquilinearForm)
   isdefined(f,:matrix) && return f.matrix

   @req f.descr==:quadratic && isdefined(f,:pol) "Cannot determine Gram matrix"
   d = nvars(parent(f.pol))
   B = zero_matrix( base_ring(f.pol), d, d )
   V = collect(AbstractAlgebra.exponent_vectors(f.pol))
   C = collect(AbstractAlgebra.coefficients(f.pol))
   for i in 1:length(V)
      x = y = 0
      for j in 1:d
         if V[i][j] !=0
            x = j
            break
         end
      end
      for j in 1:d
         if V[i][d+1-j] !=0
            y = d+1-j
            break
         end
      end
      B[x,y] = C[i]
   end
   f.matrix = B
   return B
end

"""
    defining_polynomial(f::SesquilinearForm)

Return the polynomial that defines the quadratic form `f`.
"""
function defining_polynomial(f::SesquilinearForm)
   isdefined(f,:pol) && return f.pol

   @req f.descr == :quadratic "Polynomial defined only for quadratic forms"
   R = polynomial_ring(base_ring(f.matrix), nrows(f.matrix); cached=false)[1]
   p = zero(R)
   for i in 1:nrows(f.matrix), j in i:nrows(f.matrix)
      p += f.matrix[i,j] * R[i]*R[j]
   end
   f.pol = p
   return p
end


function assign_from_description(f::SesquilinearForm)
  if f.descr == :quadratic
    f.X = GAP.Globals.QuadraticFormByMatrix(map_entries(_ring_iso(f), gram_matrix(f)), codomain(_ring_iso(f)))
  elseif f.descr == :symmetric || f.descr == :alternating
    f.X = GAP.Globals.BilinearFormByMatrix(map_entries(_ring_iso(f), gram_matrix(f)), codomain(_ring_iso(f)))
  elseif f.descr == :hermitian
    f.X = GAP.Globals.HermitianFormByMatrix(map_entries(_ring_iso(f), gram_matrix(f)), codomain(_ring_iso(f)))
  else
    error("unsupported description")
  end
end


function _ring_iso(f::SesquilinearForm)
  if !isdefined(f, :ring_iso)
      f.ring_iso = iso_oscar_gap(base_ring(f))
  end
  return f.ring_iso
end

GAP.@install function GapObj(f::SesquilinearForm)
  if !isdefined(f, :X)
    assign_from_description(f)
  end
  return f.X
end


########################################################################
#
# Operations
#
########################################################################

function Base.:*(f::SesquilinearForm, l::FieldElem)
   @req l != 0 "Zero is not admitted"
   @req parent(l)==base_ring(f) "The scalar does not belong to the base ring of the form"
   if !isdefined(f,:matrix)
      return SesquilinearForm(l*f.pol, f.descr)
   else
      g = SesquilinearForm(l*gram_matrix(f), f.descr)
      if isdefined(f,:pol) g.pol=f.pol end
      return g
   end
end

Base.:*(l::FieldElem, f::SesquilinearForm) = f*l

function Base.:^(f::SesquilinearForm{T}, x::MatElem{T}; check=false) where T <: RingElem
   @req base_ring(f)==base_ring(x) "Incompatible base rings"
   @req nrows(gram_matrix(f))==nrows(x) "Incompatible dimensions"

   if check @assert rank(x)==nrows(x) "Matrix not invertible" end
   if f.descr==:hermitian
      m = x^-1*gram_matrix(f)*conjugate_transpose(x^-1)
   else
      m = x^-1*gram_matrix(f)*transpose(x^-1)
   end
   return SesquilinearForm(m, f.descr)
end

Base.:^(f::SesquilinearForm{T}, x::MatrixGroupElem{T}; check=false) where T <: RingElem = f^matrix(x)

function (f::SesquilinearForm{T})(v::AbstractAlgebra.Generic.FreeModuleElem{T},w::AbstractAlgebra.Generic.FreeModuleElem{T}) where T <: RingElem
   @req f.descr!=:quadratic "Quadratic forms requires only one argument"

   if f.descr==:hermitian
      w = conjugate_transpose(w.v)
   else
      w = transpose(w.v)
   end
   return v.v*gram_matrix(f)*w
end

function (f::SesquilinearForm{T})(v::AbstractAlgebra.Generic.FreeModuleElem{T}) where T <: RingElem
   @req f.descr==:quadratic "Sesquilinear forms requires two arguments"
   return v.v*gram_matrix(f)*transpose(v.v)
end



########################################################################
#
# Functionalities
#
########################################################################

"""
    radical(f::SesquilinearForm{T})

Return the radical of the sesquilinear form `f`, i.e. the subspace of all `v`
such that `f(u,v)=0` for all `u`.
The radical of a quadratic form `Q` is the set of vectors `v` such that `Q(v)=0`
 and `v` lies in the radical of the corresponding bilinear form.
"""
function radical(f::SesquilinearForm{T}) where T
   V = vector_space(base_ring(f), nrows(gram_matrix(f)) )
   R = GAP.Globals.RadicalOfForm(GapObj(f))
   GAPWrap.Dimension(R) == 0 && return sub(V, [])
   L = AbstractAlgebra.Generic.FreeModuleElem{T}[]
   for l in GAP.Globals.GeneratorsOfVectorSpace(R)
      v = V([preimage(_ring_iso(f), t) for t in l])
      push!(L,v)
   end
   return sub(V,L)
end

"""
    witt_index(f::SesquilinearForm{T})

Return the Witt index of the form induced by `f` on `V/Rad(f)`.
The Witt Index is the dimension of a maximal totally isotropic (singular for quadratic forms) subspace.
"""
witt_index(f::SesquilinearForm{T}) where T = GAP.Globals.WittIndex(GapObj(f))

"""
    is_degenerate(f::SesquilinearForm{T})

Return whether `f` is degenerate, i.e. `f` has nonzero radical. A quadratic
form is degenerate if the corresponding bilinear form is.
"""
function is_degenerate(f::SesquilinearForm{T}) where T
   f.descr != :quadratic && return det(gram_matrix(f))==0
   return det(gram_matrix(f)+transpose(gram_matrix(f)))==0
end

"""
    is_singular(Q::SesquilinearForm{T})

For a quadratic form `Q`, return whether `Q` is singular, i.e. `Q` has nonzero radical.
"""
function is_singular(f::SesquilinearForm{T}) where T
   @req f.descr == :quadratic "The form is not quadratic"
   return GAPWrap.IsSingularForm(GapObj(f))
end

