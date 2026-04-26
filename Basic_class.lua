--- An instantiatable class to inherit for defining new instantiatable classes classes
-- the "base" class. To make a new class call `leef.class.new(def)` or `leef.new_class:new_class(def)`
-- Also note that these classes will not have the type `table` but instead `class` when `type(object)` is called.
-- This is apart of the [LEEF-class](https://github.com/Luanti-Extended-Engine-Features/LEEF-class) module
--
-- @module class



--[[
 leef.class       <-namespace of class related functions
    new            --creates a new class with no parents (other than leef.Basic_class)
    is_class       --checks if is a class
    Basic_class      --leef.Basic_class

 leef.Basic_class   <-base class
    new            --instance of this class
    Basic_class      --new child class from this clas
]]

--TODO:
--make base classes protected by proxy and only moddable by the file they were declared in using debug library.
--allow








--=====================================================================================
--                                     Basic_class
--=====================================================================================
leef.Basic_class = {
    instance = false,
    --name = "leef_base_class",
    --__no_copy = true
}
local objects = {
    [leef.Basic_class] = "class"
}
setmetatable(objects, {
    __mode = 'kv' --allow garbage collection.
})

--- Indicates wether the object is an instance or the base class
-- @field instance

--- Quick dirty way to fix inheritence for old mods.
-- @field __legacy_inherit

--- Only present for instances: reference to the class from which this instance originates
-- @field base_class

--- Reference to the class from which THIS object (or it's base class) was inherited from. If table is inherited from multiple classes, than value is a dummy table which inherits values of all classes in the order inherted classes were put in.
-- @field parent_class

--- creates a new base class. Calls all constructors in the chain with def.instance=true. Can also be invoked by calling the class. Constructors will be called in reverse order (that way the first has the "final say" on all fields meaning highest priority)
-- @param ... _additional_ tables inherited by def
-- @param def the table containing the base definition of the class. This should contain a @{construct}
-- @return def a new base class
-- @function Basic_class:new_class
function leef.Basic_class.new_class(...)
    local inherited = {...}
    local nvargs = select("#", ...)

    --check for shit which will break other shit
    for i=1,nvargs do
        local v = inherited[i]
        assert(i==nvargs or (type(v)=="class"), "bad argument #"..i.." to new_class. Expected class, got "..type(v))
    end
    local lastvartype = type(inherited[nvargs])
    assert((lastvartype=="table") or (lastvartype=="class"), "bad argument (def) #"..nvargs.." to new_class. Expected table, got "..lastvartype)

    --initialize some variables
    local def = inherited[nvargs]
    inherited[nvargs] = nil
    local nparents = #inherited
    inherited = setmetatable({}, {__index=inherited, __newindex=function()error("cannot override parents table")end})

    --more error handling
    if not (objects[def] or (type(def) == "table")) then
        local info = debug.getinfo(2)
        error("class definition expected table, got `"..type(def).."` at class defined at "..info.short_src..":"..info.currentline)
    end
    if not def.name then
        local info = debug.getinfo(2)
        minetest.log("warning", "LEEF Basic_class.lua: no name defined for class defined at "..info.short_src..":"..info.currentline)
        --def.name = info.source..":"..info.currentline
    end


    --set variables in this table.
    objects[def] = "class"
    def.instance = false

    local self
    if (nparents==1) or def._legacy_inherit then
        self = inherited[1]
        assert(self)
        def.parent_class = self
    else
        print("dummy table", def.name)
        def.parent_class = setmetatable({}, {__index=function(t, k)
            if k=="name" then
                local new_list = {}
                for i, _ in pairs(inherited) do
                    table.insert(new_list, i)
                end
                return new_list
            elseif k=="parent_class" then
                return inherited
            end
            for i=1,nparents do
                if inherited[i][k] then
                    return inherited[i][k]
                end
            end
        end})
    end

    --construction chain- calls all parent (and sub-parent) construction methods by calling its parent's constructor method (which then calls the next parent's etc)
    function def._construct(parameters)
        for i=nparents, 1, -1 do
            if inherited[i]._construct then
                inherited[i]._construct(parameters)
            end
        end
        if rawget(def, "construct") then
            def.construct(parameters)
        end
    end


    --allow backwards compatibility. Legacy class calls it's own class constructor method
    if not def._legacy_inherit then
        function def._construct_new_class(parameters)
            --rawget because in a instance it may only be present in a hierarchy but not the table itself
            for i=nparents, 1, -1 do
                if inherited[i]._construct_new_class then
                    inherited[i]._construct_new_class(parameters)
                end
            end
            if rawget(def, "construct_new_class") then
                def.construct_new_class(parameters)
            end
        end
    end

    --iterate through table properties
    setmetatable(def, {
        __index = def.parent_class, --if multiple inheritence it will be set to the dummy object
        __call = function(tbl, ...)
            tbl:new(...)
        end
    })
    --call before new constructor is made
    if not def._legacy_inherit then
        for i=nparents, 1, -1 do
            if inherited[i]._construct_new_class then
                inherited[i]._construct_new_class(def, true)
            end
        end
    else
        def._construct(def)
    end

    return def
end

--- Called when an instance is created.
-- will be called for any classes which are children or grandchildren (etc) instances, aswell as instances of this class.
-- use this to instantiate arbitrary data like subclasses.
-- if the field "_legacy_inherit" is present, it will be called for new base classes as well as the initialization of this base class if present.
-- @param self the table (which would be def from new()).
-- @function Basic_class:construct

--- Called when a new child class is created is created.
-- will be called when a new child or grandchild (etc) class is created.
-- useful for instantiation of subtables or any other data.
-- @param self the table (which would be def from new()).
-- @function Basic_class:construct_new_class

--- creates an instance of the base class. Calls all constructors in the chain with def.instance=true
-- @param def field for the new instance of the class. If fields are not present they will refer to the base class's fields (if present in the base class).
-- @return self a new instance of the class.
-- @function Basic_class:new
function leef.Basic_class:new(def)
    objects[def] = "class"
    --if not def then def = {} else def = table.shallow_copy(def) end
    def.base_class = self
    def.instance = true
    --def.__no_copy = true
    function def:new_class()
        assert(false, "cannot inherit instantiated object")
    end
    def.inherit = def.new_class
    setmetatable(def, {__index = self})
    --call the construct chain for inherited objects, also important this is called after meta changes
    self._construct(def)
    return def
end

--- (for printing) dumps the variables of this class
-- @param self
-- @tparam bool dump_classes whether to also print/dump sub-classes.
-- @treturn string
-- @function Basic_class:dump
function leef.Basic_class:dump(dump_classes)
    local str = "{"
    for i, v in pairs(self) do
        if type(i) == "string" then
            str=str.."\n\t[\""..tostring(i).."\"] = "
        else
            str=str.."\n\t["..tostring(i).."] = "
        end
        if type(v) == "table" then
            local dumptable = dump(v):gsub("\n", "\n\t")
            str=str..dumptable
        elseif type(v) == "class" then
            if dump_classes then
                str = str..v:dump():gsub("\n", "\n\t")
            else
                str = str..string.sub(tostring(v), 7)..((v.name and ":<"..v.name..">:") or ":<nameless class>:")..((v.instance and "instance=true") or "instance=false")
            end
        else
            str = str..tostring(v)
        end
    end
    return str.."\n}"
end

--deprecated. The same as new_class, but has settings differences. Please don't use this :(
function leef.Basic_class:inherit(def)
    def._legacy_inherit = true
    self:new_class(def)
    return def
end



--=====================================================================================
--                                  additional API
--=====================================================================================

--- creates a new class
-- @param ... (optional) tables inherited by the new class, defaults to `leef.Basic_class`
-- @param def the table containing the base definition of the class. This should contain a @{construct}-- @treturn class
-- @function leef.class.new
function leef.class.new(...)
    if #{...}==1 then
        return leef.Basic_class.new_class(leef.Basic_class, ...)
    else
        return leef.Basic_class.new_class(...)
    end
end

--- checks if something is a class
-- @param value value
-- @treturn bool
-- @function leef.class.is_class
function leef.class.is_class(value)
    if objects[value] then return true end
    return false
end

local old_type = type
local objects_by_proxy = leef.class.proxy_table.objects_by_proxy
function type(...)
    local a = ...
    if objects[a] then return objects[a] end
    if objects_by_proxy[a] then return type(objects_by_proxy[a]) end
    return old_type(...)
end