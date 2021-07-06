const pyjlanytype = pynew()

pyjlany_repr(self) = Py("<jl $(repr(self))>")

pyjlany_str(self) = Py(string(self))

function pyjlany_getattr(self, k_::Py)
    k = Symbol(pyjl_attr_py2jl(pyconvert(String, k_)))
    Py(getproperty(self, k))
end
pyjl_handle_error_type(::typeof(pyjlany_getattr), self, exc) = pybuiltins.AttributeError

function pyjlany_setattr(self, k_::Py, v_::Py)
    k = Symbol(pyjl_attr_py2jl(pyconvert(String, k_)))
    v = pyconvert(Any, v_)
    setproperty!(self, k, v)
    Py(nothing)
end
pyjl_handle_error_type(::typeof(pyjlany_setattr), self, exc) = pybuiltins.AttributeError

pyjlany_dir(self) = pylist(pyjl_attr_jl2py(string(k)) for k in propertynames(self, true))

function pyjlany_call(self, args_::Py, kwargs_::Py)
    # TODO:
    # args = pyconvert(Vector{Any}, args_)
    # kwargs = pyconvert(Dict{Symbol,Any}, kwargs_)
    args = Any[]
    for a in args_
        push!(args, pyconvert(Any, a))
        pydel!(a)
    end
    kwargs = Dict{Symbol,Any}()
    for k in kwargs_
        v = kwargs_[k]
        push!(kwargs, pyconvert(Symbol, k) => pyconvert(Any, v))
        pydel!(k)
        pydel!(v)
    end
    Py(self(args...; kwargs...))
end
pyjl_handle_error_type(::typeof(pyjlany_call), self, exc) = exc isa MethodError && exc.f === self ? pybuiltins.TypeError : PyNULL

pyjlany_getitem(self, k_::Py) =
    if pyistuple(k_)
        k = pyconvert(Vector{Any}, k_)
        Py(self[k...])
    else
        k = pyconvert(Any, k_)
        Py(self[k])
    end
pyjl_handle_error_type(::typeof(pyjlany_getitem), self, exc) = exc isa BoundsError ? pybuiltins.IndexError : exc isa KeyError ? pybuiltins.KeyError : PyNULL

function pyjlany_setitem(self, k_::Py, v_::Py)
    v = pyconvert(Any, v_)
    if pyistuple(k_)
        k = pyconvert(Vector{Any}, k_)
        self[k...] = v
    else
        k = pyconvert(Any, k_)
        self[k] = v
    end
    Py(nothing)
end
pyjl_handle_error_type(::typeof(pyjlany_setitem), self, exc) = exc isa BoundsError ? pybuiltins.IndexError : exc isa KeyError ? pybuiltins.KeyError : PyNULL

function pyjlany_delitem(self, k_::Py)
    if pyistuple(k_)
        k = pyconvert(Vector{Any}, k_)
        delete!(self, k...)
    else
        k = pyconvert(Any, k_)
        delete!(self, k)
    end
    Py(nothing)
end
pyjl_handle_error_type(::typeof(pyjlany_delitem), self, exc) = exc isa BoundsError ? pybuiltins.IndexError : exc isa KeyError ? pybuiltins.KeyError : PyNULL

pyjlany_contains(self, v::Py) = Py(pyconvert(Any, v) in self)
pyjl_handle_error_type(::typeof(pyjlany_contains), self, exc) = exc isa MethodError && exc.f === in ? pybuiltins.TypeError : PyNULL

struct pyjlany_op{OP}
    op :: OP
end
(op::pyjlany_op)(self) = Py(op.op(self))
function (op::pyjlany_op)(self, other_::Py)
    if pyisjl(other_)
        other = pyjlvalue(other_)
        Py(op.op(self, other))
    else
        Py(pybuiltins.NotImplemented)
    end
end
function (op::pyjlany_op)(self, other_::Py, other2_::Py)
    if pyisjl(other_) && pyisjl(other2_)
        other = pyjlvalue(other_)
        other2 = pyjlvalue(other2_)
        Py(op.op(self, other, other2))
    else
        Py(pybuiltins.NotImplemented)
    end
end
pyjl_handle_error_type(op::pyjlany_op, self, exc) = exc isa MethodError && exc.f === op.op ? pybuiltins.TypeError : PyNULL

struct pyjlany_rev_op{OP}
    op :: OP
end
function (op::pyjlany_rev_op)(self, other_::Py)
    if pyisjl(other_)
        other = pyjlvalue(other_)
        Py(op.op(self, other))
    else
        Py(pybuiltins.NotImplemented)
    end
end
function (op::pyjlany_rev_op)(self, other_::Py, other2_::Py)
    if pyisjl(other_) && pyisjl(other2_)
        other = pyjlvalue(other_)
        other2 = pyjlvalue(other2_)
        Py(op.op(self, other, other2))
    else
        Py(pybuiltins.NotImplemented)
    end
end
pyjl_handle_error_type(op::pyjlany_rev_op, self, exc) = exc isa MethodError && exc.f === op.op ? pybuiltins.TypeError : PyNULL

pyjlany_name(self) = Py(string(nameof(self)))
pyjl_handle_error_type(::typeof(pyjlany_name), self, exc) = exc isa MethodError && exc.f === nameof ? pybuiltins.AttributeError : PyNULL

function pyjlany_display(self, mime_::Py)
    mime = pyconvertarg(Union{Nothing,String}, mime_, "mime")
    x = Utils.ExtraNewline(self)
    if mime === nothing
        display(x)
    else
        display(mime, x)
    end
    Py(nothing)
end

function pyjlany_help(self, mime_::Py)
    mime = pyconvertarg(Union{Nothing,String}, mime_, "mime")
    x = Utils.ExtraNewline(Docs.doc(self))
    if mime === nothing
        display(x)
    else
        display(mime, x)
    end
    Py(nothing)
end

function pyjlany_mimebundle(self, include::Py, exclude::Py)
    # TODO: use include/exclude
    mimes = Utils.mimes_for(self)
    # make the bundle
    ans = pydict()
    for m in mimes
        try
            io = IOBuffer()
            show(io, MIME(m), self)
            v = take!(io)
            ans[m] = vo = istextmime(m) ? pystr(String(v)) : pybytes(v)
            pydel!(vo)
        catch err
            # silently skip anything that didn't work
        end
    end
    return ans
end

function init_jlwrap_any()
    jl = pyjuliacallmodule
    filename = "$(@__FILE__):$(1+@__LINE__)"
    pybuiltins.exec(pybuiltins.compile("""
    class AnyValue(ValueBase):
        __slots__ = ()
        __module__ = "juliacall"
        def __repr__(self):
            if self._jl_isnull():
                return "<jl NULL>"
            else:
                return self._jl_callmethod($(pyjl_methodnum(pyjlany_repr)))
        def __str__(self):
            if self._jl_isnull():
                return "NULL"
            else:
                return self._jl_callmethod($(pyjl_methodnum(pyjlany_str)))
        def __getattr__(self, k):
            if k.startswith("__") and k.endswith("__"):
                raise AttributeError(k)
            else:
                return self._jl_callmethod($(pyjl_methodnum(pyjlany_getattr)), k)
        def __setattr__(self, k, v):
            try:
                ValueBase.__setattr__(self, k, v)
            except AttributeError:
                if k.startswith("__") and k.endswith("__"):
                    raise AttributeError(k)
                else:
                    self._jl_callmethod($(pyjl_methodnum(pyjlany_setattr)), k, v)
        def __dir__(self):
            return ValueBase.__dir__(self) + self._jl_callmethod($(pyjl_methodnum(pyjlany_dir)))
        def __call__(self, *args, **kwargs):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_call)), args, kwargs)
        def __len__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(length))))
        def __getitem__(self, k):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_getitem)), k)
        def __setitem__(self, k, v):
            self._jl_callmethod($(pyjl_methodnum(pyjlany_setitem)), k, v)
        def __delitem__(self, k):
            self._jl_callmethod($(pyjl_methodnum(pyjlany_delitem)), k)
        def __iter__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(Iterator))))
        def __reversed__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(reverse))))
        def __contains__(self, v):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_contains)), v)
        def __pos__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(+))))
        def __neg__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(-))))
        def __abs__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(abs))))
        def __invert__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(~))))
        def __add__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(+))), other)
        def __sub__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(-))), other)
        def __mul__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(*))), other)
        def __truediv__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(/))), other)
        def __floordiv__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(÷))), other)
        def __mod__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(%))), other)
        def __pow__(self, other, modulo=None):
            if modulo is None:
                return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(^))), other)
            else:
                return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(powermod))), other, modulo)
        def __lshift__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(<<))), other)
        def __rshift__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(>>))), other)
        def __and__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(&))), other)
        def __xor__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(⊻))), other)
        def __or__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(|))), other)
        def __radd__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(+))), other)
        def __rsub__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(-))), other)
        def __rmul__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(*))), other)
        def __rtruediv__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(/))), other)
        def __rfloordiv__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(÷))), other)
        def __rmod__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(%))), other)
        def __rpow__(self, other, modulo=None):
            if modulo is None:
                return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(^))), other)
            else:
                return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(powermod))), other, modulo)
        def __rlshift__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(<<))), other)
        def __rrshift__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(>>))), other)
        def __rand__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(&))), other)
        def __rxor__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(⊻))), other)
        def __ror__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_rev_op(|))), other)
        def __eq__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(==))), other)
        def __ne__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(!=))), other)
        def __le__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(≤))), other)
        def __lt__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(<))), other)
        def __ge__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(≥))), other)
        def __gt__(self, other):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(>))), other)
        def __hash__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_op(hash))))
        @property
        def __name__(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_name)))
        def _jl_raw(self):
            return self._jl_callmethod($(pyjl_methodnum(pyjlraw)))
        def _jl_display(self, mime=None):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_display)), mime)
        def _jl_help(self, mime=None):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_help)), mime)
        def _repr_mimebundle_(self, include=None, exclude=None):
            return self._jl_callmethod($(pyjl_methodnum(pyjlany_mimebundle)), include, exclude)
    """, filename, "exec"), jl.__dict__)
    pycopy!(pyjlanytype, jl.AnyValue)
end

pyjl(v) = pyjl(pyjlanytype, v)